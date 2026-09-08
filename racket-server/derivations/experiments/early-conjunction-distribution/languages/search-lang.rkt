#lang racket

(require redex/reduction-semantics
         "../../dormant-branch-semantics/source/languages/search-lang.rkt")

(provide distributed-search-lang)

(check-redundancy #t)

;; This experiment keeps the production search carrier and adds only the
;; focus indices needed to maintain eager distribution. In particular, after
;; crossing Conj, an ordinary step cannot cross a directly exposed choice.
(define-extended-language distributed-search-lang search-lang
  ;; The historical distributed presentation keeps right-active choice in
  ;; its common carrier. Production now localizes this phase to rail, but the
  ;; experiment remains mechanically unchanged.
  [W ::= ....
         (DisjR owners W W)]

  [WorkOwnerSlot ::= ....
                     (DisjR hole W W)]

  [WorkPath ::= ....
                (DisjR owners W WorkPath)]

  [EarlyWW hole
           (Conj owners EarlyConjWW g)
           (DisjL owners EarlyWW W)
           (DisjR owners W EarlyWW)]
  [EarlyConjWW hole
               (Conj owners EarlyConjWW g)]
  [EarlyWF (in-hole SpineContext (More EarlyWW))]

  ;; Choice rules cannot cross Conj; eager distribution owns any choice that
  ;; appears directly beneath a conjunction.
  [EarlyChoiceWW hole
                 (DisjL owners EarlyChoiceWW W)
                 (DisjR owners W EarlyChoiceWW)]
  [EarlyChoiceWF
   (in-hole SpineContext (More EarlyChoiceWW))])
