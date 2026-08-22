#lang racket

(require "./language.rkt"
         "./source.rkt"
         "./wf.rkt"
         "./tests.rkt")

(provide (all-from-out "./language.rkt")
         (all-from-out "./source.rkt")
         (all-from-out "./wf.rkt")
         CORE-E-ORACLE-TESTS)

(module+ test
  (require rackunit/text-ui)
  (run-tests CORE-E-ORACLE-TESTS))
