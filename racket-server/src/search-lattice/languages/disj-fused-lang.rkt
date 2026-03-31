#lang racket

(require redex/reduction-semantics
         "./disj-seq-lang.rkt")

(provide disj-fused-lang)

(check-redundancy #t)

(define-extended-language disj-fused-lang disj-seq-lang
  [KLate ::= KBranch
             (KLate × g c)])
