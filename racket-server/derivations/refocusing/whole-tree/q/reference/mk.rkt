#lang racket

(require redex/reduction-semantics
         (prefix-in lean: "../../reference/lean/mk/language.rkt")
         (prefix-in marked: "../../reference/marked/mk/language.rkt")
         "./source-schema.rkt")

(provide Q-A/mk
         Q-W/mk
         Q-R/mk
         Q-R-in-lean-language?/mk)

(define-reference-source-Q
  marked:pk-mk-lang
  Q-A/mk
  Q-W/mk
  Q-R/mk)

(define (Q-R-in-lean-language?/mk frontier)
  (redex-match? lean:lean-mk-lang F frontier))
