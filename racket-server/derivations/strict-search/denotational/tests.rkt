#lang racket

(require rackunit racket/engine
         (prefix-in s: "semantics.rkt")
         (prefix-in b: "bridge.rkt")
         "observe.rkt"
         (prefix-in d: "../../functional-search/direct-interpreter.rkt")
         (prefix-in r: "../a7-a9/05-registers.rkt")
         (only-in "../tests.rkt" finite-goals))

(define corpus
  (append finite-goals
          (list d:nested-rail-witness
                (d:Disj (d:Disj (d:put 'A) (d:put 'B) 'chunk)
                        (d:Conj (d:put 'p) (d:put 'q) 'right) 'outer)
                (d:Conj (d:Disj (d:put 'A) (d:put 'B) 'answers)
                        (d:Disj (d:put 'p) (d:Suspend (d:put 'q) 'pause) 'body)
                        'bind-more))))

(define (direct-snapshot search [depth 0])
  (match search
    [(d:Empty next) `(Empty ,next)]
    [(d:One state) `(One ,state)]
    [(d:Yield state rest) `(Yield ,state ,(direct-snapshot rest depth))]
    [(d:Delay resume)
     `(Delay ,(if (zero? depth) 'Unforced (direct-snapshot (resume) (sub1 depth))))]))

(define (with-events runner goal state)
  (define events '())
  (define (K request incoming)
    (define tag
      (match request [(d:Succeed tag) tag] [(d:FailGoal tag) tag] [(d:Atom _ tag) tag]))
    (set! events (cons (list tag incoming) events))
    (d:basic-kernel request incoming))
  (define result (runner goal #:kernel K #:state state))
  (values result (reverse events)))

(define (native-run goal #:kernel K #:state state)
  (b:reify-frontier (s:run (b:denote goal) #:kernel K #:state state)))
(define (native-search goal #:kernel K #:state state)
  (s:run-search (b:denote goal) #:kernel K #:state state))

;; Bounded host execution is solely a test harness. The semantic program has
;; no fuel and produces no artificial Empty/Done when an observation diverges.
(define (check-running thunk)
  (define computation (engine (lambda (_enable-stop) (thunk))))
  (dynamic-wind void
                (lambda () (check-false (engine-run 20 computation)))
                (lambda () (engine-kill computation))))

(module+ test
  (for* ([goal (in-list corpus)]
         [next (in-list '(0 7))])
    (test-case (format "functional denotation/direct/register, next=~a: ~s" next goal)
      (define state (struct-copy d:State (d:empty-state) [next next]))
      (define-values (expected expected-events) (with-events d:run goal state))
      (define-values (actual events) (with-events native-run goal state))
      (check-equal? actual expected)
      (check-equal? events expected-events)
      (check-equal? actual (r:run goal #:state state))
      (define-values (boundary boundary-events) (with-events d:run-search goal state))
      (define-values (search search-events) (with-events native-search goal state))
      (check-true (procedure-arity-includes? search 4))
      (check-false (procedure-arity-includes? search 0))
      (check-equal? (snapshot search) (direct-snapshot boundary))
      (check-equal? search-events boundary-events)
      ;; Extensional representation checks preserve Delay without forcing it
      ;; during either conversion, then compare the same finite unfoldings.
      (define pure (d:run-search goal #:state state))
      (define reflected (b:reflect-search pure))
      (check-equal? (snapshot reflected #:delays 8) (direct-snapshot pure 8))
      (check-equal? (direct-snapshot (b:reify-search reflected) 8)
                    (direct-snapshot pure 8))
      (check-equal? (b:run goal #:state state) expected)))

  (test-case "native Goal, Search and readback values are functions"
    (define goal (s:disj (s:succeed) (s:fail)))
    (check-true (procedure-arity-includes? goal 2))
    (define search (s:run-search goal))
    (define frontier (s:render search))
    (check-true (procedure-arity-includes? frontier 4))
    (check-equal? (d:frontier-shape (b:reify-frontier frontier)) '(Emit initial (Done 0)))
    (s:case-search
     search
     (lambda (_) (fail-check "expected Yield"))
     (lambda (_) (fail-check "expected Yield"))
     (lambda (_state rest)
       (check-true (procedure-arity-includes? rest 4))
       (check-false (procedure-arity-includes? rest 0)))
     (lambda (_) (fail-check "expected Yield"))))

  (test-case "Scott constructor lambdas do not delay eager sibling work"
    (define events '())
    (define (work tag)
      (s:atom (lambda (state)
                (set! events (append events (list tag)))
                (s:success-outcome state))
              tag))
    (define goal
      (s:disj (work 'A)
              (s:conj (work 'p) (s:conj (work 'q) (s:suspend (work 'h))))))
    (define search (s:run-search goal))
    ;; No eliminator has been called by this observer yet.
    (check-equal? events '(A p q))
    (define reified (b:reify-search search))
    (check-equal? events '(A p q))
    (define reflected (b:reflect-search reified))
    (check-equal? events '(A p q))
    (void (s:render reflected))
    (check-equal? events '(A p q h)))

  (test-case "bind evaluates both continuation results before resuming either"
    (define events '())
    (define (put tag)
      (s:atom (lambda (state) (s:success-outcome (struct-copy d:State state [tag tag])))
              tag))
    (define continue
      (s:conj
       (s:atom (lambda (state)
                 (set! events (append events (list (d:State-tag state))))
                 (s:success-outcome state)))
       (s:suspend
        (s:atom (lambda (state)
                  (set! events (append events '(resumed)))
                  (s:success-outcome state))))))
    (define search (s:run-search (s:conj (s:disj (put 'A) (put 'B)) continue)))
    (check-equal? events '(A B))
    (void (s:render search))
    (check-equal? events '(A B resumed resumed)))

  (test-case "fresh failure retains the exact allocation supply"
    (define state (struct-copy d:State (d:empty-state) [next 7]))
    (define goal (s:fresh 3 (lambda (_a _b _c) (s:fail))))
    (check-equal? (snapshot (s:run-search goal #:state state)) '(Empty 10))
    (check-equal? (b:reify-frontier (s:run goal #:state state)) (d:Done 10)))

  (test-case "fresh callback and capture are deferred until the goal runs"
    (define called? #f)
    (define goal
      (d:Fresh 2
               (lambda (x y)
                 (set! called? #t)
                 (d:Suspend
                  (d:Fresh 1
                           (lambda (z)
                             (d:Atom
                              (lambda (state)
                                (s:success-outcome
                                 (struct-copy d:State state
                                              [tag (map d:LVar-level (list x y z))])))
                              'capture))
                           'inner)
                  'delay))
               'outer))
    (define meaning (b:denote goal))
    (check-false called?)
    (define result
      (b:reify-frontier (s:run meaning #:state (struct-copy d:State (d:empty-state) [next 5]))))
    (check-true called?)
    (match-define (d:Forced (d:Last (d:Answer final))) result)
    (check-equal? (d:State-next final) 8)
    (check-equal? (d:State-tag final) '(5 6 7)))

  (test-case "saved Delay captures the kernel and supports independent reuse"
    (define (K request state)
      (match request
        [(d:Succeed _) (s:success-outcome (struct-copy d:State state [tag 'custom]))]
        [_ (s:failure-outcome)]))
    (define search (s:run-search (s:suspend (s:succeed)) #:kernel K))
    (check-equal? (snapshot search) '(Delay Unforced))
    (for ([_ (in-range 2)])
      (check-equal? (d:frontier-shape (b:reify-frontier (s:render search)))
                    '(Forced (Last custom)))))

  (test-case "native kernel outcomes select a handler without replaying kernel work"
    (define calls 0)
    (define initial (struct-copy d:State (d:empty-state) [next 7]))
    (define final (struct-copy d:State initial [tag 'native] [next 12]))
    (define (K request _state)
      (set! calls (add1 calls))
      (match request
        ['pass (s:success-outcome final)]
        ['reject (s:failure-outcome)]))
    (define success (K 'pass initial))
    (define failure (K 'reject initial))
    (check-equal? calls 2)
    (for ([_ (in-range 2)])
      (check-eq? (success (lambda () (fail-check "unexpected failure")) values) final)
      (check-equal? (failure (lambda () 'failed)
                             (lambda (_) (fail-check "unexpected success")))
                    'failed))
    (check-equal? calls 2)
    (define search (s:run-search (s:atomic 'pass) #:kernel K #:state initial))
    (check-equal? calls 3)
    (check-equal? (snapshot search) `(One ,final))
    (check-equal? (snapshot search) `(One ,final))
    (check-equal? calls 3)
    (check-equal? (snapshot (s:run-search (s:atomic 'reject) #:kernel K #:state initial))
                  '(Empty 7))
    (check-equal? calls 4))

  (test-case "basic kernel returns the Atom's functional outcome unchanged"
    (define calls 0)
    (define initial (d:empty-state))
    (define success (s:success-outcome initial))
    (define failure (s:failure-outcome))
    (define (pass state)
      (set! calls (add1 calls))
      (check-eq? state initial)
      success)
    (define outcome (d:basic-kernel (d:Atom pass 'pass) initial))
    (check-eq? outcome success)
    (check-equal? calls 1)
    (for ([_ (in-range 2)])
      (check-eq? (outcome (lambda () (fail-check "unexpected failure")) values) initial))
    (check-equal? calls 1)
    (check-eq? (d:basic-kernel (d:Atom (lambda (_) failure) 'reject) initial) failure)
    (check-equal? (snapshot (s:run-search (s:atom pass) #:state initial)) `(One ,initial))
    (check-equal? calls 2))

  (test-case "syntax bridge shares native kernel outcomes across Delay forcing"
    (define (K request state)
      (match request
        [(d:Succeed _) (s:success-outcome (struct-copy d:State state [tag 'custom] [next 13]))]
        [(d:FailGoal _) (s:failure-outcome)]))
    (define goal
      (d:Disj (d:Suspend (d:Succeed 'custom) 'pause) (d:FailGoal 'reject) 'choice))
    (check-equal? (b:run goal #:kernel K) (d:run goal #:kernel K))
    (check-equal? (direct-snapshot (b:run-search goal #:kernel K) 3)
                  (direct-snapshot (d:run-search goal #:kernel K) 3)))

  (define omega (s:fix-goal (lambda (self) self)))
  (define (answers-functional self) (s:disj (s:succeed) (s:suspend self)))
  (define answers (s:fix-goal answers-functional))

  (test-case "a productive fixed point has inspectable infinite Search prefixes"
    (define (direct-loop)
      (d:Disj (d:Succeed 'succeed)
              (d:Suspend (d:Fresh 0 direct-loop 'unfold) 'suspend) 'disj))
    (for ([depth (in-range 8)])
      (check-equal? (snapshot (s:run-search answers) #:delays depth)
                    (direct-snapshot (d:run-search (direct-loop)) depth))))

  (test-case "finite fixed-point unfoldings stabilize each tested observation"
    (define (unfold count)
      (if (zero? count) omega (answers-functional (unfold (sub1 count)))))
    (for ([depth (in-range 8)])
      (check-equal? (snapshot (s:run-search (unfold (add1 depth))) #:delays depth)
                    (snapshot (s:run-search answers) #:delays depth))))

  (test-case "least fixed point of identity diverges; eager constructors propagate it"
    (check-running (lambda () (s:run-search omega)))
    (check-running (lambda () (s:run-search (s:disj (s:succeed) omega))))
    (check-running (lambda () (s:yield-search (d:empty-state) (s:run-search omega))))
    (define delayed (s:run-search (s:suspend omega)))
    (check-equal? (snapshot delayed) '(Delay Unforced))
    (check-running (lambda () (snapshot delayed #:delays 1)))
    ;; A productive infinite Search need not have a finite complete readback.
    (check-running (lambda () (s:run answers))))

  (test-case "native constructor boundary and inspection errors remain explicit"
    (check-exn exn:fail:contract? (lambda () (snapshot (s:empty-search 0) #:delays -1)))
    (check-exn exn:fail:contract? (lambda () (s:run-search (s:fresh -1 values))))
    (check-exn exn:fail? (lambda () (s:run-search (s:succeed) #:kernel (lambda (_g _s) 'bad))))
    (check-exn exn:fail:contract? (lambda () (s:run-search (s:atom (lambda (_) #f)))))
    (check-exn exn:fail:contract? (lambda () (s:run-search (s:atom values))))
    (check-exn exn:fail? (lambda () (b:denote (d:Call 'later '() 'call))))))
