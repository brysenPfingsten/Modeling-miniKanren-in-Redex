#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: redex/parameter)
         "./core-stage-schema.rkt")

(provide selected-foreign-base-lang
         selected-foreign-evidence
         selected-foreign-base-R
         selected-foreign/base-D
         selected-foreign/base-Z
         selected-foreign/base-M
         selected-foreign/base-B
         selected-foreign/base-Big
         selected-foreign-base-D-lang
         selected-foreign-base-decompose
         selected-foreign-base-contract
         selected-foreign-base-D-step
         selected-foreign-base-Z-lang
         selected-foreign-base-refocus-phase
         selected-foreign-base-Z-step
         selected-foreign-base-M-lang
         selected-foreign-base-machineize
         selected-foreign-base-M-step
         selected-foreign-base-B-lang
         selected-foreign-base-compress
         selected-foreign-base-B-step
         selected-foreign-base-Big-lang
         selected-foreign-base-big-evaluate
         selected-foreign-base-promote)

;; This base contains only base-owned syntax.  Input exists solely as the
;; declared domain of a liftable dependency; the foreign feature owns every
;; later constructor and domain extension.
(define-language selected-foreign-base-lang
  [N natural]
  [Input N]
  [Result (Value N)]
  [Failure natural]
  [Task (Echo Input)
        (Tick N)
        (Fail N)
        (Allocate N)
        (Value N)
        (Crashed N)
        (Wrap Task)]
  [World (Root Task)
         (Halted N)
         (Aborted N)]
  [TaskPath hole
            (Wrap TaskPath)]
  [TaskFocus (Root TaskPath)]
  [WorldSpine hole])

(redex-parameter:define-judgment-form* selected-foreign-base-lang
  #:mode (selected-foreign-evidence I O)
  #:contract (selected-foreign-evidence Input N)
  [---------------- "base-evidence-left"
   (selected-foreign-evidence natural natural)]
  [---------------- "base-evidence-right"
   (selected-foreign-evidence natural natural)])

(redex-parameter:define-reduction-relation*
 selected-foreign-base-R
 selected-foreign-base-lang
 #:parameters
 ([query-evidence selected-foreign-evidence])
 #:domain World
 [--> (in-hole TaskFocus (Echo Input))
      (in-hole TaskFocus (Tick N))
      (judgment-holds (query-evidence Input N))
      echo]
 [--> (in-hole TaskFocus (Tick N_0))
      (in-hole TaskFocus (Value N_1))
      (where N_1 ,(add1 (term N_0)))
      tick]
 [--> (in-hole TaskFocus (Fail N))
      (in-hole TaskFocus (Crashed N))
      fail]
 [--> (in-hole TaskFocus (Allocate N))
      (in-hole TaskFocus (Tick N))
      allocate]
 [--> (in-hole TaskFocus (Wrap (Value N)))
      (in-hole TaskFocus (Value N))
      pop-wrap-value]
 [--> (in-hole TaskFocus (Wrap (Crashed N)))
      (in-hole TaskFocus (Crashed N))
      pop-wrap-crash]
 [--> (Root (Value N)) (Halted N) finish-value]
 [--> (Root (Crashed N)) (Aborted N) finish-failure])

(define-syntax-rule
  (selected-foreign-source
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
      #:premises
      ((query-evidence Input N))]
     [tick
      #:site work
      #:from (run (Tick N_0) TaskFocus)
      #:to (settled (Value N_1) TaskFocus)
      #:premises
      ((where N_1 ,(add1 (term N_0))))]
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
      #:premises ()])))

(define-generated-core-stage-instance
  #:source-interface selected-foreign-source
  #:instance selected-foreign/base)

(define-selected-decomposition-stage selected-foreign/base-D
  #:from selected-foreign/base
  #:language selected-foreign-base-D-lang
  #:plug-D selected-foreign-base-plug-D
  #:plug-C selected-foreign-base-plug-C
  #:contract-label selected-foreign-base-contract-label
  #:decompose selected-foreign-base-decompose
  #:contract selected-foreign-base-contract
  #:step selected-foreign-base-D-step)

(define-selected-refocused-stage selected-foreign/base-Z
  #:from selected-foreign/base-D
  #:language selected-foreign-base-Z-lang
  #:refocus-phase selected-foreign-base-refocus-phase
  #:D->Z selected-foreign-base-D->Z
  #:Z->D selected-foreign-base-Z->D
  #:readback selected-foreign-base-readback-Z
  #:refocus-spec selected-foreign-base-refocus/spec
  #:refocus-work-direct selected-foreign-base-Z-refocus-work
  #:refocus-direct selected-foreign-base-Z-refocus
  #:step-spec selected-foreign-base-Z-step/spec
  #:step-direct selected-foreign-base-Z-step)

(define-selected-machine-isomorphism-stage selected-foreign/base-M
  #:from selected-foreign/base-Z
  #:language selected-foreign-base-M-lang
  #:machineize selected-foreign-base-machineize
  #:encode-ZM selected-foreign-base-encode-ZM
  #:decode-MZ selected-foreign-base-decode-MZ
  #:D->M selected-foreign-base-D->M
  #:M->D selected-foreign-base-M->D
  #:readback selected-foreign-base-readback-M
  #:refocus-work-direct selected-foreign-base-M-refocus-work
  #:refocus-direct selected-foreign-base-M-refocus
  #:step-direct selected-foreign-base-M-step
  #:corresponds selected-foreign-base-ZM-corresponds
  #:step-spec selected-foreign-base-M-step/spec
  #:square selected-foreign-base-ZM-square)

(define-selected-compression-policy selected-foreign/base-compression
  #:settled-producers (tick)
  #:dead-producers (fail)
  #:settled-followers (pop-wrap-value finish-value)
  #:dead-followers (pop-wrap-crash finish-failure)
  #:singletons
  (echo allocate
   pop-wrap-value pop-wrap-crash
   finish-value finish-failure)
  #:retained-observation rule-labels
  #:maximum-span 2)

(define-selected-compressed-stage selected-foreign/base-B
  #:from selected-foreign/base-M
  #:policy selected-foreign/base-compression
  #:language selected-foreign-base-B-lang
  #:compress selected-foreign-base-compress
  #:encode-MB selected-foreign-base-encode-MB
  #:decode-BM selected-foreign-base-decode-BM
  #:readback selected-foreign-base-readback-B
  #:span-labels selected-foreign-base-span-labels
  #:produce-settled selected-foreign-base-produce-settled
  #:produce-dead selected-foreign-base-produce-dead
  #:advance-settled selected-foreign-base-advance-settled
  #:advance-dead selected-foreign-base-advance-dead
  #:step-direct selected-foreign-base-B-step
  #:corresponds selected-foreign-base-MB-corresponds
  #:replay selected-foreign-base-replay/M
  #:step-spec selected-foreign-base-B-step/spec
  #:square selected-foreign-base-MB-square)

(define-selected-fixed-point-stage selected-foreign/base-Big
  #:from selected-foreign/base-B
  #:language selected-foreign-base-Big-lang
  #:readback selected-foreign-base-readback-Big
  #:dispatch selected-foreign-base-big-dispatch
  #:run selected-foreign-base-big-run
  #:settled selected-foreign-base-big-settled
  #:dead selected-foreign-base-big-dead
  #:final selected-foreign-base-big-final
  #:evaluate selected-foreign-base-big-evaluate
  #:spec-language selected-foreign-base-Big-spec-lang
  #:initialize selected-foreign-base-initialize-B
  #:close selected-foreign-base-close-B
  #:flatten selected-foreign-base-flatten-BTrace
  #:promote selected-foreign-base-promote
  #:evaluate-spec selected-foreign-base-big-evaluate/spec
  #:unfold-square selected-foreign-base-B-Big-unfold-square
  #:closure-square selected-foreign-base-B-Big-closure-square
  #:root-square selected-foreign-base-B-Big-root-square)
