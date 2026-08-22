#lang racket

(require rackunit
         rackunit/text-ui
         "./comparison-tests.rkt"
         "./dependency-tests.rkt")

(provide GENERATED-CORE-SOURCES)

(define/provide-test-suite GENERATED-CORE-SOURCES
  GENERATED-CORE-SOURCE-COMPARISONS
  GENERATED-CORE-SOURCE-DEPENDENCIES)

(module+ test
  (run-tests GENERATED-CORE-SOURCES))
