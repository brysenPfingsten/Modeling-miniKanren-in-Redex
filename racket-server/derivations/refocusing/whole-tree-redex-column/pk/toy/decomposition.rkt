#lang racket

(require redex/reduction-semantics
         "../decomposition-language-schema.rkt"
         "../decomposition-schema.rkt"
         "./kernel.rkt"
         "./labels.rkt"
         "./language.rkt"
         "./wf.rkt")

(provide pk-toy-decomposition-lang
         decompose/toy
         contract/toy
         plug-D/toy
         plug-C/toy
         contract-label/toy
         decompose-one/toy
         next-decomposition/toy
         decomposed-step/spec/toy
         decomposed-steps/spec/toy
         decomposition-image/toy
         reachable-decomposition/via/toy
         decomposed-step/direct/toy
         decomposed-red/direct/toy)

(check-redundancy #t)

(define-pk-decomposition-language
  pk-toy-decomposition-lang
  pk-toy-lang)

(define-pk-decomposition-spec
  pk-toy-decomposition-lang
  kernel-step/toy
  kernel-open-fresh/toy
  whole-marker-support/toy
  control-resume/toy
  control-freeze/toy
  wf-frontier/toy
  plug-D/toy
  plug-C/toy
  contract-label/toy
  decomposition-choice-success/toy
  decomposition-choice-alternate/toy
  decompose/toy
  contract/toy
  decompose-one/toy
  next-decomposition/toy
  decomposed-step/spec/toy
  decomposed-steps/spec/toy
  decomposition-image/toy
  reachable-decomposition/via/toy)

(define-pk-decomposition-direct
  pk-toy-decomposition-lang
  kernel-step/toy
  kernel-open-fresh/toy
  whole-marker-support/toy
  control-resume/toy
  control-freeze/toy
  label->redex-name/toy
  plug-D/toy
  next-decomposition/toy
  decomposition-choice-success/toy
  decomposition-choice-alternate/toy
  decomposed-step/direct/toy
  decomposed-red/direct/toy)
