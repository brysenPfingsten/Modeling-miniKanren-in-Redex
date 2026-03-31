#lang racket

(require redex/reduction-semantics
         "./calls-lang.rkt"
         "./search-base-fused-lang.rkt")

(provide search-base-fused-calls-lang)

(check-redundancy #t)

(define-union-language search-base-fused-calls-lang
  calls-lang
  search-base-fused-lang)
