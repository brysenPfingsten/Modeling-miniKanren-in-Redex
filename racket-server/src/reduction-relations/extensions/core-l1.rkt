#lang racket

(require redex/reduction-semantics
         "../../extensions/l1-calls-delay.rkt"
         "./core-common.rkt")

(check-redundancy #t)

(provide L1
         L1/K
         core-base-l1)

(define core-redex/l1 (extend-core-redex L1))
(define core-step/l1 (compatible-closure core-redex/l1 L1 s))
(define core-cfg/l1 (context-closure core-step/l1 L1 (Γ ans* hole)))

(define whole-cfg/l1 (extend-whole-cfg L1))
(define core-base-l1 (union-reduction-relations core-cfg/l1 whole-cfg/l1))

(define-extended-language L1/K
  L1
  [K ::= hole
         (K × g c)
         (delay K)]
  [K1 ::= K])
