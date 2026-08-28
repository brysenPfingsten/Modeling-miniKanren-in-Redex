#lang racket

(require rackunit/text-ui
         "./intrinsic-dependency-tests.rkt"
         "./source-tests.rkt")

(define failures
  (+ (run-tests lean-source-tests)
     (run-tests lean-intrinsic-dependency-tests)))

(unless (zero? failures)
  (exit 1))
