#lang racket

(require redex/reduction-semantics
         "../big-step-correspondence-schema.rkt"
         "./big-step-spec.rkt"
         "./big-step.rkt"
         "./compressed.rkt")

(provide big-step-square/toy
         big-step-unfold-square/toy
         root-big-step-square/toy)

(check-redundancy #t)

(define-pk-big-step-correspondence
  pk-toy-big-step-direct-lang
  compressed-step/direct/toy
  compressed-big-step/spec/toy
  promote/direct/toy
  big-step/spec/toy
  big-step/direct/toy
  big-step-square/toy
  big-step-unfold-square/toy
  root-big-step-square/toy)
