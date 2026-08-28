#lang racket

(require rackunit
         rackunit/text-ui
         "../q/reference/tests/source-tests.rkt"
         "../reference/lean/tests/intrinsic-dependency-tests.rkt"
         "../reference/lean/tests/source-tests.rkt")

;; Source-only acceptance boundary for the independent lean reference and the
;; marked-to-lean Q_R laws.  Deliberately imports no D/Z/M/B/Big artifact.
(define source-checkpoint-tests
  (test-suite
   "whole-tree lean source checkpoint"
   lean-source-tests
   lean-intrinsic-dependency-tests
   reference-Q-source-tests))

(exit (if (zero? (run-tests source-checkpoint-tests)) 0 1))
