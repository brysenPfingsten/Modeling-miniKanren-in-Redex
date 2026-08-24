#lang racket

(require redex/reduction-semantics
         "../../core/n/language.rkt")

(provide search-n-oracle-lang)

(check-redundancy #t)

;; Numeric sibling worlds keep independent next counters.  The grammar adds no
;; right-active carrier and no Search-specific runtime wrapper.
(define-extended-language search-n-oracle-lang core-n-oracle-lang
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
