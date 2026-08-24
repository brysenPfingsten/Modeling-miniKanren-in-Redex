#lang racket

(require rackunit
         rackunit/text-ui
         "./search-join-schema-fixture.rkt")

(define/provide-test-suite SEARCH-JOIN-SCHEMA
  (test-case "SearchJoinDelta is an explicit zero-rule identity"
    (check-equal? search-join-smoke-owned-rule-labels '())))

(module+ test
  (run-tests SEARCH-JOIN-SCHEMA))
