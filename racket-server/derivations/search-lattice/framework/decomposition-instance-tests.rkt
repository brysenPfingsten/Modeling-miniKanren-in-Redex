#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "decomposition-instance.rkt")

(provide DECOMPOSITION-FRAMEWORK-TESTS)

(define-language smoke-source
  [W (Leaf natural)
     (Allocate natural)
     (Stopped)]
  [F (More W)
     (Done)]
  [WorkFocus (More hole)]
  [SpineContext hole])

(define-decomposition-instance
  #:source-language smoke-source
  #:decomposition-language smoke-decomposition
  #:work W
  #:frontier F
  #:work-focus WorkFocus
  #:spine-context SpineContext
  #:rule-names (work-rule frontier-rule)
  #:work-redexes ((Leaf natural))
  #:frontier-redexes ((More (Stopped)))
  #:allocation-redexes ((Allocate natural))
  #:terminals ((Done))
  #:plug-D smoke-plug-D
  #:plug-C smoke-plug-C
  #:contract-label smoke-contract-label
  #:decompose smoke-decompose)

(define/provide-test-suite DECOMPOSITION-FRAMEWORK-TESTS
  (check-equal?
   (judgment-holds
    (smoke-decompose (More (Leaf 1)) D)
    D)
   (term ((DecWork (Leaf 1) (More hole)))))
  (check-equal?
   (judgment-holds
    (smoke-decompose (More (Stopped)) D)
    D)
   (term ((DecFrontier (More (Stopped)) hole))))
  (check-equal?
   (judgment-holds
    (smoke-decompose (More (Allocate 0)) D)
    D)
   (term ((DecAllocate (Allocate 0) (More hole)))))
  (check-equal?
   (judgment-holds (smoke-decompose (Done) D) D)
   (term ((Final (Done)))))
  (check-equal?
   (term (smoke-plug-D (DecAllocate (Allocate 0) (More hole))))
   (term (More (Allocate 0))))
  (check-equal?
   (term
    (smoke-plug-C
     (ContractWork work-rule (Stopped) (More hole))))
   (term (More (Stopped))))
  (check-equal?
   (term
    (smoke-contract-label
     (ContractFrontier frontier-rule (Done) hole)))
   'frontier-rule))

(module+ test
  (run-tests DECOMPOSITION-FRAMEWORK-TESTS))
