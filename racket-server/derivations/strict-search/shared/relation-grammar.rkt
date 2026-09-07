#lang racket

(require redex/reduction-semantics "grammar-s.rkt" "grammar-e.rkt" "grammar-n.rkt")
(provide StrictSRel StrictERel StrictNRel)

;; Relation definitions are closed apart from their lexical parameters. Their
;; environment belongs to the running program, including paused Frontiers.
;; The call-free feature grammars remain unchanged.
(define-syntax-rule (define-rel-language name parent)
  (define-extended-language name parent
    [r (variable-prefix r:)]
    [call (r t (... ...) tag)]
    [g .... call]
    [definition (r (x_!_ (... ...)) g)]
    [Γ (definition (... ...))]
    [q .... (program Γ q)]
    [C .... (program Γ C)]
    [p (program Γ q)]))

(define-rel-language StrictSRel StrictS)
(define-rel-language StrictERel StrictE)
(define-rel-language StrictNRel StrictN)
