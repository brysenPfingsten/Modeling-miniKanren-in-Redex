#lang racket

(require redex/reduction-semantics
         "../../core/s/language.rkt")

(provide disjunction-s-oracle-lang)

(check-redundancy #t)

;; Direct Owner-preserving Disjunction source carrier.  DisjL selects only
;; its left child as the active world; Emit makes its residual frontier the
;; unique active continuation.
(define-extended-language disjunction-s-oracle-lang core-s-oracle-lang
  [g ....
     (g ∨ g tag)]
  [W ....
     (DisjL owners W W)]
  [F ....
     (Emit owners A F)]

  [WorkOwnerSlot (Work hole g σ)
                 (Returned hole σ)
                 (Dead hole)
                 (Conj hole W g)
                 (DisjL hole W W)]

  [WorkPath ....
            (DisjL owners WorkPath W)]

  [SpineContext ....
                (Emit owners A SpineContext)])
