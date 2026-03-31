#lang racket

(require redex/reduction-semantics
         "./rail-seq-lang.rkt")

(provide rail-fused-lang)

(check-redundancy #t)

(define-extended-language rail-fused-lang rail-seq-lang
  [KLate ::= KBranch
             (KLate × g c)
             (search +-> KLate)])
