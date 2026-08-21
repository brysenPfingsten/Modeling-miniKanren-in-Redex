#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: redex/parameter)
         "stage-generators.rkt"
         "stage-generators-parameter-base-fixture.rkt")

(provide hygiene-evidence/extended
         hygiene-D-lang
         hygiene-contract
         hygiene-D-step
         hygiene-B-lang
         hygiene-B-step/direct
         hygiene-B-step/spec
         hygiene-Big-lang
         hygiene-big-evaluate/direct
         hygiene-big-evaluate/spec)

(define-extended-language hygiene-source-lang
  hygiene-base-lang
  [Input .... string])

(redex-parameter:define-extended-judgment-form*
 hygiene-evidence
 hygiene-source-lang
 #:mode (hygiene-evidence/extended I O)
 [---------------- "extended-evidence-left"
  (hygiene-evidence/extended string 7)]
 [---------------- "extended-evidence-right"
  (hygiene-evidence/extended string 7)])

;; This host-side Redex predicate deliberately collides by spelling with the
;; inherited judgment slot.  A side-condition body must retain this binding,
;; while a rule-premise head with the same spelling denotes the slot.
(define-metafunction hygiene-source-lang
  evidence : Input -> boolean
  [(evidence "cross-module") #t]
  [(evidence Input) #f])

;; The new rule is parsed in this module, but its evidence premise calls the
;; slot carried by the exported base descriptor.  This is the cross-module
;; hygiene boundary under test.
(define-derivation-delta hygiene/I
  #:from hygiene/base
  #:source-language hygiene-source-lang
  #:redex-parameter-overrides
  ([evidence hygiene-evidence/extended])
  #:run-productions-add ()
  #:nonallocation-run-productions-add ()
  #:frames-add ()
  #:work-redexes-add ()
  #:frontier-redexes-add ()
  #:allocation-redexes-add ()
  #:terminals-add ()
  #:open-work-productions-add ()
  #:rules-add
  ([query
    #:site work
    #:from (run (Query Input) WorkFocus)
    #:to (run (Tick N) WorkFocus)
    #:premises
    ((side-condition (evidence Input))
     (side-condition/hidden (evidence Input))
     (evidence Input N))]))

(define-decomposition-stage hygiene/D
  #:from hygiene/I
  #:language hygiene-D-lang
  #:plug-D hygiene-plug-D
  #:plug-C hygiene-plug-C
  #:contract-label hygiene-contract-label
  #:decompose hygiene-decompose
  #:contract hygiene-contract
  #:step hygiene-D-step)

(define-refocused-stage hygiene/Z
  #:from hygiene/D
  #:language hygiene-Z-lang
  #:D->Z hygiene-D->Z
  #:Z->D hygiene-Z->D
  #:readback hygiene-readback-Z
  #:refocus-spec hygiene-refocus/spec
  #:refocus-work-direct hygiene-refocus-work/direct
  #:refocus-direct hygiene-refocus/direct
  #:step-spec hygiene-Z-step/spec
  #:step-direct hygiene-Z-step/direct)

(define-machine-isomorphism-stage hygiene/M
  #:from hygiene/Z
  #:language hygiene-M-lang
  #:encode-ZM hygiene-encode-ZM
  #:decode-MZ hygiene-decode-MZ
  #:D->M hygiene-D->M
  #:M->D hygiene-M->D
  #:readback hygiene-readback-M
  #:refocus-work-direct hygiene-machine-refocus-work/direct
  #:refocus-direct hygiene-machine-refocus/direct
  #:step-direct hygiene-M-step/direct
  #:corresponds hygiene-ZM-corresponds
  #:step-spec hygiene-M-step/spec
  #:square hygiene-ZM-square)

(define-compression-policy hygiene/compression
  #:settled-producers (tick)
  #:dead-producers (fail)
  #:settled-followers (pop-value finish)
  #:dead-followers (pop-crash)
  #:singletons (query allocate pop-value pop-crash finish)
  #:retained-observation rule-labels
  #:maximum-span 2)

(define-compressed-stage hygiene/B
  #:from hygiene/M
  #:policy hygiene/compression
  #:language hygiene-B-lang
  #:encode-MB hygiene-encode-MB
  #:decode-BM hygiene-decode-BM
  #:readback hygiene-readback-B
  #:span-labels hygiene-span-labels
  #:produce-settled hygiene-produce-settled
  #:produce-dead hygiene-produce-dead
  #:advance-settled hygiene-advance-settled
  #:advance-dead hygiene-advance-dead
  #:step-direct hygiene-B-step/direct
  #:corresponds hygiene-MB-corresponds
  #:replay hygiene-replay/M
  #:step-spec hygiene-B-step/spec
  #:square hygiene-MB-square)

(define-fixed-point-stage hygiene/Big
  #:from hygiene/B
  #:language hygiene-Big-lang
  #:readback hygiene-readback-Big
  #:dispatch hygiene-big-dispatch/direct
  #:run hygiene-big-run/direct
  #:settled hygiene-big-settled/direct
  #:dead hygiene-big-dead/direct
  #:final hygiene-big-final/direct
  #:evaluate hygiene-big-evaluate/direct
  #:spec-language hygiene-Big-spec-lang
  #:initialize hygiene-initialize-B/spec
  #:close hygiene-close-B/spec
  #:flatten hygiene-flatten-BTrace
  #:promote hygiene-promote-B/direct
  #:evaluate-spec hygiene-big-evaluate/spec
  #:unfold-square hygiene-B-Big-unfold-square
  #:closure-square hygiene-B-Big-closure-square
  #:root-square hygiene-B-Big-root-square)
