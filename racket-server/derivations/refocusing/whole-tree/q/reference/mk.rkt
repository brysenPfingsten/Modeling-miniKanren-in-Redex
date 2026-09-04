#lang racket

(require redex/reduction-semantics
         (prefix-in lean-d:
                    "../../reference/lean/mk/decomposition.rkt")
         (prefix-in lean: "../../reference/lean/mk/language.rkt")
         (prefix-in marked-d:
                    "../../reference/marked/mk/decomposition.rkt")
         (prefix-in marked: "../../reference/marked/mk/language.rkt")
         "./decomposition-schema.rkt"
         "./source-schema.rkt")

(provide Q-A/mk
         Q-W/mk
         Q-R/mk
         Q-D/mk
         Q-R-in-lean-language?/mk)

(define-reference-source-Q
  marked:pk-mk-lang
  Q-A/mk
  Q-W/mk
  Q-R/mk)

(define-reference-decomposition-Q
  marked-d:pk-mk-decomposition-lang
  marked-d:plug-D/mk
  Q-R/mk
  lean-d:decompose/lean-mk
  Q-D/mk)

(define (Q-R-in-lean-language?/mk frontier)
  (redex-match? lean:lean-mk-lang F frontier))
