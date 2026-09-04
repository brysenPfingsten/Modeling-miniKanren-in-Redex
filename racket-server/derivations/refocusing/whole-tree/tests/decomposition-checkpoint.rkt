#lang racket

(require rackunit
         rackunit/text-ui
         "../q/reference/tests/decomposition-tests.rkt"
         "../q/reference/tests/source-tests.rkt"
         "../reference/lean/tests/decomposition-tests.rkt"
         "../reference/lean/tests/intrinsic-dependency-tests.rkt"
         "../reference/lean/tests/source-tests.rkt")

;; Acceptance boundary through D.  This includes the prior source checkpoint,
;; the independent lean decomposition, and the stagewise Q_R/Q_D laws, but no
;; refocused, machine, compressed, cached, or big-step artifact.
(define decomposition-checkpoint-tests
  (test-suite "whole-tree lean decomposition checkpoint"
    lean-source-tests
    lean-decomposition-tests
    lean-intrinsic-dependency-tests
    reference-Q-source-tests
    reference-Q-decomposition-tests))

(exit (if (zero? (run-tests decomposition-checkpoint-tests)) 0 1))
