#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: "./core-redex-parameter.rkt")
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
  (define-query-evidence-extension base-evidence language evidence)
  (redex-parameter:define-extended-judgment-form*
   base-evidence
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
  selected-foreign-evidence
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
  #:source-language selected-foreign-query-source-lang
  #:feature-singletons (query pop-box-value pop-box-crash)
  #:D
  [#:parameters
   ([query-evidence selected-foreign-query-evidence/D])
   #:artifacts
   (D-artifacts
    #:language selected-foreign-query-D-lang
    #:plug-D selected-foreign-query-plug-D
    #:plug-C selected-foreign-query-plug-C
    #:contract-label selected-foreign-query-contract-label
    #:decompose selected-foreign-query-decompose
    #:contract selected-foreign-query-contract
    #:step selected-foreign-query-D-step)
   #:forms
   ((provide selected-foreign-query-D-lang
            selected-foreign-query-plug-D
            selected-foreign-query-plug-C
            selected-foreign-query-contract-label
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
     BASE-D-PARAMETER-query-evidence
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
    #:mode (selected-foreign-query-D-step I O O)
    #:parameters
    ([step-contract selected-foreign-query-contract]
     [step-contract-label selected-foreign-query-contract-label]
     [step-plug-C selected-foreign-query-plug-C]
     [step-decompose selected-foreign-query-decompose])))]

  #:Z
  [#:parameters
   ([query-evidence selected-foreign-query-evidence/Z])
   #:artifacts
   (Z-artifacts
    #:language selected-foreign-query-Z-lang
    #:refocus-phase selected-foreign-query-refocus-phase
    #:refocus-work-direct selected-foreign-query-Z-refocus-work
    #:refocus-direct selected-foreign-query-Z-refocus
    #:step-direct selected-foreign-query-Z-step)
   #:forms
   ((provide selected-foreign-query-Z-lang
            selected-foreign-query-refocus-phase
            selected-foreign-query-Z-refocus-work
            selected-foreign-query-Z-refocus
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
     BASE-Z-PARAMETER-query-evidence
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
    #:mode (selected-foreign-query-Z-refocus I O)
    #:parameters
    ([refocus-work-dependency selected-foreign-query-Z-refocus-work]))

   (redex-parameter:define-extended-judgment-form*
    BASE-Z-STEP
    selected-foreign-query-Z-lang
    #:mode (selected-foreign-query-Z-step I O O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/Z]
     [step-refocus-work selected-foreign-query-Z-refocus-work])
    [(query-evidence Input N)
     (step-refocus-work
      (Tick N) TaskFocus Z_1)
     ---------------- "query"
     (selected-foreign-query-Z-step
      (ZWork (Query Input) TaskFocus)
      query
      Z_1)]
    [(step-refocus-work
      (Value N) TaskFocus Z_1)
     ---------------- "pop-box-value"
     (selected-foreign-query-Z-step
      (ZWork (Box (Value N)) TaskFocus)
      pop-box-value
      Z_1)]
    [(step-refocus-work
      (Crashed N) TaskFocus Z_1)
     ---------------- "pop-box-crash"
     (selected-foreign-query-Z-step
      (ZWork (Box (Crashed N)) TaskFocus)
      pop-box-crash
      Z_1)]))
   #:diagnostic-parameters
   ([query-evidence selected-foreign-query-evidence/Z])
   #:diagnostics
   (Z-diagnostics
    #:D->Z selected-foreign-query-D->Z
    #:Z->D selected-foreign-query-Z->D
    #:readback selected-foreign-query-readback-Z
    #:refocus-spec selected-foreign-query-refocus/spec
    #:step-spec selected-foreign-query-Z-step/spec)
   #:diagnostic-forms
   ((provide selected-foreign-query-D->Z
             selected-foreign-query-Z->D
             selected-foreign-query-readback-Z
             selected-foreign-query-refocus/spec
             selected-foreign-query-Z-step/spec)

    ;; These codecs and specifications are secondary diagnostics.  The phase
    ;; transformation and direct transition system above do not call them.
    (define-metafunction selected-foreign-query-Z-lang
      selected-foreign-query-D->Z : D -> Z
      [(selected-foreign-query-D->Z (Final T)) (ZFinal T)]
      [(selected-foreign-query-D->Z (DecWork WR SourceWorkFocus))
       (ZWork WR SourceWorkFocus)]
      [(selected-foreign-query-D->Z
        (DecFrontier FR SourceSpineContext))
       (ZFrontier FR SourceSpineContext)]
      [(selected-foreign-query-D->Z (DecAllocate AR SourceWorkFocus))
       (ZAllocate AR SourceWorkFocus)])

    (define-metafunction selected-foreign-query-Z-lang
      selected-foreign-query-Z->D : Z -> D
      [(selected-foreign-query-Z->D (ZFinal T)) (Final T)]
      [(selected-foreign-query-Z->D (ZWork WR SourceWorkFocus))
       (DecWork WR SourceWorkFocus)]
      [(selected-foreign-query-Z->D
        (ZFrontier FR SourceSpineContext))
       (DecFrontier FR SourceSpineContext)]
      [(selected-foreign-query-Z->D (ZAllocate AR SourceWorkFocus))
       (DecAllocate AR SourceWorkFocus)])

    (define-metafunction selected-foreign-query-Z-lang
      selected-foreign-query-readback-Z : Z -> SourceF
      [(selected-foreign-query-readback-Z (ZFinal T)) T]
      [(selected-foreign-query-readback-Z
        (ZWork WR SourceWorkFocus))
       (in-hole SourceWorkFocus WR)]
      [(selected-foreign-query-readback-Z
        (ZFrontier FR SourceSpineContext))
       (in-hole SourceSpineContext FR)]
      [(selected-foreign-query-readback-Z
        (ZAllocate AR SourceWorkFocus))
       (in-hole SourceWorkFocus AR)])

    (define-judgment-form selected-foreign-query-Z-lang
      #:contract (selected-foreign-query-refocus/spec C Z)
      #:mode (selected-foreign-query-refocus/spec I O)
      [(where SourceF_0 (selected-foreign-query-plug-C C))
       (selected-foreign-query-decompose SourceF_0 D_0)
       (where Z_0 (selected-foreign-query-D->Z D_0))
       ----
       (selected-foreign-query-refocus/spec C Z_0)])

    (define-judgment-form selected-foreign-query-Z-lang
      #:contract (selected-foreign-query-Z-step/spec Z RuleName Z)
      #:mode (selected-foreign-query-Z-step/spec I O O)
      [(where D_0 (selected-foreign-query-Z->D Z_0))
       (selected-foreign-query-contract D_0 C_0)
       (where RuleName
              (selected-foreign-query-contract-label C_0))
       (selected-foreign-query-refocus/spec C_0 Z_1)
       ----
       (selected-foreign-query-Z-step/spec Z_0 RuleName Z_1)]))]

  #:M
  [#:parameters
   ([query-evidence selected-foreign-query-evidence/M])
   #:artifacts
   (M-artifacts
    #:language selected-foreign-query-M-lang
    #:machineize selected-foreign-query-machineize
    #:refocus-work-direct selected-foreign-query-M-refocus-work
    #:refocus-direct selected-foreign-query-M-refocus
    #:step-direct selected-foreign-query-M-step)
   #:forms
   ((provide selected-foreign-query-M-lang
            selected-foreign-query-machineize
            selected-foreign-query-M-refocus-work
            selected-foreign-query-M-refocus
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
     BASE-M-PARAMETER-query-evidence
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
    #:mode (selected-foreign-query-M-refocus I O)
    #:parameters
    ([refocus-work-dependency selected-foreign-query-M-refocus-work]))

   (redex-parameter:define-extended-judgment-form*
    BASE-M-STEP
    selected-foreign-query-M-lang
    #:mode (selected-foreign-query-M-step I O O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/M]
     [step-refocus-work selected-foreign-query-M-refocus-work])
    [(query-evidence Input N)
     (step-refocus-work
      (Tick N) TaskFocus M_1)
     ---------------- "query"
     (selected-foreign-query-M-step
      (MWork (Query Input) TaskFocus)
      query
      M_1)]
    [(step-refocus-work
      (Value N) TaskFocus M_1)
     ---------------- "pop-box-value"
     (selected-foreign-query-M-step
      (MWork (Box (Value N)) TaskFocus)
      pop-box-value
      M_1)]
    [(step-refocus-work
      (Crashed N) TaskFocus M_1)
     ---------------- "pop-box-crash"
     (selected-foreign-query-M-step
      (MWork (Box (Crashed N)) TaskFocus)
      pop-box-crash
      M_1)]))
   #:diagnostic-parameters
   ([query-evidence selected-foreign-query-evidence/M])
   #:diagnostics
   (M-diagnostics
    #:encode-ZM selected-foreign-query-encode-ZM
    #:decode-MZ selected-foreign-query-decode-MZ
    #:D->M selected-foreign-query-D->M
    #:M->D selected-foreign-query-M->D
    #:readback selected-foreign-query-readback-M
    #:corresponds selected-foreign-query-ZM-corresponds
    #:step-spec selected-foreign-query-M-step/spec
    #:square selected-foreign-query-ZM-square)
   #:diagnostic-forms
   ((provide selected-foreign-query-encode-ZM
             selected-foreign-query-decode-MZ
             selected-foreign-query-D->M
             selected-foreign-query-M->D
             selected-foreign-query-readback-M
             selected-foreign-query-ZM-corresponds
             selected-foreign-query-M-step/spec
             selected-foreign-query-ZM-square)

    ;; Z and M intentionally remain carrier-isomorphic, but the direct M
    ;; transition system above is generated independently of these diagnostics.
    (define-metafunction selected-foreign-query-M-lang
      selected-foreign-query-encode-ZM : Z -> M
      [(selected-foreign-query-encode-ZM (ZFinal T)) (MFinal T)]
      [(selected-foreign-query-encode-ZM
        (ZWork WR SourceWorkFocus))
       (MWork WR SourceWorkFocus)]
      [(selected-foreign-query-encode-ZM
        (ZFrontier FR SourceSpineContext))
       (MFrontier FR SourceSpineContext)]
      [(selected-foreign-query-encode-ZM
        (ZAllocate AR SourceWorkFocus))
       (MAllocate AR SourceWorkFocus)])

    (define-metafunction selected-foreign-query-M-lang
      selected-foreign-query-decode-MZ : M -> Z
      [(selected-foreign-query-decode-MZ (MFinal T)) (ZFinal T)]
      [(selected-foreign-query-decode-MZ
        (MWork WR SourceWorkFocus))
       (ZWork WR SourceWorkFocus)]
      [(selected-foreign-query-decode-MZ
        (MFrontier FR SourceSpineContext))
       (ZFrontier FR SourceSpineContext)]
      [(selected-foreign-query-decode-MZ
        (MAllocate AR SourceWorkFocus))
       (ZAllocate AR SourceWorkFocus)])

    (define-metafunction selected-foreign-query-M-lang
      selected-foreign-query-D->M : D -> M
      [(selected-foreign-query-D->M (Final T)) (MFinal T)]
      [(selected-foreign-query-D->M
        (DecWork WR SourceWorkFocus))
       (MWork WR SourceWorkFocus)]
      [(selected-foreign-query-D->M
        (DecFrontier FR SourceSpineContext))
       (MFrontier FR SourceSpineContext)]
      [(selected-foreign-query-D->M
        (DecAllocate AR SourceWorkFocus))
       (MAllocate AR SourceWorkFocus)])

    (define-metafunction selected-foreign-query-M-lang
      selected-foreign-query-M->D : M -> D
      [(selected-foreign-query-M->D (MFinal T)) (Final T)]
      [(selected-foreign-query-M->D
        (MWork WR SourceWorkFocus))
       (DecWork WR SourceWorkFocus)]
      [(selected-foreign-query-M->D
        (MFrontier FR SourceSpineContext))
       (DecFrontier FR SourceSpineContext)]
      [(selected-foreign-query-M->D
        (MAllocate AR SourceWorkFocus))
       (DecAllocate AR SourceWorkFocus)])

    (define-metafunction selected-foreign-query-M-lang
      selected-foreign-query-readback-M : M -> SourceF
      [(selected-foreign-query-readback-M (MFinal T)) T]
      [(selected-foreign-query-readback-M
        (MWork WR SourceWorkFocus))
       (in-hole SourceWorkFocus WR)]
      [(selected-foreign-query-readback-M
        (MFrontier FR SourceSpineContext))
       (in-hole SourceSpineContext FR)]
      [(selected-foreign-query-readback-M
        (MAllocate AR SourceWorkFocus))
       (in-hole SourceWorkFocus AR)])

    (define-judgment-form selected-foreign-query-M-lang
      #:contract (selected-foreign-query-ZM-corresponds Z M)
      #:mode (selected-foreign-query-ZM-corresponds I O)
      [(where M_0 (selected-foreign-query-encode-ZM Z_0))
       ----
       (selected-foreign-query-ZM-corresponds Z_0 M_0)])

    (define-judgment-form selected-foreign-query-M-lang
      #:contract (selected-foreign-query-M-step/spec M RuleName M)
      #:mode (selected-foreign-query-M-step/spec I O O)
      [(where Z_0 (selected-foreign-query-decode-MZ M_0))
       (selected-foreign-query-Z-step Z_0 RuleName Z_1)
       (where M_1 (selected-foreign-query-encode-ZM Z_1))
       ----
       (selected-foreign-query-M-step/spec M_0 RuleName M_1)])

    (define-judgment-form selected-foreign-query-M-lang
      #:contract
      (selected-foreign-query-ZM-square Z RuleName Z M M)
      #:mode (selected-foreign-query-ZM-square I O O O O)
      [(where M_0 (selected-foreign-query-encode-ZM Z_0))
       (selected-foreign-query-Z-step Z_0 RuleName Z_1)
       (where M_1 (selected-foreign-query-encode-ZM Z_1))
       (selected-foreign-query-M-step M_0 RuleName M_1)
       ----
       (selected-foreign-query-ZM-square
        Z_0 RuleName Z_1 M_0 M_1)]))]

  #:B
  [#:parameters
   ([query-evidence selected-foreign-query-evidence/B])
   #:artifacts
   (B-artifacts
    #:language selected-foreign-query-B-lang
    #:compress selected-foreign-query-compress
    #:span-labels selected-foreign-query-span-labels
    #:produce-settled selected-foreign-query-base-produce-settled
    #:produce-dead selected-foreign-query-base-produce-dead
    #:advance-settled selected-foreign-query-base-advance-settled
    #:advance-dead selected-foreign-query-base-advance-dead
    #:base-singleton selected-foreign-query-singleton
    #:step-direct selected-foreign-query-B-step)
   #:forms
   ((provide selected-foreign-query-B-lang
            selected-foreign-query-compress
            selected-foreign-query-span-labels
            selected-foreign-query-base-produce-settled
            selected-foreign-query-base-produce-dead
            selected-foreign-query-base-advance-settled
            selected-foreign-query-base-advance-dead
            selected-foreign-query-singleton
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
     BASE-B-PARAMETER-query-evidence
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
    #:mode (selected-foreign-query-base-produce-settled I I O O O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/B]))

   (redex-parameter:define-extended-judgment-form*
    BASE-B-PRODUCE-DEAD
    selected-foreign-query-B-lang
    #:mode (selected-foreign-query-base-produce-dead I I O O O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/B]))

   (redex-parameter:define-extended-judgment-form*
    BASE-B-ADVANCE-SETTLED
    selected-foreign-query-B-lang
    #:mode (selected-foreign-query-base-advance-settled I I O O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/B]))

   (redex-parameter:define-extended-judgment-form*
    BASE-B-ADVANCE-DEAD
    selected-foreign-query-B-lang
    #:mode (selected-foreign-query-base-advance-dead I I O O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/B]))

   (redex-parameter:define-extended-judgment-form*
    BASE-B-SINGLETON
    selected-foreign-query-B-lang
    #:mode (selected-foreign-query-singleton I O O)
    #:parameters
    ([query-evidence selected-foreign-query-evidence/B]
     [singleton-advance-settled
      selected-foreign-query-base-advance-settled]
     [singleton-advance-dead
      selected-foreign-query-base-advance-dead])
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
    #:parameters
    ([step-produce-settled
      selected-foreign-query-base-produce-settled]
     [step-produce-dead
      selected-foreign-query-base-produce-dead]
     [step-base-advance-settled
      selected-foreign-query-base-advance-settled]
     [step-base-advance-dead
      selected-foreign-query-base-advance-dead]
     [step-singleton selected-foreign-query-singleton])
    [(step-produce-settled
      SourceW SourceWorkFocus_0
      SettledProducerName Settled SourceWorkFocus_1)
     (side-condition
      ,(and
        (not
         (judgment-holds
          (step-base-advance-settled
           ,(term Settled)
           ,(term SourceWorkFocus_1)
           SettledFollowerName_probe
           B_base-probe)))
        (judgment-holds
         (step-singleton
          ,(term (BSettled Settled SourceWorkFocus_1))
          TransitionSpan_feature-probe
          B_feature-probe))))
     ---------------- "settled-feature-boundary"
     (selected-foreign-query-B-step
      (BRun SourceW SourceWorkFocus_0)
      (transition-span SettledProducerName)
      (BSettled Settled SourceWorkFocus_1))]
    [(step-produce-dead
      SourceW SourceWorkFocus_0
      DeadProducerName FailureSummary SourceWorkFocus_1)
     (side-condition
      ,(and
        (not
         (judgment-holds
          (step-base-advance-dead
           ,(term FailureSummary)
           ,(term SourceWorkFocus_1)
           DeadFollowerName_probe
           B_base-probe)))
        (judgment-holds
         (step-singleton
          ,(term (BDead FailureSummary SourceWorkFocus_1))
          TransitionSpan_feature-probe
          B_feature-probe))))
     ---------------- "dead-feature-boundary"
     (selected-foreign-query-B-step
      (BRun SourceW SourceWorkFocus_0)
      (transition-span DeadProducerName)
      (BDead FailureSummary SourceWorkFocus_1))]))
   #:diagnostic-parameters
   ([query-evidence selected-foreign-query-evidence/B])
   #:diagnostics
   (B-diagnostics
    #:encode-MB selected-foreign-query-encode-MB
    #:decode-BM selected-foreign-query-decode-BM
    #:readback selected-foreign-query-readback-B
    #:corresponds selected-foreign-query-MB-corresponds
    #:replay selected-foreign-query-replay/M
    #:step-spec selected-foreign-query-B-step/spec
    #:square selected-foreign-query-MB-square)
   #:diagnostic-forms
   ((provide selected-foreign-query-encode-MB
             selected-foreign-query-decode-BM
             selected-foreign-query-readback-B
             selected-foreign-query-MB-corresponds
             selected-foreign-query-replay/M
             selected-foreign-query-B-step/spec
             selected-foreign-query-MB-square)

    ;; The M/B codec is a secondary transport diagnostic.  Compression and
    ;; direct B stepping above never decode through M.
    (define-metafunction selected-foreign-query-B-lang
      selected-foreign-query-encode-MB : M -> B
      [(selected-foreign-query-encode-MB (MFinal T)) (BFinal T)]
      [(selected-foreign-query-encode-MB
        (MAllocate AR SourceWorkFocus))
       (BRun AR SourceWorkFocus)]
      [(selected-foreign-query-encode-MB
        (MWork NonAllocateRun SourceWorkFocus))
       (BRun NonAllocateRun SourceWorkFocus)]
      [(selected-foreign-query-encode-MB
        (MWork (in-hole Frame Settled) SourceWorkFocus))
       (BSettled Settled (in-hole SourceWorkFocus Frame))]
      [(selected-foreign-query-encode-MB
        (MWork (in-hole Frame (Crashed N)) SourceWorkFocus))
       (BDead N (in-hole SourceWorkFocus Frame))]
      [(selected-foreign-query-encode-MB
        (MFrontier (Root Settled) hole))
       (BSettled Settled (Root hole))]
      [(selected-foreign-query-encode-MB
        (MFrontier (Root (Crashed N)) hole))
       (BDead N (Root hole))])

    (define-metafunction selected-foreign-query-B-lang
      selected-foreign-query-decode-BM : B -> M
      [(selected-foreign-query-decode-BM (BFinal T)) (MFinal T)]
      [(selected-foreign-query-decode-BM
        (BRun AR SourceWorkFocus))
       (MAllocate AR SourceWorkFocus)]
      [(selected-foreign-query-decode-BM
        (BRun NonAllocateRun SourceWorkFocus))
       (MWork NonAllocateRun SourceWorkFocus)]
      [(selected-foreign-query-decode-BM
        (BSettled Settled (in-hole SourceWorkFocus Frame)))
       (MWork (in-hole Frame Settled) SourceWorkFocus)]
      [(selected-foreign-query-decode-BM
        (BDead N (in-hole SourceWorkFocus Frame)))
       (MWork (in-hole Frame (Crashed N)) SourceWorkFocus)]
      [(selected-foreign-query-decode-BM
        (BSettled Settled (Root hole)))
       (MFrontier (Root Settled) hole)]
      [(selected-foreign-query-decode-BM
        (BDead N (Root hole)))
       (MFrontier (Root (Crashed N)) hole)])

    (define-metafunction selected-foreign-query-B-lang
      selected-foreign-query-readback-B : B -> SourceF
      [(selected-foreign-query-readback-B
        (BRun NonAllocateRun SourceWorkFocus))
       (in-hole SourceWorkFocus NonAllocateRun)]
      [(selected-foreign-query-readback-B
        (BRun AR SourceWorkFocus))
       (in-hole SourceWorkFocus AR)]
      [(selected-foreign-query-readback-B
        (BSettled Settled SourceWorkFocus))
       (in-hole SourceWorkFocus Settled)]
      [(selected-foreign-query-readback-B
        (BDead N SourceWorkFocus))
       (in-hole SourceWorkFocus (Crashed N))]
      [(selected-foreign-query-readback-B (BFinal T)) T])

    (define-judgment-form selected-foreign-query-B-lang
      #:contract (selected-foreign-query-MB-corresponds M B)
      #:mode (selected-foreign-query-MB-corresponds I O)
      [(where B_0 (selected-foreign-query-compress M_0))
       ----
       (selected-foreign-query-MB-corresponds M_0 B_0)])

    (define-judgment-form selected-foreign-query-B-lang
      #:contract
      (selected-foreign-query-replay/M M TransitionSpan M)
      #:mode (selected-foreign-query-replay/M I O O)
      [(selected-foreign-query-M-step M_0 SingletonRuleName M_1)
       ----
       (selected-foreign-query-replay/M
        M_0 (transition-span SingletonRuleName) M_1)]
      [(selected-foreign-query-M-step M_0 SettledProducerName M_1)
       (selected-foreign-query-M-step M_1 SettledFollowerName M_2)
       ----
       (selected-foreign-query-replay/M
        M_0
        (transition-span SettledProducerName SettledFollowerName)
        M_2)]
      [(selected-foreign-query-M-step M_0 DeadProducerName M_1)
       (selected-foreign-query-M-step M_1 DeadFollowerName M_2)
       ----
       (selected-foreign-query-replay/M
        M_0
        (transition-span DeadProducerName DeadFollowerName)
        M_2)])

    (define-judgment-form selected-foreign-query-B-lang
      #:contract
      (selected-foreign-query-B-step/spec B TransitionSpan B)
      #:mode (selected-foreign-query-B-step/spec I O O)
      [(where M_0 (selected-foreign-query-decode-BM B_0))
       (selected-foreign-query-replay/M M_0 TransitionSpan M_1)
       (where B_1 (selected-foreign-query-encode-MB M_1))
       ----
       (selected-foreign-query-B-step/spec B_0 TransitionSpan B_1)])

    (define-judgment-form selected-foreign-query-B-lang
      #:contract
      (selected-foreign-query-MB-square B TransitionSpan B M M)
      #:mode (selected-foreign-query-MB-square I O O O O)
      [(where M_0 (selected-foreign-query-decode-BM B_0))
       (selected-foreign-query-replay/M M_0 TransitionSpan M_1)
       (where B_1 (selected-foreign-query-encode-MB M_1))
       (selected-foreign-query-B-step B_0 TransitionSpan B_1)
       ----
       (selected-foreign-query-MB-square
        B_0 TransitionSpan B_1 M_0 M_1)]))]

  #:Big
  [#:parameters
   ([query-evidence selected-foreign-query-evidence/Big])
   #:artifacts
   (Big-artifacts
    #:language selected-foreign-query-Big-lang
    #:dispatch-one selected-foreign-query-big-dispatch-one
    #:dispatch selected-foreign-query-big-dispatch
    #:run selected-foreign-query-big-run
    #:settled selected-foreign-query-big-settled
    #:dead selected-foreign-query-big-dead
    #:final selected-foreign-query-big-final
    #:evaluate selected-foreign-query-big-evaluate)
   #:forms
   ((provide selected-foreign-query-Big-lang
            selected-foreign-query-big-dispatch-one
            selected-foreign-query-big-dispatch
            selected-foreign-query-big-run
            selected-foreign-query-big-settled
            selected-foreign-query-big-dead
            selected-foreign-query-big-final
            selected-foreign-query-big-evaluate)

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
     BASE-BIG-PARAMETER-query-evidence
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
    #:mode (selected-foreign-query-big-dispatch I I O)
    #:parameters
    ([dispatch-next selected-foreign-query-big-dispatch-one]))

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-RUN
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-run I I O)
    #:parameters
    ([run-dispatch selected-foreign-query-big-dispatch]))

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-SETTLED
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-settled I I O)
    #:parameters
    ([settled-dispatch selected-foreign-query-big-dispatch]))

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-DEAD
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-dead I I O)
    #:parameters
    ([dead-dispatch selected-foreign-query-big-dispatch]))

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-FINAL
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-final I O))

   (redex-parameter:define-extended-judgment-form*
    BASE-BIG-EVALUATE
    selected-foreign-query-Big-lang
    #:mode (selected-foreign-query-big-evaluate I O)
    #:parameters
    ([evaluate-dispatch selected-foreign-query-big-dispatch]
     [evaluate-final selected-foreign-query-big-final])))
   #:diagnostic-parameters
   ([query-evidence selected-foreign-query-evidence/Big-spec])
   #:diagnostics
   (Big-diagnostics
    #:readback selected-foreign-query-readback-Big
    #:spec-language selected-foreign-query-Big-spec-lang
    #:initialize selected-foreign-query-initialize-B
    #:close selected-foreign-query-close-B
    #:flatten selected-foreign-query-flatten-BTrace
    #:promote selected-foreign-query-promote
    #:evaluate-spec selected-foreign-query-big-evaluate/spec
    #:unfold-square selected-foreign-query-B-Big-unfold-square
    #:closure-square selected-foreign-query-B-Big-closure-square
    #:root-square selected-foreign-query-B-Big-root-square)
   #:diagnostic-forms
   ((provide selected-foreign-query-readback-Big
             selected-foreign-query-Big-spec-lang
             selected-foreign-query-initialize-B
             selected-foreign-query-close-B
             selected-foreign-query-flatten-BTrace
             selected-foreign-query-promote
             selected-foreign-query-big-evaluate/spec
             selected-foreign-query-B-Big-unfold-square
             selected-foreign-query-B-Big-closure-square
             selected-foreign-query-B-Big-root-square)

   (define-metafunction selected-foreign-query-Big-lang
     selected-foreign-query-readback-Big : Big -> SourceF
     [(selected-foreign-query-readback-Big (BigFinal T)) T])

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

   (define-query-evidence-extension
     BASE-BIG-DIAGNOSTIC-PARAMETER-query-evidence
     selected-foreign-query-Big-spec-lang
     selected-foreign-query-evidence/Big-spec)

   (define-judgment-form selected-foreign-query-Big-spec-lang
     #:contract (selected-foreign-query-initialize-B SourceF B)
     #:mode (selected-foreign-query-initialize-B I O)
     [(selected-foreign-query-decompose SourceF_0 D_0)
      (where Z_0 (selected-foreign-query-refocus-phase D_0))
      (where M_0 (selected-foreign-query-machineize Z_0))
      (where B_0 (selected-foreign-query-compress M_0))
      ----
      (selected-foreign-query-initialize-B SourceF_0 B_0)])

   (define-judgment-form selected-foreign-query-Big-spec-lang
     #:contract (selected-foreign-query-close-B B BTrace T)
     #:mode (selected-foreign-query-close-B I O O)
     [----
      (selected-foreign-query-close-B (BFinal T) () T)]
     [(selected-foreign-query-B-step B_0 TransitionSpan_0 B_1)
      (selected-foreign-query-close-B
       B_1
       (TransitionSpan_rest ...)
       T_0)
      ----
      (selected-foreign-query-close-B
       B_0
       (TransitionSpan_0 TransitionSpan_rest ...)
       T_0)])

   (define-metafunction selected-foreign-query-Big-spec-lang
     selected-foreign-query-flatten-BTrace : BTrace -> LabelTrace
     [(selected-foreign-query-flatten-BTrace ()) ()]
     [(selected-foreign-query-flatten-BTrace
       (TransitionSpan_0 TransitionSpan_rest ...))
      (RuleName_span ... RuleName_rest ...)
      (where (RuleName_span ...)
             (selected-foreign-query-span-labels TransitionSpan_0))
      (where (RuleName_rest ...)
             (selected-foreign-query-flatten-BTrace
              (TransitionSpan_rest ...)))])

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
       (BFinal T) Big_0)])

   (define-judgment-form selected-foreign-query-Big-spec-lang
     #:contract
     (selected-foreign-query-big-evaluate/spec SourceF BTrace Big)
     #:mode (selected-foreign-query-big-evaluate/spec I O O)
     [(selected-foreign-query-initialize-B SourceF_0 B_0)
      (selected-foreign-query-close-B B_0 BTrace_0 T_0)
      ----
      (selected-foreign-query-big-evaluate/spec
       SourceF_0 BTrace_0 (BigFinal T_0))])

   (define-judgment-form selected-foreign-query-Big-spec-lang
     #:contract
     (selected-foreign-query-B-Big-unfold-square
      B TransitionSpan B Big)
     #:mode (selected-foreign-query-B-Big-unfold-square I O O O)
     [(selected-foreign-query-B-step B_0 TransitionSpan_0 B_1)
      (selected-foreign-query-promote B_0 Big_0)
      (selected-foreign-query-promote B_1 Big_0)
      ----
      (selected-foreign-query-B-Big-unfold-square
       B_0 TransitionSpan_0 B_1 Big_0)])

   (define-judgment-form selected-foreign-query-Big-spec-lang
     #:contract
     (selected-foreign-query-B-Big-closure-square B BTrace Big)
     #:mode (selected-foreign-query-B-Big-closure-square I O O)
     [(selected-foreign-query-close-B B_0 BTrace_0 T_0)
      (selected-foreign-query-promote B_0 (BigFinal T_0))
      ----
      (selected-foreign-query-B-Big-closure-square
       B_0 BTrace_0 (BigFinal T_0))])

   (define-judgment-form selected-foreign-query-Big-spec-lang
     #:contract
     (selected-foreign-query-B-Big-root-square SourceF BTrace Big)
     #:mode (selected-foreign-query-B-Big-root-square I O O)
     [(selected-foreign-query-big-evaluate/spec
       SourceF_0 BTrace_0 Big_0)
      (selected-foreign-query-big-evaluate SourceF_0 Big_0)
      ----
      (selected-foreign-query-B-Big-root-square
       SourceF_0 BTrace_0 Big_0)]))])
