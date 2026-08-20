#lang racket

(require redex/reduction-semantics
         "./core-lang.rkt")

(provide delay-lang)

(check-redundancy #t)

;; Explicit delayed-goal/runtime delay layer, independent of relation relcall.
(define-extended-language delay-lang core-lang
  [g ....
     (suspend g tag)]
  [W ....
     (PendingDelay owners W)]
  [F ....
     (Forced owners F)]

  [WorkOwnerSlot ::= ....
                     (PendingDelay hole W)]

  [SpineContext ::= ....
                    (Forced owners SpineContext)])
