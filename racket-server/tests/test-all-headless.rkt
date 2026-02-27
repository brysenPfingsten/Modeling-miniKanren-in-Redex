#lang racket

(require rackunit
         rackunit/text-ui
         "./property-core.rkt")

(define-test-suite HEADLESS
  PROPERTY-CORE)

(module+ test
  (run-tests HEADLESS))
