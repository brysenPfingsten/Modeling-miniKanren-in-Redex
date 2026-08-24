#lang racket

(require redex/reduction-semantics
         "../../core/n/language.rkt")

(provide disjunction-n-oracle-lang)

(check-redundancy #t)

;; Direct numeric Disjunction carrier.  Sibling worlds copy the incoming
;; next-bearing state and therefore may independently reuse the same level.
(define-extended-language disjunction-n-oracle-lang core-n-oracle-lang
  [g ....
     (g ∨ g tag)]
  [W ....
     (DisjL W W)]
  [F ....
     (Emit A F)]

  [WorkPath ....
            (DisjL WorkPath W)]

  [SpineContext ....
                (Emit A SpineContext)])
