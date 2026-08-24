#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../source/s.rkt"
         "./policy.rkt")

(provide core/stage/R/S
         core/stage/D/S
         core/stage/Z/S
         core/stage/M/S
         core/stage/B/S
         core/stage/Big/S
         core/staged-row/S
         generated-core-stage-s-decomposition-lang
         generated-stage-plug-C/s
         generated-stage-contract-label/s
         generated-stage-decompose/s
         generated-stage-contract/s
         generated-stage-decomposed-step/s
         generated-core-stage-s-refocused-lang
         generated-stage-refocus-phase/s
         generated-stage-refocus-work/direct/s
         generated-stage-refocus/direct/s/frontier
         generated-stage-refocus/direct/s
         generated-stage-refocused-step/direct/s
         generated-core-stage-s-machine-lang
         generated-stage-machineize/s
         generated-stage-machine-refocus-work/direct/s
         generated-stage-machine-refocus/direct/s/frontier
         generated-stage-machine-refocus/direct/s
         generated-stage-machine-step/direct/s
         generated-core-stage-s-compressed-lang
         generated-stage-compress/s
         generated-stage-compress/s/frontier
         generated-stage-transition-span-labels/s
         generated-stage-produce-settled/direct/s
         generated-stage-produce-dead/direct/s
         generated-stage-advance-settled/direct/s
         generated-stage-advance-dead/direct/s
         generated-stage-compressed-step/direct/s/base-singleton
         generated-stage-compressed-step/direct/s
         generated-stage-replay-transition-span/M/s
         generated-core-stage-s-big-lang
         generated-stage-big-dispatch/direct/s/one
         generated-stage-big-dispatch/direct/s
         generated-stage-big-dispatch/direct/s/refocus-frontier
         generated-stage-big-dispatch/direct/s/control-one
         generated-stage-big-dispatch/direct/s/control
         generated-stage-big-dispatch/direct/s/frontier
         generated-stage-big-run/direct/s
         generated-stage-big-settled/direct/s
         generated-stage-big-dead/direct/s
         generated-stage-big-final/direct/s
         generated-stage-big-evaluate/direct/s
         generated-core-stage-s-big-spec-lang
         generated-stage-initialize-B/spec/s
         generated-stage-close-B/spec/s
         generated-stage-flatten-BTrace/s
         generated-stage-promote-B/direct/s
         generated-stage-big-evaluate/spec/s
         generated-stage-B-Big-unfold-square/s
         generated-stage-B-Big-closure-square/s
         generated-stage-B-Big-root-square/s)

(module+ diagnostics
  (provide generated-stage-plug-D/s
           generated-stage-D->Z/s
           generated-stage-Z->D/s
           generated-stage-readback-Z/s
           generated-stage-refocus/spec/s
           generated-stage-refocused-step/spec/s
           generated-stage-encode-ZM/s
           generated-stage-decode-MZ/s
           generated-stage-D->M/s
           generated-stage-M->D/s
           generated-stage-readback-M/s
           generated-stage-ZM-corresponds/s
           generated-stage-machine-step/spec/s
           generated-stage-ZM-step-square/s
           generated-stage-encode-MB/s
           generated-stage-decode-BM/s
           generated-stage-readback-B/s
           generated-stage-MB-corresponds/s
           generated-stage-compressed-step/spec/s
           generated-stage-MB-step-square/s
           generated-stage-readback-Big/s))

(check-redundancy #t)

;; The source-interface is the only semantic input.  The five invocations
;; below are the common structural transformations; no core rule is restated.
(define-generated-core-stage-instance
  #:source-interface generated-core-s-source
  #:instance core/stage/R/S)

(define-selected-decomposition-stage core/stage/D/S
  #:from core/stage/R/S
  #:language generated-core-stage-s-decomposition-lang
  #:plug-D generated-stage-plug-D/s
  #:plug-C generated-stage-plug-C/s
  #:contract-label generated-stage-contract-label/s
  #:decompose generated-stage-decompose/s
  #:contract generated-stage-contract/s
  #:step generated-stage-decomposed-step/s)

(define-selected-refocused-stage core/stage/Z/S
  #:from core/stage/D/S
  #:language generated-core-stage-s-refocused-lang
  #:refocus-phase generated-stage-refocus-phase/s
  #:D->Z generated-stage-D->Z/s
  #:Z->D generated-stage-Z->D/s
  #:readback generated-stage-readback-Z/s
  #:refocus-spec generated-stage-refocus/spec/s
  #:refocus-work-direct generated-stage-refocus-work/direct/s
  #:refocus-direct generated-stage-refocus/direct/s
  #:step-spec generated-stage-refocused-step/spec/s
  #:step-direct generated-stage-refocused-step/direct/s)

(define-selected-machine-isomorphism-stage core/stage/M/S
  #:from core/stage/Z/S
  #:language generated-core-stage-s-machine-lang
  #:machineize generated-stage-machineize/s
  #:encode-ZM generated-stage-encode-ZM/s
  #:decode-MZ generated-stage-decode-MZ/s
  #:D->M generated-stage-D->M/s
  #:M->D generated-stage-M->D/s
  #:readback generated-stage-readback-M/s
  #:refocus-work-direct generated-stage-machine-refocus-work/direct/s
  #:refocus-direct generated-stage-machine-refocus/direct/s
  #:step-direct generated-stage-machine-step/direct/s
  #:corresponds generated-stage-ZM-corresponds/s
  #:step-spec generated-stage-machine-step/spec/s
  #:square generated-stage-ZM-step-square/s)

(define-selected-compressed-stage core/stage/B/S
  #:from core/stage/M/S
  #:policy generated-core-compression-policy
  #:language generated-core-stage-s-compressed-lang
  #:compress generated-stage-compress/s
  #:encode-MB generated-stage-encode-MB/s
  #:decode-BM generated-stage-decode-BM/s
  #:readback generated-stage-readback-B/s
  #:span-labels generated-stage-transition-span-labels/s
  #:produce-settled generated-stage-produce-settled/direct/s
  #:produce-dead generated-stage-produce-dead/direct/s
  #:advance-settled generated-stage-advance-settled/direct/s
  #:advance-dead generated-stage-advance-dead/direct/s
  #:step-direct generated-stage-compressed-step/direct/s
  #:corresponds generated-stage-MB-corresponds/s
  #:replay generated-stage-replay-transition-span/M/s
  #:step-spec generated-stage-compressed-step/spec/s
  #:square generated-stage-MB-step-square/s)

(define-selected-fixed-point-stage core/stage/Big/S
  #:from core/stage/B/S
  #:language generated-core-stage-s-big-lang
  #:readback generated-stage-readback-Big/s
  #:dispatch generated-stage-big-dispatch/direct/s
  #:run generated-stage-big-run/direct/s
  #:settled generated-stage-big-settled/direct/s
  #:dead generated-stage-big-dead/direct/s
  #:final generated-stage-big-final/direct/s
  #:evaluate generated-stage-big-evaluate/direct/s
  #:spec-language generated-core-stage-s-big-spec-lang
  #:initialize generated-stage-initialize-B/spec/s
  #:close generated-stage-close-B/spec/s
  #:flatten generated-stage-flatten-BTrace/s
  #:promote generated-stage-promote-B/direct/s
  #:evaluate-spec generated-stage-big-evaluate/spec/s
  #:unfold-square generated-stage-B-Big-unfold-square/s
  #:closure-square generated-stage-B-Big-closure-square/s
  #:root-square generated-stage-B-Big-root-square/s)

(define-selected-staged-row core/staged-row/S
  #:source-language generated-core-s-lang
  #:D core/stage/D/S
  #:Z core/stage/Z/S
  #:M core/stage/M/S
  #:B core/stage/B/S
  #:Big core/stage/Big/S)
