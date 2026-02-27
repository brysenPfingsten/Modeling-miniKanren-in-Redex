#lang racket

(require rackunit
         rackunit/text-ui
         "./helpers-tests.rkt"
         "./property-core.rkt")

(define-test-suite HEADLESS
  HELPERS-TESTS
  PROPERTY-CORE)

(module+ test
  (run-tests HEADLESS))
