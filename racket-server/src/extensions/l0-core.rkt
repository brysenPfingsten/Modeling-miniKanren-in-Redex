#lang racket

(require redex/reduction-semantics
         "../core-definitions.rkt")

(check-redundancy #t)

(provide L0
         L0/K)

;; L0 is the base Core syntax without any call/disjunction extensions.
(define-extended-language L0 Core)

(define-extended-language L0/K
  L0
  ;; Deterministic core context: step in conjunction's left tree only.
  [K ::= hole
         (K × g c)])
