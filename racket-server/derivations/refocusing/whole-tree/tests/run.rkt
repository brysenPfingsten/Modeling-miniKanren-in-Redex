#lang racket

(require rackunit
         rackunit/text-ui
         "../reference/marked/tests/front-half-tests.rkt"
         "../reference/marked/tests/grammar-litmus-tests.rkt"
         "../reference/marked/tests/middle-tests.rkt"
         "../reference/marked/tests/back-half-tests.rkt"
         "../reference/marked/tests/observation-tests.rkt"
         "../reference/marked/tests/intrinsic-dependency-tests.rkt"
         "./temporary-oracle-parity-tests.rkt"
         "./temporary-observation-oracle-parity-tests.rkt")

(define whole-tree-tests
  (test-suite
   "canonical whole-tree consolidation aggregate"
   front-half-tests
   grammar-litmus-tests
   middle-tests
   pk-back-half-tests
   observation-tests
   intrinsic-dependency-tests
   temporary-oracle-parity-tests
   temporary-observation-oracle-parity-tests))

(exit (if (zero? (run-tests whole-tree-tests)) 0 1))
