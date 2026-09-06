#lang racket

(require "semantics.rkt")
(provide snapshot)

;; A finite inspection budget for Delay bodies, not fuel in the semantics.
;; Unforced identifies the inspection boundary. It means neither Empty nor
;; divergence. A diverging eager computation can still prevent this returning.
(define (snapshot search #:delays [depth 0] #:state [show-state values])
  (unless (exact-nonnegative-integer? depth)
    (raise-argument-error 'snapshot "exact-nonnegative-integer?" depth))
  (case-search
   search
   (lambda (next) `(Empty ,next))
   (lambda (state) `(One ,(show-state state)))
   (lambda (state rest)
     `(Yield ,(show-state state) ,(snapshot rest #:delays depth #:state show-state)))
   (lambda (resume)
     `(Delay ,(if (zero? depth)
                  'Unforced
                  (snapshot (resume) #:delays (sub1 depth) #:state show-state))))))
