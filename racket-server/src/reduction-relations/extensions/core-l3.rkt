#lang racket

(require redex/reduction-semantics
         "../../extensions/l3-union-base.rkt"
         "./core-common.rkt")

(check-redundancy #t)

(provide L3
         L3/K
         core-base-l3
         core-base-extra-l3)

(define core-redex/l3 (extend-core-redex L3))
(define core-step/l3 (compatible-closure core-redex/l3 L3 s))
(define core-cfg/l3 (context-closure core-step/l3 L3 (Γ ans* hole)))

(define whole-cfg/l3 (extend-whole-cfg L3))
(define core-base-l3 (union-reduction-relations core-cfg/l3 whole-cfg/l3))

(define-extended-language L3/K
  L3
  [K ::= hole
         (K × g c)
         (delay K)
         (K <-+ s)]
  [K3 ::= K])

(define core-base-extra-l3
  (extend-reduction-relation
    core-base-l3
    L3/K))
