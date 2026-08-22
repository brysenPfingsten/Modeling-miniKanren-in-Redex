#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
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
     (term (More ,focused)))))

(module+ test
  (run-tests CORE-STAGE-SCHEMA-TESTS))
