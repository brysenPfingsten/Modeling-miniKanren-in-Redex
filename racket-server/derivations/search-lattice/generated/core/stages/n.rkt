#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../../../framework/stage-generators.rkt"
         "../source/n.rkt"
         "./policy.rkt")

(provide core/stage/R/N
         core/stage/D/N
         core/stage/Z/N
         core/stage/M/N
         core/stage/B/N
         core/stage/Big/N
         generated-core-stage-n-decomposition-lang
         generated-stage-plug-D/n
         generated-stage-plug-C/n
         generated-stage-contract-label/n
         generated-stage-decompose/n
         generated-stage-contract/n
         generated-stage-decomposed-step/n
         generated-core-stage-n-refocused-lang
         generated-stage-D->Z/n
         generated-stage-Z->D/n
         generated-stage-readback-Z/n
         generated-stage-refocus/spec/n
         generated-stage-refocus-work/direct/n
         generated-stage-refocus/direct/n
         generated-stage-refocused-step/spec/n
         generated-stage-refocused-step/direct/n
         generated-core-stage-n-machine-lang
         generated-stage-encode-ZM/n
         generated-stage-decode-MZ/n
         generated-stage-D->M/n
         generated-stage-M->D/n
         generated-stage-readback-M/n
         generated-stage-machine-refocus-work/direct/n
         generated-stage-machine-refocus/direct/n
         generated-stage-machine-step/direct/n
         generated-stage-ZM-corresponds/n
         generated-stage-machine-step/spec/n
         generated-stage-ZM-step-square/n
         generated-core-stage-n-compressed-lang
         generated-stage-encode-MB/n
         generated-stage-decode-BM/n
         generated-stage-readback-B/n
         generated-stage-transition-span-labels/n
         generated-stage-produce-settled/direct/n
         generated-stage-produce-dead/direct/n
         generated-stage-advance-settled/direct/n
         generated-stage-advance-dead/direct/n
         generated-stage-compressed-step/direct/n
         generated-stage-MB-corresponds/n
         generated-stage-replay-transition-span/M/n
         generated-stage-compressed-step/spec/n
         generated-stage-MB-step-square/n
         generated-core-stage-n-big-lang
         generated-stage-readback-Big/n
         generated-stage-big-dispatch/direct/n
         generated-stage-big-run/direct/n
         generated-stage-big-settled/direct/n
         generated-stage-big-dead/direct/n
         generated-stage-big-final/direct/n
         generated-stage-big-evaluate/direct/n
         generated-core-stage-n-big-spec-lang
         generated-stage-initialize-B/spec/n
         generated-stage-close-B/spec/n
         generated-stage-flatten-BTrace/n
         generated-stage-promote-B/direct/n
         generated-stage-big-evaluate/spec/n
         generated-stage-B-Big-unfold-square/n
         generated-stage-B-Big-closure-square/n
         generated-stage-B-Big-root-square/n)

(check-redundancy #t)

(define-generated-core-stage-instance
  #:source-interface generated-core-n-source
  #:instance core/stage/R/N)

(define-decomposition-stage core/stage/D/N
  #:from core/stage/R/N
  #:language generated-core-stage-n-decomposition-lang
  #:plug-D generated-stage-plug-D/n
  #:plug-C generated-stage-plug-C/n
  #:contract-label generated-stage-contract-label/n
  #:decompose generated-stage-decompose/n
  #:contract generated-stage-contract/n
  #:step generated-stage-decomposed-step/n)

(define-refocused-stage core/stage/Z/N
  #:from core/stage/D/N
  #:language generated-core-stage-n-refocused-lang
  #:D->Z generated-stage-D->Z/n
  #:Z->D generated-stage-Z->D/n
  #:readback generated-stage-readback-Z/n
  #:refocus-spec generated-stage-refocus/spec/n
  #:refocus-work-direct generated-stage-refocus-work/direct/n
  #:refocus-direct generated-stage-refocus/direct/n
  #:step-spec generated-stage-refocused-step/spec/n
  #:step-direct generated-stage-refocused-step/direct/n)

(define-machine-isomorphism-stage core/stage/M/N
  #:from core/stage/Z/N
  #:language generated-core-stage-n-machine-lang
  #:encode-ZM generated-stage-encode-ZM/n
  #:decode-MZ generated-stage-decode-MZ/n
  #:D->M generated-stage-D->M/n
  #:M->D generated-stage-M->D/n
  #:readback generated-stage-readback-M/n
  #:refocus-work-direct generated-stage-machine-refocus-work/direct/n
  #:refocus-direct generated-stage-machine-refocus/direct/n
  #:step-direct generated-stage-machine-step/direct/n
  #:corresponds generated-stage-ZM-corresponds/n
  #:step-spec generated-stage-machine-step/spec/n
  #:square generated-stage-ZM-step-square/n)

(define-compressed-stage core/stage/B/N
  #:from core/stage/M/N
  #:policy generated-core-compression-policy
  #:language generated-core-stage-n-compressed-lang
  #:encode-MB generated-stage-encode-MB/n
  #:decode-BM generated-stage-decode-BM/n
  #:readback generated-stage-readback-B/n
  #:span-labels generated-stage-transition-span-labels/n
  #:produce-settled generated-stage-produce-settled/direct/n
  #:produce-dead generated-stage-produce-dead/direct/n
  #:advance-settled generated-stage-advance-settled/direct/n
  #:advance-dead generated-stage-advance-dead/direct/n
  #:step-direct generated-stage-compressed-step/direct/n
  #:corresponds generated-stage-MB-corresponds/n
  #:replay generated-stage-replay-transition-span/M/n
  #:step-spec generated-stage-compressed-step/spec/n
  #:square generated-stage-MB-step-square/n)

(define-fixed-point-stage core/stage/Big/N
  #:from core/stage/B/N
  #:language generated-core-stage-n-big-lang
  #:readback generated-stage-readback-Big/n
  #:dispatch generated-stage-big-dispatch/direct/n
  #:run generated-stage-big-run/direct/n
  #:settled generated-stage-big-settled/direct/n
  #:dead generated-stage-big-dead/direct/n
  #:final generated-stage-big-final/direct/n
  #:evaluate generated-stage-big-evaluate/direct/n
  #:spec-language generated-core-stage-n-big-spec-lang
  #:initialize generated-stage-initialize-B/spec/n
  #:close generated-stage-close-B/spec/n
  #:flatten generated-stage-flatten-BTrace/n
  #:promote generated-stage-promote-B/direct/n
  #:evaluate-spec generated-stage-big-evaluate/spec/n
  #:unfold-square generated-stage-B-Big-unfold-square/n
  #:closure-square generated-stage-B-Big-closure-square/n
  #:root-square generated-stage-B-Big-root-square/n)
