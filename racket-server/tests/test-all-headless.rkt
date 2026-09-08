#lang racket

(require rackunit
         rackunit/text-ui
         "./confidence-gates-tests.rkt"
         "./example-compat-tests.rkt"
         "./frontier-example-tests.rkt"
         "./minikanren-library-tests.rkt"
         "./model-example-matrix-tests.rkt"
         "./program-runner-tests.rkt"
         "./search-runtime-tests.rkt"
         "./scheduler-integration-tests.rkt"
         "./test-app.rkt"
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
  APP
  FRONTIER-EXAMPLES
  VISIBLE-CONTRACTS
  SEARCH-RUNTIME
  SCHEDULER-INTEGRATION
  CONFIDENCE-GATES
  MODEL-EXAMPLE-MATRIX)

(module+ test
  ;; The GUI uses strict matrix scheduler rows. Earlier dormant-branch source
  ;; gates and their interpreter comparisons remain separate research checks.
  (require "../derivations/all.rkt"
           "../derivations/experiments/all.rkt"
           (submod "./search-picture-tests.rkt" test))
  (define failures (run-tests HEADLESS))
  (unless (zero? failures)
    (error 'HEADLESS "~a test case(s) failed" failures)))
