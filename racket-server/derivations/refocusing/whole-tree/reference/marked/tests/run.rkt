#lang racket

(require rackunit
         rackunit/text-ui
         "./front-half-tests.rkt"
         "./grammar-litmus-tests.rkt"
         "./middle-tests.rkt"
         "./back-half-tests.rkt"
         "./intrinsic-dependency-tests.rkt")

(define pk-tests
  (test-suite
   "whole-tree P[K] column"
   front-half-tests
   grammar-litmus-tests
   middle-tests
   pk-back-half-tests
   intrinsic-dependency-tests))

(exit (if (zero? (run-tests pk-tests)) 0 1))
