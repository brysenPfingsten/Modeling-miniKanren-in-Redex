#lang racket

(require redex/reduction-semantics)

(provide define-lift-search-to-relcall)

(define-syntax-rule (define-lift-search-to-relcall name rel lang)
  (define name
    (context-closure
     (extend-reduction-relation rel lang #:domain any)
     lang
     (Γ hole))))
