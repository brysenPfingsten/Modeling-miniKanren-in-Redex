#lang racket

(require redex/reduction-semantics
         "source.rkt"
         "../shared/kernel.rkt"
         "../shared/stages/schema.rkt"
         "../shared/stages/views.rkt")

(provide RetainedS retained-view)

;; The constructor decomposition is the existing strict S decomposition.
;; The smaller source language excludes a pending prefix, so no prefix frame
;; can arise. Root Owners are retained by the ordinary merge/bind/yield frames.
;; D, Z, M and B are constructed by the unchanged generic stage definitions.
(define-S-view retained-view ScopeS retained-value? retained-frontier?)

(define (extend-support inherited owners)
  (if owners (owners-support owners inherited) inherited))

(define RetainedS
  (Stage 'RetainedScope/S retained-contract retained-view extend-support))
