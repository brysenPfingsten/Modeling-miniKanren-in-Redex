#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: redex/parameter)
         (prefix-in frozen: "./stage-generators.rkt"))

(provide selected-functor-oracle-source-lang
         selected-functor-oracle-R
         selected-functor-oracle-D-lang
         selected-functor-oracle-decompose
         selected-functor-oracle-contract
         selected-functor-oracle-D-step
         selected-functor-oracle-Z-lang
         selected-functor-oracle-D->Z
         selected-functor-oracle-Z->D
         selected-functor-oracle-readback-Z
         selected-functor-oracle-Z-step/spec
         selected-functor-oracle-Z-step
         selected-functor-oracle-M-lang
         selected-functor-oracle-encode-ZM
         selected-functor-oracle-decode-MZ
         selected-functor-oracle-D->M
         selected-functor-oracle-M->D
         selected-functor-oracle-readback-M
         selected-functor-oracle-ZM-corresponds
         selected-functor-oracle-M-step/spec
         selected-functor-oracle-M-step
         selected-functor-oracle-ZM-square
         selected-functor-oracle-B-lang
         selected-functor-oracle-encode-MB
         selected-functor-oracle-decode-BM
         selected-functor-oracle-readback-B
         selected-functor-oracle-span-labels
         selected-functor-oracle-MB-corresponds
         selected-functor-oracle-replay/M
         selected-functor-oracle-B-step/spec
         selected-functor-oracle-B-step
         selected-functor-oracle-MB-square
         selected-functor-oracle-Big-lang
         selected-functor-oracle-readback-Big
         selected-functor-oracle-Big-spec-lang
         selected-functor-oracle-initialize-B
         selected-functor-oracle-close-B
         selected-functor-oracle-flatten-BTrace
         selected-functor-oracle-promote
         selected-functor-oracle-big-evaluate/spec
         selected-functor-oracle-B-Big-unfold-square
         selected-functor-oracle-B-Big-closure-square
         selected-functor-oracle-B-Big-root-square
         selected-functor-oracle-big-evaluate)

;; This route intentionally uses the frozen #:environment prototype.  It is a
;; test-only whole-instance oracle: Base, Delta1, and Delta2 are merged before
;; any stage is emitted.  No selected public module imports it.
(define-language selected-functor-oracle-base-lang
  [N natural]
  [Input N]
  [Result (Value N)]
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

(redex-parameter:define-judgment-form* selected-functor-oracle-base-lang
  #:mode (selected-functor-oracle-evidence/base I O)
  #:contract (selected-functor-oracle-evidence/base Input N)
  [---------------- "base-evidence-left"
   (selected-functor-oracle-evidence/base natural natural)]
  [---------------- "base-evidence-right"
   (selected-functor-oracle-evidence/base natural natural)])

(define-extended-language selected-functor-oracle-query-lang
  selected-functor-oracle-base-lang
  [Input .... string]
  [Task ....
        (Query Input)
        (Box Task)
        (Seal Task)]
  [TaskPath ....
            (Box TaskPath)
            (Seal TaskPath)])

(redex-parameter:define-extended-judgment-form*
 selected-functor-oracle-evidence/base
 selected-functor-oracle-query-lang
 #:mode (selected-functor-oracle-evidence/query I O)
 [---------------- "query-evidence-left"
  (selected-functor-oracle-evidence/query "cross-module" 7)]
 [---------------- "query-evidence-right"
  (selected-functor-oracle-evidence/query "cross-module" 7)])

(define-extended-language selected-functor-oracle-source-lang
  selected-functor-oracle-query-lang
  [Task .... (Probe Input)])

(redex-parameter:define-extended-judgment-form*
 selected-functor-oracle-evidence/query
 selected-functor-oracle-source-lang
 #:mode (selected-functor-oracle-evidence I O))

(redex-parameter:define-reduction-relation*
 selected-functor-oracle-R
 selected-functor-oracle-source-lang
 #:parameters
 ([query-evidence selected-functor-oracle-evidence])
 #:domain World
 [--> (in-hole TaskFocus (Echo Input))
      (in-hole TaskFocus (Tick N))
      (judgment-holds (query-evidence Input N))
      echo]
 [--> (in-hole TaskFocus (Query Input))
      (in-hole TaskFocus (Tick N))
      (judgment-holds (query-evidence Input N))
      query]
 [--> (in-hole TaskFocus (Probe Input))
      (in-hole TaskFocus (Query Input))
      probe]
 [--> (in-hole TaskFocus (Tick N_0))
      (in-hole TaskFocus (Value N_1))
      (where N_1 ,(add1 (term N_0)))
      tick]
 [--> (in-hole TaskFocus (Fail N))
      (in-hole TaskFocus (Crashed N))
      fail]
 [--> (in-hole TaskFocus (Tick N))
      (in-hole TaskFocus (Value N))
      (side-condition #f)
      sentinel-settled]
 [--> (in-hole TaskFocus (Fail N))
      (in-hole TaskFocus (Crashed N))
      (side-condition #f)
      sentinel-dead]
 [--> (in-hole TaskFocus (Allocate N))
      (in-hole TaskFocus (Tick N))
      allocate]
 [--> (in-hole TaskFocus (Wrap (Value N)))
      (in-hole TaskFocus (Value N))
      pop-wrap-value]
 [--> (in-hole TaskFocus (Wrap (Crashed N)))
      (in-hole TaskFocus (Crashed N))
      pop-wrap-crash]
 [--> (in-hole TaskFocus (Box (Value N)))
      (in-hole TaskFocus (Value N))
      pop-box-value]
 [--> (in-hole TaskFocus (Box (Crashed N)))
      (in-hole TaskFocus (Crashed N))
      pop-box-crash]
 [--> (Root (Value N)) (Halted N) finish-value]
 [--> (Root (Crashed N)) (Aborted N) finish-failure])

(frozen:define-derivation-instance selected-functor-oracle/base
  #:source-language selected-functor-oracle-base-lang
  #:redex-parameters
  ([query-evidence selected-functor-oracle-evidence/base])
  #:work Task
  #:frontier World
  #:settled Result
  #:work-focus TaskFocus
  #:spine-context WorldSpine
  #:environment N
  #:run-productions ((Echo Input) (Tick N) (Fail N) (Allocate N))
  #:nonallocation-run-productions ((Echo Input) (Tick N) (Fail N))
  #:dead-view [N (Crashed N)]
  #:root-focus (Root hole)
  #:root-spine hole
  #:frames ((Wrap hole))
  #:work-redexes
  ((Echo Input) (Tick N) (Fail N)
   (Wrap (Value N)) (Wrap (Crashed N)))
  #:frontier-redexes ((Root (Value N)) (Root (Crashed N)))
  #:allocation-redexes ((Allocate N))
  #:terminals ((Halted N) (Aborted N))
  #:open-work-productions ((Wrap OpenW))
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
    #:to (dead N (Crashed N) TaskFocus)
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
    #:from (pop-dead (Wrap hole) N (Crashed N) TaskFocus)
    #:to (dead N (Crashed N) TaskFocus)
    #:premises ()]
   [finish-value
    #:site frontier
    #:from (root-settled (Value N) WorldSpine)
    #:to (final (Halted N) WorldSpine)
    #:premises ()]
   [finish-failure
    #:site frontier
    #:from (root-dead N (Crashed N) WorldSpine)
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
    #:to (dead N (Crashed N) TaskFocus)
    #:premises ((side-condition #f))]))

(frozen:define-derivation-delta selected-functor-oracle/query
  #:from selected-functor-oracle/base
  #:source-language selected-functor-oracle-query-lang
  #:redex-parameter-overrides
  ([query-evidence selected-functor-oracle-evidence/query])
  #:run-productions-add ((Query Input))
  #:nonallocation-run-productions-add ((Query Input))
  #:frames-add ((Box hole) (Seal hole))
  #:work-redexes-add
  ((Query Input) (Box (Value N)) (Box (Crashed N)))
  #:frontier-redexes-add ()
  #:allocation-redexes-add ()
  #:terminals-add ()
  #:open-work-productions-add ((Box OpenW) (Seal OpenW))
  #:rules-add
  ([query
    #:site work
    #:from (run (Query Input) TaskFocus)
    #:to (run (Tick N) TaskFocus)
    #:premises ((query-evidence Input N))]
   [pop-box-value
    #:site work
    #:from (pop-settled (Box hole) (Value N) TaskFocus)
    #:to (settled (Value N) TaskFocus)
    #:premises ()]
   [pop-box-crash
    #:site work
    #:from (pop-dead (Box hole) N (Crashed N) TaskFocus)
    #:to (dead N (Crashed N) TaskFocus)
    #:premises ()]))

(frozen:define-derivation-delta selected-functor-oracle/probe
  #:from selected-functor-oracle/query
  #:source-language selected-functor-oracle-source-lang
  #:redex-parameter-overrides
  ([query-evidence selected-functor-oracle-evidence])
  #:run-productions-add ((Probe Input))
  #:nonallocation-run-productions-add ((Probe Input))
  #:frames-add ()
  #:work-redexes-add ((Probe Input))
  #:frontier-redexes-add ()
  #:allocation-redexes-add ()
  #:terminals-add ()
  #:open-work-productions-add ()
  #:rules-add
  ([probe
    #:site work
    #:from (run (Probe Input) TaskFocus)
    #:to (run (Query Input) TaskFocus)
    #:premises ()]))

(frozen:define-decomposition-stage selected-functor-oracle/D
  #:from selected-functor-oracle/probe
  #:language selected-functor-oracle-D-lang
  #:plug-D selected-functor-oracle-plug-D
  #:plug-C selected-functor-oracle-plug-C
  #:contract-label selected-functor-oracle-contract-label
  #:decompose selected-functor-oracle-decompose
  #:contract selected-functor-oracle-contract
  #:step selected-functor-oracle-D-step)

(frozen:define-refocused-stage selected-functor-oracle/Z
  #:from selected-functor-oracle/D
  #:language selected-functor-oracle-Z-lang
  #:D->Z selected-functor-oracle-D->Z
  #:Z->D selected-functor-oracle-Z->D
  #:readback selected-functor-oracle-readback-Z
  #:refocus-spec selected-functor-oracle-refocus/spec
  #:refocus-work-direct selected-functor-oracle-refocus-work
  #:refocus-direct selected-functor-oracle-refocus
  #:step-spec selected-functor-oracle-Z-step/spec
  #:step-direct selected-functor-oracle-Z-step)

(frozen:define-machine-isomorphism-stage selected-functor-oracle/M
  #:from selected-functor-oracle/Z
  #:language selected-functor-oracle-M-lang
  #:encode-ZM selected-functor-oracle-encode-ZM
  #:decode-MZ selected-functor-oracle-decode-MZ
  #:D->M selected-functor-oracle-D->M
  #:M->D selected-functor-oracle-M->D
  #:readback selected-functor-oracle-readback-M
  #:refocus-work-direct selected-functor-oracle-M-refocus-work
  #:refocus-direct selected-functor-oracle-M-refocus
  #:step-direct selected-functor-oracle-M-step
  #:corresponds selected-functor-oracle-ZM-corresponds
  #:step-spec selected-functor-oracle-M-step/spec
  #:square selected-functor-oracle-ZM-square)

(frozen:define-compression-policy selected-functor-oracle/compression
  #:settled-producers (sentinel-settled)
  #:dead-producers (sentinel-dead)
  #:settled-followers
  (pop-wrap-value pop-box-value finish-value)
  #:dead-followers
  (pop-wrap-crash pop-box-crash finish-failure)
  #:singletons
  (echo query probe tick fail allocate
   pop-wrap-value pop-wrap-crash
   pop-box-value pop-box-crash
   finish-value finish-failure)
  #:retained-observation rule-labels
  #:maximum-span 2)

(frozen:define-compressed-stage selected-functor-oracle/B
  #:from selected-functor-oracle/M
  #:policy selected-functor-oracle/compression
  #:language selected-functor-oracle-B-lang
  #:encode-MB selected-functor-oracle-encode-MB
  #:decode-BM selected-functor-oracle-decode-BM
  #:readback selected-functor-oracle-readback-B
  #:span-labels selected-functor-oracle-span-labels
  #:produce-settled selected-functor-oracle-produce-settled
  #:produce-dead selected-functor-oracle-produce-dead
  #:advance-settled selected-functor-oracle-advance-settled
  #:advance-dead selected-functor-oracle-advance-dead
  #:step-direct selected-functor-oracle-B-step
  #:corresponds selected-functor-oracle-MB-corresponds
  #:replay selected-functor-oracle-replay/M
  #:step-spec selected-functor-oracle-B-step/spec
  #:square selected-functor-oracle-MB-square)

(frozen:define-fixed-point-stage selected-functor-oracle/Big
  #:from selected-functor-oracle/B
  #:language selected-functor-oracle-Big-lang
  #:readback selected-functor-oracle-readback-Big
  #:dispatch selected-functor-oracle-big-dispatch
  #:run selected-functor-oracle-big-run
  #:settled selected-functor-oracle-big-settled
  #:dead selected-functor-oracle-big-dead
  #:final selected-functor-oracle-big-final
  #:evaluate selected-functor-oracle-big-evaluate
  #:spec-language selected-functor-oracle-Big-spec-lang
  #:initialize selected-functor-oracle-initialize-B
  #:close selected-functor-oracle-close-B
  #:flatten selected-functor-oracle-flatten-BTrace
  #:promote selected-functor-oracle-promote
  #:evaluate-spec selected-functor-oracle-big-evaluate/spec
  #:unfold-square selected-functor-oracle-B-Big-unfold-square
  #:closure-square selected-functor-oracle-B-Big-closure-square
  #:root-square selected-functor-oracle-B-Big-root-square)
