#lang racket

(require redex/reduction-semantics
         "../big-step-language-schema.rkt"
         "./language.rkt")

(provide pk-toy-big-step-lang
         big-step-readback/toy)

(check-redundancy #t)

(define-pk-big-step-language
  pk-toy-big-step-lang
  pk-toy-lang
  big-step-readback/toy)
