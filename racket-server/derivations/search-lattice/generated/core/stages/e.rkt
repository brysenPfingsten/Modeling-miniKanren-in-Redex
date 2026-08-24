#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../source/e.rkt"
         "./policy.rkt")

(provide core/stage/R/E
         core/stage/D/E
         core/stage/Z/E
         core/stage/M/E
         core/stage/B/E
         core/stage/Big/E
         core/staged-row/E
         generated-core-stage-e-decomposition-lang
         generated-stage-plug-C/e
         generated-stage-contract-label/e
         generated-stage-decompose/e
         generated-stage-contract/e
         generated-stage-decomposed-step/e
         generated-core-stage-e-refocused-lang
         generated-stage-refocus-phase/e
         generated-stage-refocus-work/direct/e
         generated-stage-refocus/direct/e/frontier
         generated-stage-refocus/direct/e
         generated-stage-refocused-step/direct/e
         generated-core-stage-e-machine-lang
         generated-stage-machineize/e
         generated-stage-machine-refocus-work/direct/e
         generated-stage-machine-refocus/direct/e/frontier
         generated-stage-machine-refocus/direct/e
         generated-stage-machine-step/direct/e
         generated-core-stage-e-compressed-lang
         generated-stage-compress/e
         generated-stage-compress/e/frontier
         generated-stage-transition-span-labels/e
         generated-stage-produce-settled/direct/e
         generated-stage-produce-dead/direct/e
         generated-stage-advance-settled/direct/e
         generated-stage-advance-dead/direct/e
         generated-stage-compressed-step/direct/e/base-singleton
         generated-stage-compressed-step/direct/e
         generated-stage-replay-transition-span/M/e
         generated-core-stage-e-big-lang
         generated-stage-big-dispatch/direct/e/one
         generated-stage-big-dispatch/direct/e
         generated-stage-big-dispatch/direct/e/refocus-frontier
         generated-stage-big-dispatch/direct/e/control-one
         generated-stage-big-dispatch/direct/e/control
         generated-stage-big-dispatch/direct/e/frontier
         generated-stage-big-run/direct/e
         generated-stage-big-settled/direct/e
         generated-stage-big-dead/direct/e
         generated-stage-big-final/direct/e
         generated-stage-big-evaluate/direct/e
         generated-core-stage-e-big-spec-lang
         generated-stage-initialize-B/spec/e
         generated-stage-close-B/spec/e
         generated-stage-flatten-BTrace/e
         generated-stage-promote-B/direct/e
         generated-stage-big-evaluate/spec/e
         generated-stage-B-Big-unfold-square/e
         generated-stage-B-Big-closure-square/e
         generated-stage-B-Big-root-square/e)

(module+ diagnostics
  (provide generated-stage-plug-D/e
           generated-stage-D->Z/e
           generated-stage-Z->D/e
           generated-stage-readback-Z/e
           generated-stage-refocus/spec/e
           generated-stage-refocused-step/spec/e
           generated-stage-encode-ZM/e
           generated-stage-decode-MZ/e
           generated-stage-D->M/e
           generated-stage-M->D/e
           generated-stage-readback-M/e
           generated-stage-ZM-corresponds/e
           generated-stage-machine-step/spec/e
           generated-stage-ZM-step-square/e
           generated-stage-encode-MB/e
           generated-stage-decode-BM/e
           generated-stage-readback-B/e
           generated-stage-MB-corresponds/e
           generated-stage-compressed-step/spec/e
           generated-stage-MB-step-square/e
           generated-stage-readback-Big/e))

(check-redundancy #t)

(define-generated-core-stage-instance
  #:source-interface generated-core-e-source
  #:instance core/stage/R/E)

(define-selected-decomposition-stage core/stage/D/E
  #:from core/stage/R/E
  #:language generated-core-stage-e-decomposition-lang
  #:plug-D generated-stage-plug-D/e
  #:plug-C generated-stage-plug-C/e
  #:contract-label generated-stage-contract-label/e
  #:decompose generated-stage-decompose/e
  #:contract generated-stage-contract/e
  #:step generated-stage-decomposed-step/e)

(define-selected-refocused-stage core/stage/Z/E
  #:from core/stage/D/E
  #:language generated-core-stage-e-refocused-lang
  #:refocus-phase generated-stage-refocus-phase/e
  #:D->Z generated-stage-D->Z/e
  #:Z->D generated-stage-Z->D/e
  #:readback generated-stage-readback-Z/e
  #:refocus-spec generated-stage-refocus/spec/e
  #:refocus-work-direct generated-stage-refocus-work/direct/e
  #:refocus-direct generated-stage-refocus/direct/e
  #:step-spec generated-stage-refocused-step/spec/e
  #:step-direct generated-stage-refocused-step/direct/e)

(define-selected-machine-isomorphism-stage core/stage/M/E
  #:from core/stage/Z/E
  #:language generated-core-stage-e-machine-lang
  #:machineize generated-stage-machineize/e
  #:encode-ZM generated-stage-encode-ZM/e
  #:decode-MZ generated-stage-decode-MZ/e
  #:D->M generated-stage-D->M/e
  #:M->D generated-stage-M->D/e
  #:readback generated-stage-readback-M/e
  #:refocus-work-direct generated-stage-machine-refocus-work/direct/e
  #:refocus-direct generated-stage-machine-refocus/direct/e
  #:step-direct generated-stage-machine-step/direct/e
  #:corresponds generated-stage-ZM-corresponds/e
  #:step-spec generated-stage-machine-step/spec/e
  #:square generated-stage-ZM-step-square/e)

(define-selected-compressed-stage core/stage/B/E
  #:from core/stage/M/E
  #:policy generated-core-compression-policy
  #:language generated-core-stage-e-compressed-lang
  #:compress generated-stage-compress/e
  #:encode-MB generated-stage-encode-MB/e
  #:decode-BM generated-stage-decode-BM/e
  #:readback generated-stage-readback-B/e
  #:span-labels generated-stage-transition-span-labels/e
  #:produce-settled generated-stage-produce-settled/direct/e
  #:produce-dead generated-stage-produce-dead/direct/e
  #:advance-settled generated-stage-advance-settled/direct/e
  #:advance-dead generated-stage-advance-dead/direct/e
  #:step-direct generated-stage-compressed-step/direct/e
  #:corresponds generated-stage-MB-corresponds/e
  #:replay generated-stage-replay-transition-span/M/e
  #:step-spec generated-stage-compressed-step/spec/e
  #:square generated-stage-MB-step-square/e)

(define-selected-fixed-point-stage core/stage/Big/E
  #:from core/stage/B/E
  #:language generated-core-stage-e-big-lang
  #:readback generated-stage-readback-Big/e
  #:dispatch generated-stage-big-dispatch/direct/e
  #:run generated-stage-big-run/direct/e
  #:settled generated-stage-big-settled/direct/e
  #:dead generated-stage-big-dead/direct/e
  #:final generated-stage-big-final/direct/e
  #:evaluate generated-stage-big-evaluate/direct/e
  #:spec-language generated-core-stage-e-big-spec-lang
  #:initialize generated-stage-initialize-B/spec/e
  #:close generated-stage-close-B/spec/e
  #:flatten generated-stage-flatten-BTrace/e
  #:promote generated-stage-promote-B/direct/e
  #:evaluate-spec generated-stage-big-evaluate/spec/e
  #:unfold-square generated-stage-B-Big-unfold-square/e
  #:closure-square generated-stage-B-Big-closure-square/e
  #:root-square generated-stage-B-Big-root-square/e)

(define-selected-staged-row core/staged-row/E
  #:source-language generated-core-e-lang
  #:D core/stage/D/E
  #:Z core/stage/Z/E
  #:M core/stage/M/E
  #:B core/stage/B/E
  #:Big core/stage/Big/E)
