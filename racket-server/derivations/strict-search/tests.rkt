#lang racket

(require racket/match
         rackunit
         redex/reduction-semantics
         (prefix-in direct: "../functional-search/direct-interpreter.rkt")
         (prefix-in strict: "source.rkt")
         (prefix-in refocused: "refocused.rkt")
         (prefix-in functional: "functional-machine.rkt")
         (prefix-in correspondence: "correspondence.rkt"))

(provide finite-goals)

;; Exhaustive by syntax size through four constructors.  Fresh is interpreted
;; from its actual body procedure; it is not silently collapsed into an atom.
(define (goals-of-size size)
  (match size
    [1 (list (direct:put 'A)
             (direct:Succeed 'success)
             (direct:FailGoal 'failure))]
    [_
     (append
      (append-map
       (lambda (body)
         (list (direct:Suspend body 'delay)
               (direct:Fresh 2 (lambda (_x _y) body) 'fresh)))
       (goals-of-size (sub1 size)))
      (append-map
       (lambda (pair)
         (match-define (list left right) pair)
         (list (direct:Conj left right 'conjunction)
               (direct:Disj left right 'choice)))
       (for*/list ([left-size (in-range 1 (sub1 size))]
                   [left (in-list (goals-of-size left-size))]
                   [right (in-list (goals-of-size (- size left-size 1)))])
         (list left right))))]))

(define finite-goals (append-map goals-of-size '(1 2 3 4)))

(define (check-refocused-trace configuration [fuel 2000])
  (match-define (refocused:Focus control frames) configuration)
  (define before (refocused:plug control frames))
  (match-define (refocused:Focus decomposed context) (refocused:decompose before))
  (check-equal? (refocused:plug decomposed context) before)
  (match (refocused:machine-step/tagged configuration)
    [#f
     (check-true (strict:observation-value? before))]
    [(list label (and next (refocused:Focus control* frames*)))
     (when (zero? fuel)
       (error 'check-refocused-trace "correspondence trace exhausted fuel"))
     (define after (refocused:plug control* frames*))
     (match label
       ["admin" (check-equal? after before)]
       [_
        (check-equal?
         (apply-reduction-relation/tag-with-names strict:strict-red before)
         (list (list label after)))])
     (check-refocused-trace next (sub1 fuel))]))

(define (check-functional-trace configuration [fuel 2000])
  (define before (correspondence:decode-configuration configuration))
  (cond
    [(functional:machine-final? configuration)
     (check-true (strict:observation-value? before))]
    [else
     (when (zero? fuel)
       (error 'check-functional-trace "correspondence trace exhausted fuel"))
     (define next (functional:machine-step configuration))
     (define after (correspondence:decode-configuration next))
     (unless (equal? before after)
       (check-equal?
        (map second
             (apply-reduction-relation/tag-with-names strict:strict-red before))
        (list after)))
     (check-functional-trace next (sub1 fuel))]))

(struct Engine (name run search) #:transparent)

(define engines
  (list
   (Engine 'direct direct:run direct:run-search)
   (Engine 'strict-reduction strict:run strict:run-search)
   (Engine 'refocused refocused:run refocused:run-search)
   (Engine 'cps functional:cps-run functional:cps-run-search)
   (Engine 'defunctionalized functional:run functional:run-search)))

(define (record-kernel events)
  (lambda (goal state)
    (match goal
      [(direct:Atom _ (and tag (or 'p 'q 'h 'continuation 'resumed)))
       (set-box! events (cons (list tag (direct:State-tag state))
                             (unbox events)))]
      [_ (void)])
    (direct:basic-kernel goal state)))

(define (identity-atom tag)
  (direct:Atom direct:success-outcome tag))

(define (fuel-exhausted? exception)
  (or (functional:exn:fail:fuel? exception)
      (and (exn:fail? exception)
           (regexp-match? #rx"fuel exhausted" (exn-message exception)))))

(define eager-sibling
  (direct:Disj
   (direct:put 'A)
   (direct:Conj
    (identity-atom 'p)
    (direct:Conj
     (identity-atom 'q)
     (direct:Suspend (identity-atom 'h) 'delay)
     'q-then-delay)
    'p-then-rest)
   'choice))

(define eager-bind
  (direct:Conj
   (direct:Disj (direct:put 'A) (direct:put 'B) 'choice)
   (direct:Conj
    (identity-atom 'continuation)
    (direct:Suspend (identity-atom 'resumed) 'delay)
    'continue-then-delay)
   'bind))

(define fresh-identity
  (direct:Fresh
   2
   (lambda (x y)
     (direct:Fresh
      1
      (lambda (z)
        (direct:Atom
         (lambda (state)
           (direct:success-outcome
            (struct-copy direct:State state
                         [substitution (list (list x z) (list y 'payload))]
                         [trail (list x y z)])))
         'remember-variables))
      'inner-fresh))
   'outer-fresh))

;; The source trace records semantic observer events after the corresponding
;; reduction.  Recording a terminating kernel is a diagnostic observation of
;; work order, not a side-effectful kernel admitted by the fusion conjecture.
(define (source-events goal)
  (define events (box '()))
  (define K
    (lambda (atomic state)
      (match atomic
        [(direct:Atom _ (and tag (or 'p 'q 'h)))
         (set-box! events (cons tag (unbox events)))]
        [_ (void)])
      (direct:basic-kernel atomic state)))
  (define relation (strict:make-strict-red K))
  (define (step computation [fuel 1000])
    (cond
      [(strict:observation-value? computation) (reverse (unbox events))]
      [(zero? fuel) (error 'source-events "source trace exhausted fuel")]
      [else
       (match (apply-reduction-relation/tag-with-names relation computation)
         [(list (list name next))
          (match (~a name)
            ["render-yield" (set-box! events (cons 'emit (unbox events)))]
            ["render-delay" (set-box! events (cons 'force (unbox events)))]
            ["render-one" (set-box! events (cons 'last (unbox events)))]
            ["render-empty" (set-box! events (cons 'done (unbox events)))]
            [_ (void)])
          (step next (sub1 fuel))]
         [other (error 'source-events "expected one reduction, got ~e" other)])]))
  (step `(render ,(strict:initial goal))))

(module+ test
  (check-equal? (length finite-goals) 171)

  (for ([goal (in-list (append finite-goals
                                (list direct:nested-rail-witness
                                      eager-sibling eager-bind fresh-identity)))]
        [index (in-naturals)])
    (define expected (direct:run goal))
    (for ([engine (in-list (cdr engines))])
      (test-case (format "~a agrees with direct interpreter, goal ~a"
                         (Engine-name engine) index)
        ;; Structural equality retains full State data, Empty's allocation
        ;; counter, exact answer order, Forced nodes, and Last versus Done.
        (check-equal? ((Engine-run engine) goal) expected))))

  (check-equal?
   (direct:frontier-shape (strict:run direct:nested-rail-witness))
   '(Forced (Forced (Forced (Forced (Emit A (Emit B (Last C))))))))

  (for ([goal (in-list (append finite-goals
                                (list direct:nested-rail-witness
                                      eager-sibling eager-bind)))]
        [index (in-naturals)])
    (test-case (format "refocused/source step correspondence, goal ~a" index)
      (check-refocused-trace (refocused:initial-machine goal)))
    (test-case (format "defunctionalized/source step correspondence, goal ~a" index)
      (define initial (functional:initial-machine goal #:render? #t))
      (check-equal? (correspondence:decode-configuration initial)
                    `(render ,(strict:initial goal)))
      (check-functional-trace initial)))

  (for ([engine (in-list engines)])
    (test-case (format "~a matures the right operand before returning"
                       (Engine-name engine))
      (define events (box '()))
      (void ((Engine-search engine) eager-sibling #:kernel (record-kernel events)))
      (check-equal? (reverse (unbox events)) '((p initial) (q initial))))

    (test-case (format "~a matures bind continuation and recursive residual"
                       (Engine-name engine))
      (define events (box '()))
      (void ((Engine-search engine) eager-bind #:kernel (record-kernel events)))
      (check-equal? (reverse (unbox events))
                    '((continuation A) (continuation B))))

    (test-case (format "~a does no work beneath Delay"
                       (Engine-name engine))
      (define events (box '()))
      (void ((Engine-search engine)
             (direct:Suspend (identity-atom 'h) 'delay)
             #:kernel (record-kernel events)))
      (check-equal? (unbox events) '()))

    (test-case (format "~a threads fresh variables from a nonzero counter"
                       (Engine-name engine))
      (define result
        ((Engine-run engine) fresh-identity
                             #:state (struct-copy direct:State (direct:empty-state)
                                                  [next 7])))
      (match result
        [(direct:Last (direct:Answer state))
         (check-equal? (direct:State-next state) 10)
         (check-equal? (direct:State-trail state)
                       (list (direct:LVar 7) (direct:LVar 8) (direct:LVar 9)))
         (check-equal? (direct:State-substitution state)
                       (list (list (direct:LVar 7) (direct:LVar 9))
                             (list (direct:LVar 8) 'payload)))]
        [_ (fail-check (format "expected one fresh answer, got ~e" result))]))

    (test-case (format "~a retains an eager Yield tail" (Engine-name engine))
      (define events (box '()))
      (void ((Engine-search engine)
             (direct:Disj
              (direct:Disj (direct:put 'A) (identity-atom 'p) 'inner)
              (identity-atom 'q)
              'outer)
             #:kernel (record-kernel events)))
      (check-equal? (reverse (unbox events)) '((p initial) (q initial)))))

  (check-equal? (source-events eager-sibling) '(p q emit force h last))

  ;; These source-level probes distinguish a pending computation under Yield
  ;; from a mature Search and make the Delay context barrier executable.
  (define state (direct:empty-state))
  (define pending `(eval ,(strict:encode-goal (identity-atom 'p)) ,state))
  (check-false (strict:search-value? `(Yield ,state ,pending)))
  (check-true (strict:search-value? `(Delay ,pending)))
  (define yield-events (box '()))
  (check-equal?
   (strict:normalize `(Yield ,state ,pending) #:kernel (record-kernel yield-events))
   `(Yield ,state (One ,state)))
  (check-equal? (reverse (unbox yield-events)) '((p initial)))
  (define delay-events (box '()))
  (check-equal?
   (strict:normalize `(Delay ,pending) #:kernel (record-kernel delay-events))
   `(Delay ,pending))
  (check-equal? (unbox delay-events) '())

  ;; The host Fresh callback returns immediately; its expansion diverges in
  ;; object-level eval, where every machine can enforce a finite step budget.
  ;; This exhibits why a guarded fusion hypothesis is necessary without
  ;; introducing relcalls or a non-terminating host kernel.
  (define (omega) (direct:Fresh 0 omega 'unguarded))
  (define unguarded-right
    (direct:Disj (direct:put 'A) (omega) 'strict-right))
  (define guarded-right
    (direct:Disj (direct:put 'A)
                 (direct:Suspend (omega) 'guard)
                 'guarded-right))
  (for ([engine (in-list engines)])
    (test-case (format "~a reaches an explicit Delay before expanding omega"
                       (Engine-name engine))
      (check-not-exn (lambda () ((Engine-search engine) guarded-right)))))
  (for ([engine (in-list (cdr engines))])
    (test-case (format "~a cannot return A across an unguarded right operand"
                       (Engine-name engine))
      (check-exn fuel-exhausted?
                 (lambda () ((Engine-search engine) unguarded-right #:fuel 64))))
    (test-case (format "~a spends fuel after forcing guarded omega"
                       (Engine-name engine))
      (check-exn fuel-exhausted?
                 (lambda () ((Engine-run engine) guarded-right #:fuel 64)))))

  ;; The source and both strict derivations intentionally stop before relcall
  ;; policy; the direct interpreter alone has a relation environment.
  (for ([engine (in-list (cdr engines))])
    (check-exn #rx"[Rr]elcall|Call|call"
               (lambda () ((Engine-run engine) (direct:Call 'omega '() 'call))))))
