#lang racket

(require redex/reduction-semantics
         "./core-lang.rkt")

(provide disj-lang)

(check-redundancy #t)

;; Neutral left-active disjunction. Rail adds right-active work.
(define-extended-language disj-lang core-lang
  [g ....
     (g ∨ g tag)]
  [W ....
     (DisjL owners W W)]
  [F ....
     (Emit owners A F)]

  [WorkOwnerSlot ::= ....
                     (DisjL hole W W)]

  [WorkPath ::= ....
                (DisjL owners WorkPath W)]

  [SpineContext ::= ....
                    (Emit owners A SpineContext)])
