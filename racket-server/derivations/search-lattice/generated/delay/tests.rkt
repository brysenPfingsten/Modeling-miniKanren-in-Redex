#lang racket

(require rackunit
         rackunit/text-ui
         "source-tests.rkt"
         "horizontal-tests.rkt"
         "embedding-tests.rkt"
         "cube-tests.rkt"
         "transport-diagnostics-tests.rkt"
         "dependency-tests.rkt")

(provide GENERATED-DELAY-TESTS)

(define GENERATED-DELAY-TESTS
  (test-suite
   "generated Delay R/D/Z/M/B/Big evidence"
   GENERATED-DELAY-SOURCE-TESTS
   GENERATED-DELAY-HORIZONTAL-TESTS
   GENERATED-DELAY-EMBEDDING-TESTS
   GENERATED-DELAY-CUBE-TESTS
   GENERATED-DELAY-TRANSPORT-DIAGNOSTICS-TESTS
   GENERATED-DELAY-DEPENDENCY-TESTS))

(module+ test
  (run-tests GENERATED-DELAY-TESTS))
