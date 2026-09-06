#lang racket

(require rackunit redex/reduction-semantics
         (prefix-in d: "../../functional-search/direct-interpreter.rkt")
         (prefix-in a: "01-anf.rkt") (prefix-in c: "02-cps.rkt")
         (prefix-in f: "03-defunc.rkt") (prefix-in m: "04-machine.rkt")
         (prefix-in r: "05-registers.rkt") (prefix-in q: "correspondence.rkt")
         (prefix-in old: "../functional-machine.rkt")
         (prefix-in source: "../source.rkt") (prefix-in refocus: "../refocused.rkt")
         "03-data.rkt" "runtime.rkt" "derive.rkt" "../tests.rkt")

(define corpus
  (append finite-goals
          (list d:nested-rail-witness
                (d:Disj (d:Disj (d:put 'A) (d:put 'B) 'left-chunk) (d:put 'C) 'outer)
                (d:Conj (d:Disj (d:put 'A) (d:put 'B) 'answers)
                        (d:Disj (d:put 'p) (d:Suspend (d:put 'q) 'pause) 'body)
                        'bind-more))))

(define (mature-shape search)
  (match search
    [(d:Empty next) `(Empty ,next)]
    [(d:One state) `(One ,state)]
    [(d:Yield state rest) `(Yield ,state ,(mature-shape rest))]
    [(d:Delay _) 'Delay]))

(define runners (list a:run c:run f:run m:run r:run))
(define search-runners (list a:run-search c:run-search f:run-search m:run-search r:run-search))

(define (run/events runner goal state)
  (define events '())
  (define (K goal incoming)
    (define tag
      (match goal
        [(d:Atom _ tag) tag] [(d:Succeed tag) tag] [(d:FailGoal tag) tag]))
    (set! events (cons (list tag incoming) events))
    (d:basic-kernel goal incoming))
  (define result (runner goal #:kernel K #:state state))
  (values result (reverse events)))

(define reached-kinds '())
(define reached-points '())
(define (remember! configuration)
  (match configuration
    [(m:Call pc operands)
     (unless (member pc reached-points) (set! reached-points (cons pc reached-points)))
     (define kind (object-name (last operands)))
     (unless (member kind reached-kinds) (set! reached-kinds (cons kind reached-kinds)))]
    [_ (void)]))

(define (check-path current bank [fuel 10000])
  (remember! current)
  (check-equal? (r:decode bank) current)
  (check-equal? (r:decode (r:from-machine current)) current)
  (match current
    [(m:Halted _)
     (define count (r:Registers-steps bank))
     (check-false (m:step current))
     (check-false (r:step! bank))
     (check-equal? (r:Registers-steps bank) count)]
    [(m:Call pc _)
     (when (zero? fuel) (error 'check-path "test path budget exhausted"))
     (define next (m:step current))
     (check-true (r:step! bank))
     (check-equal? (r:decode bank) next)
     (define before-old (q:decode-machine current))
     (define after-old (q:decode-machine next))
     (check-equal? after-old
                   (if (q:extra-admin? current)
                       before-old
                       (old:machine-step before-old)))
     (define before-source (q:decode-source current))
     (define after-source (q:decode-source next))
     (match pc
       [(or 'continue/d 'return/d) (check-equal? after-source before-source)]
       [_
        ;; Classify by the actual program point, never by term inequality.
        ;; In particular eval/Fresh may be a genuine source self-loop.
        (define edges
          (apply-reduction-relation/tag-with-names source:strict-red before-source))
        (match-define (list (list label expected)) edges)
        (check-equal? after-source expected)
        (define focus (refocus:decompose before-source))
        (match-define (list focused-label (refocus:Focus control frames))
          (refocus:machine-step/tagged focus))
        (check-equal? focused-label label)
        (check-equal? (refocus:plug control frames) after-source)])
     (check-path next bank (sub1 fuel))]))

(module+ test
  (test-case "generated machine and registers reproduce their source exactly"
    (check-true (check-generated!))
    (check-equal? (map car (control-signatures))
                  '(eval/d merge/d bind/d continue/d force/d render/d return/d)))

  (test-case "tail reifier rejects hidden non-tail control calls"
    (define (jump pc args) `(Call ,pc ,args))
    (define (halt value) `(Halted ,value))
    (check-exn exn:fail? (lambda () (transform-tail '(list (eval/d x)) '(eval/d) jump halt)))
    (check-exn exn:fail? (lambda () (transform-tail '(map eval/d xs) '(eval/d) jump halt)))
    (check-equal? (transform-tail '(if ready? (eval/d x) answer) '(eval/d) jump halt)
                  '(if ready? (Call eval/d (x)) (Halted answer))))

  (for ([goal (in-list corpus)] [index (in-naturals)])
    (test-case (format "all five stages: exact observation and atomic work ~a" index)
      (define state (struct-copy d:State (d:empty-state) [next 5]))
      (define-values (expected events) (run/events d:run goal state))
      (for ([runner (in-list runners)])
        (define-values (result observed) (run/events runner goal state))
        (check-equal? result expected)
        (check-equal? observed events))
      (define-values (boundary boundary-events) (run/events d:run-search goal state))
      (for ([runner (in-list search-runners)])
        (define-values (result observed) (run/events runner goal state))
        (check-equal? (mature-shape result) (mature-shape boundary))
        (check-equal? observed boundary-events)))
    (test-case (format "every edge: generated registers/machine, older AM, R and refocusing ~a" index)
      (define initial (m:initial goal))
      (check-path initial (r:from-machine initial))))

  (test-case "every CPS continuation family and every control point is reached"
    (for ([kind '(KDone KConj KDisjLeft KDisjRight KYield KBindHead KBindTail
                       KMergeForced KBindForced KRun KEmit KRenderForced KForced)])
      (check-not-false (member kind reached-kinds)))
    (for ([pc '(eval/d merge/d bind/d continue/d force/d render/d return/d)])
      (check-not-false (member pc reached-points))))

  (test-case "CPS Delay resumptions accept and tail-call an arbitrary continuation"
    (define state (d:empty-state))
    (define (capture value) `(captured ,(mature-shape value)))
    (for ([goal (in-list
                (list (d:Suspend (d:put 'A) 'eval)
                      (d:Disj (d:Suspend (d:put 'A) 'eval) (d:put 'B) 'merge)
                      (d:Conj (d:Suspend (d:put 'A) 'eval) (d:put 'B) 'bind)))])
      (match-define (d:Delay direct-rest) (d:run-search goal #:state state))
      (match-define (d:Delay cps-rest) (c:run-search goal #:state state))
      (check-true (procedure-arity-includes? cps-rest 1))
      (check-false (procedure-arity-includes? cps-rest 0))
      (check-equal? (cps-rest capture) (capture (direct-rest)))
      ;; Reusing a semantic resumption does not reuse the observer continuation.
      (check-equal? (cps-rest mature-shape) (mature-shape (direct-rest)))))

  (test-case "strict disjunction retains its entire mature left chunk"
    (define goal
      (d:Disj (d:Disj (d:put 'A) (d:put 'B) 'chunk)
              (d:Conj (d:put 'p) (d:put 'q) 'sibling) 'choice))
    (define (seek current)
      (match current
        [(m:Call 'eval/d (list (d:Conj _ _ _) _ _ (KDisjRight chunk _)))
         (check-equal? (match chunk [(d:Yield a (d:One b)) (list (d:State-tag a) (d:State-tag b))])
                       '(A B))]
        [(m:Halted _) (fail-check "lost the mature left chunk")]
        [_ (seek (m:step current))]))
    (seek (m:initial goal)))

  (test-case "saved Delay closures preserve their kernel across later rendering"
    (define (K request state)
      (match request
        [(d:Succeed _) (d:success-outcome (struct-copy d:State state [tag 'custom]))]
        [_ (d:failure-outcome)]))
    (define goal (d:Suspend (d:Succeed 'later) 'delay))
    (define search (c:run-search goal #:kernel K))
    (check-equal? (c:render/k search K values) (d:run goal #:kernel K))
    (check-equal? (f:run goal #:kernel K) (r:run goal #:kernel K)))

  (test-case "native functional outcomes are produced and selected eagerly"
    (for ([runner (in-list (cons d:run runners))])
      (define events '())
      (define (record! event) (set! events (cons event events)))
      (define (atom label success?)
        (d:Atom
         (lambda (state)
           (record! `(produce ,label))
           (define state* (struct-copy d:State state [tag label]))
           (lambda (failure success)
             (record! `(select ,label))
             (if success? (success state*) (failure))))
         label))
      (define state (struct-copy d:State (d:empty-state) [next 7]))
      (define result
        (runner (d:Disj (atom 'left #t) (atom 'right #f) 'choice) #:state state))
      (check-equal? (reverse events)
                    '((produce left) (select left) (produce right) (select right)))
      (check-equal? result
                    (d:Emit (d:Answer (struct-copy d:State state [tag 'left]))
                            (d:Done 7)))))

  (test-case "legacy raw kernel and Atom results are not converted"
    (for ([runner (in-list (cons d:run runners))])
      (for ([raw (in-list (list #f (d:empty-state)))])
        (check-exn exn:fail:contract?
                   (lambda () (runner (d:Succeed 'raw) #:kernel (lambda (_ __) raw))))
        (check-exn exn:fail:contract?
                   (lambda () (runner (d:Atom (lambda (_) raw) 'raw)))))))

  (test-case "fresh variables and their lexical environment survive suspension"
    ;; This body creates new host closures on each evaluation. Compare exact
    ;; States, rather than claiming literal equality of those procedures.
    (define goal
      (d:Fresh
       2
       (lambda (x y)
         (d:Suspend
          (d:Fresh
           1
           (lambda (z)
             (d:Atom
              (lambda (state)
                (d:success-outcome
                 (struct-copy d:State state
                              [tag (map d:LVar-level (list x y z))])))
              'capture))
           'inner)
          'pause))
       'outer))
    (define state (struct-copy d:State (d:empty-state) [next 5]))
    (define expected (d:run goal #:state state))
    (match-define (d:Forced (d:Last (d:Answer final))) expected)
    (check-equal? (d:State-next final) 8)
    (check-equal? (d:State-tag final) '(5 6 7))
    (for ([runner (in-list runners)])
      (check-equal? (runner goal #:state state) expected)))

  (test-case "private banks can interleave without sharing live registers"
    (define left (r:initial d:nested-rail-witness))
    (define right (r:initial (d:put 'separate)))
    (define (interleave)
      (define left-live? (r:step! left))
      (define right-live? (r:step! right))
      (when (or left-live? right-live?) (interleave)))
    (interleave)
    (check-equal? (r:Registers-r0 left) (d:run d:nested-rail-witness))
    (check-equal? (r:Registers-r0 right) (d:run (d:put 'separate)))
    (check-false (r:Registers-r1 left))
    (check-false (r:Registers-r2 left))
    (check-false (r:Registers-r3 left)))

  (test-case "unguarded eager work remains an eval self-loop, not an emitted answer"
    (define omega (d:Fresh 0 (lambda () omega) 'omega))
    (define goal (d:Disj (d:put 'A) omega 'strict-choice))
    (define bank (r:initial goal))
    (define interrupted
      (with-handlers ([exn:fail:budget? values]) (r:drive! bank #:fuel 40)))
    (check-true (exn:fail:budget? interrupted))
    (define current (exn:fail:budget-configuration interrupted))
    (check-equal? (m:Call-pc current) 'eval/d)
    (check-false (q:extra-admin? current))
    (check-equal? (m:step current) current)
    (check-equal? (apply-reduction-relation/tag-with-names source:strict-red
                                                         (q:decode-source current))
                  (list (list "eval-fresh" (q:decode-source current)))))

  (test-case "object Delay terminates eager evaluation even above divergent work"
    (define omega (d:Fresh 0 (lambda () omega) 'omega))
    (define goal (d:Suspend omega 'barrier))
    (for ([runner (in-list search-runners)])
      (check-equal? (mature-shape (runner goal)) 'Delay))
    (check-exn exn:fail:budget? (lambda () (m:run goal #:fuel 25)))
    (check-exn exn:fail:budget? (lambda () (r:run goal #:fuel 25))))

  (test-case "invalid budgets and out-of-scope calls fail explicitly"
    (check-exn exn:fail:contract? (lambda () (m:run (d:Succeed 'ok) #:fuel -1)))
    (check-exn exn:fail:contract? (lambda () (r:run (d:Succeed 'ok) #:fuel 1/2)))
    (for ([runner (in-list runners)])
      (check-exn exn:fail? (lambda () (runner (d:Call 'unimplemented '() 'call)))))))
