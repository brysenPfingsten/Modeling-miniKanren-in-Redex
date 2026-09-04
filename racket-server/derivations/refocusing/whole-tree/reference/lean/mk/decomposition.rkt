#lang racket

(require redex/reduction-semantics
         "../decomposition-language-schema.rkt"
         "../decomposition-schema.rkt"
         "./kernel.rkt"
         "./labels.rkt"
         "./language.rkt"
         "./source.rkt"
         "./wf.rkt")

(provide lean-mk-decomposition-lang
         decompose/lean-mk
         contract/lean-mk
         plug-D/lean-mk
         plug-C/lean-mk
         contract-label/lean-mk
         decompose-one/lean-mk
         next-decomposition/lean-mk
         decomposed-step/spec/lean-mk
         decomposed-steps/spec/lean-mk
         decomposition-image/lean-mk
         reachable-decomposition/via/lean-mk
         decomposed-step/direct/lean-mk
         decomposed-red/direct/lean-mk)

(check-redundancy #t)

(define-lean-decomposition-language lean-mk-decomposition-lang lean-mk-lang)

(define-lean-decomposition-spec lean-mk-decomposition-lang
                                kernel-step/lean-mk
                                kernel-open-fresh/lean-mk
                                whole-runtime-support/lean-mk
                                control-resume/lean-mk
                                control-freeze/lean-mk
                                wf-frontier/lean-mk
                                plug-D/lean-mk
                                plug-C/lean-mk
                                contract-label/lean-mk
                                decomposition-choice-success/lean-mk
                                decomposition-choice-alternate/lean-mk
                                decompose/lean-mk
                                contract/lean-mk
                                decompose-one/lean-mk
                                next-decomposition/lean-mk
                                decomposed-step/spec/lean-mk
                                decomposed-steps/spec/lean-mk
                                decomposition-image/lean-mk
                                reachable-decomposition/via/lean-mk)

(define-lean-decomposition-direct lean-mk-decomposition-lang
                                  kernel-step/lean-mk
                                  kernel-open-fresh/lean-mk
                                  whole-runtime-support/lean-mk
                                  control-resume/lean-mk
                                  control-freeze/lean-mk
                                  label->redex-name/lean-mk
                                  next-decomposition/lean-mk
                                  decomposition-choice-success/lean-mk
                                  decomposition-choice-alternate/lean-mk
                                  decomposed-step/direct/lean-mk
                                  decomposed-red/direct/lean-mk)
