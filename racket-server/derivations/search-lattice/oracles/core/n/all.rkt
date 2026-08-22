#lang racket

(require rackunit/text-ui
         "./language.rkt"
         "./source.rkt"
         "./wf.rkt"
         "./tests.rkt")

(provide (all-from-out "./language.rkt")
         (all-from-out "./source.rkt")
         (all-from-out "./wf.rkt")
         (all-from-out "./tests.rkt"))

(module+ test
  (run-tests CORE-N-ORACLE-TESTS))
