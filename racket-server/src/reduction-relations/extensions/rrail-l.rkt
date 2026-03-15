#lang racket

(require redex/reduction-semantics
         "./rail-common.rkt"
         "./rbase-l.rkt")

(check-redundancy #t)

(provide Rrail-l)

(define Rrail-l
  (extend-with-rail-rules
   (lift-l3-to-l4 Rbase-l)))
