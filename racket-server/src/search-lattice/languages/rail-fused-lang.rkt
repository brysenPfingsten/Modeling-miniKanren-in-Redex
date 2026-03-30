#lang racket

(require redex/reduction-semantics
         "./search-base-lang.rkt")

(provide rail-fused-lang)

(check-redundancy #t)

(define-extended-language rail-fused-lang search-base-lang
  [runnable-root .... (search +-> search)]
  [KWork .... (search +-> KWork)])
