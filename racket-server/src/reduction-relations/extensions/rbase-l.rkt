#lang racket

(require redex/reduction-semantics
         "./rcall-lazy.rkt"
         "./rdisj-left.rkt"
         "./core-l3.rkt")

(check-redundancy #t)

(provide Rbase-l)

(define call-lazy-extra/l3
  (extend-reduction-relation
    call-lazy-extra/l1
    L3/K))

(define disj-extra/l3
  (extend-reduction-relation
    disj-extra/l2
    L3/K))

(define Rbase-l
  (union-reduction-relations
   call-lazy-extra/l3
   disj-extra/l3
   core-base-extra-l3))
