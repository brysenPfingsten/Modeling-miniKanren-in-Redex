#lang racket

(require redex/reduction-semantics
         "./l0-core.rkt")

(check-redundancy #t)

(provide L1
         L1/K)

;; L1 adds relation calls and delay/proceed administrative nodes.
(define-extended-language L1 L0
  [g .... (r t ... tag)
     (sdelay g tag)]
  [pr ((r t ... tag) σ)
      (g σ)]
  [s .... (delay s)
     (proceed pr)])

(define-union-language L1/K L1 L0/K)
