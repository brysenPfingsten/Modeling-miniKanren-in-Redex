#lang racket

(require redex/reduction-semantics)

(provide define-pk-observations)

(define-syntax-rule
  (define-pk-observations
    language-id
    frontier-split-id
    restore-frontier-id
    frontier-prefix-events-id
    answer-payloads-id
    answer-states-id
    scoped-answers-id
    forced-events-id
    residual-id
    trace-labels-id
    rule-cost-id
    force-count-id
    whole-marker-support-id
    kernel-open-fresh-id
    allocation-edge-id
    allocation-events-id
    observation-prefix-id
    frontier-delta-id)
  (begin
    ;; F has a unique maximal FF prefix and one non-wrapper tail.  This is the
    ;; grammatical completed-prefix view; no ordered host traversal chooses
    ;; the split.
    (define-judgment-form
      language-id
      #:contract (frontier-split-id F FF FTail)
      #:mode (frontier-split-id I O O)
      [---------------------------------------------------- "frontier factorization"
       (frontier-split-id (in-hole FF FTail) FF FTail)])

    (define-metafunction language-id
      restore-frontier-id : FF FTail -> F
      [(restore-frontier-id FF FTail)
       (in-hole FF FTail)])

    ;; Events are listed outermost-to-innermost, which is also creation order:
    ;; source rules add new frontier evidence only at the existing prefix tail.
    (define-metafunction language-id
      frontier-prefix-events-id : F -> (FrontierEvent (... ...))
      [(frontier-prefix-events-id (More W)) ()]
      [(frontier-prefix-events-id Done) ()]
      [(frontier-prefix-events-id (Last A)) ()]
      [(frontier-prefix-events-id (FrontierFresh intro F tag))
       ((FrontierFreshEvent intro tag) FrontierEvent_rest (... ...))
       (where (FrontierEvent_rest (... ...))
              (frontier-prefix-events-id F))]
      [(frontier-prefix-events-id (Emit A F))
       ((EmitEvent A) FrontierEvent_rest (... ...))
       (where (FrontierEvent_rest (... ...))
              (frontier-prefix-events-id F))]
      [(frontier-prefix-events-id (Forced F))
       (ForcedEvent FrontierEvent_rest (... ...))
       (where (FrontierEvent_rest (... ...))
              (frontier-prefix-events-id F))])

    (define-metafunction language-id
      answer-payloads-id : F -> (A (... ...))
      [(answer-payloads-id (More W)) ()]
      [(answer-payloads-id Done) ()]
      [(answer-payloads-id (Last A)) (A)]
      [(answer-payloads-id (FrontierFresh intro F tag))
       (answer-payloads-id F)]
      [(answer-payloads-id (Emit A F))
       (A A_rest (... ...))
       (where (A_rest (... ...)) (answer-payloads-id F))]
      [(answer-payloads-id (Forced F))
       (answer-payloads-id F)])

    (define-metafunction language-id
      answer-state : A -> kst
      [(answer-state (Answer kst)) kst]
      [(answer-state (AnswerFresh intro A tag))
       (answer-state A)])

    ;; These are the raw kernel states carried by completed answers.  In
    ;; particular, they are not the user-facing query observations supplied
    ;; by a concrete kernel such as Kmk.
    (define-metafunction language-id
      answer-states-id : F -> (kst (... ...))
      [(answer-states-id F)
       ((answer-state A) (... ...))
       (where (A (... ...)) (answer-payloads-id F))])

    (define-metafunction language-id
      scoped-answer-at : A (ScopeOwner (... ...)) -> SA
      [(scoped-answer-at (Answer kst) (ScopeOwner (... ...)))
       (ScopedAnswer kst (ScopeOwner (... ...)))]
      [(scoped-answer-at
        (AnswerFresh intro A tag)
        (ScopeOwner (... ...)))
       (scoped-answer-at
        A
        (ScopeOwner (... ...) (Owner intro tag)))])

    (define-metafunction language-id
      scoped-answers-at : F (ScopeOwner (... ...)) -> (SA (... ...))
      [(scoped-answers-at (More W) (ScopeOwner (... ...))) ()]
      [(scoped-answers-at Done (ScopeOwner (... ...))) ()]
      [(scoped-answers-at (Last A) (ScopeOwner (... ...)))
       ((scoped-answer-at A (ScopeOwner (... ...))))]
      [(scoped-answers-at
        (FrontierFresh intro F tag)
        (ScopeOwner (... ...)))
       (scoped-answers-at
        F
        (ScopeOwner (... ...) (Owner intro tag)))]
      [(scoped-answers-at (Emit A F) (ScopeOwner (... ...)))
       ((scoped-answer-at A (ScopeOwner (... ...))) SA_rest (... ...))
       (where (SA_rest (... ...))
              (scoped-answers-at F (ScopeOwner (... ...))))]
      [(scoped-answers-at (Forced F) (ScopeOwner (... ...)))
       (scoped-answers-at F (ScopeOwner (... ...)))])

    (define-metafunction language-id
      scoped-answers-id : F -> (SA (... ...))
      [(scoped-answers-id F) (scoped-answers-at F ())])

    (define-metafunction language-id
      forced-events-id : F -> (ForceEvent (... ...))
      [(forced-events-id (More W)) ()]
      [(forced-events-id Done) ()]
      [(forced-events-id (Last A)) ()]
      [(forced-events-id (FrontierFresh intro F tag))
       (forced-events-id F)]
      [(forced-events-id (Emit A F))
       (forced-events-id F)]
      [(forced-events-id (Forced F))
       (ForcedEvent ForceEvent_rest (... ...))
       (where (ForceEvent_rest (... ...)) (forced-events-id F))])

    (define-metafunction language-id
      residual-id : F -> FTail
      [(residual-id F) FTail
       (judgment-holds (frontier-split-id F FF FTail))])

    ;; Keep the ordered rule labels as an executable projection of the trace,
    ;; rather than asking clients to maintain a parallel host-language list.
    (define-metafunction language-id
      trace-labels-id : Trace -> Labels
      [(trace-labels-id ()) ()]
      [(trace-labels-id
        ((Edge F_before ell F_after) TraceEdge_rest (... ...)))
       (ell ell_rest (... ...))
       (where (ell_rest (... ...))
              (trace-labels-id (TraceEdge_rest (... ...))))])

    ;; The only Phase-2 scalar cost is unit exact-step cost.  Exact labels are
    ;; retained as its free basis, so a later weighted model is an explicit
    ;; map rather than a hidden source-semantics choice.
    (define-metafunction language-id
      rule-cost-id : Labels -> n
      [(rule-cost-id (ell (... ...)))
       ,(length (term (ell (... ...))))])

    (define-metafunction language-id
      force-count-id : Labels -> n
      [(force-count-id (ell (... ...)))
       ,(count (lambda (label)
                 (equal? label '(force-delay delay)))
               (term (ell (... ...))))])

    ;; Allocation payload cannot be recovered from a label alone.  Repeating
    ;; the source rule's whole-frontier support and kernel opening premises
    ;; makes this a standalone reflection of the genuine allocation edge,
    ;; rather than a shape-and-label classifier.  The repeated WF and tag
    ;; patterns ensure that exposure/copying is never an allocation.
    (define-judgment-form
      language-id
      #:contract (allocation-edge-id F ell F AllocationEvent)
      #:mode (allocation-edge-id I I I O)
      [(where intro_used
              (whole-marker-support-id F_whole))
       (where (OpenedFresh intro_new g_new)
              (kernel-open-fresh-id lexical_fresh g_body intro_used))
       ---------------------------------------------------- "fresh allocation event"
       (allocation-edge-id
        (name F_whole
              (in-hole WF_0
                       (Work (fresh lexical_fresh
                                    g_body
                                    tag_fresh)
                             kst_before)))
        (allocate-fresh core)
        (in-hole WF_0
                 (WorkFresh intro_new
                            (Work g_new kst_before)
                            tag_fresh))
        (AllocateEvent tag_fresh lexical_fresh intro_new))])

    (define-metafunction language-id
      allocation-events-id : Trace -> (AllocationEvent (... ...))
      [(allocation-events-id ()) ()]
      [(allocation-events-id
        ((Edge
          (name F_whole
                (in-hole WF_0
                         (Work (fresh lexical_fresh
                                      g_body
                                      tag_fresh)
                               kst_before)))
          (allocate-fresh core)
          (in-hole WF_0
                   (WorkFresh intro_new
                              (Work g_new kst_before)
                              tag_fresh)))
         TraceEdge_rest (... ...)))
       ((AllocateEvent tag_fresh lexical_fresh intro_new)
        AllocationEvent_rest (... ...))
       (where intro_used
              (whole-marker-support-id F_whole))
       (where (OpenedFresh intro_new g_new)
              (kernel-open-fresh-id lexical_fresh g_body intro_used))
       (where (AllocationEvent_rest (... ...))
              (allocation-events-id (TraceEdge_rest (... ...))))]
      [(allocation-events-id
        ((Edge F_0 ell F_1) TraceEdge_rest (... ...)))
       (allocation-events-id (TraceEdge_rest (... ...)))])

    ;; A single inductive relation serves answer, scoped-answer, and event
    ;; prefix checks without converting observations to a different container.
    (define-judgment-form
      language-id
      #:contract (observation-prefix-id (any (... ...)) (any (... ...)))
      #:mode (observation-prefix-id I I)
      [---------------------------------------------------- "empty observation prefix"
       (observation-prefix-id () (any (... ...)))]
      [(observation-prefix-id (any_before (... ...))
                              (any_after (... ...)))
       ---------------------------------------------------- "one observation prefix element"
       (observation-prefix-id
        (any_0 any_before (... ...))
        (any_0 any_after (... ...)))])

    (define-judgment-form
      language-id
      #:contract (event-prefix/delta
                  (FrontierEvent (... ...))
                  (FrontierEvent (... ...))
                  (FrontierEvent (... ...)))
      #:mode (event-prefix/delta I I O)
      [---------------------------------------------------- "frontier event delta"
       (event-prefix/delta ()
                           (FrontierEvent_delta (... ...))
                           (FrontierEvent_delta (... ...)))]
      [(event-prefix/delta
        (FrontierEvent_before (... ...))
        (FrontierEvent_after (... ...))
        (FrontierEvent_delta (... ...)))
       ---------------------------------------------------- "shared frontier event"
       (event-prefix/delta
        (FrontierEvent_0 FrontierEvent_before (... ...))
        (FrontierEvent_0 FrontierEvent_after (... ...))
        (FrontierEvent_delta (... ...)))])

    (define-judgment-form
      language-id
      #:contract (frontier-delta-id F F (FrontierEvent (... ...)))
      #:mode (frontier-delta-id I I O)
      [(where (FrontierEvent_before (... ...))
              (frontier-prefix-events-id F_before))
       (where (FrontierEvent_after (... ...))
              (frontier-prefix-events-id F_after))
       (event-prefix/delta
        (FrontierEvent_before (... ...))
        (FrontierEvent_after (... ...))
        (FrontierEvent_delta (... ...)))
       ---------------------------------------------------- "frontier extension delta"
       (frontier-delta-id
        F_before
        F_after
        (FrontierEvent_delta (... ...)))])))
