#lang racket

(require redex/reduction-semantics
         "../decomposition-language-schema.rkt"
         "../decomposition-schema.rkt"
         "./kernel.rkt"
         "./labels.rkt"
         "./language.rkt"
         "./source.rkt"
         "./wf.rkt")

(provide lean-toy-decomposition-lang
         decompose/lean-toy
         contract/lean-toy
         plug-D/lean-toy
         plug-C/lean-toy
         contract-label/lean-toy
         decompose-one/lean-toy
         next-decomposition/lean-toy
         decomposed-step/spec/lean-toy
         decomposed-steps/spec/lean-toy
         decomposition-image/lean-toy
         reachable-decomposition/via/lean-toy
         decomposed-step/direct/lean-toy
         decomposed-red/direct/lean-toy)

(check-redundancy #t)

(define-lean-decomposition-language lean-toy-decomposition-lang lean-toy-lang)

(define-lean-decomposition-spec lean-toy-decomposition-lang
                                kernel-step/lean-toy
                                kernel-open-fresh/lean-toy
                                whole-runtime-support/lean-toy
                                control-resume/lean-toy
                                control-freeze/lean-toy
                                wf-frontier/lean-toy
                                plug-D/lean-toy
                                plug-C/lean-toy
                                contract-label/lean-toy
                                decomposition-choice-success/lean-toy
                                decomposition-choice-alternate/lean-toy
                                decompose/lean-toy
                                contract/lean-toy
                                decompose-one/lean-toy
                                next-decomposition/lean-toy
                                decomposed-step/spec/lean-toy
                                decomposed-steps/spec/lean-toy
                                decomposition-image/lean-toy
                                reachable-decomposition/via/lean-toy)

(define-lean-decomposition-direct lean-toy-decomposition-lang
                                  kernel-step/lean-toy
                                  kernel-open-fresh/lean-toy
                                  whole-runtime-support/lean-toy
                                  control-resume/lean-toy
                                  control-freeze/lean-toy
                                  label->redex-name/lean-toy
                                  next-decomposition/lean-toy
                                  decomposition-choice-success/lean-toy
                                  decomposition-choice-alternate/lean-toy
                                  decomposed-step/direct/lean-toy
                                  decomposed-red/direct/lean-toy)
