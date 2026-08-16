#lang racket

(require redex/reduction-semantics
         "../big-step-correspondence-schema.rkt"
         "./big-step-spec.rkt"
         "./big-step.rkt"
         "./compressed.rkt")

(provide big-step-square/mk
         big-step-unfold-square/mk
         root-big-step-square/mk)

(check-redundancy #t)

(define-pk-big-step-correspondence
  pk-mk-big-step-direct-lang
  compressed-step/direct/mk
  compressed-big-step/spec/mk
  promote/direct/mk
  big-step/spec/mk
  big-step/direct/mk
  big-step-square/mk
  big-step-unfold-square/mk
  root-big-step-square/mk)
