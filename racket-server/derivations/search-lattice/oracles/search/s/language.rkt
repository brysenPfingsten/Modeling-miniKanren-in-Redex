#lang racket

(require redex/reduction-semantics
         "../../core/s/language.rkt")

(provide search-s-oracle-lang)

(check-redundancy #t)

;; Search is the neutral grammar join.  PendingDelay is intentionally absent
;; from WorkPath: crossing a delayed active DisjL child belongs to a scheduler.
(define-extended-language search-s-oracle-lang core-s-oracle-lang
  [g ....
     (suspend g tag)
     (g ∨ g tag)]

  [W ....
     (PendingDelay owners W)
     (DisjL owners W W)]

  [F ....
     (Forced owners F)
     (Emit owners A F)]

  [WorkOwnerSlot (Work hole g σ)
                 (Returned hole σ)
                 (Dead hole)
                 (Conj hole W g)
                 (PendingDelay hole W)
                 (DisjL hole W W)]

  [WorkPath ....
            (DisjL owners WorkPath W)]

  [SpineContext ....
                (Forced owners SpineContext)
                (Emit owners A SpineContext)])
