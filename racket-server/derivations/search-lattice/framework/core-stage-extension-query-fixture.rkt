#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: redex/parameter)
         "./core-stage-extension-base-fixture.rkt"
         "./core-stage-schema.rkt")

(provide selected-foreign-query-source-lang
         selected-foreign-query-evidence
         selected-foreign-query-R
         selected-foreign/query-extension)

;; Query and Box enter only here.  The extended evidence has two distinct
;; proofs for the accepted string, so both inherited Echo and feature-owned
;; Query expose dependency lifting without successor-set deduplication.
(define-syntax-rule
  (define-query-evidence-extension language evidence)
  (redex-parameter:define-extended-judgment-form*
   selected-foreign-evidence
   language
   #:mode (evidence I O)
   [---------------- "query-evidence-left"
    (evidence "cross-module" 7)]
   [---------------- "query-evidence-right"
    (evidence "cross-module" 7)]))

(define-extended-language selected-foreign-query-source-lang
  selected-foreign-base-lang
  [Input .... string]
  [Task ....
        (Query Input)
        (Box Task)
        (Seal Task)]
  [TaskPath ....
            (Box TaskPath)
            (Seal TaskPath)])

(define-query-evidence-extension
  selected-foreign-query-source-lang
  selected-foreign-query-evidence)

(redex-parameter:define-extended-reduction-relation*
 selected-foreign-query-R
 selected-foreign-base-R
 selected-foreign-query-source-lang
 #:parameters
 ([query-evidence selected-foreign-query-evidence])
 [--> (in-hole TaskFocus (Query Input))
      (in-hole TaskFocus (Tick N))
      (judgment-holds (query-evidence Input N))
      query]
 [--> (in-hole TaskFocus (Box (Value N)))
      (in-hole TaskFocus (Value N))
      pop-box-value]
 [--> (in-hole TaskFocus (Box (Crashed N)))
      (in-hole TaskFocus (Crashed N))
      pop-box-crash])

(define-selected-stage-extension selected-foreign/query-extension
  #:D
  ((provide selected-foreign-query-D-lang
            selected-foreign-query-plug-D
            selected-foreign-query-decompose
            selected-foreign-query-contract
            selected-foreign-query-D-step)

   (define-extended-language selected-foreign-query-D-lang
     BASE-D-LANGUAGE
     [Input .... string]
     [Task ....
           (Query Input)
           (Box Task)
           (Seal Task)]
     [TaskPath ....
               (Box TaskPath)
               (Seal TaskPath)]
     [RuleName ....
               query
               pop-box-value
               pop-box-crash]
     [FeatureRuleName query pop-box-value pop-box-crash]
     [WR ....
         (Query Input)
         (Box (Value N))
         (Box (Crashed N))]
     ;; A grammar-only witness consumes both retained full-view aliases.  It
     ;; deliberately adds no semantic coordinate case.
     [FeatureViewWitness
      (feature-view SourceRuntimeVariable SourceState)])

   (define-query-evidence-extension
     selected-foreign-query-D-lang
     selected-foreign-query-evidence/D)

   (redex-parameter:define-extended-metafunction*
    BASE-D-PLUG
    selected-foreign-query-D-lang
    selected-foreign-query-plug-D : D -> SourceF)

   (redex-parameter:define-extended-metafunction*
    BASE-C-PLUG
    selected-foreign-query-D-lang
    selected-foreign-query-plug-C : C -> SourceF)

   (redex-parameter:define-extended-metafunction*
    BASE-CONTRACT-LABEL
    selected-foreign-query-D-lang
    selected-foreign-query-contract-label : C -> RuleName)

   (redex-parameter:define-extended-judgment-form*
    BASE-DECOMPOSE
    selected-foreign-query-D-lang
    #:mode (selected-foreign-query-decompose I O))

   (redex-parameter:define-extended-judgment-form*
    BASE-CONTRACT
    selected-foreign-query-D-lang
    #:mode (selected-foreign-query-contract I O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/D])
    [(query-evidence Input N)
     ---------------- "query"
     (selected-foreign-query-contract
      (DecWork (Query Input) TaskFocus)
      (ContractWork query (Tick N) TaskFocus))]
    [---------------- "pop-box-value"
     (selected-foreign-query-contract
      (DecWork (Box (Value N)) TaskFocus)
      (ContractWork pop-box-value (Value N) TaskFocus))]
    [---------------- "pop-box-crash"
     (selected-foreign-query-contract
      (DecWork (Box (Crashed N)) TaskFocus)
      (ContractWork pop-box-crash (Crashed N) TaskFocus))])

   (redex-parameter:define-extended-judgment-form*
    BASE-D-STEP
    selected-foreign-query-D-lang
    #:mode (selected-foreign-query-D-step I O O)))

  #:Z
  ((provide selected-foreign-query-Z-lang
            selected-foreign-query-refocus-phase
            selected-foreign-query-Z-step)

   (define-extended-language selected-foreign-query-Z-lang
     BASE-Z-LANGUAGE
     [Input .... string]
     [Task ....
           (Query Input)
           (Box Task)
           (Seal Task)]
     [TaskPath ....
               (Box TaskPath)
               (Seal TaskPath)]
     [RuleName ....
               query
               pop-box-value
               pop-box-crash]
     [WR ....
         (Query Input)
         (Box (Value N))
         (Box (Crashed N))]
     [RunW .... (Query Input)]
     [Frame .... (Box hole) (Seal hole)]
     [OpenW .... (Box OpenW) (Seal OpenW)])

   (define-query-evidence-extension
     selected-foreign-query-Z-lang
     selected-foreign-query-evidence/Z)

   (redex-parameter:define-extended-metafunction*
    BASE-REFOCUS-PHASE
    selected-foreign-query-Z-lang
    selected-foreign-query-refocus-phase : D -> Z)

   (redex-parameter:define-extended-judgment-form*
    BASE-Z-REFOCUS-WORK
    selected-foreign-query-Z-lang
    #:mode (selected-foreign-query-Z-refocus-work I I O))

   (redex-parameter:define-extended-judgment-form*
    BASE-Z-REFOCUS
    selected-foreign-query-Z-lang
    #:mode (selected-foreign-query-Z-refocus I O))

   (redex-parameter:define-extended-judgment-form*
    BASE-Z-STEP
    selected-foreign-query-Z-lang
    #:mode (selected-foreign-query-Z-step I O O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/Z])
    [(query-evidence Input N)
     (selected-foreign-query-Z-refocus-work
      (Tick N) TaskFocus Z_1)
     ---------------- "query"
     (selected-foreign-query-Z-step
      (ZWork (Query Input) TaskFocus)
      query
      Z_1)]
    [(selected-foreign-query-Z-refocus-work
      (Value N) TaskFocus Z_1)
     ---------------- "pop-box-value"
     (selected-foreign-query-Z-step
      (ZWork (Box (Value N)) TaskFocus)
      pop-box-value
      Z_1)]
    [(selected-foreign-query-Z-refocus-work
      (Crashed N) TaskFocus Z_1)
     ---------------- "pop-box-crash"
     (selected-foreign-query-Z-step
      (ZWork (Box (Crashed N)) TaskFocus)
      pop-box-crash
      Z_1)]))

  #:M
  ((provide selected-foreign-query-M-lang
            selected-foreign-query-machineize
            selected-foreign-query-M-step)

   (define-extended-language selected-foreign-query-M-lang
     BASE-M-LANGUAGE
     [Input .... string]
     [Task ....
           (Query Input)
           (Box Task)
           (Seal Task)]
     [TaskPath ....
               (Box TaskPath)
               (Seal TaskPath)]
     [RuleName ....
               query
               pop-box-value
               pop-box-crash]
     [WR ....
         (Query Input)
         (Box (Value N))
         (Box (Crashed N))]
     [RunW .... (Query Input)]
     [Frame .... (Box hole) (Seal hole)]
     [OpenW .... (Box OpenW) (Seal OpenW)])

   (define-query-evidence-extension
     selected-foreign-query-M-lang
     selected-foreign-query-evidence/M)

   (redex-parameter:define-extended-metafunction*
    BASE-MACHINEIZE
    selected-foreign-query-M-lang
    selected-foreign-query-machineize : Z -> M)

   (redex-parameter:define-extended-judgment-form*
    BASE-M-REFOCUS-WORK
    selected-foreign-query-M-lang
    #:mode (selected-foreign-query-M-refocus-work I I O))

   (redex-parameter:define-extended-judgment-form*
    BASE-M-REFOCUS
    selected-foreign-query-M-lang
    #:mode (selected-foreign-query-M-refocus I O))

   (redex-parameter:define-extended-judgment-form*
    BASE-M-STEP
    selected-foreign-query-M-lang
    #:mode (selected-foreign-query-M-step I O O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/M])
    [(query-evidence Input N)
     (selected-foreign-query-M-refocus-work
      (Tick N) TaskFocus M_1)
     ---------------- "query"
     (selected-foreign-query-M-step
      (MWork (Query Input) TaskFocus)
      query
      M_1)]
    [(selected-foreign-query-M-refocus-work
      (Value N) TaskFocus M_1)
     ---------------- "pop-box-value"
     (selected-foreign-query-M-step
      (MWork (Box (Value N)) TaskFocus)
      pop-box-value
      M_1)]
    [(selected-foreign-query-M-refocus-work
      (Crashed N) TaskFocus M_1)
     ---------------- "pop-box-crash"
     (selected-foreign-query-M-step
      (MWork (Box (Crashed N)) TaskFocus)
      pop-box-crash
      M_1)]))

  #:B
  ((provide selected-foreign-query-B-lang
            selected-foreign-query-compress
            selected-foreign-query-span-labels
            selected-foreign-query-B-step)

   (define-extended-language selected-foreign-query-B-lang
     BASE-B-LANGUAGE
     [Input .... string]
     [Task ....
           (Query Input)
           (Box Task)
           (Seal Task)]
     [TaskPath ....
               (Box TaskPath)
               (Seal TaskPath)]
     [RuleName ....
               query
               pop-box-value
               pop-box-crash]
     [WR ....
         (Query Input)
         (Box (Value N))
         (Box (Crashed N))]
     [RunW .... (Query Input)]
     [Frame .... (Box hole) (Seal hole)]
     [OpenW .... (Box OpenW) (Seal OpenW)]
     [NonAllocateRun .... (Query Input)]
     [SingletonRuleName ....
                        query
                        pop-box-value
                        pop-box-crash])

   (define-query-evidence-extension
     selected-foreign-query-B-lang
     selected-foreign-query-evidence/B)

   (redex-parameter:define-extended-metafunction*
    BASE-COMPRESS
    selected-foreign-query-B-lang
    selected-foreign-query-compress : M -> B)

   (redex-parameter:define-extended-metafunction*
    BASE-SPAN-LABELS
    selected-foreign-query-B-lang
    selected-foreign-query-span-labels : TransitionSpan -> LabelTrace)

   (redex-parameter:define-extended-judgment-form*
    BASE-B-PRODUCE-SETTLED
    selected-foreign-query-B-lang
    #:mode (selected-foreign-query-base-produce-settled I I O O O))

   (redex-parameter:define-extended-judgment-form*
    BASE-B-PRODUCE-DEAD
    selected-foreign-query-B-lang
    #:mode (selected-foreign-query-base-produce-dead I I O O O))

   (redex-parameter:define-extended-judgment-form*
    BASE-B-ADVANCE-SETTLED
    selected-foreign-query-B-lang
    #:mode (selected-foreign-query-base-advance-settled I I O O))

   (redex-parameter:define-extended-judgment-form*
    BASE-B-ADVANCE-DEAD
    selected-foreign-query-B-lang
    #:mode (selected-foreign-query-base-advance-dead I I O O))

   (redex-parameter:define-extended-judgment-form*
    BASE-B-SINGLETON
    selected-foreign-query-B-lang
    #:mode (selected-foreign-query-singleton I O O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/B])
    [(query-evidence Input N)
     ---------------- "query"
     (selected-foreign-query-singleton
      (BRun (Query Input) TaskFocus)
      (transition-span query)
      (BRun (Tick N) TaskFocus))]
    [---------------- "pop-box-value"
     (selected-foreign-query-singleton
      (BSettled (Value N)
                (in-hole TaskFocus (Box hole)))
      (transition-span pop-box-value)
      (BSettled (Value N) TaskFocus))]
    [---------------- "pop-box-crash"
     (selected-foreign-query-singleton
      (BDead N
             (in-hole TaskFocus (Box hole)))
      (transition-span pop-box-crash)
      (BDead N TaskFocus))])

   (redex-parameter:define-extended-judgment-form*
    BASE-B-STEP
    selected-foreign-query-B-lang
    #:mode (selected-foreign-query-B-step I O O)
    [(selected-foreign-query-base-produce-settled
      SourceW SourceWorkFocus_0
      SettledProducerName Settled SourceWorkFocus_1)
     (side-condition
      ,(and
        (not
         (judgment-holds
          (selected-foreign-query-base-advance-settled
           ,(term Settled)
           ,(term SourceWorkFocus_1)
           SettledFollowerName_probe
           B_base-probe)))
        (judgment-holds
         (selected-foreign-query-singleton
          ,(term (BSettled Settled SourceWorkFocus_1))
          TransitionSpan_feature-probe
          B_feature-probe))))
     ---------------- "settled-feature-boundary"
     (selected-foreign-query-B-step
      (BRun SourceW SourceWorkFocus_0)
      (transition-span SettledProducerName)
      (BSettled Settled SourceWorkFocus_1))]
    [(selected-foreign-query-base-produce-dead
      SourceW SourceWorkFocus_0
      DeadProducerName FailureSummary SourceWorkFocus_1)
     (side-condition
      ,(and
        (not
         (judgment-holds
          (selected-foreign-query-base-advance-dead
           ,(term FailureSummary)
           ,(term SourceWorkFocus_1)
           DeadFollowerName_probe
           B_base-probe)))
        (judgment-holds
         (selected-foreign-query-singleton
          ,(term (BDead FailureSummary SourceWorkFocus_1))
          TransitionSpan_feature-probe
          B_feature-probe))))
     ---------------- "dead-feature-boundary"
     (selected-foreign-query-B-step
      (BRun SourceW SourceWorkFocus_0)
      (transition-span DeadProducerName)
      (BDead FailureSummary SourceWorkFocus_1))]))

  #:Big
  ((provide selected-foreign-query-Big-lang
            selected-foreign-query-big-dispatch
            selected-foreign-query-big-evaluate
            selected-foreign-query-Big-spec-lang
            selected-foreign-query-promote)

   (define-extended-language selected-foreign-query-Big-lang
     BASE-BIG-LANGUAGE
     [Input .... string]
     [Task ....
           (Query Input)
           (Box Task)
           (Seal Task)]
     [TaskPath ....
               (Box TaskPath)
               (Seal TaskPath)]
     [RunW .... (Query Input)]
     [Frame .... (Box hole) (Seal hole)])

   (define-query-evidence-extension
     selected-foreign-query-Big-lang
     selected-foreign-query-evidence/Big)

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-DISPATCH-ONE
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-dispatch-one I I O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/Big])
    [(query-evidence Input N)
     ---------------- "query"
     (selected-foreign-query-big-dispatch-one
      (Query Input) TaskFocus
      (BigContinue (Tick N) TaskFocus))]
    [---------------- "pop-box-value"
     (selected-foreign-query-big-dispatch-one
      (Value N)
      (in-hole TaskFocus (Box hole))
      (BigContinue (Value N) TaskFocus))]
    [---------------- "pop-box-crash"
     (selected-foreign-query-big-dispatch-one
      (Crashed N)
      (in-hole TaskFocus (Box hole))
      (BigContinue (Crashed N) TaskFocus))])

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-DISPATCH
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-dispatch I I O))

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-RUN
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-run I I O))

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-SETTLED
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-settled I I O))

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-DEAD
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-dead I I O))

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-FINAL
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-final I O))

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-EVALUATE
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-evaluate I O))

   (define-extended-language selected-foreign-query-Big-spec-lang
     BASE-BIG-SPEC-LANGUAGE
     [Input .... string]
     [Task ....
           (Query Input)
           (Box Task)
           (Seal Task)]
     [TaskPath ....
               (Box TaskPath)
               (Seal TaskPath)]
     [RuleName ....
               query
               pop-box-value
               pop-box-crash]
     [WR ....
         (Query Input)
         (Box (Value N))
         (Box (Crashed N))]
     [RunW .... (Query Input)]
     [Frame .... (Box hole) (Seal hole)]
     [OpenW .... (Box OpenW) (Seal OpenW)]
     [NonAllocateRun .... (Query Input)]
     [SingletonRuleName ....
                        query
                        pop-box-value
                        pop-box-crash])

   ;; Promotion is the B-to-Big observation for the augmented row.  Its
   ;; clauses call the already-generated direct feature wrappers, so it does
   ;; not decode through an earlier stage or replay a premerged instance.
   (define-judgment-form selected-foreign-query-Big-spec-lang
     #:contract (selected-foreign-query-promote B Big)
     #:mode (selected-foreign-query-promote I O)
     [(selected-foreign-query-big-run
       RunW SourceWorkFocus Big_0)
      ----------------
      (selected-foreign-query-promote
       (BRun RunW SourceWorkFocus) Big_0)]
     [(selected-foreign-query-big-settled
       Settled SourceWorkFocus Big_0)
      ----------------
      (selected-foreign-query-promote
       (BSettled Settled SourceWorkFocus) Big_0)]
     [(selected-foreign-query-big-dead
       FailureSummary SourceWorkFocus Big_0)
      ----------------
      (selected-foreign-query-promote
       (BDead FailureSummary SourceWorkFocus) Big_0)]
     [(selected-foreign-query-big-final T Big_0)
      ----------------
      (selected-foreign-query-promote
       (BFinal T) Big_0)])))
