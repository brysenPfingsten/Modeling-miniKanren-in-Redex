#lang racket

(require redex/reduction-semantics
         "../../../languages/disj-lang.rkt")

(provide distributed-disj-lang)

(check-redundancy #t)

;; Eager distribution is a separate presentation over the ordinary
;; disjunction carrier. These context indices enforce its normalization
;; discipline without adding policy grammar to the production language.
(define-extended-language distributed-disj-lang disj-lang
  [EarlyWW hole
           (Conj owners EarlyConjWW g)
           (DisjL owners EarlyWW W)]
  [EarlyConjWW hole
               (Conj owners EarlyConjWW g)]
  [EarlyWF (in-hole SpineContext (More EarlyWW))]

  [EarlyChoiceWW hole
                 (DisjL owners EarlyChoiceWW W)]
  [EarlyChoiceWF
   (in-hole SpineContext (More EarlyChoiceWW))])
