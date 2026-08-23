#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: "./core-redex-parameter.rkt")
         "./core-stage-extension-query-fixture.rkt"
         "./core-stage-schema.rkt")

(provide selected-functor-probe-source-lang
         selected-functor-probe-R
         selected-functor/probe-extension)

;; Delta2 intentionally targets Delta1-owned Query syntax.  It therefore
;; cannot be staged honestly against the original base row: every phase must
;; consume the row produced by the Query/Box extension.
(define-extended-language selected-functor-probe-source-lang
  selected-foreign-query-source-lang
  [Task .... (Probe Input)])

(define selected-functor-probe-R
  (extend-reduction-relation
   selected-foreign-query-R
   selected-functor-probe-source-lang
   [--> (in-hole TaskFocus (Probe Input))
        (in-hole TaskFocus (Query Input))
        probe]))

(define-selected-stage-extension selected-functor/probe-extension
  #:source-language selected-functor-probe-source-lang
  #:feature-singletons (probe)
  #:D
  [#:parameters
   ([query-evidence selected-functor-probe-query-evidence/D])
   #:artifacts
   (D-artifacts
    #:language selected-functor-probe-D-lang
    #:plug-D selected-functor-probe-plug-D
    #:plug-C selected-functor-probe-plug-C
    #:contract-label selected-functor-probe-contract-label
    #:decompose selected-functor-probe-decompose
    #:contract selected-functor-probe-contract
    #:step selected-functor-probe-D-step)
   #:forms
   ((provide selected-functor-probe-D-lang
             selected-functor-probe-query-evidence/D
             selected-functor-probe-plug-D
             selected-functor-probe-plug-C
             selected-functor-probe-contract-label
             selected-functor-probe-decompose
             selected-functor-probe-contract
             selected-functor-probe-D-step)

    (define-extended-language selected-functor-probe-D-lang
      BASE-D-LANGUAGE
      [Task .... (Probe Input)]
      [RuleName .... probe]
      [FeatureRuleName .... probe]
      [WR .... (Probe Input)])

    (redex-parameter:define-extended-judgment-form*
     BASE-D-PARAMETER-query-evidence
     selected-functor-probe-D-lang
     #:mode (selected-functor-probe-query-evidence/D I O))

    (redex-parameter:define-extended-metafunction*
     BASE-D-PLUG
     selected-functor-probe-D-lang
     selected-functor-probe-plug-D : D -> SourceF)

    (redex-parameter:define-extended-metafunction*
     BASE-C-PLUG
     selected-functor-probe-D-lang
     selected-functor-probe-plug-C : C -> SourceF)

    (redex-parameter:define-extended-metafunction*
     BASE-CONTRACT-LABEL
     selected-functor-probe-D-lang
     selected-functor-probe-contract-label : C -> RuleName)

    (redex-parameter:define-extended-judgment-form*
     BASE-DECOMPOSE
     selected-functor-probe-D-lang
     #:mode (selected-functor-probe-decompose I O))

    (redex-parameter:define-extended-judgment-form*
     BASE-CONTRACT
     selected-functor-probe-D-lang
     #:mode (selected-functor-probe-contract I O)
     #:parameters
     ([query-evidence selected-functor-probe-query-evidence/D])
     [---------------- "probe"
      (selected-functor-probe-contract
       (DecWork (Probe Input) TaskFocus)
       (ContractWork probe (Query Input) TaskFocus))])

    (redex-parameter:define-extended-judgment-form*
     BASE-D-STEP
     selected-functor-probe-D-lang
     #:mode (selected-functor-probe-D-step I O O)
     #:parameters
     ([step-contract selected-functor-probe-contract]
      [step-contract-label selected-functor-probe-contract-label]
      [step-plug-C selected-functor-probe-plug-C]
      [step-decompose selected-functor-probe-decompose])))]

  #:Z
  [#:parameters
   ([query-evidence selected-functor-probe-query-evidence/Z])
   #:artifacts
   (Z-artifacts
    #:language selected-functor-probe-Z-lang
    #:refocus-phase selected-functor-probe-refocus-phase
    #:refocus-work-direct selected-functor-probe-Z-refocus-work
    #:refocus-direct selected-functor-probe-Z-refocus
    #:step-direct selected-functor-probe-Z-step)
   #:forms
   ((provide selected-functor-probe-Z-lang
             selected-functor-probe-query-evidence/Z
             selected-functor-probe-refocus-phase
             selected-functor-probe-Z-refocus-work
             selected-functor-probe-Z-refocus
             selected-functor-probe-Z-step)

    (define-extended-language selected-functor-probe-Z-lang
      BASE-Z-LANGUAGE
      [Task .... (Probe Input)]
      [RuleName .... probe]
      [WR .... (Probe Input)]
      [RunW .... (Probe Input)])

    (redex-parameter:define-extended-judgment-form*
     BASE-Z-PARAMETER-query-evidence
     selected-functor-probe-Z-lang
     #:mode (selected-functor-probe-query-evidence/Z I O))

    (redex-parameter:define-extended-metafunction*
     BASE-REFOCUS-PHASE
     selected-functor-probe-Z-lang
     selected-functor-probe-refocus-phase : D -> Z)

    (redex-parameter:define-extended-judgment-form*
     BASE-Z-REFOCUS-WORK
     selected-functor-probe-Z-lang
     #:mode (selected-functor-probe-Z-refocus-work I I O))

    (redex-parameter:define-extended-judgment-form*
     BASE-Z-REFOCUS
     selected-functor-probe-Z-lang
     #:mode (selected-functor-probe-Z-refocus I O)
     #:parameters
     ([refocus-work-dependency selected-functor-probe-Z-refocus-work]))

    (redex-parameter:define-extended-judgment-form*
     BASE-Z-STEP
     selected-functor-probe-Z-lang
     #:mode (selected-functor-probe-Z-step I O O)
     #:parameters
     ([query-evidence selected-functor-probe-query-evidence/Z]
      [step-refocus-work selected-functor-probe-Z-refocus-work])
     [(step-refocus-work
       (Query Input) TaskFocus Z_1)
      ---------------- "probe"
      (selected-functor-probe-Z-step
       (ZWork (Probe Input) TaskFocus)
       probe
       Z_1)]))
   #:diagnostic-parameters
   ([query-evidence selected-functor-probe-query-evidence/Z])
   #:diagnostics
   (Z-diagnostics
    #:D->Z selected-functor-probe-D->Z
    #:Z->D selected-functor-probe-Z->D
    #:readback selected-functor-probe-readback-Z
    #:refocus-spec selected-functor-probe-refocus/spec
    #:step-spec selected-functor-probe-Z-step/spec)
   #:diagnostic-forms
   ((provide selected-functor-probe-D->Z
             selected-functor-probe-Z->D
             selected-functor-probe-readback-Z
             selected-functor-probe-refocus/spec
             selected-functor-probe-Z-step/spec)

    (define-metafunction selected-functor-probe-Z-lang
      selected-functor-probe-D->Z : D -> Z
      [(selected-functor-probe-D->Z (Final T)) (ZFinal T)]
      [(selected-functor-probe-D->Z (DecWork WR SourceWorkFocus))
       (ZWork WR SourceWorkFocus)]
      [(selected-functor-probe-D->Z
        (DecFrontier FR SourceSpineContext))
       (ZFrontier FR SourceSpineContext)]
      [(selected-functor-probe-D->Z (DecAllocate AR SourceWorkFocus))
       (ZAllocate AR SourceWorkFocus)])

    (define-metafunction selected-functor-probe-Z-lang
      selected-functor-probe-Z->D : Z -> D
      [(selected-functor-probe-Z->D (ZFinal T)) (Final T)]
      [(selected-functor-probe-Z->D (ZWork WR SourceWorkFocus))
       (DecWork WR SourceWorkFocus)]
      [(selected-functor-probe-Z->D
        (ZFrontier FR SourceSpineContext))
       (DecFrontier FR SourceSpineContext)]
      [(selected-functor-probe-Z->D (ZAllocate AR SourceWorkFocus))
       (DecAllocate AR SourceWorkFocus)])

    (define-metafunction selected-functor-probe-Z-lang
      selected-functor-probe-readback-Z : Z -> SourceF
      [(selected-functor-probe-readback-Z (ZFinal T)) T]
      [(selected-functor-probe-readback-Z
        (ZWork WR SourceWorkFocus))
       (in-hole SourceWorkFocus WR)]
      [(selected-functor-probe-readback-Z
        (ZFrontier FR SourceSpineContext))
       (in-hole SourceSpineContext FR)]
      [(selected-functor-probe-readback-Z
        (ZAllocate AR SourceWorkFocus))
       (in-hole SourceWorkFocus AR)])

    (define-judgment-form selected-functor-probe-Z-lang
      #:contract (selected-functor-probe-refocus/spec C Z)
      #:mode (selected-functor-probe-refocus/spec I O)
      [(where SourceF_0 (selected-functor-probe-plug-C C))
       (selected-functor-probe-decompose SourceF_0 D_0)
       (where Z_0 (selected-functor-probe-D->Z D_0))
       ----
       (selected-functor-probe-refocus/spec C Z_0)])

    (define-judgment-form selected-functor-probe-Z-lang
      #:contract (selected-functor-probe-Z-step/spec Z RuleName Z)
      #:mode (selected-functor-probe-Z-step/spec I O O)
      [(where D_0 (selected-functor-probe-Z->D Z_0))
       (selected-functor-probe-contract D_0 C_0)
       (where RuleName
              (selected-functor-probe-contract-label C_0))
       (selected-functor-probe-refocus/spec C_0 Z_1)
       ----
       (selected-functor-probe-Z-step/spec Z_0 RuleName Z_1)]))]

  #:M
  [#:parameters
   ([query-evidence selected-functor-probe-query-evidence/M])
   #:artifacts
   (M-artifacts
    #:language selected-functor-probe-M-lang
    #:machineize selected-functor-probe-machineize
    #:refocus-work-direct selected-functor-probe-M-refocus-work
    #:refocus-direct selected-functor-probe-M-refocus
    #:step-direct selected-functor-probe-M-step)
   #:forms
   ((provide selected-functor-probe-M-lang
             selected-functor-probe-query-evidence/M
             selected-functor-probe-machineize
             selected-functor-probe-M-refocus-work
             selected-functor-probe-M-refocus
             selected-functor-probe-M-step)

    (define-extended-language selected-functor-probe-M-lang
      BASE-M-LANGUAGE
      [Task .... (Probe Input)]
      [RuleName .... probe]
      [WR .... (Probe Input)]
      [RunW .... (Probe Input)])

    (redex-parameter:define-extended-judgment-form*
     BASE-M-PARAMETER-query-evidence
     selected-functor-probe-M-lang
     #:mode (selected-functor-probe-query-evidence/M I O))

    (redex-parameter:define-extended-metafunction*
     BASE-MACHINEIZE
     selected-functor-probe-M-lang
     selected-functor-probe-machineize : Z -> M)

    (redex-parameter:define-extended-judgment-form*
     BASE-M-REFOCUS-WORK
     selected-functor-probe-M-lang
     #:mode (selected-functor-probe-M-refocus-work I I O))

    (redex-parameter:define-extended-judgment-form*
     BASE-M-REFOCUS
     selected-functor-probe-M-lang
     #:mode (selected-functor-probe-M-refocus I O)
     #:parameters
     ([refocus-work-dependency selected-functor-probe-M-refocus-work]))

    (redex-parameter:define-extended-judgment-form*
     BASE-M-STEP
     selected-functor-probe-M-lang
     #:mode (selected-functor-probe-M-step I O O)
     #:parameters
     ([query-evidence selected-functor-probe-query-evidence/M]
      [step-refocus-work selected-functor-probe-M-refocus-work])
     [(step-refocus-work
       (Query Input) TaskFocus M_1)
      ---------------- "probe"
      (selected-functor-probe-M-step
       (MWork (Probe Input) TaskFocus)
       probe
       M_1)]))
   #:diagnostic-parameters
   ([query-evidence selected-functor-probe-query-evidence/M])
   #:diagnostics
   (M-diagnostics
    #:encode-ZM selected-functor-probe-encode-ZM
    #:decode-MZ selected-functor-probe-decode-MZ
    #:D->M selected-functor-probe-D->M
    #:M->D selected-functor-probe-M->D
    #:readback selected-functor-probe-readback-M
    #:corresponds selected-functor-probe-ZM-corresponds
    #:step-spec selected-functor-probe-M-step/spec
    #:square selected-functor-probe-ZM-square)
   #:diagnostic-forms
   ((provide selected-functor-probe-encode-ZM
             selected-functor-probe-decode-MZ
             selected-functor-probe-D->M
             selected-functor-probe-M->D
             selected-functor-probe-readback-M
             selected-functor-probe-ZM-corresponds
             selected-functor-probe-M-step/spec
             selected-functor-probe-ZM-square)

    (define-metafunction selected-functor-probe-M-lang
      selected-functor-probe-encode-ZM : Z -> M
      [(selected-functor-probe-encode-ZM (ZFinal T)) (MFinal T)]
      [(selected-functor-probe-encode-ZM
        (ZWork WR SourceWorkFocus))
       (MWork WR SourceWorkFocus)]
      [(selected-functor-probe-encode-ZM
        (ZFrontier FR SourceSpineContext))
       (MFrontier FR SourceSpineContext)]
      [(selected-functor-probe-encode-ZM
        (ZAllocate AR SourceWorkFocus))
       (MAllocate AR SourceWorkFocus)])

    (define-metafunction selected-functor-probe-M-lang
      selected-functor-probe-decode-MZ : M -> Z
      [(selected-functor-probe-decode-MZ (MFinal T)) (ZFinal T)]
      [(selected-functor-probe-decode-MZ
        (MWork WR SourceWorkFocus))
       (ZWork WR SourceWorkFocus)]
      [(selected-functor-probe-decode-MZ
        (MFrontier FR SourceSpineContext))
       (ZFrontier FR SourceSpineContext)]
      [(selected-functor-probe-decode-MZ
        (MAllocate AR SourceWorkFocus))
       (ZAllocate AR SourceWorkFocus)])

    (define-metafunction selected-functor-probe-M-lang
      selected-functor-probe-D->M : D -> M
      [(selected-functor-probe-D->M (Final T)) (MFinal T)]
      [(selected-functor-probe-D->M
        (DecWork WR SourceWorkFocus))
       (MWork WR SourceWorkFocus)]
      [(selected-functor-probe-D->M
        (DecFrontier FR SourceSpineContext))
       (MFrontier FR SourceSpineContext)]
      [(selected-functor-probe-D->M
        (DecAllocate AR SourceWorkFocus))
       (MAllocate AR SourceWorkFocus)])

    (define-metafunction selected-functor-probe-M-lang
      selected-functor-probe-M->D : M -> D
      [(selected-functor-probe-M->D (MFinal T)) (Final T)]
      [(selected-functor-probe-M->D
        (MWork WR SourceWorkFocus))
       (DecWork WR SourceWorkFocus)]
      [(selected-functor-probe-M->D
        (MFrontier FR SourceSpineContext))
       (DecFrontier FR SourceSpineContext)]
      [(selected-functor-probe-M->D
        (MAllocate AR SourceWorkFocus))
       (DecAllocate AR SourceWorkFocus)])

    (define-metafunction selected-functor-probe-M-lang
      selected-functor-probe-readback-M : M -> SourceF
      [(selected-functor-probe-readback-M (MFinal T)) T]
      [(selected-functor-probe-readback-M
        (MWork WR SourceWorkFocus))
       (in-hole SourceWorkFocus WR)]
      [(selected-functor-probe-readback-M
        (MFrontier FR SourceSpineContext))
       (in-hole SourceSpineContext FR)]
      [(selected-functor-probe-readback-M
        (MAllocate AR SourceWorkFocus))
       (in-hole SourceWorkFocus AR)])

    (define-judgment-form selected-functor-probe-M-lang
      #:contract (selected-functor-probe-ZM-corresponds Z M)
      #:mode (selected-functor-probe-ZM-corresponds I O)
      [(where M_0 (selected-functor-probe-encode-ZM Z_0))
       ----
       (selected-functor-probe-ZM-corresponds Z_0 M_0)])

    (define-judgment-form selected-functor-probe-M-lang
      #:contract (selected-functor-probe-M-step/spec M RuleName M)
      #:mode (selected-functor-probe-M-step/spec I O O)
      [(where Z_0 (selected-functor-probe-decode-MZ M_0))
       (selected-functor-probe-Z-step Z_0 RuleName Z_1)
       (where M_1 (selected-functor-probe-encode-ZM Z_1))
       ----
       (selected-functor-probe-M-step/spec M_0 RuleName M_1)])

    (define-judgment-form selected-functor-probe-M-lang
      #:contract
      (selected-functor-probe-ZM-square Z RuleName Z M M)
      #:mode (selected-functor-probe-ZM-square I O O O O)
      [(where M_0 (selected-functor-probe-encode-ZM Z_0))
       (selected-functor-probe-Z-step Z_0 RuleName Z_1)
       (where M_1 (selected-functor-probe-encode-ZM Z_1))
       (selected-functor-probe-M-step M_0 RuleName M_1)
       ----
       (selected-functor-probe-ZM-square
        Z_0 RuleName Z_1 M_0 M_1)]))]

  #:B
  [#:parameters
   ([query-evidence selected-functor-probe-query-evidence/B])
   #:artifacts
   (B-artifacts
    #:language selected-functor-probe-B-lang
    #:compress selected-functor-probe-compress
    #:span-labels selected-functor-probe-span-labels
    #:produce-settled selected-functor-probe-produce-settled
    #:produce-dead selected-functor-probe-produce-dead
    #:advance-settled selected-functor-probe-advance-settled
    #:advance-dead selected-functor-probe-advance-dead
    #:base-singleton selected-functor-probe-singleton
    #:step-direct selected-functor-probe-B-step)
   #:forms
   ((provide selected-functor-probe-B-lang
             selected-functor-probe-query-evidence/B
             selected-functor-probe-compress
             selected-functor-probe-span-labels
             selected-functor-probe-produce-settled
             selected-functor-probe-produce-dead
             selected-functor-probe-advance-settled
             selected-functor-probe-advance-dead
             selected-functor-probe-singleton
             selected-functor-probe-B-step)

    (define-extended-language selected-functor-probe-B-lang
      BASE-B-LANGUAGE
      [Task .... (Probe Input)]
      [RuleName .... probe]
      [WR .... (Probe Input)]
      [RunW .... (Probe Input)]
      [NonAllocateRun .... (Probe Input)]
      [SingletonRuleName .... probe])

    (redex-parameter:define-extended-judgment-form*
     BASE-B-PARAMETER-query-evidence
     selected-functor-probe-B-lang
     #:mode (selected-functor-probe-query-evidence/B I O))

    (redex-parameter:define-extended-metafunction*
     BASE-COMPRESS
     selected-functor-probe-B-lang
     selected-functor-probe-compress : M -> B)

    (redex-parameter:define-extended-metafunction*
     BASE-SPAN-LABELS
     selected-functor-probe-B-lang
     selected-functor-probe-span-labels : TransitionSpan -> LabelTrace)

    (redex-parameter:define-extended-judgment-form*
     BASE-B-PRODUCE-SETTLED
     selected-functor-probe-B-lang
     #:mode (selected-functor-probe-produce-settled I I O O O)
     #:parameters
     ([query-evidence selected-functor-probe-query-evidence/B]))

    (redex-parameter:define-extended-judgment-form*
     BASE-B-PRODUCE-DEAD
     selected-functor-probe-B-lang
     #:mode (selected-functor-probe-produce-dead I I O O O)
     #:parameters
     ([query-evidence selected-functor-probe-query-evidence/B]))

    (redex-parameter:define-extended-judgment-form*
     BASE-B-ADVANCE-SETTLED
     selected-functor-probe-B-lang
     #:mode (selected-functor-probe-advance-settled I I O O)
     #:parameters
     ([query-evidence selected-functor-probe-query-evidence/B]))

    (redex-parameter:define-extended-judgment-form*
     BASE-B-ADVANCE-DEAD
     selected-functor-probe-B-lang
     #:mode (selected-functor-probe-advance-dead I I O O)
     #:parameters
     ([query-evidence selected-functor-probe-query-evidence/B]))

    (redex-parameter:define-extended-judgment-form*
     BASE-B-SINGLETON
     selected-functor-probe-B-lang
     #:mode (selected-functor-probe-singleton I O O)
     #:parameters
     ([query-evidence selected-functor-probe-query-evidence/B]
      [singleton-advance-settled
       selected-functor-probe-advance-settled]
      [singleton-advance-dead
       selected-functor-probe-advance-dead])
     [---------------- "probe"
      (selected-functor-probe-singleton
       (BRun (Probe Input) TaskFocus)
       (transition-span probe)
       (BRun (Query Input) TaskFocus))])

    (redex-parameter:define-extended-judgment-form*
     BASE-B-STEP
     selected-functor-probe-B-lang
     #:mode (selected-functor-probe-B-step I O O)
     #:parameters
     ([step-produce-settled selected-functor-probe-produce-settled]
      [step-produce-dead selected-functor-probe-produce-dead]
      [step-base-advance-settled
       selected-functor-probe-advance-settled]
      [step-base-advance-dead selected-functor-probe-advance-dead]
      [step-singleton selected-functor-probe-singleton])))
   #:diagnostic-parameters
   ([query-evidence selected-functor-probe-query-evidence/B])
   #:diagnostics
   (B-diagnostics
    #:encode-MB selected-functor-probe-encode-MB
    #:decode-BM selected-functor-probe-decode-BM
    #:readback selected-functor-probe-readback-B
    #:corresponds selected-functor-probe-MB-corresponds
    #:replay selected-functor-probe-replay/M
    #:step-spec selected-functor-probe-B-step/spec
    #:square selected-functor-probe-MB-square)
   #:diagnostic-forms
   ((provide selected-functor-probe-encode-MB
             selected-functor-probe-decode-BM
             selected-functor-probe-readback-B
             selected-functor-probe-MB-corresponds
             selected-functor-probe-replay/M
             selected-functor-probe-B-step/spec
             selected-functor-probe-MB-square)

    (define-metafunction selected-functor-probe-B-lang
      selected-functor-probe-encode-MB : M -> B
      [(selected-functor-probe-encode-MB (MFinal T)) (BFinal T)]
      [(selected-functor-probe-encode-MB
        (MAllocate AR SourceWorkFocus))
       (BRun AR SourceWorkFocus)]
      [(selected-functor-probe-encode-MB
        (MWork NonAllocateRun SourceWorkFocus))
       (BRun NonAllocateRun SourceWorkFocus)]
      [(selected-functor-probe-encode-MB
        (MWork (in-hole Frame Settled) SourceWorkFocus))
       (BSettled Settled (in-hole SourceWorkFocus Frame))]
      [(selected-functor-probe-encode-MB
        (MWork (in-hole Frame (Crashed N)) SourceWorkFocus))
       (BDead N (in-hole SourceWorkFocus Frame))]
      [(selected-functor-probe-encode-MB
        (MFrontier (Root Settled) hole))
       (BSettled Settled (Root hole))]
      [(selected-functor-probe-encode-MB
        (MFrontier (Root (Crashed N)) hole))
       (BDead N (Root hole))])

    (define-metafunction selected-functor-probe-B-lang
      selected-functor-probe-decode-BM : B -> M
      [(selected-functor-probe-decode-BM (BFinal T)) (MFinal T)]
      [(selected-functor-probe-decode-BM
        (BRun AR SourceWorkFocus))
       (MAllocate AR SourceWorkFocus)]
      [(selected-functor-probe-decode-BM
        (BRun NonAllocateRun SourceWorkFocus))
       (MWork NonAllocateRun SourceWorkFocus)]
      [(selected-functor-probe-decode-BM
        (BSettled Settled (in-hole SourceWorkFocus Frame)))
       (MWork (in-hole Frame Settled) SourceWorkFocus)]
      [(selected-functor-probe-decode-BM
        (BDead N (in-hole SourceWorkFocus Frame)))
       (MWork (in-hole Frame (Crashed N)) SourceWorkFocus)]
      [(selected-functor-probe-decode-BM
        (BSettled Settled (Root hole)))
       (MFrontier (Root Settled) hole)]
      [(selected-functor-probe-decode-BM
        (BDead N (Root hole)))
       (MFrontier (Root (Crashed N)) hole)])

    (define-metafunction selected-functor-probe-B-lang
      selected-functor-probe-readback-B : B -> SourceF
      [(selected-functor-probe-readback-B
        (BRun NonAllocateRun SourceWorkFocus))
       (in-hole SourceWorkFocus NonAllocateRun)]
      [(selected-functor-probe-readback-B
        (BRun AR SourceWorkFocus))
       (in-hole SourceWorkFocus AR)]
      [(selected-functor-probe-readback-B
        (BSettled Settled SourceWorkFocus))
       (in-hole SourceWorkFocus Settled)]
      [(selected-functor-probe-readback-B
        (BDead N SourceWorkFocus))
       (in-hole SourceWorkFocus (Crashed N))]
      [(selected-functor-probe-readback-B (BFinal T)) T])

    (define-judgment-form selected-functor-probe-B-lang
      #:contract (selected-functor-probe-MB-corresponds M B)
      #:mode (selected-functor-probe-MB-corresponds I O)
      [(where B_0 (selected-functor-probe-compress M_0))
       ----
       (selected-functor-probe-MB-corresponds M_0 B_0)])

    (define-judgment-form selected-functor-probe-B-lang
      #:contract (selected-functor-probe-replay/M M TransitionSpan M)
      #:mode (selected-functor-probe-replay/M I O O)
      [(selected-functor-probe-M-step M_0 SingletonRuleName M_1)
       ----
       (selected-functor-probe-replay/M
        M_0 (transition-span SingletonRuleName) M_1)]
      [(selected-functor-probe-M-step M_0 SettledProducerName M_1)
       (selected-functor-probe-M-step M_1 SettledFollowerName M_2)
       ----
       (selected-functor-probe-replay/M
        M_0
        (transition-span SettledProducerName SettledFollowerName)
        M_2)]
      [(selected-functor-probe-M-step M_0 DeadProducerName M_1)
       (selected-functor-probe-M-step M_1 DeadFollowerName M_2)
       ----
       (selected-functor-probe-replay/M
        M_0
        (transition-span DeadProducerName DeadFollowerName)
        M_2)])

    (define-judgment-form selected-functor-probe-B-lang
      #:contract
      (selected-functor-probe-B-step/spec B TransitionSpan B)
      #:mode (selected-functor-probe-B-step/spec I O O)
      [(where M_0 (selected-functor-probe-decode-BM B_0))
       (selected-functor-probe-replay/M M_0 TransitionSpan M_1)
       (where B_1 (selected-functor-probe-encode-MB M_1))
       ----
       (selected-functor-probe-B-step/spec B_0 TransitionSpan B_1)])

    (define-judgment-form selected-functor-probe-B-lang
      #:contract
      (selected-functor-probe-MB-square B TransitionSpan B M M)
      #:mode (selected-functor-probe-MB-square I O O O O)
      [(where M_0 (selected-functor-probe-decode-BM B_0))
       (selected-functor-probe-replay/M M_0 TransitionSpan M_1)
       (where B_1 (selected-functor-probe-encode-MB M_1))
       (selected-functor-probe-B-step B_0 TransitionSpan B_1)
       ----
       (selected-functor-probe-MB-square
        B_0 TransitionSpan B_1 M_0 M_1)]))]

  #:Big
  [#:parameters
   ([query-evidence selected-functor-probe-query-evidence/Big])
   #:artifacts
   (Big-artifacts
    #:language selected-functor-probe-Big-lang
    #:dispatch-one selected-functor-probe-big-dispatch-one
    #:dispatch selected-functor-probe-big-dispatch
    #:run selected-functor-probe-big-run
    #:settled selected-functor-probe-big-settled
    #:dead selected-functor-probe-big-dead
    #:final selected-functor-probe-big-final
    #:evaluate selected-functor-probe-big-evaluate)
   #:forms
   ((provide selected-functor-probe-Big-lang
             selected-functor-probe-query-evidence/Big
             selected-functor-probe-big-dispatch-one
             selected-functor-probe-big-dispatch
             selected-functor-probe-big-run
             selected-functor-probe-big-settled
             selected-functor-probe-big-dead
             selected-functor-probe-big-final
             selected-functor-probe-big-evaluate)

    (define-extended-language selected-functor-probe-Big-lang
      BASE-BIG-LANGUAGE
      [Task .... (Probe Input)]
      [RunW .... (Probe Input)])

    (redex-parameter:define-extended-judgment-form*
     BASE-BIG-PARAMETER-query-evidence
     selected-functor-probe-Big-lang
     #:mode (selected-functor-probe-query-evidence/Big I O))

    (redex-parameter:define-extended-judgment-form*
     BASE-BIG-DISPATCH-ONE
     selected-functor-probe-Big-lang
     #:mode (selected-functor-probe-big-dispatch-one I I O)
     #:parameters
     ([query-evidence selected-functor-probe-query-evidence/Big])
     [---------------- "probe"
      (selected-functor-probe-big-dispatch-one
       (Probe Input) TaskFocus
       (BigContinue (Query Input) TaskFocus))])

    (redex-parameter:define-extended-judgment-form*
     BASE-BIG-DISPATCH
     selected-functor-probe-Big-lang
     #:mode (selected-functor-probe-big-dispatch I I O)
     #:parameters
     ([dispatch-next selected-functor-probe-big-dispatch-one]))

    (redex-parameter:define-extended-judgment-form*
     BASE-BIG-RUN
     selected-functor-probe-Big-lang
     #:mode (selected-functor-probe-big-run I I O)
     #:parameters
     ([run-dispatch selected-functor-probe-big-dispatch]))

    (redex-parameter:define-extended-judgment-form*
     BASE-BIG-SETTLED
     selected-functor-probe-Big-lang
     #:mode (selected-functor-probe-big-settled I I O)
     #:parameters
     ([settled-dispatch selected-functor-probe-big-dispatch]))

    (redex-parameter:define-extended-judgment-form*
     BASE-BIG-DEAD
     selected-functor-probe-Big-lang
     #:mode (selected-functor-probe-big-dead I I O)
     #:parameters
     ([dead-dispatch selected-functor-probe-big-dispatch]))

    (redex-parameter:define-extended-judgment-form*
     BASE-BIG-FINAL
     selected-functor-probe-Big-lang
     #:mode (selected-functor-probe-big-final I O))

    (redex-parameter:define-extended-judgment-form*
     BASE-BIG-EVALUATE
     selected-functor-probe-Big-lang
     #:mode (selected-functor-probe-big-evaluate I O)
     #:parameters
     ([evaluate-dispatch selected-functor-probe-big-dispatch]
      [evaluate-final selected-functor-probe-big-final])))
   #:diagnostic-parameters
   ([query-evidence selected-functor-probe-query-evidence/Big-spec])
   #:diagnostics
   (Big-diagnostics
    #:readback selected-functor-probe-readback-Big
    #:spec-language selected-functor-probe-Big-spec-lang
    #:initialize selected-functor-probe-initialize-B
    #:close selected-functor-probe-close-B
    #:flatten selected-functor-probe-flatten-BTrace
    #:promote selected-functor-probe-promote
    #:evaluate-spec selected-functor-probe-big-evaluate/spec
    #:unfold-square selected-functor-probe-B-Big-unfold-square
    #:closure-square selected-functor-probe-B-Big-closure-square
    #:root-square selected-functor-probe-B-Big-root-square)
   #:diagnostic-forms
   ((provide selected-functor-probe-readback-Big
             selected-functor-probe-query-evidence/Big-spec
             selected-functor-probe-Big-spec-lang
             selected-functor-probe-initialize-B
             selected-functor-probe-close-B
             selected-functor-probe-flatten-BTrace
             selected-functor-probe-promote
             selected-functor-probe-big-evaluate/spec
             selected-functor-probe-B-Big-unfold-square
             selected-functor-probe-B-Big-closure-square
             selected-functor-probe-B-Big-root-square)

    (define-metafunction selected-functor-probe-Big-lang
      selected-functor-probe-readback-Big : Big -> SourceF
      [(selected-functor-probe-readback-Big (BigFinal T)) T])

    (define-extended-language selected-functor-probe-Big-spec-lang
      BASE-BIG-SPEC-LANGUAGE
      [Task .... (Probe Input)]
      [RuleName .... probe]
      [WR .... (Probe Input)]
      [RunW .... (Probe Input)]
      [NonAllocateRun .... (Probe Input)]
      [SingletonRuleName .... probe])

    (redex-parameter:define-extended-judgment-form*
     BASE-BIG-DIAGNOSTIC-PARAMETER-query-evidence
     selected-functor-probe-Big-spec-lang
     #:mode (selected-functor-probe-query-evidence/Big-spec I O))

    (define-judgment-form selected-functor-probe-Big-spec-lang
      #:contract (selected-functor-probe-initialize-B SourceF B)
      #:mode (selected-functor-probe-initialize-B I O)
      [(selected-functor-probe-decompose SourceF_0 D_0)
       (where Z_0 (selected-functor-probe-refocus-phase D_0))
       (where M_0 (selected-functor-probe-machineize Z_0))
       (where B_0 (selected-functor-probe-compress M_0))
       ----
       (selected-functor-probe-initialize-B SourceF_0 B_0)])

    (define-judgment-form selected-functor-probe-Big-spec-lang
      #:contract (selected-functor-probe-close-B B BTrace T)
      #:mode (selected-functor-probe-close-B I O O)
      [----
       (selected-functor-probe-close-B (BFinal T) () T)]
      [(selected-functor-probe-B-step B_0 TransitionSpan_0 B_1)
       (selected-functor-probe-close-B
        B_1 (TransitionSpan_rest ...) T_0)
       ----
       (selected-functor-probe-close-B
        B_0 (TransitionSpan_0 TransitionSpan_rest ...) T_0)])

    (define-metafunction selected-functor-probe-Big-spec-lang
      selected-functor-probe-flatten-BTrace : BTrace -> LabelTrace
      [(selected-functor-probe-flatten-BTrace ()) ()]
      [(selected-functor-probe-flatten-BTrace
        (TransitionSpan_0 TransitionSpan_rest ...))
       (RuleName_span ... RuleName_rest ...)
       (where (RuleName_span ...)
              (selected-functor-probe-span-labels TransitionSpan_0))
       (where (RuleName_rest ...)
              (selected-functor-probe-flatten-BTrace
               (TransitionSpan_rest ...)))])

    (define-judgment-form selected-functor-probe-Big-spec-lang
      #:contract (selected-functor-probe-promote B Big)
      #:mode (selected-functor-probe-promote I O)
      [(selected-functor-probe-big-run RunW SourceWorkFocus Big_0)
       ----
       (selected-functor-probe-promote
        (BRun RunW SourceWorkFocus) Big_0)]
      [(selected-functor-probe-big-settled
        Settled SourceWorkFocus Big_0)
       ----
       (selected-functor-probe-promote
        (BSettled Settled SourceWorkFocus) Big_0)]
      [(selected-functor-probe-big-dead
        FailureSummary SourceWorkFocus Big_0)
       ----
       (selected-functor-probe-promote
        (BDead FailureSummary SourceWorkFocus) Big_0)]
      [(selected-functor-probe-big-final T Big_0)
       ----
       (selected-functor-probe-promote (BFinal T) Big_0)])

    (define-judgment-form selected-functor-probe-Big-spec-lang
      #:contract
      (selected-functor-probe-big-evaluate/spec SourceF BTrace Big)
      #:mode (selected-functor-probe-big-evaluate/spec I O O)
      [(selected-functor-probe-initialize-B SourceF_0 B_0)
       (selected-functor-probe-close-B B_0 BTrace_0 T_0)
       ----
       (selected-functor-probe-big-evaluate/spec
        SourceF_0 BTrace_0 (BigFinal T_0))])

    (define-judgment-form selected-functor-probe-Big-spec-lang
      #:contract
      (selected-functor-probe-B-Big-unfold-square
       B TransitionSpan B Big)
      #:mode (selected-functor-probe-B-Big-unfold-square I O O O)
      [(selected-functor-probe-B-step B_0 TransitionSpan_0 B_1)
       (selected-functor-probe-promote B_0 Big_0)
       (selected-functor-probe-promote B_1 Big_0)
       ----
       (selected-functor-probe-B-Big-unfold-square
        B_0 TransitionSpan_0 B_1 Big_0)])

    (define-judgment-form selected-functor-probe-Big-spec-lang
      #:contract
      (selected-functor-probe-B-Big-closure-square B BTrace Big)
      #:mode (selected-functor-probe-B-Big-closure-square I O O)
      [(selected-functor-probe-close-B B_0 BTrace_0 T_0)
       (selected-functor-probe-promote B_0 (BigFinal T_0))
       ----
       (selected-functor-probe-B-Big-closure-square
        B_0 BTrace_0 (BigFinal T_0))])

    (define-judgment-form selected-functor-probe-Big-spec-lang
      #:contract
      (selected-functor-probe-B-Big-root-square SourceF BTrace Big)
      #:mode (selected-functor-probe-B-Big-root-square I O O)
      [(selected-functor-probe-big-evaluate/spec
        SourceF_0 BTrace_0 Big_0)
       (selected-functor-probe-big-evaluate SourceF_0 Big_0)
       ----
       (selected-functor-probe-B-Big-root-square
        SourceF_0 BTrace_0 Big_0)]))])
