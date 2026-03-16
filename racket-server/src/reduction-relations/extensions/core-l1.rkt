#lang racket

(require redex/reduction-semantics
         "../../extensions/l1-calls-delay.rkt"
         "./core-common.rkt"
         "./context-pipeline.rkt")

(check-redundancy #t)

(provide L1
         L1/K
         core-cfg/l1)

(define core-redex/l1 (extend-core-redex L1))
(define-extended-language L1/K
  L1
  ;; Deterministic search context: step in conjunction's left tree only.
  ;; `delay` is an administrative barrier, so we do not descend into it.
  [K ::= hole
         (K × g c)
         ((⊤ σ) + K)])

(define-cfg/one-stage core-cfg/l1 core-redex/l1 L1/K K)
