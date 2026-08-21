#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: redex/parameter)
         "stage-generators.rkt")

(provide hygiene-base-lang
         hygiene-evidence
         hygiene/base)

;; This module owns the base grammar, its liftable dependency, and the slot
;; declaration.  The consuming feature delta intentionally lives in a
;; different module.
(define-language hygiene-base-lang
  [N natural]
  [Input natural]
  [Answer (Value N)]
  [Work (Query Input)
        (Tick N)
        (Fail N)
        (Allocate N)
        (Value N)
        (Crashed N)
        (Box Work)]
  [Frontier (Root Work)
            (Halted N)]
  [WorkPath hole
            (Box WorkPath)]
  [WorkFocus (Root WorkPath)]
  [SpineContext hole])

(redex-parameter:define-judgment-form* hygiene-base-lang
  #:mode (hygiene-evidence I O)
  #:contract (hygiene-evidence Input N)
  [---------------- "base-evidence-left"
   (hygiene-evidence natural natural)]
  [---------------- "base-evidence-right"
   (hygiene-evidence natural natural)])

(define-derivation-instance hygiene/base
  #:source-language hygiene-base-lang
  #:redex-parameters ([evidence hygiene-evidence])
  #:work Work
  #:frontier Frontier
  #:settled Answer
  #:work-focus WorkFocus
  #:spine-context SpineContext
  #:environment N
  #:run-productions ((Query Input)
                     (Tick N)
                     (Fail N)
                     (Allocate N))
  #:nonallocation-run-productions ((Query Input)
                                    (Tick N)
                                    (Fail N))
  #:dead-view [N (Crashed N)]
  #:root-focus (Root hole)
  #:root-spine hole
  #:frames ((Box hole))
  #:work-redexes ((Query Input)
                  (Tick N)
                  (Fail N)
                  (Box (Value N))
                  (Box (Crashed N)))
  #:frontier-redexes ((Root (Value N)))
  #:allocation-redexes ((Allocate N))
  #:terminals ((Halted N))
  #:open-work-productions ((Box OpenW))
  #:rules
  ([tick
    #:site work
    #:from (run (Tick N_0) WorkFocus)
   #:to (settled (Value N_1) WorkFocus)
    #:premises ((where N_1 ,(add1 (term N_0))))]
   [fail
    #:site work
    #:from (run (Fail N) WorkFocus)
    #:to (dead N (Crashed N) WorkFocus)
    #:premises ()]
   [allocate
    #:site allocation
   #:from (run (Allocate N) WorkFocus)
    #:to (run (Tick N) WorkFocus)
    #:premises ()]
   [pop-value
    #:site work
    #:from (pop-settled (Box hole) (Value N) WorkFocus)
    #:to (settled (Value N) WorkFocus)
    #:premises ()]
   [pop-crash
    #:site work
    #:from (pop-dead (Box hole) N (Crashed N) WorkFocus)
    #:to (dead N (Crashed N) WorkFocus)
    #:premises ()]
   [finish
    #:site frontier
    #:from (root-settled (Value N) SpineContext)
    #:to (final (Halted N) SpineContext)
    #:premises ()]))
