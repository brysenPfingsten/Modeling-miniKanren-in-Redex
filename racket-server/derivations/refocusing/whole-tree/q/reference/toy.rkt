#lang racket

(require redex/reduction-semantics
         (prefix-in lean-d:
                    "../../reference/lean/toy/decomposition.rkt")
         (prefix-in lean: "../../reference/lean/toy/language.rkt")
         (prefix-in marked-d:
                    "../../reference/marked/toy/decomposition.rkt")
         (prefix-in marked: "../../reference/marked/toy/language.rkt")
         "./decomposition-schema.rkt"
         "./source-schema.rkt")

(provide Q-A/toy
         Q-W/toy
         Q-R/toy
         Q-D/toy
         Q-R-in-lean-language?/toy)

(define-reference-source-Q
  marked:pk-toy-lang
  Q-A/toy
  Q-W/toy
  Q-R/toy)

(define-reference-decomposition-Q
  marked-d:pk-toy-decomposition-lang
  marked-d:plug-D/toy
  Q-R/toy
  lean-d:decompose/lean-toy
  Q-D/toy)

(define (Q-R-in-lean-language?/toy frontier)
  (redex-match? lean:lean-toy-lang F frontier))
