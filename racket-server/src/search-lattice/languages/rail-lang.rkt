#lang racket

(require redex/reduction-semantics
         "./search-lang.rkt")

(provide rail-lang)

(check-redundancy #t)

;; Rail alone owns the right-active search carrier and its work path.
(define-extended-language rail-lang search-lang
  [W ::= ....
         (DisjR owners W W)]

  [WorkOwnerSlot ::= ....
                     (DisjR hole W W)]

  [WorkPath ::= ....
                (DisjR owners W WorkPath)])
