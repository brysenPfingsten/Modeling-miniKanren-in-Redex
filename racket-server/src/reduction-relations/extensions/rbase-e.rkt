#lang racket

(require redex/reduction-semantics
         "./rcall-eager.rkt"
         "./rdisj-left.rkt"
         "./core-l3.rkt")

(check-redundancy #t)

(provide Rbase-e)

(define call-eager-extra/l3
  (extend-reduction-relation
    call-eager-extra/l1
    L3/K))

(define disj-extra/l3
  (extend-reduction-relation
    disj-extra/l2
    L3/K))

(define Rbase-e
  (union-reduction-relations
   call-eager-extra/l3
   disj-extra/l3
   core-base-extra-l3))
