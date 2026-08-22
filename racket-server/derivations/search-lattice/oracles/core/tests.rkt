#lang racket

(require rackunit
         rackunit/text-ui
         "./s/tests.rkt"
         "./e/tests.rkt"
         "./n/tests.rkt"
         "./vertical-tests.rkt"
         "./dependency-tests.rkt")

(provide CORE-SOURCE-ORACLE-TESTS)

(define/provide-test-suite CORE-SOURCE-ORACLE-TESTS
  CORE-S-ORACLE-TESTS
  CORE-E-ORACLE-TESTS
  CORE-N-ORACLE-TESTS
  CORE-R-VERTICAL-TESTS
  CORE-ORACLE-DEPENDENCY-TESTS)

(module+ test
  (run-tests CORE-SOURCE-ORACLE-TESTS))
