#lang racket

(require redex/reduction-semantics
         "../big-step-spec-schema.rkt"
         "./big-step-language.rkt"
         "./compressed.rkt"
         "./wf.rkt")

(provide compressed-big-step/spec/toy
         compressed-big-step-result/spec/toy
         big-step/spec/toy
         big-step-result/spec/toy)

(check-redundancy #t)

(define-pk-big-step-spec
  pk-toy-big-step-lang
  compressed-step/direct/toy
  initial-compressed/direct/toy
  wf-frontier/toy
  compressed-big-step/spec/toy
  compressed-big-step-result/spec/toy
  big-step/spec/toy
  big-step-result/spec/toy)
