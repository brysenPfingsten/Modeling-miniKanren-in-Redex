#lang racket

(require redex/reduction-semantics
         "../decomposition-language-schema.rkt"
         "../decomposition-schema.rkt"
         "./kernel.rkt"
         "./labels.rkt"
         "./language.rkt"
         "./wf.rkt")

(provide pk-mk-decomposition-lang
         decompose/mk
         contract/mk
         plug-D/mk
         plug-C/mk
         contract-label/mk
         decompose-one/mk
         next-decomposition/mk
         decomposed-step/spec/mk
         decomposed-steps/spec/mk
         decomposition-image/mk
         reachable-decomposition/via/mk
         decomposed-step/direct/mk
         decomposed-red/direct/mk)

(check-redundancy #t)

(define-pk-decomposition-language
  pk-mk-decomposition-lang
  pk-mk-lang)

(define-pk-decomposition-spec
  pk-mk-decomposition-lang
  kernel-step/mk
  kernel-open-fresh/mk
  whole-marker-support/mk
  control-resume/mk
  control-freeze/mk
  wf-frontier/mk
  plug-D/mk
  plug-C/mk
  contract-label/mk
  decomposition-choice-success/mk
  decomposition-choice-alternate/mk
  decompose/mk
  contract/mk
  decompose-one/mk
  next-decomposition/mk
  decomposed-step/spec/mk
  decomposed-steps/spec/mk
  decomposition-image/mk
  reachable-decomposition/via/mk)

(define-pk-decomposition-direct
  pk-mk-decomposition-lang
  kernel-step/mk
  kernel-open-fresh/mk
  whole-marker-support/mk
  control-resume/mk
  control-freeze/mk
  label->redex-name/mk
  plug-D/mk
  next-decomposition/mk
  decomposition-choice-success/mk
  decomposition-choice-alternate/mk
  decomposed-step/direct/mk
  decomposed-red/direct/mk)
