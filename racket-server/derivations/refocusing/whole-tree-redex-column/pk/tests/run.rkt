#lang racket

(require rackunit
         rackunit/text-ui
         "./front-half-tests.rkt"
         "./middle-tests.rkt"
         "./back-half-tests.rkt")

(define pk-tests
  (test-suite
   "whole-tree P[K] column"
   front-half-tests
   middle-tests
   pk-back-half-tests))

(exit (if (zero? (run-tests pk-tests)) 0 1))
