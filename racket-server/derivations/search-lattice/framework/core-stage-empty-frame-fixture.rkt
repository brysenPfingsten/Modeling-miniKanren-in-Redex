#lang racket

(require redex/reduction-semantics
         "./core-stage-schema.rkt")

(provide empty-frame-D-lang
         empty-frame-Z-lang
         empty-frame-M-lang
         empty-frame-B-lang
         empty-frame-Big-lang
         empty-frame-decompose
         empty-frame-refocus-phase
         empty-frame-machineize
         empty-frame-compress
         empty-frame-B-step
         empty-frame-big-dispatch/refocus-frontier
         empty-frame-big-dispatch/control-one
         empty-frame-big-evaluate)

;; A frame-free row is a real boundary case: the root is the only context in
;; which work can occur.  In particular, this fixture must not invent a frame
;; merely to make the generated Redex grammars nonempty.
(define-language empty-frame-source-lang
  [rv natural]
  [State (state rv)]
  [Returned (returned rv)]
  [Failure natural]
  [W (tick rv)
     (crash rv)
     (allocate rv)
     (returned rv)
     (failed rv)]
  [F (root W)
     (flip rv)
     (rail rv)
     (halted rv)
     (aborted rv)]
  [WorkFocus (root hole)]
  [Spine hole])

(define-syntax-rule
  (empty-frame-source
   #:instantiate-with instantiate
   #:instance instance)
  (instantiate instance
  #:source-language empty-frame-source-lang
  #:variable-view
  [#:runtime-variable rv]
  #:live-state-view
  [#:state State
   #:work W
   #:run-productions ((tick rv) (crash rv) (allocate rv))
   #:nonallocation-run-productions ((tick rv) (crash rv))]
  #:returned-view
  [#:carrier Returned
   #:materialized (returned rv)]
  #:failure-summary-view
  [#:carrier Failure
   #:materialized (failed Failure)]
  #:terminal-view
  [#:frontier F
   #:success (halted rv)
   #:failure (aborted rv)]
  #:payload/context-view
  [#:work-focus WorkFocus
   #:spine-context Spine
   #:root-focus (root hole)
   #:root-spine hole
   #:frames ()
   #:work-redexes ((tick rv) (crash rv))
   #:frontier-redexes ((root (returned rv))
                       (root (failed rv))
                       (flip rv)
                       (rail rv))
   #:allocation-redexes ((allocate rv))
   #:open-work-productions ()]
  #:rules
  ([tick
    #:site work
    #:from (run (tick rv_0) WorkFocus)
    #:to (settled (returned rv_1) WorkFocus)
    #:premises
    ((where rv_1 ,(add1 (term rv_0))))]
   [crash
    #:site work
    #:from (run (crash rv) WorkFocus)
    #:to (failed rv (failed rv) WorkFocus)
    #:premises ()]
   [allocate
    #:site allocation
    #:from (run (allocate rv) WorkFocus)
    #:to (run (tick rv) WorkFocus)
    #:premises ()]
   [finish-success
    #:site frontier
    #:from (root-settled (returned rv) Spine)
    #:to (final (halted rv) Spine)
    #:premises ()]
   [finish-failure
    #:site frontier
    #:from (root-failed rv (failed rv) Spine)
    #:to (final (aborted rv) Spine)
    #:premises ()]
   [flip
    #:site frontier
    #:from (frontier (flip rv_0) Spine)
    #:to (frontier (rail rv_1) Spine)
    #:premises
    ((where rv_1 ,(add1 (term rv_0))))])))

(define-generated-core-stage-instance
  #:source-interface empty-frame-source
  #:instance empty-frame/core)

(define-selected-decomposition-stage empty-frame/D
  #:from empty-frame/core
  #:language empty-frame-D-lang
  #:plug-D empty-frame-plug-D
  #:plug-C empty-frame-plug-C
  #:contract-label empty-frame-contract-label
  #:decompose empty-frame-decompose
  #:contract empty-frame-contract
  #:step empty-frame-D-step)

(define-selected-refocused-stage empty-frame/Z
  #:from empty-frame/D
  #:language empty-frame-Z-lang
  #:refocus-phase empty-frame-refocus-phase
  #:D->Z empty-frame-D->Z
  #:Z->D empty-frame-Z->D
  #:readback empty-frame-readback-Z
  #:refocus-spec empty-frame-refocus/spec
  #:refocus-work-direct empty-frame-Z-refocus-work
  #:refocus-direct empty-frame-Z-refocus
  #:step-spec empty-frame-Z-step/spec
  #:step-direct empty-frame-Z-step)

(define-selected-machine-isomorphism-stage empty-frame/M
  #:from empty-frame/Z
  #:language empty-frame-M-lang
  #:machineize empty-frame-machineize
  #:encode-ZM empty-frame-encode-ZM
  #:decode-MZ empty-frame-decode-MZ
  #:D->M empty-frame-D->M
  #:M->D empty-frame-M->D
  #:readback empty-frame-readback-M
  #:refocus-work-direct empty-frame-M-refocus-work
  #:refocus-direct empty-frame-M-refocus
  #:step-direct empty-frame-M-step
  #:corresponds empty-frame-ZM-corresponds
  #:step-spec empty-frame-M-step/spec
  #:square empty-frame-ZM-square)

(define-selected-compression-policy empty-frame-policy
  #:settled-producers (tick)
  #:dead-producers (crash)
  #:settled-followers (finish-success)
  #:dead-followers (finish-failure)
  #:singletons (allocate finish-success finish-failure flip)
  #:retained-observation rule-labels
  #:maximum-span 2)

(define-selected-compressed-stage empty-frame/B
  #:from empty-frame/M
  #:policy empty-frame-policy
  #:language empty-frame-B-lang
  #:compress empty-frame-compress
  #:encode-MB empty-frame-encode-MB
  #:decode-BM empty-frame-decode-BM
  #:readback empty-frame-readback-B
  #:span-labels empty-frame-span-labels
  #:produce-settled empty-frame-produce-settled
  #:produce-dead empty-frame-produce-dead
  #:advance-settled empty-frame-advance-settled
  #:advance-dead empty-frame-advance-dead
  #:step-direct empty-frame-B-step
  #:corresponds empty-frame-MB-corresponds
  #:replay empty-frame-replay
  #:step-spec empty-frame-B-step/spec
  #:square empty-frame-MB-square)

(define-selected-fixed-point-stage empty-frame/Big
  #:from empty-frame/B
  #:language empty-frame-Big-lang
  #:readback empty-frame-readback-Big
  #:dispatch empty-frame-big-dispatch
  #:run empty-frame-big-run
  #:settled empty-frame-big-settled
  #:dead empty-frame-big-dead
  #:final empty-frame-big-final
  #:evaluate empty-frame-big-evaluate
  #:spec-language empty-frame-Big-spec-lang
  #:initialize empty-frame-initialize
  #:close empty-frame-close
  #:flatten empty-frame-flatten
  #:promote empty-frame-promote
  #:evaluate-spec empty-frame-big-evaluate/spec
  #:unfold-square empty-frame-unfold-square
  #:closure-square empty-frame-closure-square
  #:root-square empty-frame-root-square)
