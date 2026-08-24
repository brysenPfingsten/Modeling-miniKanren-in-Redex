#lang racket

(require redex/reduction-semantics
         "../../core/e/language.rkt")

(provide disjunction-e-oracle-lang)

(check-redundancy #t)

;; Direct state-support Disjunction carrier.  Choice and emission contain no
;; copied Support decoration: each possible world keeps its own state/summary.
(define-extended-language disjunction-e-oracle-lang core-e-oracle-lang
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
