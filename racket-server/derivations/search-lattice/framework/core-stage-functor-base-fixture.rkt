#lang racket

(require redex/reduction-semantics
         "./core-stage-extension-base-fixture.rkt"
         "./core-stage-schema.rkt")

(provide selected-functor/base-row
         selected-functor-base-R
         selected-functor-base-D-lang
         selected-functor-base-D-step
         selected-functor-base-Z-lang
         selected-functor-base-Z-step
         selected-functor-base-M-lang
         selected-functor-base-M-step
         selected-functor-base-B-lang
         selected-functor-base-B-step
         selected-functor-base-Big-lang
         selected-functor-base-big-evaluate)

;; The frozen prototype requires both producer classes to be inhabited.  These
;; two base-owned rules are syntactically present but semantically impossible;
;; every executable base rule can therefore remain a singleton on both routes.
(define selected-functor-base-R
  (extend-reduction-relation
   selected-foreign-base-R
   selected-foreign-base-lang
   [--> (in-hole TaskFocus (Tick N))
        (in-hole TaskFocus (Value N))
        (side-condition #f)
        sentinel-settled]
   [--> (in-hole TaskFocus (Fail N))
        (in-hole TaskFocus (Crashed N))
        (side-condition #f)
        sentinel-dead]))

(define-syntax-rule
  (selected-functor-base-source
   #:instantiate-with instantiate
   #:instance instance)
  (instantiate instance
    #:source-language selected-foreign-base-lang
    #:redex-parameters
    ([query-evidence selected-foreign-evidence])
    #:variable-view
    [#:runtime-variable N]
    #:live-state-view
    [#:state N
     #:work Task
     #:run-productions ((Echo Input)
                        (Tick N)
                        (Fail N)
                        (Allocate N))
     #:nonallocation-run-productions ((Echo Input)
                                      (Tick N)
                                      (Fail N))]
    #:returned-view
    [#:carrier Result
     #:materialized (Value N)]
    #:failure-summary-view
    [#:carrier Failure
     #:materialized (Crashed Failure)]
    #:terminal-view
    [#:frontier World
     #:success (Halted N)
     #:failure (Aborted N)]
    #:payload/context-view
    [#:work-focus TaskFocus
     #:spine-context WorldSpine
     #:root-focus (Root hole)
     #:root-spine hole
     #:frames ((Wrap hole))
     #:work-redexes ((Echo Input)
                     (Tick N)
                     (Fail N)
                     (Wrap (Value N))
                     (Wrap (Crashed N)))
     #:frontier-redexes ((Root (Value N))
                         (Root (Crashed N)))
     #:allocation-redexes ((Allocate N))
     #:open-work-productions ((Wrap OpenW))]
    #:rules
    ([echo
      #:site work
      #:from (run (Echo Input) TaskFocus)
      #:to (run (Tick N) TaskFocus)
      #:premises ((query-evidence Input N))]
     [tick
      #:site work
      #:from (run (Tick N_0) TaskFocus)
      #:to (settled (Value N_1) TaskFocus)
      #:premises ((where N_1 ,(add1 (term N_0))))]
     [fail
      #:site work
      #:from (run (Fail N) TaskFocus)
      #:to (failed N (Crashed N) TaskFocus)
      #:premises ()]
     [allocate
      #:site allocation
      #:from (run (Allocate N) TaskFocus)
      #:to (run (Tick N) TaskFocus)
      #:premises ()]
     [pop-wrap-value
      #:site work
      #:from (pop-settled (Wrap hole) (Value N) TaskFocus)
      #:to (settled (Value N) TaskFocus)
      #:premises ()]
     [pop-wrap-crash
      #:site work
      #:from (pop-failed (Wrap hole) N (Crashed N) TaskFocus)
      #:to (failed N (Crashed N) TaskFocus)
      #:premises ()]
     [finish-value
      #:site frontier
      #:from (root-settled (Value N) WorldSpine)
      #:to (final (Halted N) WorldSpine)
      #:premises ()]
     [finish-failure
      #:site frontier
      #:from (root-failed N (Crashed N) WorldSpine)
      #:to (final (Aborted N) WorldSpine)
      #:premises ()]
     [sentinel-settled
      #:site work
      #:from (run (Tick N) TaskFocus)
      #:to (settled (Value N) TaskFocus)
      #:premises ((side-condition #f))]
     [sentinel-dead
      #:site work
      #:from (run (Fail N) TaskFocus)
      #:to (failed N (Crashed N) TaskFocus)
      #:premises ((side-condition #f))])))

(define-generated-core-stage-instance
  #:source-interface selected-functor-base-source
  #:instance selected-functor/base)

(define-selected-decomposition-stage selected-functor/base-D
  #:from selected-functor/base
  #:language selected-functor-base-D-lang
  #:plug-D selected-functor-base-plug-D
  #:plug-C selected-functor-base-plug-C
  #:contract-label selected-functor-base-contract-label
  #:decompose selected-functor-base-decompose
  #:contract selected-functor-base-contract
  #:step selected-functor-base-D-step)

(define-selected-refocused-stage selected-functor/base-Z
  #:from selected-functor/base-D
  #:language selected-functor-base-Z-lang
  #:refocus-phase selected-functor-base-refocus-phase
  #:D->Z selected-functor-base-D->Z
  #:Z->D selected-functor-base-Z->D
  #:readback selected-functor-base-readback-Z
  #:refocus-spec selected-functor-base-refocus/spec
  #:refocus-work-direct selected-functor-base-Z-refocus-work
  #:refocus-direct selected-functor-base-Z-refocus
  #:step-spec selected-functor-base-Z-step/spec
  #:step-direct selected-functor-base-Z-step)

(define-selected-machine-isomorphism-stage selected-functor/base-M
  #:from selected-functor/base-Z
  #:language selected-functor-base-M-lang
  #:machineize selected-functor-base-machineize
  #:encode-ZM selected-functor-base-encode-ZM
  #:decode-MZ selected-functor-base-decode-MZ
  #:D->M selected-functor-base-D->M
  #:M->D selected-functor-base-M->D
  #:readback selected-functor-base-readback-M
  #:refocus-work-direct selected-functor-base-M-refocus-work
  #:refocus-direct selected-functor-base-M-refocus
  #:step-direct selected-functor-base-M-step
  #:corresponds selected-functor-base-ZM-corresponds
  #:step-spec selected-functor-base-M-step/spec
  #:square selected-functor-base-ZM-square)

(define-selected-compression-policy selected-functor/base-compression
  #:settled-producers (sentinel-settled)
  #:dead-producers (sentinel-dead)
  #:settled-followers (pop-wrap-value finish-value)
  #:dead-followers (pop-wrap-crash finish-failure)
  #:singletons
  (echo tick fail allocate
   pop-wrap-value pop-wrap-crash
   finish-value finish-failure)
  #:retained-observation rule-labels
  #:maximum-span 2)

(define-selected-compressed-stage selected-functor/base-B
  #:from selected-functor/base-M
  #:policy selected-functor/base-compression
  #:language selected-functor-base-B-lang
  #:compress selected-functor-base-compress
  #:encode-MB selected-functor-base-encode-MB
  #:decode-BM selected-functor-base-decode-BM
  #:readback selected-functor-base-readback-B
  #:span-labels selected-functor-base-span-labels
  #:produce-settled selected-functor-base-produce-settled
  #:produce-dead selected-functor-base-produce-dead
  #:advance-settled selected-functor-base-advance-settled
  #:advance-dead selected-functor-base-advance-dead
  #:step-direct selected-functor-base-B-step
  #:corresponds selected-functor-base-MB-corresponds
  #:replay selected-functor-base-replay/M
  #:step-spec selected-functor-base-B-step/spec
  #:square selected-functor-base-MB-square)

(define-selected-fixed-point-stage selected-functor/base-Big
  #:from selected-functor/base-B
  #:language selected-functor-base-Big-lang
  #:readback selected-functor-base-readback-Big
  #:dispatch selected-functor-base-big-dispatch
  #:run selected-functor-base-big-run
  #:settled selected-functor-base-big-settled
  #:dead selected-functor-base-big-dead
  #:final selected-functor-base-big-final
  #:evaluate selected-functor-base-big-evaluate
  #:spec-language selected-functor-base-Big-spec-lang
  #:initialize selected-functor-base-initialize-B
  #:close selected-functor-base-close-B
  #:flatten selected-functor-base-flatten-BTrace
  #:promote selected-functor-base-promote
  #:evaluate-spec selected-functor-base-big-evaluate/spec
  #:unfold-square selected-functor-base-B-Big-unfold-square
  #:closure-square selected-functor-base-B-Big-closure-square
  #:root-square selected-functor-base-B-Big-root-square)

(define-selected-staged-row selected-functor/base-row
  #:source-language selected-foreign-base-lang
  #:D selected-functor/base-D
  #:Z selected-functor/base-Z
  #:M selected-functor/base-M
  #:B selected-functor/base-B
  #:Big selected-functor/base-Big)
