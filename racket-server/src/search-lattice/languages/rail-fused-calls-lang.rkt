#lang racket

(require redex/reduction-semantics
         "./calls-lang.rkt"
         "./rail-fused-lang.rkt")

(provide rail-fused-calls-lang)

(check-redundancy #t)

(define-union-language rail-fused-calls/join
  calls-lang
  rail-fused-lang)

(define-extended-language rail-fused-calls-lang
  rail-fused-calls/join
  [K ::= hole
        (K × g c)]
  [KCorePath ::= hole
                 (Scoped c KCorePath)
                 (KCorePath <-+ f)
                 (f +-> KCorePath)]
  [KScopePath ::= hole
                  (Scoped c KScopePath)
                  (KScopePath <-+ f)
                  (f +-> KScopePath)])
