#lang racket

(require redex/reduction-semantics
         "./rail-common.rkt"
         "./rbase-e.rkt")

(check-redundancy #t)

(provide Rrail-e)

(define Rrail-e
  (extend-with-rail-rules
   (lift-l3-to-l4 Rbase-e)))
