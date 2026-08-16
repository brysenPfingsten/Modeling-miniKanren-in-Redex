#lang racket

(require redex/reduction-semantics
         "../big-step-spec-schema.rkt"
         "./big-step-language.rkt"
         "./compressed.rkt"
         "./wf.rkt")

(provide compressed-big-step/spec/mk
         compressed-big-step-result/spec/mk
         big-step/spec/mk
         big-step-result/spec/mk)

(check-redundancy #t)

(define-pk-big-step-spec
  pk-mk-big-step-lang
  compressed-step/direct/mk
  initial-compressed/direct/mk
  wf-frontier/mk
  compressed-big-step/spec/mk
  compressed-big-step-result/spec/mk
  big-step/spec/mk
  big-step-result/spec/mk)
