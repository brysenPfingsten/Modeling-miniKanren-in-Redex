#lang racket

(require redex/reduction-semantics
         "../big-step-language-schema.rkt"
         "./language.rkt")

(provide pk-mk-big-step-lang
         big-step-readback/mk)

(check-redundancy #t)

(define-pk-big-step-language
  pk-mk-big-step-lang
  pk-mk-lang
  big-step-readback/mk)
