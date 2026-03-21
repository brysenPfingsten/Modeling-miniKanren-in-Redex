#lang racket

(require rackunit
         rackunit/text-ui
         "./helpers-tests.rkt"
         "./property-core.rkt"
         "./search-lattice-tests.rkt"
         "./search-runtime-tests.rkt"
         "./example-compat-tests.rkt"
         "./determinism-overlap-tests.rkt"
         "./confidence-gates-tests.rkt"
         "./model-example-matrix-tests.rkt")

(define-test-suite HEADLESS
  HELPERS-TESTS
  PROPERTY-CORE
  SEARCH-RUNTIME
  SEARCH-LATTICE
  EXAMPLE-COMPAT
  DETERMINISM-OVERLAP
  CONFIDENCE-GATES
  MODEL-EXAMPLE-MATRIX)

(module+ test
  (run-tests HEADLESS))
