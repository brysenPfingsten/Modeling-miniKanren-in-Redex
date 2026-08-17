#lang racket

(require rackunit
         rackunit/text-ui
         "../../whole-tree-redex-column/pk/tests/front-half-tests.rkt"
         "../../whole-tree-redex-column/pk/tests/grammar-litmus-tests.rkt"
         "../../whole-tree-redex-column/pk/tests/middle-tests.rkt"
         "../../whole-tree-redex-column/pk/tests/back-half-tests.rkt"
         "../../whole-tree-redex-column/pk/tests/intrinsic-dependency-tests.rkt"
         "./temporary-oracle-parity-tests.rkt")

(define whole-tree-tests
  (test-suite
   "canonical whole-tree consolidation aggregate"
   front-half-tests
   grammar-litmus-tests
   middle-tests
   pk-back-half-tests
   intrinsic-dependency-tests
   temporary-oracle-parity-tests))

(exit (if (zero? (run-tests whole-tree-tests)) 0 1))
