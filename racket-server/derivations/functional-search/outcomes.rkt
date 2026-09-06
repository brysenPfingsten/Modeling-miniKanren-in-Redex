#lang racket/base

(provide failure-outcome success-outcome)

;; Native direct-style kernel results. Kernel work finishes before either
;; constructor returns. These functions select an already-computed result;
;; they are neither delayed computation nor a kernel continuation interface.
(define (failure-outcome)
  (lambda (on-failure _success) (on-failure)))

(define (success-outcome state)
  (lambda (_failure on-success) (on-success state)))
