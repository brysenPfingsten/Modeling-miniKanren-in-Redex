#lang racket

(require redex/reduction-semantics
         "../source-schema.rkt"
         "./kernel.rkt"
         "./labels.rkt"
         "./language.rkt")

(provide initial-tree/toy
         source-step/toy
         source-red/toy)

(define-pk-source
  pk-toy-lang
  kernel-step/toy
  kernel-initial-state/toy
  kernel-open-fresh/toy
  whole-marker-support/toy
  control-resume/toy
  control-freeze/toy
  label->redex-name/toy
  initial-tree/toy
  settled-choice-success/toy
  settled-choice-alternate/toy
  source-step/toy
  source-red/toy)
