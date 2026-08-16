#lang racket

(require redex/reduction-semantics)

(provide define-pk-compressed)

;; Direct symbolic compression.  This schema never invokes an exact machine
;; step; its equations are the independently transformed artifact.
(define-syntax-rule
  (define-pk-compressed
    compressed-lang
    machine-lang
    kernel-step/K
    kernel-open-fresh/K
    whole-marker-support/K
    control-resume/K
    control-freeze/K
    wf-frontier/K
    residual-state
    symbolic-path/direct
    compressed-step/direct
    compressed-steps/direct
    initial-compressed-query/direct
    initial-compressed/direct
    compressed-readback
    reachable-compressed/via
    compressed-red/direct)
  (begin
    (define-extended-language compressed-lang
      machine-lang
      [B (BRun NW WF)
         (BSettled SR WF)
         (BDead WF)
         (BDelay W WF)
         (BFinal T FF)]
      [Marks (ell (... ...))]
      [Span (transition-span ell ell (... ...))]
      [Spans (Span (... ...))]
      [Path (path Marks B)]
      ;; Derivation program points, not operational states.  BQGoal names the
      ;; complete source-goal dispatcher; only its katom clauses call K.
      [BQ (BQRun NW WF)
          (BQLocal NR WF)
          (BQGoal g kst WF)
          (BQFresh intro W tag LF)
          (BQConj W g WF)
          (BQLeft W W WF)
          (BQRight W W WF)
          (BQSettled SR WF)
          (BQDead WF)
          (BQDelay W WF)])

    (define-metafunction compressed-lang
      compressed-choice-success : SC -> S
      [(compressed-choice-success (DisjL S W)) S]
      [(compressed-choice-success (DisjR W S)) S])

    (define-metafunction compressed-lang
      compressed-choice-alternate : SC -> W
      [(compressed-choice-alternate (DisjL S W)) W]
      [(compressed-choice-alternate (DisjR W S)) W])

    (define-metafunction compressed-lang
      residual-state : W WF -> B
      [(residual-state Dead WF) (BDead WF)]
      [(residual-state (PendingDelay W) WF) (BDelay W WF)]
      [(residual-state SR WF) (BSettled SR WF)]
      [(residual-state NW WF) (BRun NW WF)])

    (define-metafunction compressed-lang
      prepend-path : ell Path -> Path
      [(prepend-path ell (path (ell_rest (... ...)) B))
       (path (ell ell_rest (... ...)) B)])

    ;; One statically known boundary exposure is fused after an unfinished
    ;; constructor producer.  Ordered metafunction clauses implement the same
    ;; disjoint WorkFresh/BF versus remaining-WF partition used by EQAfter.
    (define-metafunction compressed-lang
      after-unfinished : W WF -> Path
      [(after-unfinished
        (WorkFresh intro W tag)
        (in-hole FF (More hole)))
       (path
        ((expose-frontier-fresh core))
        (residual-state
         W
         (in-hole FF
                  (FrontierFresh intro (More hole) tag))))]
      [(after-unfinished W WF)
       (path () (residual-state W WF))])

    (define-judgment-form
      compressed-lang
      #:contract (symbolic-path/direct BQ Path)
      #:mode (symbolic-path/direct I O)

      ;; Downward dispatcher.  A WorkFresh at BF has grammatical priority;
      ;; every nonfresh unfinished node delegates to the local constructor.
      [---------------------------------------------------- "compress root WorkFresh"
       (symbolic-path/direct
        (BQRun (WorkFresh intro W tag)
               (in-hole FF (More hole)))
        (path
         ((expose-frontier-fresh core))
         (residual-state
          W
          (in-hole FF
                   (FrontierFresh intro (More hole) tag)))))]

      [(symbolic-path/direct (BQLocal NR WF) Path)
       ---------------------------------------------------- "compress nonfresh run"
       (symbolic-path/direct (BQRun NR WF) Path)]

      [(symbolic-path/direct (BQFresh intro W tag LF) Path)
       ---------------------------------------------------- "compress local fresh"
       (symbolic-path/direct
        (BQRun (WorkFresh intro W tag) LF)
        Path)]

      ;; Local constructor dispatcher.
      [(symbolic-path/direct (BQGoal g kst WF) Path)
       ---------------------------------------------------- "compress local goal"
       (symbolic-path/direct (BQLocal (Work g kst) WF) Path)]

      [(symbolic-path/direct (BQConj W g WF) Path)
       ---------------------------------------------------- "compress local conjunction"
       (symbolic-path/direct (BQLocal (Conj W g) WF) Path)]

      [(symbolic-path/direct (BQLeft W_1 W_2 WF) Path)
       ---------------------------------------------------- "compress local left choice"
       (symbolic-path/direct (BQLocal (DisjL W_1 W_2) WF) Path)]

      [(symbolic-path/direct (BQRight W_1 W_2 WF) Path)
       ---------------------------------------------------- "compress local right choice"
       (symbolic-path/direct (BQLocal (DisjR W_1 W_2) WF) Path)]

      ;; The only kernel-specific control boundary: both outcomes preserve
      ;; the exact dynamic kell, then consume the following control edge.
      [(kernel-step/K katom kst (KernelSuccess kst_new) kell)
       (symbolic-path/direct
        (BQSettled (Returned kst_new) WF)
        Path_1)
       (where Path_2 (prepend-path kell Path_1))
       ---------------------------------------------------- "compress kernel success"
       (symbolic-path/direct (BQGoal katom kst WF) Path_2)]

      [(kernel-step/K katom kst KernelFailure kell)
       (symbolic-path/direct (BQDead WF) Path_1)
       (where Path_2 (prepend-path kell Path_1))
       ---------------------------------------------------- "compress kernel failure"
       (symbolic-path/direct (BQGoal katom kst WF) Path_2)]

      ;; Shared structural goal producers.
      [(where F_whole
              (in-hole WF
                       (Work (fresh (x (... ...)) g tag_fresh) kst)))
       (where intro_used (whole-marker-support/K F_whole))
       (where (OpenedFresh intro_new g_new)
              (kernel-open-fresh/K (x (... ...)) g intro_used))
       (where Path_1
              (after-unfinished
               (WorkFresh intro_new (Work g_new kst) tag_fresh)
               WF))
       (where Path_2
              (prepend-path (allocate-fresh core) Path_1))
       ---------------------------------------------------- "compress allocate fresh"
       (symbolic-path/direct
        (BQGoal (fresh (x (... ...)) g tag_fresh) kst WF)
        Path_2)]

      [(where Path_1
              (after-unfinished
               (Conj (Work g_1 kst) g_2)
               WF))
       (where Path_2
              (prepend-path (expand-conjunction core) Path_1))
       ---------------------------------------------------- "compress expand conjunction"
       (symbolic-path/direct
        (BQGoal (conj g_1 g_2 tag) kst WF)
        Path_2)]

      [(where Path_1
              (after-unfinished
               (DisjL (Work g_1 kst) (Work g_2 kst))
               WF))
       (where Path_2
              (prepend-path (expand-disjunction disj) Path_1))
       ---------------------------------------------------- "compress expand disjunction"
       (symbolic-path/direct
        (BQGoal (disj g_1 g_2 tag) kst WF)
        Path_2)]

      [(symbolic-path/direct (BQDelay (Work g kst) WF) Path_1)
       (where Path_2
              (prepend-path (suspend-goal delay) Path_1))
       ---------------------------------------------------- "compress suspend goal"
       (symbolic-path/direct
        (BQGoal (suspend g tag) kst WF)
        Path_2)]

      ;; WorkFresh dispatcher.
      [(symbolic-path/direct
        (BQSettled (WorkFresh intro S tag) LF)
        Path)
       ---------------------------------------------------- "compress settled fresh success"
       (symbolic-path/direct (BQFresh intro S tag LF) Path)]

      [---------------------------------------------------- "compress expose left through fresh"
       (symbolic-path/direct
        (BQFresh intro (DisjL S W) tag LF)
        (path
         ((expose-choice-through-work-fresh disj))
         (BSettled
          (DisjL (WorkFresh intro S tag)
                 (WorkFresh intro W tag))
          LF)))]

      [---------------------------------------------------- "compress expose right through fresh"
       (symbolic-path/direct
        (BQFresh intro (DisjR W S) tag LF)
        (path
         ((expose-choice-through-work-fresh search-join))
         (BSettled
          (DisjR (WorkFresh intro W tag)
                 (WorkFresh intro S tag))
          LF)))]

      [---------------------------------------------------- "compress erase dead fresh"
       (symbolic-path/direct
        (BQFresh intro Dead tag LF)
        (path ((erase-dead-fresh core)) (BDead LF)))]

      [---------------------------------------------------- "compress bubble delay through fresh"
       (symbolic-path/direct
        (BQFresh intro (PendingDelay W) tag LF)
        (path
         ((bubble-delay-through-fresh delay))
         (BDelay (WorkFresh intro W tag) LF)))]

      [(symbolic-path/direct
        (BQRun NW (in-hole LF (WorkFresh intro hole tag)))
        Path)
       ---------------------------------------------------- "compress descend fresh"
       (symbolic-path/direct (BQFresh intro NW tag LF) Path)]

      ;; Conjunction dispatcher.
      [(where Path_1
              (after-unfinished (control-resume/K S g) WF))
       (where Path_2
              (prepend-path (conj-return core) Path_1))
       ---------------------------------------------------- "compress conjunction return"
       (symbolic-path/direct (BQConj S g WF) Path_2)]

      [---------------------------------------------------- "compress conjunction failure"
       (symbolic-path/direct
        (BQConj Dead g WF)
        (path ((conj-fail core)) (BDead WF)))]

      [---------------------------------------------------- "compress conjunction delay"
       (symbolic-path/direct
        (BQConj (PendingDelay W) g WF)
        (path
         ((bubble-delay-through-conj delay))
         (BDelay (Conj W g) WF)))]

      [(where Path_1
              (after-unfinished
               (DisjL (control-resume/K S g) (Conj W g))
               WF))
       (where Path_2
              (prepend-path (late-distribute-settled disj) Path_1))
       ---------------------------------------------------- "compress late distribute left"
       (symbolic-path/direct
        (BQConj (DisjL S W) g WF)
        Path_2)]

      [(where Path_1
              (after-unfinished
               (DisjR (Conj W g) (control-resume/K S g))
               WF))
       (where Path_2
              (prepend-path
               (late-distribute-right-settled search-join)
               Path_1))
       ---------------------------------------------------- "compress late distribute right"
       (symbolic-path/direct
        (BQConj (DisjR W S) g WF)
        Path_2)]

      [(symbolic-path/direct
        (BQRun NW (in-hole WF (Conj hole g)))
        Path)
       ---------------------------------------------------- "compress descend conjunction"
       (symbolic-path/direct (BQConj NW g WF) Path)]

      ;; Rail dispatchers.
      [(symbolic-path/direct
        (BQSettled (DisjL S W) WF)
        Path)
       ---------------------------------------------------- "compress settled left choice"
       (symbolic-path/direct (BQLeft S W WF) Path)]

      [---------------------------------------------------- "compress skip left failure"
       (symbolic-path/direct
        (BQLeft Dead W WF)
        (path
         ((skip-left-failure disj))
         (residual-state W WF)))]

      [---------------------------------------------------- "compress enter right rail"
       (symbolic-path/direct
        (BQLeft (PendingDelay W_1) W_2 WF)
        (path
         ((rail-enter-right search-join))
         (BDelay (DisjR W_1 W_2) WF)))]

      [---------------------------------------------------- "compress reassociate left"
       (symbolic-path/direct
        (BQLeft SC W_2 WF)
        (path
         ((reassociate-left-result disj))
         (BSettled
          (DisjL (compressed-choice-success SC)
                 (DisjL (compressed-choice-alternate SC) W_2))
          WF)))]

      [(symbolic-path/direct
        (BQRun NW (in-hole WF (DisjL hole W)))
        Path)
       ---------------------------------------------------- "compress descend left rail"
       (symbolic-path/direct (BQLeft NW W WF) Path)]

      [(symbolic-path/direct
        (BQSettled (DisjR W S) WF)
        Path)
       ---------------------------------------------------- "compress settled right choice"
       (symbolic-path/direct (BQRight W S WF) Path)]

      [---------------------------------------------------- "compress skip right failure"
       (symbolic-path/direct
        (BQRight W Dead WF)
        (path
         ((skip-right-failure search-join))
         (residual-state W WF)))]

      [---------------------------------------------------- "compress return left rail"
       (symbolic-path/direct
        (BQRight W_1 (PendingDelay W_2) WF)
        (path
         ((rail-return-left search-join))
         (BDelay (DisjL W_1 W_2) WF)))]

      [---------------------------------------------------- "compress reassociate right"
       (symbolic-path/direct
        (BQRight W_1 SC WF)
        (path
         ((reassociate-right-result search-join))
         (BSettled
          (DisjR
           (DisjR W_1 (compressed-choice-alternate SC))
           (compressed-choice-success SC))
          WF)))]

      [(symbolic-path/direct
        (BQRun NW (in-hole WF (DisjR W hole)))
        Path)
       ---------------------------------------------------- "compress descend right rail"
       (symbolic-path/direct (BQRight W NW WF) Path)]

      ;; Settled-result upward dispatcher.
      [---------------------------------------------------- "compress finish success"
       (symbolic-path/direct
        (BQSettled (Returned kst) (in-hole FF (More hole)))
        (path
         ((finish-success core))
         (BFinal (Last (Answer kst)) FF)))]

      [---------------------------------------------------- "compress expose settled frontier fresh"
       (symbolic-path/direct
        (BQSettled (WorkFresh intro S tag)
                   (in-hole FF (More hole)))
        (path
         ((expose-frontier-fresh core))
         (residual-state
          S
          (in-hole FF
                   (FrontierFresh intro (More hole) tag)))))]

      [---------------------------------------------------- "compress commit left answer"
       (symbolic-path/direct
        (BQSettled (DisjL S W) (in-hole FF (More hole)))
        (path
         ((commit-choice-answer disj))
         (residual-state
          W
          (in-hole FF
                   (Emit (control-freeze/K S) (More hole))))))]

      [---------------------------------------------------- "compress commit right answer"
       (symbolic-path/direct
        (BQSettled (DisjR W S) (in-hole FF (More hole)))
        (path
         ((commit-right-choice-answer search-join))
         (residual-state
          W
          (in-hole FF
                   (Emit (control-freeze/K S) (More hole))))))]

      [(symbolic-path/direct
        (BQSettled (WorkFresh intro S tag) LF)
        Path)
       ---------------------------------------------------- "compress silently cross fresh success"
       (symbolic-path/direct
        (BQSettled S (in-hole LF (WorkFresh intro hole tag)))
        Path)]

      [---------------------------------------------------- "compress expose left choice at fresh frame"
       (symbolic-path/direct
        (BQSettled
         (DisjL S W)
         (in-hole LF (WorkFresh intro hole tag)))
        (path
         ((expose-choice-through-work-fresh disj))
         (BSettled
          (DisjL (WorkFresh intro S tag)
                 (WorkFresh intro W tag))
          LF)))]

      [---------------------------------------------------- "compress expose right choice at fresh frame"
       (symbolic-path/direct
        (BQSettled
         (DisjR W S)
         (in-hole LF (WorkFresh intro hole tag)))
        (path
         ((expose-choice-through-work-fresh search-join))
         (BSettled
          (DisjR (WorkFresh intro W tag)
                 (WorkFresh intro S tag))
          LF)))]

      [(where Path_1
              (after-unfinished (control-resume/K S g) WF))
       (where Path_2
              (prepend-path (conj-return core) Path_1))
       ---------------------------------------------------- "compress settled through conjunction"
       (symbolic-path/direct
        (BQSettled S (in-hole WF (Conj hole g)))
        Path_2)]

      [(where Path_1
              (after-unfinished
               (DisjL (control-resume/K S g) (Conj W g))
               WF))
       (where Path_2
              (prepend-path (late-distribute-settled disj) Path_1))
       ---------------------------------------------------- "compress settled left through conjunction"
       (symbolic-path/direct
        (BQSettled (DisjL S W) (in-hole WF (Conj hole g)))
        Path_2)]

      [(where Path_1
              (after-unfinished
               (DisjR (Conj W g) (control-resume/K S g))
               WF))
       (where Path_2
              (prepend-path
               (late-distribute-right-settled search-join)
               Path_1))
       ---------------------------------------------------- "compress settled right through conjunction"
       (symbolic-path/direct
        (BQSettled (DisjR W S) (in-hole WF (Conj hole g)))
        Path_2)]

      [(symbolic-path/direct
        (BQSettled (DisjL S W) WF)
        Path)
       ---------------------------------------------------- "compress silently form left choice"
       (symbolic-path/direct
        (BQSettled S (in-hole WF (DisjL hole W)))
        Path)]

      [---------------------------------------------------- "compress reassociate settled left frame"
       (symbolic-path/direct
        (BQSettled SC (in-hole WF (DisjL hole W_2)))
        (path
         ((reassociate-left-result disj))
         (BSettled
          (DisjL (compressed-choice-success SC)
                 (DisjL (compressed-choice-alternate SC) W_2))
          WF)))]

      [(symbolic-path/direct
        (BQSettled (DisjR W S) WF)
        Path)
       ---------------------------------------------------- "compress silently form right choice"
       (symbolic-path/direct
        (BQSettled S (in-hole WF (DisjR W hole)))
        Path)]

      [---------------------------------------------------- "compress reassociate settled right frame"
       (symbolic-path/direct
        (BQSettled SC (in-hole WF (DisjR W_1 hole)))
        (path
         ((reassociate-right-result search-join))
         (BSettled
          (DisjR
           (DisjR W_1 (compressed-choice-alternate SC))
           (compressed-choice-success SC))
          WF)))]

      ;; Failure and delay propagation.
      [---------------------------------------------------- "compress finish failure"
       (symbolic-path/direct
        (BQDead (in-hole FF (More hole)))
        (path ((finish-failure core)) (BFinal Done FF)))]

      [---------------------------------------------------- "compress dead through fresh"
       (symbolic-path/direct
        (BQDead (in-hole LF (WorkFresh intro hole tag)))
        (path ((erase-dead-fresh core)) (BDead LF)))]

      [---------------------------------------------------- "compress dead through conjunction"
       (symbolic-path/direct
        (BQDead (in-hole WF (Conj hole g)))
        (path ((conj-fail core)) (BDead WF)))]

      [---------------------------------------------------- "compress dead skips left"
       (symbolic-path/direct
        (BQDead (in-hole WF (DisjL hole W)))
        (path
         ((skip-left-failure disj))
         (residual-state W WF)))]

      [---------------------------------------------------- "compress dead skips right"
       (symbolic-path/direct
        (BQDead (in-hole WF (DisjR W hole)))
        (path
         ((skip-right-failure search-join))
         (residual-state W WF)))]

      [---------------------------------------------------- "compress force delay"
       (symbolic-path/direct
        (BQDelay W (in-hole FF (More hole)))
        (path
         ((force-delay delay))
         (residual-state
          W
          (in-hole FF (Forced (More hole))))))]

      [---------------------------------------------------- "compress delay through fresh"
       (symbolic-path/direct
        (BQDelay W (in-hole LF (WorkFresh intro hole tag)))
        (path
         ((bubble-delay-through-fresh delay))
         (BDelay (WorkFresh intro W tag) LF)))]

      [---------------------------------------------------- "compress delay through conjunction"
       (symbolic-path/direct
        (BQDelay W (in-hole WF (Conj hole g)))
        (path
         ((bubble-delay-through-conj delay))
         (BDelay (Conj W g) WF)))]

      [---------------------------------------------------- "compress delay enters right rail"
       (symbolic-path/direct
        (BQDelay W_1 (in-hole WF (DisjL hole W_2)))
        (path
         ((rail-enter-right search-join))
         (BDelay (DisjR W_1 W_2) WF)))]

      [---------------------------------------------------- "compress delay returns left rail"
       (symbolic-path/direct
        (BQDelay W_2 (in-hole WF (DisjR W_1 hole)))
        (path
         ((rail-return-left search-join))
         (BDelay (DisjL W_1 W_2) WF)))])

    (define-judgment-form
      compressed-lang
      #:contract (compressed-step/direct B Span B)
      #:mode (compressed-step/direct I O O)

      [(symbolic-path/direct
        (BQRun NW WF)
        (path (ell_0 ell_rest (... ...)) B_1))
       ---------------------------------------------------- "compressed run step"
       (compressed-step/direct
        (BRun NW WF)
        (transition-span ell_0 ell_rest (... ...))
        B_1)]

      [(symbolic-path/direct
        (BQSettled SR WF)
        (path (ell_0 ell_rest (... ...)) B_1))
       ---------------------------------------------------- "compressed settled step"
       (compressed-step/direct
        (BSettled SR WF)
        (transition-span ell_0 ell_rest (... ...))
        B_1)]

      [(symbolic-path/direct
        (BQDead WF)
        (path (ell_0 ell_rest (... ...)) B_1))
       ---------------------------------------------------- "compressed dead step"
       (compressed-step/direct
        (BDead WF)
        (transition-span ell_0 ell_rest (... ...))
        B_1)]

      [(symbolic-path/direct
        (BQDelay W WF)
        (path (ell_0 ell_rest (... ...)) B_1))
       ---------------------------------------------------- "compressed delay step"
       (compressed-step/direct
        (BDelay W WF)
        (transition-span ell_0 ell_rest (... ...))
        B_1)])

    (define-judgment-form
      compressed-lang
      #:contract (compressed-steps/direct B Spans B)
      #:mode (compressed-steps/direct I O O)

      [---------------------------------------------------- "zero compressed steps"
       (compressed-steps/direct B () B)]

      [(compressed-step/direct B_0 Span B_1)
       (compressed-steps/direct B_1 (Span_rest (... ...)) B_2)
       ---------------------------------------------------- "one or more compressed steps"
       (compressed-steps/direct
        B_0
        (Span Span_rest (... ...))
        B_2)])

    (define-judgment-form
      compressed-lang
      #:contract (initial-compressed-query/direct F FF B)
      #:mode (initial-compressed-query/direct I I O)

      [(initial-compressed-query/direct
        F
        (in-hole FF (Emit A hole))
        B)
       ---------------------------------------------------- "compressed initial emit"
       (initial-compressed-query/direct (Emit A F) FF B)]

      [(initial-compressed-query/direct
        F
        (in-hole FF (FrontierFresh intro hole tag))
        B)
       ---------------------------------------------------- "compressed initial frontier fresh"
       (initial-compressed-query/direct
        (FrontierFresh intro F tag)
        FF
        B)]

      [(initial-compressed-query/direct
        F
        (in-hole FF (Forced hole))
        B)
       ---------------------------------------------------- "compressed initial forced"
       (initial-compressed-query/direct (Forced F) FF B)]

      [(where B (residual-state W (in-hole FF (More hole))))
       ---------------------------------------------------- "compressed initial More"
       (initial-compressed-query/direct (More W) FF B)]

      [---------------------------------------------------- "compressed initial terminal"
       (initial-compressed-query/direct T FF (BFinal T FF))])

    (define-judgment-form
      compressed-lang
      #:contract (initial-compressed/direct F B)
      #:mode (initial-compressed/direct I O)

      [(initial-compressed-query/direct F hole B)
       ---------------------------------------------------- "initial compressed state"
       (initial-compressed/direct F B)])

    (define-metafunction compressed-lang
      compressed-readback : B -> F
      [(compressed-readback (BRun NW WF)) (in-hole WF NW)]
      [(compressed-readback (BSettled SR WF)) (in-hole WF SR)]
      [(compressed-readback (BDead WF)) (in-hole WF Dead)]
      [(compressed-readback (BDelay W WF))
       (in-hole WF (PendingDelay W))]
      [(compressed-readback (BFinal T FF)) (in-hole FF T)])

    (define-judgment-form
      compressed-lang
      #:contract (reachable-compressed/via F Spans B)
      #:mode (reachable-compressed/via I O O)

      [(wf-frontier/K F)
       (initial-compressed/direct F B_0)
       (compressed-steps/direct B_0 Spans B)
       ---------------------------------------------------- "reachable compressed state with spans"
       (reachable-compressed/via F Spans B)])

    (define compressed-red/direct
      (reduction-relation
       compressed-lang
       #:domain B
       [--> B_0 B_1
            (judgment-holds
             (compressed-step/direct B_0 Span B_1))
            (computed-name (format "~s" (term Span)))]))))
