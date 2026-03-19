#lang racket

(require redex/reduction-semantics
         "./l0-core.rkt")

(check-redundancy #t)

(provide L2
         L2/K)

;; L2 adds disjunction goals and left-pointing tree disjunction.
(define-extended-language L2 L0
  [g .... (g ∨ g tag)]
  [s .... (s <-+ s)])

(define-extended-language L2/K
  L2
  ;; General strategic context used by disjunction extension rules.
  [K ::= hole
         (K × g c)
         (K <-+ s)]
  ;; Core reduction context: conjunction only (no disjunction descent).
  [Kcore ::= hole
             (Kcore × g c)]
  ;; Left-disjunction scheduler context.
  [Kleft ::= hole
             (Kleft <-+ s)])
