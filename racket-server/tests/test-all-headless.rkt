#lang racket

(require rackunit
         rackunit/text-ui
         "./determinism-overlap-tests.rkt"
         "./minikanren-library-tests.rkt"
         "./program-runner-tests.rkt"
         "./property-core.rkt"
         "./property-non-core.rkt"
         "./search-lattice-tests.rkt"
         "./stabilization-gates-tests.rkt")

(define-test-suite HEADLESS
  DETERMINISM-OVERLAP
  MINIKANREN-LIBRARY
  PROGRAM-RUNNER
  PROPERTY-CORE
  PROPERTY-NON-CORE
  SEARCH-LATTICE
  STABILIZATION-GATES)

(module+ test
  (run-tests HEADLESS))
