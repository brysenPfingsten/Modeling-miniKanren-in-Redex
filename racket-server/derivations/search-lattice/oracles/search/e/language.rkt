#lang racket

(require redex/reduction-semantics
         "../../core/e/language.rkt")

(provide search-e-oracle-lang)

(check-redundancy #t)

;; State-local support remains in the worlds and terminal summaries.  Neither
;; Delay nor Disjunction introduces a copied wrapper summary.
(define-extended-language search-e-oracle-lang core-e-oracle-lang
  [g ....
     (suspend g tag)
     (g ∨ g tag)]

  [W ....
     (PendingDelay W)
     (DisjL W W)]

  [F ....
     (Forced F)
     (Emit A F)]

  [WorkPath ....
            (DisjL WorkPath W)]

  [SpineContext ....
                (Forced SpineContext)
                (Emit A SpineContext)])
