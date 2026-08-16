#lang racket

(require redex/reduction-semantics)

(provide define-pk-source)

;; One handwritten source schema is instantiated against each precise kernel
;; language.  Kernel judgment premises decide only an atomic leaf's result and
;; exact tagged label; every control choice remains visible in Redex.
(define-syntax-rule
  (define-pk-source
    language-id
    kernel-step-id
    kernel-initial-state-id
    kernel-open-fresh-id
    whole-marker-support-id
    control-resume-id
    control-freeze-id
    label->redex-name-id
    initial-tree-id
    settled-choice-success-id
    settled-choice-alternate-id
    source-step-id
    source-red-id)
  (begin
    (define-metafunction language-id
      initial-tree-id : g -> F
      [(initial-tree-id g)
       (More (Work g (kernel-initial-state-id)))])

    (define-metafunction language-id
      settled-choice-success-id : SC -> S
      [(settled-choice-success-id (DisjL S W)) S]
      [(settled-choice-success-id (DisjR W S)) S])

    (define-metafunction language-id
      settled-choice-alternate-id : SC -> W
      [(settled-choice-alternate-id (DisjL S W)) W]
      [(settled-choice-alternate-id (DisjR W S)) W])

    (define-judgment-form
      language-id
      #:contract (source-step-id F ell F)
      #:mode (source-step-id I O O)

      [---------------------------------------------------- "expose frontier fresh"
       (source-step-id
        (in-hole FF (More (WorkFresh intro W tag)))
        (expose-frontier-fresh core)
        (in-hole FF (FrontierFresh intro (More W) tag)))]

      [---------------------------------------------------- "finish success"
       (source-step-id
        (in-hole FF (More (Returned kst)))
        (finish-success core)
        (in-hole FF (Last (Answer kst))))]

      [---------------------------------------------------- "finish failure"
       (source-step-id
        (in-hole FF (More Dead))
        (finish-failure core)
        (in-hole FF Done))]

      [---------------------------------------------------- "force delay"
       (source-step-id
        (in-hole FF (More (PendingDelay W)))
        (force-delay delay)
        (in-hole FF (Forced (More W))))]

      [---------------------------------------------------- "commit left answer"
       (source-step-id
        (in-hole FF (More (DisjL S W)))
        (commit-choice-answer disj)
        (in-hole FF (Emit (control-freeze-id S) (More W))))]

      [---------------------------------------------------- "commit right answer"
       (source-step-id
        (in-hole FF (More (DisjR W S)))
        (commit-right-choice-answer search-join)
        (in-hole FF (Emit (control-freeze-id S) (More W))))]

      [(kernel-step-id katom
                       kst
                       (KernelSuccess kst_new)
                       kell)
       ---------------------------------------------------- "kernel atomic success"
       (source-step-id
        (in-hole WF (Work katom kst))
        kell
        (in-hole WF (Returned kst_new)))]

      [(kernel-step-id katom kst KernelFailure kell)
       ---------------------------------------------------- "kernel atomic failure"
       (source-step-id
        (in-hole WF (Work katom kst))
        kell
        (in-hole WF Dead))]

      [(where intro_used
              (whole-marker-support-id F_whole))
       (where (OpenedFresh intro_new g_new)
              (kernel-open-fresh-id
               (x (... ...))
               g
               intro_used))
       ---------------------------------------------------- "allocate fresh"
       (source-step-id
        (name F_whole
              (in-hole WF
                       (Work (fresh (x (... ...)) g tag_fresh)
                             kst)))
        (allocate-fresh core)
        (in-hole WF
                 (WorkFresh intro_new
                            (Work g_new kst)
                            tag_fresh)))]

      [---------------------------------------------------- "expand conjunction"
       (source-step-id
        (in-hole WF (Work (conj g_1 g_2 tag) kst))
        (expand-conjunction core)
        (in-hole WF (Conj (Work g_1 kst) g_2)))]

      [---------------------------------------------------- "expand disjunction"
       (source-step-id
        (in-hole WF (Work (disj g_1 g_2 tag) kst))
        (expand-disjunction disj)
        (in-hole WF (DisjL (Work g_1 kst) (Work g_2 kst))))]

      [---------------------------------------------------- "suspend goal"
       (source-step-id
        (in-hole WF (Work (suspend g tag) kst))
        (suspend-goal delay)
        (in-hole WF (PendingDelay (Work g kst))))]

      [---------------------------------------------------- "expose left choice through fresh"
       (source-step-id
        (in-hole LF (WorkFresh intro (DisjL S W) tag))
        (expose-choice-through-work-fresh disj)
        (in-hole LF
                 (DisjL (WorkFresh intro S tag)
                        (WorkFresh intro W tag))))]

      [---------------------------------------------------- "expose right choice through fresh"
       (source-step-id
        (in-hole LF (WorkFresh intro (DisjR W S) tag))
        (expose-choice-through-work-fresh search-join)
        (in-hole LF
                 (DisjR (WorkFresh intro W tag)
                        (WorkFresh intro S tag))))]

      [---------------------------------------------------- "erase dead fresh"
       (source-step-id
        (in-hole LF (WorkFresh intro Dead tag))
        (erase-dead-fresh core)
        (in-hole LF Dead))]

      [---------------------------------------------------- "bubble delay through fresh"
       (source-step-id
        (in-hole LF
                 (WorkFresh intro (PendingDelay W) tag))
        (bubble-delay-through-fresh delay)
        (in-hole LF
                 (PendingDelay (WorkFresh intro W tag))))]

      [---------------------------------------------------- "conjunction return"
       (source-step-id
        (in-hole WF (Conj S g))
        (conj-return core)
        (in-hole WF (control-resume-id S g)))]

      [---------------------------------------------------- "conjunction failure"
       (source-step-id
        (in-hole WF (Conj Dead g))
        (conj-fail core)
        (in-hole WF Dead))]

      [---------------------------------------------------- "bubble delay through conjunction"
       (source-step-id
        (in-hole WF (Conj (PendingDelay W) g))
        (bubble-delay-through-conj delay)
        (in-hole WF (PendingDelay (Conj W g))))]

      [---------------------------------------------------- "late distribute left"
       (source-step-id
        (in-hole WF (Conj (DisjL S W) g))
        (late-distribute-settled disj)
        (in-hole WF
                 (DisjL (control-resume-id S g)
                        (Conj W g))))]

      [---------------------------------------------------- "late distribute right"
       (source-step-id
        (in-hole WF (Conj (DisjR W S) g))
        (late-distribute-right-settled search-join)
        (in-hole WF
                 (DisjR (Conj W g)
                        (control-resume-id S g))))]

      [---------------------------------------------------- "skip left failure"
       (source-step-id
        (in-hole WF (DisjL Dead W))
        (skip-left-failure disj)
        (in-hole WF W))]

      [---------------------------------------------------- "enter right rail"
       (source-step-id
        (in-hole WF (DisjL (PendingDelay W_1) W_2))
        (rail-enter-right search-join)
        (in-hole WF (PendingDelay (DisjR W_1 W_2))))]

      [---------------------------------------------------- "reassociate left result"
       (source-step-id
        (in-hole WF (DisjL SC W_2))
        (reassociate-left-result disj)
        (in-hole WF
                 (DisjL (settled-choice-success-id SC)
                        (DisjL (settled-choice-alternate-id SC)
                               W_2))))]

      [---------------------------------------------------- "skip right failure"
       (source-step-id
        (in-hole WF (DisjR W Dead))
        (skip-right-failure search-join)
        (in-hole WF W))]

      [---------------------------------------------------- "return to left rail"
       (source-step-id
        (in-hole WF (DisjR W_1 (PendingDelay W_2)))
        (rail-return-left search-join)
        (in-hole WF (PendingDelay (DisjL W_1 W_2))))]

      [---------------------------------------------------- "reassociate right result"
       (source-step-id
        (in-hole WF (DisjR W_1 SC))
        (reassociate-right-result search-join)
        (in-hole WF
                 (DisjR
                  (DisjR W_1
                         (settled-choice-alternate-id SC))
                  (settled-choice-success-id SC))))])

    ;; This relation is a direct executable presentation of the judgment.  A
    ;; computed name preserves the exact kernel label rather than collapsing
    ;; all atomic transitions under one administrative rule name.
    (define source-red-id
      (reduction-relation
       language-id
       #:domain F
       [--> F_1 F_2
            (judgment-holds (source-step-id F_1 ell F_2))
            (computed-name
             (term (label->redex-name-id ell)))]))))
