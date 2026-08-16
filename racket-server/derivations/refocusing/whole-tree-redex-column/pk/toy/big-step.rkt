#lang racket

(require redex/reduction-semantics
         "../big-step-schema.rkt"
         "./big-step-language.rkt"
         "./kernel.rkt"
         "./wf.rkt")

(provide pk-toy-big-step-direct-lang
         evaluate-query/direct/toy
         big-run/direct/toy
         big-settled/direct/toy
         big-dead/direct/toy
         big-delay/direct/toy
         big-final/direct/toy
         promote/direct/toy
         big-step/direct/toy)

(check-redundancy #t)

(define-pk-big-step
  pk-toy-big-step-direct-lang
  pk-toy-big-step-lang
  kernel-step/toy
  kernel-open-fresh/toy
  whole-marker-support/toy
  control-resume/toy
  control-freeze/toy
  wf-frontier/toy
  evaluate-query/direct/toy
  big-run/direct/toy
  big-settled/direct/toy
  big-dead/direct/toy
  big-delay/direct/toy
  big-final/direct/toy
  promote/direct/toy
  big-step/direct/toy)
