#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "./core-stage-empty-frame-fixture.rkt"
         "./core-stage-schema-consumer-fixture.rkt")

(provide CORE-STAGE-SCHEMA-TESTS)

(define EMPTY-STATE
  (term (box 0 () () () (label "state"))))

(define-test-suite CORE-STAGE-SCHEMA-TESTS
  (test-case "a foreign interface generates an ordinary D artifact"
    (check-true
     (redex-match?
      foreign-core-D-lang
      D
      (term
       (DecWork
        (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
        (More hole)))))
    (check-equal?
     (judgment-holds
      (foreign-core-decompose
       (More (Work 0 (succeed (label "yes")) ,EMPTY-STATE))
       D)
      D)
     (list
      (term
       (DecWork
        (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
        (More hole))))))

  (test-case "private rule helpers survive an adversarial module boundary"
    (define allocation-D
      (term
       (DecAllocate
        (Work
         0
         (∃ (x:a)
            (x:a =? (nat 7) (label "body"))
            (label "fresh"))
         ,EMPTY-STATE)
        (More hole))))
    (check-equal?
     (judgment-holds
      (foreign-core-contract ,allocation-D C)
      C)
     (list
      (term
       (ContractWork
        allocate-fresh
        (Work
         1
         (0 =? (nat 7) (label "body"))
         (box 1 () () () (label "state")))
        (More hole)))))

    ;; These premises use the generated private walk/unify/store helpers, not
    ;; merely the fixture's explicitly declared allocation helpers.
    (define unify-D
      (term
       (DecWork
        (Work
         1
         (0 =? (nat 9) (label "bind"))
         (box 1 () () () (label "state-1")))
        (More hole))))
    (check-equal?
     (judgment-holds (foreign-core-contract ,unify-D C) C)
     (list
      (term
       (ContractWork
        unify-success
        (Returned
         1
         (box
          1
          ((0 (nat 9)))
          ()
          ((0 =? (nat 9) (label "bind")))
          (label "state-1")))
        (More hole)))))

    (define focused
      (term (Work 0 (succeed (label "focused")) ,EMPTY-STATE)))
    (define focus (term (More hole)))
    (check-equal?
     (foreign-interface-focus-roundtrip focused focus)
     (list focused focus))
    (check-equal?
     (foreign-interface-Q (term (More ,focused)))
     (term (More ,focused))))

  (test-case "selected phase arrows and Z/M steppers are native"
    (define source-D
      (term
       (DecWork
        (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
        (More hole))))
    (define source-Z
      (term (foreign-core-refocus-phase ,source-D)))
    (define source-M
      (term (foreign-core-machineize ,source-Z)))
    (define source-B
      (term (foreign-core-compress ,source-M)))
    (check-equal?
     source-Z
     (term
      (ZWork
       (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
       (More hole))))
    (check-equal?
     source-M
     (term
      (MWork
       (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
       (More hole))))
    (check-equal?
     source-B
     (term
      (BRun
       (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
       (More hole))))
    (check-equal?
     (judgment-holds
      (foreign-core-Z-step/direct ,source-Z RuleName Z)
      (RuleName Z))
     (list
      (list
       'succeed
       (term (ZFrontier (More (Returned 0 ,EMPTY-STATE)) hole)))))
    (check-equal?
     (judgment-holds
      (foreign-core-M-step/direct ,source-M RuleName M)
      (RuleName M))
     (list
      (list
       'succeed
       (term (MFrontier (More (Returned 0 ,EMPTY-STATE)) hole)))))
    (check-equal?
     (judgment-holds
      (foreign-core-B-step/direct ,source-B TransitionSpan B)
      (TransitionSpan B))
     (list
      (list
       (term (transition-span succeed finish-success))
       (term (BFinal (Last 0 (Answer 0 ,EMPTY-STATE)))))))
    (check-equal?
     (judgment-holds
      (foreign-core-promote ,source-B Big)
      Big)
     (list
      (term (BigFinal (Last 0 (Answer 0 ,EMPTY-STATE))))))
    (check-true
     (foreign-core-D-square?
      (term
       (More
        (Work 0 (succeed (label "yes")) ,EMPTY-STATE)))))
    (check-true (foreign-core-Z-square? source-D))
    (check-true (foreign-core-M-square? source-Z))
    (check-true (foreign-core-B-square? source-M))
    (check-true (foreign-core-Big-square? source-B)))

  (test-case "every declared selected view is materialized in generated grammars"
    (check-true
     (redex-match? empty-frame-D-lang SourceRuntimeVariable (term 3)))
    (check-true
     (redex-match? empty-frame-D-lang SourceState (term (state 3))))
    (check-true
     (redex-match? empty-frame-D-lang SourceReturnedView
                   (term (returned 3))))
    (check-true
     (redex-match? empty-frame-D-lang SourceFailureView (term (failed 3))))
    (check-true
     (redex-match? empty-frame-D-lang SourceTerminalSuccess
                   (term (halted 3))))
    (check-true
     (redex-match? empty-frame-D-lang SourceTerminalFailure
                   (term (aborted 3))))
    (check-true
     (redex-match? empty-frame-Z-lang Settled (term (returned 3))))
    (check-true
     (redex-match? empty-frame-M-lang DeadW (term (failed 3))))
    (check-true
     (redex-match? empty-frame-B-lang T (term (halted 3))))
    (check-true
     (redex-match? empty-frame-Big-lang T (term (aborted 3)))))

  (test-case "a frame-free selected row renders all five stages"
    (define source-D (term (DecWork (tick 3) (root hole))))
    (define source-Z (term (empty-frame-refocus-phase ,source-D)))
    (define source-M (term (empty-frame-machineize ,source-Z)))
    (define source-B (term (empty-frame-compress ,source-M)))
    (check-equal? source-Z (term (ZWork (tick 3) (root hole))))
    (check-equal? source-M (term (MWork (tick 3) (root hole))))
    (check-equal? source-B (term (BRun (tick 3) (root hole))))
    (check-equal?
     (judgment-holds
      (empty-frame-B-step ,source-B TransitionSpan B)
      (TransitionSpan B))
     (list
      (list
       (term (transition-span tick finish-success))
       (term (BFinal (halted 4))))))
    (check-equal?
     (judgment-holds
      (empty-frame-big-evaluate (root (tick 3)) Big)
      Big)
     (list (term (BigFinal (halted 4)))))))

(module+ test
  (run-tests CORE-STAGE-SCHEMA-TESTS))
