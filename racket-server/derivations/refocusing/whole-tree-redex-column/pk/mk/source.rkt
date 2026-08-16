#lang racket

(require redex/reduction-semantics
         "../source-schema.rkt"
         "./kernel.rkt"
         "./labels.rkt"
         "./language.rkt")

(provide initial-tree/mk
         source-step/mk
         source-red/mk)

(define-pk-source
  pk-mk-lang
  kernel-step/mk
  kernel-initial-state/mk
  kernel-open-fresh/mk
  whole-marker-support/mk
  control-resume/mk
  control-freeze/mk
  label->redex-name/mk
  initial-tree/mk
  settled-choice-success/mk
  settled-choice-alternate/mk
  source-step/mk
  source-red/mk)
