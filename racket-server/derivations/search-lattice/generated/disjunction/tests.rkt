#lang racket

(require rackunit
         rackunit/text-ui
         "source-tests.rkt"
         "horizontal-tests.rkt"
         "embedding-tests.rkt"
         "cube-tests.rkt"
         "transport-diagnostics-tests.rkt"
         "dependency-tests.rkt")

(provide GENERATED-DISJUNCTION-TESTS)

(define GENERATED-DISJUNCTION-TESTS
  (test-suite
   "generated Disjunction R/D/Z/M/B/Big evidence"
   GENERATED-DISJUNCTION-SOURCE-TESTS
   GENERATED-DISJUNCTION-HORIZONTAL-TESTS
   GENERATED-DISJUNCTION-EMBEDDING-TESTS
   GENERATED-DISJUNCTION-CUBE-TESTS
   GENERATED-DISJUNCTION-TRANSPORT-DIAGNOSTICS-TESTS
   GENERATED-DISJUNCTION-DEPENDENCY-TESTS))

(module+ test
  (run-tests GENERATED-DISJUNCTION-TESTS))
