#lang racket

(require redex/reduction-semantics
         "../../extensions/l2-left-disjunction.rkt"
         "./core-common.rkt")

(check-redundancy #t)

(provide L2
         core-base-l2)

(define core-redex/l2 (extend-core-redex L2))
(define core-step/l2 (compatible-closure core-redex/l2 L2 s))
(define core-cfg/l2 (context-closure core-step/l2 L2 (Γ ans* hole)))

(define whole-cfg/l2 (extend-whole-cfg L2))
(define core-base-l2 (union-reduction-relations core-cfg/l2 whole-cfg/l2))
