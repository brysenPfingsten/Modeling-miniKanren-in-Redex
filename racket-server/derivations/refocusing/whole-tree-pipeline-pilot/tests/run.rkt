#lang racket

(require rackunit
         rackunit/text-ui
         "./compression-tests.rkt"
         "./decomposition-tests.rkt"
         "./refocused-tests.rkt"
         "./source-tests.rkt")

(define pilot-tests
  (test-suite
   "whole-tree pipeline pilot"
   source-tests
   decomposition-tests
   refocused-tests
   compression-tests))

(exit (if (zero? (run-tests pilot-tests)) 0 1))
