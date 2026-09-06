#lang racket

(require redex/reduction-semantics
         "source.rkt"
         "../shared/kernel.rkt"
         "../shared/stages/schema.rkt"
         "../shared/stages/views.rkt")

(provide RetainedS retained-view)

;; The shared strict S grammar retains scope on active roots. No pending
;; prefix frame exists; ordinary merge/bind/yield frames retain root Owners.
;; D, Z, M and B are constructed by the unchanged generic stage definitions.
(define-S-view retained-view ScopeS retained-value? retained-frontier?)

(define (extend-support inherited owners)
  (if owners (owners-support owners inherited) inherited))

(define RetainedS
  (Stage 'RetainedScope/S retained-contract retained-view extend-support))
