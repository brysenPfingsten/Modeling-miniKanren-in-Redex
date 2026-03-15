#lang racket

(require redex/reduction-semantics
         "../../extensions/l3-union-base.rkt"
         "./core-common.rkt")

(check-redundancy #t)

(provide L3
         L3/K
         core-cfg/l3)

(define core-redex/l3 (extend-core-redex L3))
(define-extended-language L3/K
  L3
  ;; General strategic context used by call/disjunction extension rules.
  [K ::= hole
         (K × g c)
         (K <-+ s)
         ((⊤ σ) + K)]
  ;; Core reduction context: conjunction only (no disjunction or delay descent).
  [Kcore ::= hole
             (Kcore × g c)]
  ;; Left-disjunction scheduler context.
  [Kleft ::= hole
             (Kleft <-+ s)
             ((⊤ σ) + Kleft)]
  ;; Call-step base context; left-disjunction lifting is applied separately.
  [Kcall ::= hole
             (Kcall × g c)]
  ;; Delay invocation context: top-level or under answer-stream tails only.
  [Kdelay ::= hole
              ((⊤ σ) + Kdelay)])

(define core-step/base-l3 (context-closure core-redex/l3 L3/K Kcore))
(define core-step/l3 (context-closure core-step/base-l3 L3/K Kleft))
(define core-cfg/l3 (context-closure core-step/l3 L3/K (Γ hole)))
