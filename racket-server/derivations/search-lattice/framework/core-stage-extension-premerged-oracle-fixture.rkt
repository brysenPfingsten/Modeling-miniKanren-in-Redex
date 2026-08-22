#lang racket

(require redex/reduction-semantics)

(provide selected-foreign-premerged-oracle-lang
         selected-foreign-premerged-oracle-evidence
         selected-foreign-premerged-oracle-R
         selected-foreign-premerged-oracle-D-step
         selected-foreign-premerged-oracle-Z-step
         selected-foreign-premerged-oracle-M-step
         selected-foreign-premerged-oracle-B-step
         selected-foreign-premerged-oracle-big-evaluate)

;; This test-only bounded observation oracle declares the base and foreign
;; feature as one frozen language.  It covers the inherited/feature evidence
;; representatives and both success and failure boundary paths used below; it
;; is not a second general-purpose coordinate generator.  It is intentionally
;; independent of the selected renderer and of StageExtension application.
(define-language selected-foreign-premerged-oracle-lang
  [N natural]
  [Input N string]
  [Result (Value N)]
  [Failure natural]
  [Task (Echo Input)
        (Query Input)
        (Tick N)
        (Fail N)
        (Allocate N)
        (Value N)
        (Crashed N)
        (Wrap Task)
        (Box Task)
        (Seal Task)]
  [World (Root Task)
         (Halted N)
         (Aborted N)]
  [TaskPath hole
            (Wrap TaskPath)
            (Box TaskPath)
            (Seal TaskPath)]
  [TaskFocus (Root TaskPath)]
  [WorldSpine hole]
  [T (Halted N) (Aborted N)]
  [RuleName echo query tick fail allocate
            pop-wrap-value pop-wrap-crash
            pop-box-value pop-box-crash
            finish-value finish-failure]
  [WR (Echo Input)
      (Query Input)
      (Tick N)
      (Fail N)
      (Wrap (Value N))
      (Wrap (Crashed N))
      (Box (Value N))
      (Box (Crashed N))]
  [AR (Allocate N)]
  [FR (Root (Value N))
      (Root (Crashed N))]
  [D (Final T)
     (DecWork WR TaskFocus)
     (DecFrontier FR WorldSpine)
     (DecAllocate AR TaskFocus)]
  [RunW (Echo Input)
        (Query Input)
        (Tick N)
        (Fail N)]
  [Z (ZFinal T)
     (ZWork WR TaskFocus)
     (ZFrontier FR WorldSpine)
     (ZAllocate AR TaskFocus)]
  [M (MFinal T)
     (MWork WR TaskFocus)
     (MFrontier FR WorldSpine)
     (MAllocate AR TaskFocus)]
  [TransitionSpan (transition-span RuleName ...)]
  [B (BFinal T)
     (BRun RunW TaskFocus)
     (BRun AR TaskFocus)
     (BSettled Result TaskFocus)
     (BDead Failure TaskFocus)]
  [Big (BigFinal T)])

;; The duplicate names are intentional proof evidence, not duplicate semantic
;; clauses.  Redex successor sets deduplicate them; build-derivations retains
;; both proof trees.
(define-judgment-form selected-foreign-premerged-oracle-lang
  #:contract (selected-foreign-premerged-oracle-evidence Input N)
  #:mode (selected-foreign-premerged-oracle-evidence I O)
  [---------------- "base-evidence-left"
   (selected-foreign-premerged-oracle-evidence natural natural)]
  [---------------- "base-evidence-right"
   (selected-foreign-premerged-oracle-evidence natural natural)]
  [---------------- "query-evidence-left"
   (selected-foreign-premerged-oracle-evidence "cross-module" 7)]
  [---------------- "query-evidence-right"
   (selected-foreign-premerged-oracle-evidence "cross-module" 7)])

(define selected-foreign-premerged-oracle-R
  (reduction-relation
   selected-foreign-premerged-oracle-lang
   #:domain World
   [--> (in-hole TaskFocus (Echo Input))
        (in-hole TaskFocus (Tick N))
        (judgment-holds
         (selected-foreign-premerged-oracle-evidence Input N))
        echo]
   [--> (in-hole TaskFocus (Query Input))
        (in-hole TaskFocus (Tick N))
        (judgment-holds
         (selected-foreign-premerged-oracle-evidence Input N))
        query]
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
   [--> (in-hole TaskFocus (Box (Value N)))
        (in-hole TaskFocus (Value N))
        pop-box-value]
   [--> (in-hole TaskFocus (Box (Crashed N)))
        (in-hole TaskFocus (Crashed N))
        pop-box-crash]
   [--> (Root (Value N)) (Halted N) finish-value]
   [--> (Root (Crashed N)) (Aborted N) finish-failure]))

(define-judgment-form selected-foreign-premerged-oracle-lang
  #:contract (selected-foreign-premerged-oracle-D-step D RuleName D)
  #:mode (selected-foreign-premerged-oracle-D-step I O O)
  [(selected-foreign-premerged-oracle-evidence Input N)
   ---------------- "echo"
   (selected-foreign-premerged-oracle-D-step
    (DecWork (Echo Input) TaskFocus)
    echo
    (DecWork (Tick N) TaskFocus))]
  [(selected-foreign-premerged-oracle-evidence Input N)
   ---------------- "query"
   (selected-foreign-premerged-oracle-D-step
    (DecWork (Query Input) TaskFocus)
    query
    (DecWork (Tick N) TaskFocus))])

(define-judgment-form selected-foreign-premerged-oracle-lang
  #:contract (selected-foreign-premerged-oracle-Z-step Z RuleName Z)
  #:mode (selected-foreign-premerged-oracle-Z-step I O O)
  [(selected-foreign-premerged-oracle-evidence Input N)
   ---------------- "echo"
   (selected-foreign-premerged-oracle-Z-step
    (ZWork (Echo Input) TaskFocus)
    echo
    (ZWork (Tick N) TaskFocus))]
  [(selected-foreign-premerged-oracle-evidence Input N)
   ---------------- "query"
   (selected-foreign-premerged-oracle-Z-step
    (ZWork (Query Input) TaskFocus)
    query
    (ZWork (Tick N) TaskFocus))])

(define-judgment-form selected-foreign-premerged-oracle-lang
  #:contract (selected-foreign-premerged-oracle-M-step M RuleName M)
  #:mode (selected-foreign-premerged-oracle-M-step I O O)
  [(selected-foreign-premerged-oracle-evidence Input N)
   ---------------- "echo"
   (selected-foreign-premerged-oracle-M-step
    (MWork (Echo Input) TaskFocus)
    echo
    (MWork (Tick N) TaskFocus))]
  [(selected-foreign-premerged-oracle-evidence Input N)
   ---------------- "query"
   (selected-foreign-premerged-oracle-M-step
    (MWork (Query Input) TaskFocus)
    query
    (MWork (Tick N) TaskFocus))])

(define-judgment-form selected-foreign-premerged-oracle-lang
  #:contract (selected-foreign-premerged-oracle-B-step B TransitionSpan B)
  #:mode (selected-foreign-premerged-oracle-B-step I O O)
  [(selected-foreign-premerged-oracle-evidence Input N)
   ---------------- "echo"
   (selected-foreign-premerged-oracle-B-step
    (BRun (Echo Input) TaskFocus)
    (transition-span echo)
    (BRun (Tick N) TaskFocus))]
  [(selected-foreign-premerged-oracle-evidence Input N)
   ---------------- "query"
   (selected-foreign-premerged-oracle-B-step
    (BRun (Query Input) TaskFocus)
    (transition-span query)
    (BRun (Tick N) TaskFocus))]
  [---------------- "allocate"
   (selected-foreign-premerged-oracle-B-step
    (BRun (Allocate N) TaskFocus)
    (transition-span allocate)
    (BRun (Tick N) TaskFocus))]
  [(where N_1 ,(add1 (term N_0)))
   ---------------- "tick-feature-boundary"
   (selected-foreign-premerged-oracle-B-step
    (BRun (Tick N_0) (in-hole TaskFocus (Box hole)))
    (transition-span tick)
    (BSettled (Value N_1) (in-hole TaskFocus (Box hole))))]
  [---------------- "pop-box-value"
   (selected-foreign-premerged-oracle-B-step
    (BSettled (Value N) (in-hole TaskFocus (Box hole)))
    (transition-span pop-box-value)
    (BSettled (Value N) TaskFocus))]
  [(where N_1 ,(add1 (term N_0)))
   ---------------- "tick-base-fusion"
   (selected-foreign-premerged-oracle-B-step
    (BRun (Tick N_0) (in-hole TaskFocus (Wrap hole)))
    (transition-span tick pop-wrap-value)
    (BSettled (Value N_1) TaskFocus))]
  [(where N_1 ,(add1 (term N_0)))
   ---------------- "tick-root-fusion"
   (selected-foreign-premerged-oracle-B-step
    (BRun (Tick N_0) (Root hole))
    (transition-span tick finish-value)
    (BFinal (Halted N_1)))]
  [---------------- "fail-feature-boundary"
   (selected-foreign-premerged-oracle-B-step
    (BRun (Fail N) (in-hole TaskFocus (Box hole)))
    (transition-span fail)
    (BDead N (in-hole TaskFocus (Box hole))))]
  [---------------- "pop-box-crash"
   (selected-foreign-premerged-oracle-B-step
    (BDead N (in-hole TaskFocus (Box hole)))
    (transition-span pop-box-crash)
    (BDead N TaskFocus))]
  [---------------- "fail-base-fusion"
   (selected-foreign-premerged-oracle-B-step
    (BRun (Fail N) (in-hole TaskFocus (Wrap hole)))
    (transition-span fail pop-wrap-crash)
    (BDead N TaskFocus))]
  [---------------- "fail-root-fusion"
   (selected-foreign-premerged-oracle-B-step
    (BRun (Fail N) (Root hole))
    (transition-span fail finish-failure)
    (BFinal (Aborted N)))]
  [---------------- "finish-value"
   (selected-foreign-premerged-oracle-B-step
    (BSettled (Value N) (Root hole))
    (transition-span finish-value)
    (BFinal (Halted N)))]
  [---------------- "finish-failure"
   (selected-foreign-premerged-oracle-B-step
    (BDead N (Root hole))
    (transition-span finish-failure)
    (BFinal (Aborted N)))])

(define-judgment-form selected-foreign-premerged-oracle-lang
  #:contract
  (selected-foreign-premerged-oracle-big-evaluate World Big)
  #:mode (selected-foreign-premerged-oracle-big-evaluate I O)
  [(selected-foreign-premerged-oracle-evidence Input N_0)
   (where N_1 ,(add1 (term N_0)))
   ---------------- "echo-box"
   (selected-foreign-premerged-oracle-big-evaluate
    (Root (Box (Echo Input)))
    (BigFinal (Halted N_1)))]
  [(selected-foreign-premerged-oracle-evidence Input N_0)
   (where N_1 ,(add1 (term N_0)))
   ---------------- "query-box"
   (selected-foreign-premerged-oracle-big-evaluate
    (Root (Box (Query Input)))
    (BigFinal (Halted N_1)))]
  [(selected-foreign-premerged-oracle-evidence Input N_0)
   (where N_1 ,(add1 (term N_0)))
   ---------------- "echo-nested-box"
   (selected-foreign-premerged-oracle-big-evaluate
    (Root (Box (Box (Echo Input))))
    (BigFinal (Halted N_1)))]
  [(selected-foreign-premerged-oracle-evidence Input N_0)
   (where N_1 ,(add1 (term N_0)))
   ---------------- "query-nested-box"
   (selected-foreign-premerged-oracle-big-evaluate
    (Root (Box (Box (Query Input))))
    (BigFinal (Halted N_1)))]
  [(selected-foreign-premerged-oracle-evidence Input N_0)
   (where N_1 ,(add1 (term N_0)))
   ---------------- "echo-root"
   (selected-foreign-premerged-oracle-big-evaluate
    (Root (Echo Input))
    (BigFinal (Halted N_1)))]
  [(selected-foreign-premerged-oracle-evidence Input N_0)
   (where N_1 ,(add1 (term N_0)))
   ---------------- "query-root"
   (selected-foreign-premerged-oracle-big-evaluate
    (Root (Query Input))
    (BigFinal (Halted N_1)))]
  [---------------- "fail-box"
   (selected-foreign-premerged-oracle-big-evaluate
    (Root (Box (Fail N)))
    (BigFinal (Aborted N)))]
  [---------------- "fail-root"
   (selected-foreign-premerged-oracle-big-evaluate
    (Root (Fail N))
    (BigFinal (Aborted N)))])
