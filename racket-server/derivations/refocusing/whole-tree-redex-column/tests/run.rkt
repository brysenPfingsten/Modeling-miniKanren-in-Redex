#lang racket

(require rackunit
         rackunit/text-ui
         "./source-tests.rkt"
         "./decomposition-tests.rkt"
         "./refocused-tests.rkt"
         "./machine-tests.rkt"
         "./compression-tests.rkt"
         "./big-step-tests.rkt"
         "./kernel-parameter-tests.rkt")

(run-tests
 (test-suite
  "whole-tree Redex column"
  source-tests
  decomposition-tests
  refocused-tests
  machine-tests
  compression-tests
  big-step-tests
  kernel-parameter-tests))
