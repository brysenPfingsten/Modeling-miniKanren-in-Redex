#lang racket

(require rackunit
         rackunit/text-ui
         "./confidence-gates-tests.rkt"
         "./example-compat-tests.rkt"
         "./frontier-example-tests.rkt"
         "./minikanren-library-tests.rkt"
         "./model-example-matrix-tests.rkt"
         "./program-runner-tests.rkt"
         "./property-core.rkt"
         "./property-non-core.rkt"
         "./retired-work-syntax-tests.rkt"
         "./search-lattice/all.rkt"
         "./search-runtime-tests.rkt"
         "./test-syntax-checking.rkt"
         "./test-transpiler.rkt"
         "./test-zipper.rkt"
         "./visible-contract-tests.rkt")

(define-test-suite HEADLESS
  SYNTAX-CHECKER
  ZIPPER
  TRANSPILER
  EXAMPLE-COMPAT
  MINIKANREN-LIBRARY
  PROGRAM-RUNNER
  PROPERTY-CORE
  PROPERTY-NON-CORE
  RETIRED-WORK-SYNTAX
  SEARCH-LATTICE-SEMANTICS
  FRONTIER-EXAMPLES
  VISIBLE-CONTRACTS
  SEARCH-RUNTIME
  CONFIDENCE-GATES
  MODEL-EXAMPLE-MATRIX)

(module+ test
  (run-tests HEADLESS))
