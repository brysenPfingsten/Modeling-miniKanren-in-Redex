#lang racket

(require redex/reduction-semantics)

(provide define-pk-decomposition-spec
         define-pk-decomposition-direct)

;; The compositional presentation is written independently of the direct
;; presentation below.  In particular, no clause table generates both sides
;; of the D arrow.
(define-syntax-rule
  (define-pk-decomposition-spec
    language-id
    kernel-step-id
    kernel-open-fresh-id
    whole-marker-support-id
    control-resume-id
    control-freeze-id
    wf-frontier-id
    plug-D-id
    plug-C-id
    contract-label-id
    choice-success-id
    choice-alternate-id
    decompose-id
    contract-id
    decompose-one-id
    next-decomposition-id
    decomposed-step/spec-id
    decomposed-steps/spec-id
    decomposition-image-id
    reachable-decomposition/via-id)
  (begin
    (define-metafunction language-id
      plug-D-id : D -> F
      [(plug-D-id (DecWork W WF))
       (in-hole WF W)]
      [(plug-D-id (DecFrontier T FF))
       (in-hole FF T)])

    (define-metafunction language-id
      plug-C-id : C -> F
      [(plug-C-id (ContractWork ell W WF))
       (in-hole WF W)]
      [(plug-C-id (ContractFrontier ell F FF))
       (in-hole FF F)])

    (define-metafunction language-id
      contract-label-id : C -> ell
      [(contract-label-id (ContractWork ell W WF)) ell]
      [(contract-label-id (ContractFrontier ell F FF)) ell])

    (define-metafunction language-id
      choice-success-id : SC -> S
      [(choice-success-id (DisjL S W)) S]
      [(choice-success-id (DisjR W S)) S])

    (define-metafunction language-id
      choice-alternate-id : SC -> W
      [(choice-alternate-id (DisjL S W)) W]
      [(choice-alternate-id (DisjR W S)) W])

    (define-judgment-form
      language-id
      #:contract (decompose-id F D)
      #:mode (decompose-id I O)

      [---------------------------------------------------- "decompose More boundary"
       (decompose-id
        (in-hole BF BR)
        (DecWork BR BF))]

      [---------------------------------------------------- "decompose local WorkFresh"
       (decompose-id
        (in-hole LF LFR)
        (DecWork LFR LF))]

      [---------------------------------------------------- "decompose local work"
       (decompose-id
        (in-hole WF LR)
        (DecWork LR WF))]

      [---------------------------------------------------- "decompose terminal frontier"
       (decompose-id
        (in-hole FF T)
        (DecFrontier T FF))])

    (define-judgment-form
      language-id
      #:contract (contract-id D C)
      #:mode (contract-id I O)

      [---------------------------------------------------- "contract expose frontier fresh"
       (contract-id
        (DecWork (WorkFresh intro W tag)
                 (in-hole FF (More hole)))
        (ContractFrontier
         (expose-frontier-fresh core)
         (FrontierFresh intro (More W) tag)
         FF))]

      [---------------------------------------------------- "contract finish success"
       (contract-id
        (DecWork (Returned kst)
                 (in-hole FF (More hole)))
        (ContractFrontier
         (finish-success core)
         (Last (Answer kst))
         FF))]

      [---------------------------------------------------- "contract finish failure"
       (contract-id
        (DecWork Dead (in-hole FF (More hole)))
        (ContractFrontier (finish-failure core) Done FF))]

      [---------------------------------------------------- "contract force delay"
       (contract-id
        (DecWork (PendingDelay W)
                 (in-hole FF (More hole)))
        (ContractFrontier
         (force-delay delay)
         (Forced (More W))
         FF))]

      [---------------------------------------------------- "contract commit left answer"
       (contract-id
        (DecWork (DisjL S W)
                 (in-hole FF (More hole)))
        (ContractFrontier
         (commit-choice-answer disj)
         (Emit (control-freeze-id S) (More W))
         FF))]

      [---------------------------------------------------- "contract commit right answer"
       (contract-id
        (DecWork (DisjR W S)
                 (in-hole FF (More hole)))
        (ContractFrontier
         (commit-right-choice-answer search-join)
         (Emit (control-freeze-id S) (More W))
         FF))]

      [(kernel-step-id katom
                       kst
                       (KernelSuccess kst_new)
                       kell)
       ---------------------------------------------------- "contract kernel success"
       (contract-id
        (DecWork (Work katom kst) WF)
        (ContractWork kell (Returned kst_new) WF))]

      [(kernel-step-id katom kst KernelFailure kell)
       ---------------------------------------------------- "contract kernel failure"
       (contract-id
        (DecWork (Work katom kst) WF)
        (ContractWork kell Dead WF))]

      [(where F_whole
              (in-hole WF
                       (Work (fresh (x (... ...)) g tag_fresh)
                             kst)))
       (where intro_used
              (whole-marker-support-id F_whole))
       (where (OpenedFresh intro_new g_new)
              (kernel-open-fresh-id
               (x (... ...))
               g
               intro_used))
       ---------------------------------------------------- "contract allocate fresh"
       (contract-id
        (DecWork
         (Work (fresh (x (... ...)) g tag_fresh) kst)
         WF)
        (ContractWork
         (allocate-fresh core)
         (WorkFresh intro_new
                    (Work g_new kst)
                    tag_fresh)
         WF))]

      [---------------------------------------------------- "contract expand conjunction"
       (contract-id
        (DecWork (Work (conj g_1 g_2 tag) kst) WF)
        (ContractWork
         (expand-conjunction core)
         (Conj (Work g_1 kst) g_2)
         WF))]

      [---------------------------------------------------- "contract expand disjunction"
       (contract-id
        (DecWork (Work (disj g_1 g_2 tag) kst) WF)
        (ContractWork
         (expand-disjunction disj)
         (DisjL (Work g_1 kst) (Work g_2 kst))
         WF))]

      [---------------------------------------------------- "contract suspend goal"
       (contract-id
        (DecWork (Work (suspend g tag) kst) WF)
        (ContractWork
         (suspend-goal delay)
         (PendingDelay (Work g kst))
         WF))]

      [---------------------------------------------------- "contract expose left choice through fresh"
       (contract-id
        (DecWork (WorkFresh intro (DisjL S W) tag) LF)
        (ContractWork
         (expose-choice-through-work-fresh disj)
         (DisjL (WorkFresh intro S tag)
                (WorkFresh intro W tag))
         LF))]

      [---------------------------------------------------- "contract expose right choice through fresh"
       (contract-id
        (DecWork (WorkFresh intro (DisjR W S) tag) LF)
        (ContractWork
         (expose-choice-through-work-fresh search-join)
         (DisjR (WorkFresh intro W tag)
                (WorkFresh intro S tag))
         LF))]

      [---------------------------------------------------- "contract erase dead fresh"
       (contract-id
        (DecWork (WorkFresh intro Dead tag) LF)
        (ContractWork (erase-dead-fresh core) Dead LF))]

      [---------------------------------------------------- "contract bubble delay through fresh"
       (contract-id
        (DecWork (WorkFresh intro (PendingDelay W) tag) LF)
        (ContractWork
         (bubble-delay-through-fresh delay)
         (PendingDelay (WorkFresh intro W tag))
         LF))]

      [---------------------------------------------------- "contract conjunction return"
       (contract-id
        (DecWork (Conj S g) WF)
        (ContractWork
         (conj-return core)
         (control-resume-id S g)
         WF))]

      [---------------------------------------------------- "contract conjunction failure"
       (contract-id
        (DecWork (Conj Dead g) WF)
        (ContractWork (conj-fail core) Dead WF))]

      [---------------------------------------------------- "contract bubble delay through conjunction"
       (contract-id
        (DecWork (Conj (PendingDelay W) g) WF)
        (ContractWork
         (bubble-delay-through-conj delay)
         (PendingDelay (Conj W g))
         WF))]

      [---------------------------------------------------- "contract late distribute left"
       (contract-id
        (DecWork (Conj (DisjL S W) g) WF)
        (ContractWork
         (late-distribute-settled disj)
         (DisjL (control-resume-id S g) (Conj W g))
         WF))]

      [---------------------------------------------------- "contract late distribute right"
       (contract-id
        (DecWork (Conj (DisjR W S) g) WF)
        (ContractWork
         (late-distribute-right-settled search-join)
         (DisjR (Conj W g) (control-resume-id S g))
         WF))]

      [---------------------------------------------------- "contract skip left failure"
       (contract-id
        (DecWork (DisjL Dead W) WF)
        (ContractWork (skip-left-failure disj) W WF))]

      [---------------------------------------------------- "contract enter right rail"
       (contract-id
        (DecWork (DisjL (PendingDelay W_1) W_2) WF)
        (ContractWork
         (rail-enter-right search-join)
         (PendingDelay (DisjR W_1 W_2))
         WF))]

      [---------------------------------------------------- "contract reassociate left"
       (contract-id
        (DecWork (DisjL SC W_2) WF)
        (ContractWork
         (reassociate-left-result disj)
         (DisjL (choice-success-id SC)
                (DisjL (choice-alternate-id SC) W_2))
         WF))]

      [---------------------------------------------------- "contract skip right failure"
       (contract-id
        (DecWork (DisjR W Dead) WF)
        (ContractWork (skip-right-failure search-join) W WF))]

      [---------------------------------------------------- "contract return to left rail"
       (contract-id
        (DecWork (DisjR W_1 (PendingDelay W_2)) WF)
        (ContractWork
         (rail-return-left search-join)
         (PendingDelay (DisjL W_1 W_2))
         WF))]

      [---------------------------------------------------- "contract reassociate right"
       (contract-id
        (DecWork (DisjR W_1 SC) WF)
        (ContractWork
         (reassociate-right-result search-join)
         (DisjR (DisjR W_1 (choice-alternate-id SC))
                (choice-success-id SC))
         WF))])

    (define-metafunction language-id
      decompose-one-id : F -> D
      [(decompose-one-id F) D
       (judgment-holds (decompose-id F D))])

    (define-metafunction language-id
      next-decomposition-id : C -> D
      [(next-decomposition-id C) D
       (where F (plug-C-id C))
       (judgment-holds (decompose-id F D))])

    (define-judgment-form
      language-id
      #:contract (decomposed-step/spec-id D ell D)
      #:mode (decomposed-step/spec-id I O O)
      [(contract-id D_1 C)
       (where ell (contract-label-id C))
       (where F (plug-C-id C))
       (decompose-id F D_2)
       ---------------------------------------------------- "decomposed step specification"
       (decomposed-step/spec-id D_1 ell D_2)])

    (define-judgment-form
      language-id
      #:contract (decomposed-steps/spec-id D Labels D)
      #:mode (decomposed-steps/spec-id I O O)
      [---------------------------------------------------- "zero decomposed steps"
       (decomposed-steps/spec-id D () D)]
      [(decomposed-step/spec-id D_0 ell D_1)
       (decomposed-steps/spec-id
        D_1
        (ell_rest (... ...))
        D_2)
       ---------------------------------------------------- "one or more decomposed steps"
       (decomposed-steps/spec-id
        D_0
        (ell ell_rest (... ...))
        D_2)])

    (define-judgment-form
      language-id
      #:contract (decomposition-image-id F D)
      #:mode (decomposition-image-id I O)
      [(wf-frontier-id F)
       (decompose-id F D)
       ---------------------------------------------------- "decomposition image"
       (decomposition-image-id F D)])

    (define-judgment-form
      language-id
      #:contract (reachable-decomposition/via-id F Labels D)
      #:mode (reachable-decomposition/via-id I O O)
      [(wf-frontier-id F)
       (decompose-id F D_0)
       (decomposed-steps/spec-id D_0 Labels D)
       ---------------------------------------------------- "reachable decomposition with trace"
       (reachable-decomposition/via-id F Labels D)])))

;; The direct presentation repeats every transformed contractum.  It invokes
;; only root re-decomposition, never the contract judgment above.
(define-syntax-rule
  (define-pk-decomposition-direct
    language-id
    kernel-step-id
    kernel-open-fresh-id
    whole-marker-support-id
    control-resume-id
    control-freeze-id
    label->redex-name-id
    plug-D-id
    next-decomposition-id
    choice-success-id
    choice-alternate-id
    decomposed-step/direct-id
    decomposed-red/direct-id)
  (begin
    (define-judgment-form
      language-id
      #:contract (decomposed-step/direct-id D ell D)
      #:mode (decomposed-step/direct-id I O O)

      [---------------------------------------------------- "direct expose frontier fresh"
       (decomposed-step/direct-id
        (DecWork (WorkFresh intro W tag)
                 (in-hole FF (More hole)))
        (expose-frontier-fresh core)
        (next-decomposition-id
         (ContractFrontier
          (expose-frontier-fresh core)
          (FrontierFresh intro (More W) tag)
          FF)))]

      [---------------------------------------------------- "direct finish success"
       (decomposed-step/direct-id
        (DecWork (Returned kst)
                 (in-hole FF (More hole)))
        (finish-success core)
        (next-decomposition-id
         (ContractFrontier
          (finish-success core)
          (Last (Answer kst))
          FF)))]

      [---------------------------------------------------- "direct finish failure"
       (decomposed-step/direct-id
        (DecWork Dead (in-hole FF (More hole)))
        (finish-failure core)
        (next-decomposition-id
         (ContractFrontier (finish-failure core) Done FF)))]

      [---------------------------------------------------- "direct force delay"
       (decomposed-step/direct-id
        (DecWork (PendingDelay W)
                 (in-hole FF (More hole)))
        (force-delay delay)
        (next-decomposition-id
         (ContractFrontier
          (force-delay delay)
          (Forced (More W))
          FF)))]

      [---------------------------------------------------- "direct commit left answer"
       (decomposed-step/direct-id
        (DecWork (DisjL S W)
                 (in-hole FF (More hole)))
        (commit-choice-answer disj)
        (next-decomposition-id
         (ContractFrontier
          (commit-choice-answer disj)
          (Emit (control-freeze-id S) (More W))
          FF)))]

      [---------------------------------------------------- "direct commit right answer"
       (decomposed-step/direct-id
        (DecWork (DisjR W S)
                 (in-hole FF (More hole)))
        (commit-right-choice-answer search-join)
        (next-decomposition-id
         (ContractFrontier
          (commit-right-choice-answer search-join)
          (Emit (control-freeze-id S) (More W))
          FF)))]

      [(kernel-step-id katom
                       kst
                       (KernelSuccess kst_new)
                       kell)
       ---------------------------------------------------- "direct kernel success"
       (decomposed-step/direct-id
        (DecWork (Work katom kst) WF)
        kell
        (next-decomposition-id
         (ContractWork kell (Returned kst_new) WF)))]

      [(kernel-step-id katom kst KernelFailure kell)
       ---------------------------------------------------- "direct kernel failure"
       (decomposed-step/direct-id
        (DecWork (Work katom kst) WF)
        kell
        (next-decomposition-id
         (ContractWork kell Dead WF)))]

      [(where F_whole
              (in-hole WF
                       (Work (fresh (x (... ...)) g tag_fresh)
                             kst)))
       (where intro_used
              (whole-marker-support-id F_whole))
       (where (OpenedFresh intro_new g_new)
              (kernel-open-fresh-id
               (x (... ...))
               g
               intro_used))
       ---------------------------------------------------- "direct allocate fresh"
       (decomposed-step/direct-id
        (DecWork
         (Work (fresh (x (... ...)) g tag_fresh) kst)
         WF)
        (allocate-fresh core)
        (next-decomposition-id
         (ContractWork
          (allocate-fresh core)
          (WorkFresh intro_new
                     (Work g_new kst)
                     tag_fresh)
          WF)))]

      [---------------------------------------------------- "direct expand conjunction"
       (decomposed-step/direct-id
        (DecWork (Work (conj g_1 g_2 tag) kst) WF)
        (expand-conjunction core)
        (next-decomposition-id
         (ContractWork
          (expand-conjunction core)
          (Conj (Work g_1 kst) g_2)
          WF)))]

      [---------------------------------------------------- "direct expand disjunction"
       (decomposed-step/direct-id
        (DecWork (Work (disj g_1 g_2 tag) kst) WF)
        (expand-disjunction disj)
        (next-decomposition-id
         (ContractWork
          (expand-disjunction disj)
          (DisjL (Work g_1 kst) (Work g_2 kst))
          WF)))]

      [---------------------------------------------------- "direct suspend goal"
       (decomposed-step/direct-id
        (DecWork (Work (suspend g tag) kst) WF)
        (suspend-goal delay)
        (next-decomposition-id
         (ContractWork
          (suspend-goal delay)
          (PendingDelay (Work g kst))
          WF)))]

      [---------------------------------------------------- "direct expose left choice through fresh"
       (decomposed-step/direct-id
        (DecWork (WorkFresh intro (DisjL S W) tag) LF)
        (expose-choice-through-work-fresh disj)
        (next-decomposition-id
         (ContractWork
          (expose-choice-through-work-fresh disj)
          (DisjL (WorkFresh intro S tag)
                 (WorkFresh intro W tag))
          LF)))]

      [---------------------------------------------------- "direct expose right choice through fresh"
       (decomposed-step/direct-id
        (DecWork (WorkFresh intro (DisjR W S) tag) LF)
        (expose-choice-through-work-fresh search-join)
        (next-decomposition-id
         (ContractWork
          (expose-choice-through-work-fresh search-join)
          (DisjR (WorkFresh intro W tag)
                 (WorkFresh intro S tag))
          LF)))]

      [---------------------------------------------------- "direct erase dead fresh"
       (decomposed-step/direct-id
        (DecWork (WorkFresh intro Dead tag) LF)
        (erase-dead-fresh core)
        (next-decomposition-id
         (ContractWork (erase-dead-fresh core) Dead LF)))]

      [---------------------------------------------------- "direct bubble delay through fresh"
       (decomposed-step/direct-id
        (DecWork (WorkFresh intro (PendingDelay W) tag) LF)
        (bubble-delay-through-fresh delay)
        (next-decomposition-id
         (ContractWork
          (bubble-delay-through-fresh delay)
          (PendingDelay (WorkFresh intro W tag))
          LF)))]

      [---------------------------------------------------- "direct conjunction return"
       (decomposed-step/direct-id
        (DecWork (Conj S g) WF)
        (conj-return core)
        (next-decomposition-id
         (ContractWork
          (conj-return core)
          (control-resume-id S g)
          WF)))]

      [---------------------------------------------------- "direct conjunction failure"
       (decomposed-step/direct-id
        (DecWork (Conj Dead g) WF)
        (conj-fail core)
        (next-decomposition-id
         (ContractWork (conj-fail core) Dead WF)))]

      [---------------------------------------------------- "direct bubble delay through conjunction"
       (decomposed-step/direct-id
        (DecWork (Conj (PendingDelay W) g) WF)
        (bubble-delay-through-conj delay)
        (next-decomposition-id
         (ContractWork
          (bubble-delay-through-conj delay)
          (PendingDelay (Conj W g))
          WF)))]

      [---------------------------------------------------- "direct late distribute left"
       (decomposed-step/direct-id
        (DecWork (Conj (DisjL S W) g) WF)
        (late-distribute-settled disj)
        (next-decomposition-id
         (ContractWork
          (late-distribute-settled disj)
          (DisjL (control-resume-id S g) (Conj W g))
          WF)))]

      [---------------------------------------------------- "direct late distribute right"
       (decomposed-step/direct-id
        (DecWork (Conj (DisjR W S) g) WF)
        (late-distribute-right-settled search-join)
        (next-decomposition-id
         (ContractWork
          (late-distribute-right-settled search-join)
          (DisjR (Conj W g) (control-resume-id S g))
          WF)))]

      [---------------------------------------------------- "direct skip left failure"
       (decomposed-step/direct-id
        (DecWork (DisjL Dead W) WF)
        (skip-left-failure disj)
        (next-decomposition-id
         (ContractWork (skip-left-failure disj) W WF)))]

      [---------------------------------------------------- "direct enter right rail"
       (decomposed-step/direct-id
        (DecWork (DisjL (PendingDelay W_1) W_2) WF)
        (rail-enter-right search-join)
        (next-decomposition-id
         (ContractWork
          (rail-enter-right search-join)
          (PendingDelay (DisjR W_1 W_2))
          WF)))]

      [---------------------------------------------------- "direct reassociate left"
       (decomposed-step/direct-id
        (DecWork (DisjL SC W_2) WF)
        (reassociate-left-result disj)
        (next-decomposition-id
         (ContractWork
          (reassociate-left-result disj)
          (DisjL (choice-success-id SC)
                 (DisjL (choice-alternate-id SC) W_2))
          WF)))]

      [---------------------------------------------------- "direct skip right failure"
       (decomposed-step/direct-id
        (DecWork (DisjR W Dead) WF)
        (skip-right-failure search-join)
        (next-decomposition-id
         (ContractWork (skip-right-failure search-join) W WF)))]

      [---------------------------------------------------- "direct return to left rail"
       (decomposed-step/direct-id
        (DecWork (DisjR W_1 (PendingDelay W_2)) WF)
        (rail-return-left search-join)
        (next-decomposition-id
         (ContractWork
          (rail-return-left search-join)
          (PendingDelay (DisjL W_1 W_2))
          WF)))]

      [---------------------------------------------------- "direct reassociate right"
       (decomposed-step/direct-id
        (DecWork (DisjR W_1 SC) WF)
        (reassociate-right-result search-join)
        (next-decomposition-id
         (ContractWork
          (reassociate-right-result search-join)
          (DisjR (DisjR W_1 (choice-alternate-id SC))
                 (choice-success-id SC))
          WF)))])

    (define decomposed-red/direct-id
      (reduction-relation
       language-id
       #:domain D
       [--> D_1 D_2
            (judgment-holds
             (decomposed-step/direct-id D_1 ell D_2))
            (computed-name
             (term (label->redex-name-id ell)))]))))
