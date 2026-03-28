#lang racket

(require rackunit
         rackunit/text-ui
         "./confidence-gates-tests.rkt"
         "./determinism-overlap-tests.rkt"
         "./example-compat-tests.rkt"
         "./frontier-example-tests.rkt"
         "./frontier-observable-tests.rkt"
         "./helpers-tests.rkt"
         "./model-example-matrix-tests.rkt"
         "./property-core.rkt"
         "./search-lattice-tests.rkt"
         "./search-runtime-tests.rkt"
         "./stabilization-gates-tests.rkt"
         "./wf-trace-tests.rkt"
         "./visible-contract-tests.rkt")

(define-test-suite HEADLESS
  HELPERS-TESTS
  PROPERTY-CORE
  FRONTIER-EXAMPLES
  FRONTIER-OBSERVABLES
  VISIBLE-CONTRACTS
  SEARCH-RUNTIME
  SEARCH-LATTICE
  STABILIZATION-GATES
  WF-TRACES
  EXAMPLE-COMPAT
  DETERMINISM-OVERLAP
  CONFIDENCE-GATES
  MODEL-EXAMPLE-MATRIX)

(module+ test
  (run-tests HEADLESS))
