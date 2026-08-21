#lang racket

(require rackunit
         rackunit/text-ui
         "../framework/decomposition-instance-tests.rkt"
         "./core-matrix-tests.rkt"
         "./core-s-horizontal-tests.rkt"
         "./dependency-boundary-tests.rkt")

(provide SEARCH-LATTICE-MATRIX-SEED)

(define/provide-test-suite SEARCH-LATTICE-MATRIX-SEED
  DECOMPOSITION-FRAMEWORK-TESTS
  CORE-MATRIX-SEED
  CORE-S-HORIZONTAL
  DEPENDENCY-BOUNDARY)

(module+ test
  (run-tests SEARCH-LATTICE-MATRIX-SEED))
