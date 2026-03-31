#lang racket

(require redex/reduction-semantics
         "./search-base-seq-lang.rkt")

(provide search-base-fused-lang)

(check-redundancy #t)

(define-extended-language search-base-fused-lang
  search-base-seq-lang
  [KLate ::= KBranch
             (KLate × g c)])
