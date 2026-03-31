#lang racket

(require redex/reduction-semantics
         "./search-base-fused-lang.rkt")

(provide rail-fused-lang)

(check-redundancy #t)

(define-extended-language rail-fused-lang search-base-fused-lang
  [runnable-root .... (search +-> search)]
  [KTail .... (search +-> KTail)])
