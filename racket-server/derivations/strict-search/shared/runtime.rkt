#lang racket
(provide (struct-out exn:fail:budget) check-fuel exhausted)
(struct exn:fail:budget exn:fail (stage configuration) #:transparent)
(define (check-fuel fuel)
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error 'drive "exact-nonnegative-integer?" fuel)))
(define (exhausted stage configuration)
  (raise (exn:fail:budget "derivation runner exhausted its transition budget"
                          (current-continuation-marks) stage configuration)))
