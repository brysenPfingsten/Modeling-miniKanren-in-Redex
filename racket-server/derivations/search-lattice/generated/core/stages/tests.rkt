#lang racket

(require rackunit
         rackunit/text-ui
         "./dependency-tests.rkt"
         "./horizontal-tests.rkt"
         "./vertical-tests.rkt")

(provide GENERATED-CORE-STAGES)

(define/provide-test-suite GENERATED-CORE-STAGES
  GENERATED-CORE-STAGE-DEPENDENCIES
  GENERATED-CORE-STAGES-HORIZONTAL
  GENERATED-CORE-STAGES-VERTICAL)

(module+ test
  (run-tests GENERATED-CORE-STAGES))
