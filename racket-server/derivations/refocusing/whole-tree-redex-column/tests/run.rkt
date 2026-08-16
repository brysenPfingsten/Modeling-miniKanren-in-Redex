#lang racket

(require rackunit
         rackunit/text-ui
         "./source-tests.rkt"
         "./decomposition-tests.rkt"
         "./refocused-tests.rkt")

(run-tests
 (test-suite
  "whole-tree Redex column"
  source-tests
  decomposition-tests
  refocused-tests))
