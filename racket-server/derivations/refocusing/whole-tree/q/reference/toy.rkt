#lang racket

(require redex/reduction-semantics
         (prefix-in lean: "../../reference/lean/toy/language.rkt")
         (prefix-in marked: "../../reference/marked/toy/language.rkt")
         "./source-schema.rkt")

(provide Q-A/toy
         Q-W/toy
         Q-R/toy
         Q-R-in-lean-language?/toy)

(define-reference-source-Q
  marked:pk-toy-lang
  Q-A/toy
  Q-W/toy
  Q-R/toy)

(define (Q-R-in-lean-language?/toy frontier)
  (redex-match? lean:lean-toy-lang F frontier))
