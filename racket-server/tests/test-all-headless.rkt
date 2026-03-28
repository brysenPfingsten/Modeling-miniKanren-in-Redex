#lang racket

(require rackunit
         rackunit/text-ui
         "./property-core.rkt"
         "./stabilization-gates-tests.rkt")

(define-test-suite HEADLESS
  PROPERTY-CORE
  STABILIZATION-GATES)

(module+ test
  (run-tests HEADLESS))
