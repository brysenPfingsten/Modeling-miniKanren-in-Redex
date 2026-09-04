#lang racket

(require rackunit/text-ui
         "./decomposition-tests.rkt"
         "./intrinsic-dependency-tests.rkt"
         "./source-tests.rkt")

(define failures
  (+ (run-tests lean-source-tests)
     (run-tests lean-decomposition-tests)
     (run-tests lean-intrinsic-dependency-tests)))

(unless (zero? failures)
  (exit 1))
