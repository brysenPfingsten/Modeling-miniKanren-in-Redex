#lang racket

(require redex/reduction-semantics
         "../../core/s/language.rkt")

(provide delay-s-oracle-lang)

(check-redundancy #t)

;; Direct Owner-preserving Delay source carrier.  PendingDelay and Forced
;; retain Owner stacks; PendingDelay is deliberately absent from WorkPath and
;; therefore remains a suspension barrier.
(define-extended-language delay-s-oracle-lang core-s-oracle-lang
  [g ....
     (suspend g tag)]
  [W ....
     (PendingDelay owners W)]
  [F ....
     (Forced owners F)]

  [WorkOwnerSlot (Work hole g σ)
                 (Returned hole σ)
                 (Dead hole)
                 (Conj hole W g)
                 (PendingDelay hole W)]

  [SpineContext ....
                (Forced owners SpineContext)])
