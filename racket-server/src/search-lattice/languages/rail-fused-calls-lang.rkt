#lang racket

(require redex/reduction-semantics
         "./calls-lang.rkt"
         "./rail-fused-lang.rkt")

(provide rail-fused-calls-lang)

(check-redundancy #t)

(define-union-language rail-fused-calls-lang
  calls-lang
  rail-fused-lang)
