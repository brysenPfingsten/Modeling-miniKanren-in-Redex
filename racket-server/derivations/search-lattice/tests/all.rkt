#lang racket

(require rackunit
         rackunit/text-ui
         "./test-inventory.rkt")

(provide SEARCH-LATTICE-MATRIX-SEED)

(define SEARCH-LATTICE-MATRIX-SEED
  (make-test-suite
   "SEARCH-LATTICE-MATRIX-SEED"
   (map registered-test-suite SEARCH-LATTICE-TEST-INVENTORY)))

(module+ test
  (require-search-lattice-intrinsic-tests)
  (run-tests SEARCH-LATTICE-MATRIX-SEED))
