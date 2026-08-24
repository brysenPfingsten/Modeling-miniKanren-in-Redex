#lang racket

(require rackunit
         rackunit/text-ui
         "./delay-stage-asymmetric-fixture.rkt")

(provide DELAY-STAGE-ASYMMETRIC-TESTS)

(define-test-suite DELAY-STAGE-ASYMMETRIC-TESTS
  (test-case "stage descriptor uses the forced-prefix representation view"
    (check-true asymmetric-stage-force-target-observed?)))

(module+ test
  (run-tests DELAY-STAGE-ASYMMETRIC-TESTS))
