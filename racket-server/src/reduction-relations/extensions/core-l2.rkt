#lang racket

(require redex/reduction-semantics
         "../../extensions/l2-left-disjunction.rkt"
         "./core-common.rkt"
         "./context-pipeline.rkt")

(check-redundancy #t)

(provide L2
         L2/K
         core-cfg/l2)

(define core-redex/l2 (extend-core-redex L2))
(define-extended-language L2/K
  L2
  ;; General strategic context used by disjunction extension rules.
  [K ::= hole
         (K × g c)
         (K <-+ s)
         ((⊤ σ) + K)]
  ;; Core reduction context: conjunction only (no disjunction descent).
  [Kcore ::= hole
             (Kcore × g c)
             ((⊤ σ) + Kcore)]
  ;; Left-disjunction scheduler context.
  [Kleft ::= hole
             (Kleft <-+ s)])

(define-cfg/two-stage core-cfg/l2 core-redex/l2 L2/K Kcore Kleft)
