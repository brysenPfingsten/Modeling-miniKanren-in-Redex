#lang racket

(require rackunit
         rackunit/text-ui
         "source-tests.rkt"
         "horizontal-tests.rkt"
         "embedding-tests.rkt"
         "feature-order-tests.rkt"
         "stage-feature-order-tests.rkt"
         "cube-tests.rkt"
         "transport-diagnostics-tests.rkt"
         "dependency-tests.rkt")

(provide GENERATED-SEARCH-TESTS)

(define GENERATED-SEARCH-TESTS
  (test-suite
   "generated Search R/D/Z/M/B/Big additive-join evidence"
   GENERATED-SEARCH-SOURCE-TESTS
   GENERATED-SEARCH-HORIZONTAL-TESTS
   GENERATED-SEARCH-EMBEDDING-TESTS
   GENERATED-SEARCH-FEATURE-ORDER-TESTS
   GENERATED-SEARCH-STAGE-FEATURE-ORDER-TESTS
   GENERATED-SEARCH-CUBE-TESTS
   GENERATED-SEARCH-TRANSPORT-DIAGNOSTICS-TESTS
   GENERATED-SEARCH-DEPENDENCY-TESTS))

(module+ test
  (run-tests GENERATED-SEARCH-TESTS))
