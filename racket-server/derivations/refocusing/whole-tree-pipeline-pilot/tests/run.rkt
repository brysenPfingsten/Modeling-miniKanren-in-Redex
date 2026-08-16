#lang racket

(require rackunit
         rackunit/text-ui
         "./decomposition-tests.rkt"
         "./source-tests.rkt")

(define pilot-tests
  (test-suite
   "whole-tree pipeline pilot"
   source-tests
   decomposition-tests))

(exit (if (zero? (run-tests pilot-tests)) 0 1))
