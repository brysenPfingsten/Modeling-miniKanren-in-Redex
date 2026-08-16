#lang racket

(require redex/reduction-semantics)

(provide define-pk-big-step)

;; Independent syntax-directed fixed-point promotion.  No compressed or exact
;; machine operation occurs in this schema.
(define-syntax-rule
  (define-pk-big-step
    big-step-direct-lang
    big-step-lang
    kernel-step/K
    kernel-open-fresh/K
    whole-marker-support/K
    control-resume/K
    control-freeze/K
    wf-frontier/K
    evaluate-query/direct
    big-run/direct
    big-settled/direct
    big-dead/direct
    big-delay/direct
    big-final/direct
    promote/direct
    big-step/direct)
  (begin
    (define-extended-language big-step-direct-lang
      big-step-lang
      [EQ (EQRoot F FF)
          (EQContinue W WF)
          (EQAfter W WF)
          (EQRun NW WF)
          (EQLocal NR WF)
          (EQGoal g kst WF)
          (EQFresh intro W tag LF)
          (EQConj W g WF)
          (EQLeft W W WF)
          (EQRight W W WF)
          (EQSettled SR WF)
          (EQDead WF)
          (EQDelay W WF)
          (EQFinal T FF)])

    (define-metafunction big-step-direct-lang
      direct-choice-success : SC -> S
      [(direct-choice-success (DisjL S W)) S]
      [(direct-choice-success (DisjR W S)) S])

    (define-metafunction big-step-direct-lang
      direct-choice-alternate : SC -> W
      [(direct-choice-alternate (DisjL S W)) W]
      [(direct-choice-alternate (DisjR W S)) W])

    (define-judgment-form
      big-step-direct-lang
      #:contract (evaluate-query/direct EQ O)
      #:mode (evaluate-query/direct I O)

      ;; Root entry accumulates an F-to-F actual-hole context.
      [(evaluate-query/direct
        (EQRoot F (in-hole FF (Emit A hole)))
        O)
       ---------------------------------------------------- "direct root emit"
       (evaluate-query/direct (EQRoot (Emit A F) FF) O)]

      [(evaluate-query/direct
        (EQRoot F (in-hole FF (FrontierFresh intro hole tag)))
        O)
       ---------------------------------------------------- "direct root frontier fresh"
       (evaluate-query/direct
        (EQRoot (FrontierFresh intro F tag) FF)
        O)]

      [(evaluate-query/direct
        (EQRoot F (in-hole FF (Forced hole)))
        O)
       ---------------------------------------------------- "direct root forced"
       (evaluate-query/direct (EQRoot (Forced F) FF) O)]

      [(evaluate-query/direct
        (EQContinue W (in-hole FF (More hole)))
        O)
       ---------------------------------------------------- "direct root More"
       (evaluate-query/direct (EQRoot (More W) FF) O)]

      [(evaluate-query/direct (EQFinal T FF) O)
       ---------------------------------------------------- "direct root terminal"
       (evaluate-query/direct (EQRoot T FF) O)]

      ;; Residual phase dispatcher.
      [(evaluate-query/direct (EQDead WF) O)
       ---------------------------------------------------- "direct continue dead"
       (evaluate-query/direct (EQContinue Dead WF) O)]

      [(evaluate-query/direct (EQDelay W WF) O)
       ---------------------------------------------------- "direct continue delay"
       (evaluate-query/direct
        (EQContinue (PendingDelay W) WF)
        O)]

      [(evaluate-query/direct (EQSettled SR WF) O)
       ---------------------------------------------------- "direct continue settled"
       (evaluate-query/direct (EQContinue SR WF) O)]

      [(evaluate-query/direct (EQRun NW WF) O)
       ---------------------------------------------------- "direct continue unfinished"
       (evaluate-query/direct (EQContinue NW WF) O)]

      ;; Fixed-point image of after-unfinished.
      [(evaluate-query/direct
        (EQContinue
         W
         (in-hole FF
                  (FrontierFresh intro (More hole) tag)))
        O)
       ---------------------------------------------------- "direct after root fresh"
       (evaluate-query/direct
        (EQAfter (WorkFresh intro W tag)
                 (in-hole FF (More hole)))
        O)]

      [(evaluate-query/direct (EQContinue NF BF) O)
       ---------------------------------------------------- "direct after root nonfresh"
       (evaluate-query/direct (EQAfter NF BF) O)]

      [(evaluate-query/direct (EQContinue W LF) O)
       ---------------------------------------------------- "direct after nonroot"
       (evaluate-query/direct (EQAfter W LF) O)]

      ;; Downward run dispatcher.
      [(evaluate-query/direct
        (EQContinue
         W
         (in-hole FF
                  (FrontierFresh intro (More hole) tag)))
        O)
       ---------------------------------------------------- "direct run root fresh"
       (evaluate-query/direct
        (EQRun (WorkFresh intro W tag)
               (in-hole FF (More hole)))
        O)]

      [(evaluate-query/direct (EQLocal NR WF) O)
       ---------------------------------------------------- "direct run nonfresh"
       (evaluate-query/direct (EQRun NR WF) O)]

      [(evaluate-query/direct (EQFresh intro W tag LF) O)
       ---------------------------------------------------- "direct run nonroot fresh"
       (evaluate-query/direct
        (EQRun (WorkFresh intro W tag) LF)
        O)]

      ;; Local constructor dispatcher.
      [(evaluate-query/direct (EQGoal g kst WF) O)
       ---------------------------------------------------- "direct local goal"
       (evaluate-query/direct (EQLocal (Work g kst) WF) O)]

      [(evaluate-query/direct (EQConj W g WF) O)
       ---------------------------------------------------- "direct local conjunction"
       (evaluate-query/direct (EQLocal (Conj W g) WF) O)]

      [(evaluate-query/direct (EQLeft W_1 W_2 WF) O)
       ---------------------------------------------------- "direct local left"
       (evaluate-query/direct (EQLocal (DisjL W_1 W_2) WF) O)]

      [(evaluate-query/direct (EQRight W_1 W_2 WF) O)
       ---------------------------------------------------- "direct local right"
       (evaluate-query/direct (EQLocal (DisjR W_1 W_2) WF) O)]

      ;; Kernel-owned atomic result selection.
      [(kernel-step/K katom kst (KernelSuccess kst_new) kell)
       (evaluate-query/direct
        (EQSettled (Returned kst_new) WF)
        O)
       ---------------------------------------------------- "direct kernel success"
       (evaluate-query/direct (EQGoal katom kst WF) O)]

      [(kernel-step/K katom kst KernelFailure kell)
       (evaluate-query/direct (EQDead WF) O)
       ---------------------------------------------------- "direct kernel failure"
       (evaluate-query/direct (EQGoal katom kst WF) O)]

      ;; Shared structural goal producers.
      [(where F_whole
              (in-hole WF
                       (Work (fresh (x (... ...)) g tag_fresh) kst)))
       (where intro_used (whole-marker-support/K F_whole))
       (where (OpenedFresh intro_new g_new)
              (kernel-open-fresh/K (x (... ...)) g intro_used))
       (evaluate-query/direct
        (EQAfter
         (WorkFresh intro_new (Work g_new kst) tag_fresh)
         WF)
        O)
       ---------------------------------------------------- "direct allocate fresh"
       (evaluate-query/direct
        (EQGoal (fresh (x (... ...)) g tag_fresh) kst WF)
        O)]

      [(evaluate-query/direct
        (EQAfter (Conj (Work g_1 kst) g_2) WF)
        O)
       ---------------------------------------------------- "direct expand conjunction"
       (evaluate-query/direct
        (EQGoal (conj g_1 g_2 tag) kst WF)
        O)]

      [(evaluate-query/direct
        (EQAfter
         (DisjL (Work g_1 kst) (Work g_2 kst))
         WF)
        O)
       ---------------------------------------------------- "direct expand disjunction"
       (evaluate-query/direct
        (EQGoal (disj g_1 g_2 tag) kst WF)
        O)]

      [(evaluate-query/direct (EQDelay (Work g kst) WF) O)
       ---------------------------------------------------- "direct suspend goal"
       (evaluate-query/direct
        (EQGoal (suspend g tag) kst WF)
        O)]

      ;; WorkFresh dispatcher.
      [(evaluate-query/direct
        (EQSettled (WorkFresh intro S tag) LF)
        O)
       ---------------------------------------------------- "direct fresh success"
       (evaluate-query/direct (EQFresh intro S tag LF) O)]

      [(evaluate-query/direct
        (EQSettled
         (DisjL (WorkFresh intro S tag)
                (WorkFresh intro W tag))
         LF)
        O)
       ---------------------------------------------------- "direct expose left through fresh"
       (evaluate-query/direct
        (EQFresh intro (DisjL S W) tag LF)
        O)]

      [(evaluate-query/direct
        (EQSettled
         (DisjR (WorkFresh intro W tag)
                (WorkFresh intro S tag))
         LF)
        O)
       ---------------------------------------------------- "direct expose right through fresh"
       (evaluate-query/direct
        (EQFresh intro (DisjR W S) tag LF)
        O)]

      [(evaluate-query/direct (EQDead LF) O)
       ---------------------------------------------------- "direct erase dead fresh"
       (evaluate-query/direct (EQFresh intro Dead tag LF) O)]

      [(evaluate-query/direct
        (EQDelay (WorkFresh intro W tag) LF)
        O)
       ---------------------------------------------------- "direct bubble fresh delay"
       (evaluate-query/direct
        (EQFresh intro (PendingDelay W) tag LF)
        O)]

      [(evaluate-query/direct
        (EQRun NW (in-hole LF (WorkFresh intro hole tag)))
        O)
       ---------------------------------------------------- "direct descend fresh"
       (evaluate-query/direct (EQFresh intro NW tag LF) O)]

      ;; Conjunction dispatcher.
      [(evaluate-query/direct
        (EQAfter (control-resume/K S g) WF)
        O)
       ---------------------------------------------------- "direct conjunction return"
       (evaluate-query/direct (EQConj S g WF) O)]

      [(evaluate-query/direct (EQDead WF) O)
       ---------------------------------------------------- "direct conjunction failure"
       (evaluate-query/direct (EQConj Dead g WF) O)]

      [(evaluate-query/direct (EQDelay (Conj W g) WF) O)
       ---------------------------------------------------- "direct conjunction delay"
       (evaluate-query/direct
        (EQConj (PendingDelay W) g WF)
        O)]

      [(evaluate-query/direct
        (EQAfter
         (DisjL (control-resume/K S g) (Conj W g))
         WF)
        O)
       ---------------------------------------------------- "direct late distribute left"
       (evaluate-query/direct
        (EQConj (DisjL S W) g WF)
        O)]

      [(evaluate-query/direct
        (EQAfter
         (DisjR (Conj W g) (control-resume/K S g))
         WF)
        O)
       ---------------------------------------------------- "direct late distribute right"
       (evaluate-query/direct
        (EQConj (DisjR W S) g WF)
        O)]

      [(evaluate-query/direct
        (EQRun NW (in-hole WF (Conj hole g)))
        O)
       ---------------------------------------------------- "direct descend conjunction"
       (evaluate-query/direct (EQConj NW g WF) O)]

      ;; Rail dispatchers.
      [(evaluate-query/direct
        (EQSettled (DisjL S W) WF)
        O)
       ---------------------------------------------------- "direct settled left choice"
       (evaluate-query/direct (EQLeft S W WF) O)]

      [(evaluate-query/direct (EQContinue W WF) O)
       ---------------------------------------------------- "direct skip left failure"
       (evaluate-query/direct (EQLeft Dead W WF) O)]

      [(evaluate-query/direct
        (EQDelay (DisjR W_1 W_2) WF)
        O)
       ---------------------------------------------------- "direct enter right rail"
       (evaluate-query/direct
        (EQLeft (PendingDelay W_1) W_2 WF)
        O)]

      [(evaluate-query/direct
        (EQSettled
         (DisjL (direct-choice-success SC)
                (DisjL (direct-choice-alternate SC) W_2))
         WF)
        O)
       ---------------------------------------------------- "direct reassociate left"
       (evaluate-query/direct (EQLeft SC W_2 WF) O)]

      [(evaluate-query/direct
        (EQRun NW (in-hole WF (DisjL hole W)))
        O)
       ---------------------------------------------------- "direct descend left rail"
       (evaluate-query/direct (EQLeft NW W WF) O)]

      [(evaluate-query/direct
        (EQSettled (DisjR W S) WF)
        O)
       ---------------------------------------------------- "direct settled right choice"
       (evaluate-query/direct (EQRight W S WF) O)]

      [(evaluate-query/direct (EQContinue W WF) O)
       ---------------------------------------------------- "direct skip right failure"
       (evaluate-query/direct (EQRight W Dead WF) O)]

      [(evaluate-query/direct
        (EQDelay (DisjL W_1 W_2) WF)
        O)
       ---------------------------------------------------- "direct return left rail"
       (evaluate-query/direct
        (EQRight W_1 (PendingDelay W_2) WF)
        O)]

      [(evaluate-query/direct
        (EQSettled
         (DisjR
          (DisjR W_1 (direct-choice-alternate SC))
          (direct-choice-success SC))
         WF)
        O)
       ---------------------------------------------------- "direct reassociate right"
       (evaluate-query/direct (EQRight W_1 SC WF) O)]

      [(evaluate-query/direct
        (EQRun NW (in-hole WF (DisjR W hole)))
        O)
       ---------------------------------------------------- "direct descend right rail"
       (evaluate-query/direct (EQRight W NW WF) O)]

      ;; Boundary and upward settled dispatcher.
      [(evaluate-query/direct (EQFinal (Last (Answer kst)) FF) O)
       ---------------------------------------------------- "direct finish success"
       (evaluate-query/direct
        (EQSettled (Returned kst)
                   (in-hole FF (More hole)))
        O)]

      [(evaluate-query/direct
        (EQContinue
         S
         (in-hole FF
                  (FrontierFresh intro (More hole) tag)))
        O)
       ---------------------------------------------------- "direct expose settled frontier fresh"
       (evaluate-query/direct
        (EQSettled (WorkFresh intro S tag)
                   (in-hole FF (More hole)))
        O)]

      [(evaluate-query/direct
        (EQContinue
         W
         (in-hole FF
                  (Emit (control-freeze/K S) (More hole))))
        O)
       ---------------------------------------------------- "direct commit left answer"
       (evaluate-query/direct
        (EQSettled (DisjL S W)
                   (in-hole FF (More hole)))
        O)]

      [(evaluate-query/direct
        (EQContinue
         W
         (in-hole FF
                  (Emit (control-freeze/K S) (More hole))))
        O)
       ---------------------------------------------------- "direct commit right answer"
       (evaluate-query/direct
        (EQSettled (DisjR W S)
                   (in-hole FF (More hole)))
        O)]

      [(evaluate-query/direct
        (EQSettled (WorkFresh intro S tag) LF)
        O)
       ---------------------------------------------------- "direct cross fresh success"
       (evaluate-query/direct
        (EQSettled S (in-hole LF (WorkFresh intro hole tag)))
        O)]

      [(evaluate-query/direct
        (EQSettled
         (DisjL (WorkFresh intro S tag)
                (WorkFresh intro W tag))
         LF)
        O)
       ---------------------------------------------------- "direct expose left at fresh frame"
       (evaluate-query/direct
        (EQSettled
         (DisjL S W)
         (in-hole LF (WorkFresh intro hole tag)))
        O)]

      [(evaluate-query/direct
        (EQSettled
         (DisjR (WorkFresh intro W tag)
                (WorkFresh intro S tag))
         LF)
        O)
       ---------------------------------------------------- "direct expose right at fresh frame"
       (evaluate-query/direct
        (EQSettled
         (DisjR W S)
         (in-hole LF (WorkFresh intro hole tag)))
        O)]

      [(evaluate-query/direct
        (EQAfter (control-resume/K S g) WF)
        O)
       ---------------------------------------------------- "direct settled through conjunction"
       (evaluate-query/direct
        (EQSettled S (in-hole WF (Conj hole g)))
        O)]

      [(evaluate-query/direct
        (EQAfter
         (DisjL (control-resume/K S g) (Conj W g))
         WF)
        O)
       ---------------------------------------------------- "direct settled left through conjunction"
       (evaluate-query/direct
        (EQSettled (DisjL S W) (in-hole WF (Conj hole g)))
        O)]

      [(evaluate-query/direct
        (EQAfter
         (DisjR (Conj W g) (control-resume/K S g))
         WF)
        O)
       ---------------------------------------------------- "direct settled right through conjunction"
       (evaluate-query/direct
        (EQSettled (DisjR W S) (in-hole WF (Conj hole g)))
        O)]

      [(evaluate-query/direct
        (EQSettled (DisjL S W) WF)
        O)
       ---------------------------------------------------- "direct form left choice"
       (evaluate-query/direct
        (EQSettled S (in-hole WF (DisjL hole W)))
        O)]

      [(evaluate-query/direct
        (EQSettled
         (DisjL (direct-choice-success SC)
                (DisjL (direct-choice-alternate SC) W_2))
         WF)
        O)
       ---------------------------------------------------- "direct reassociate settled left frame"
       (evaluate-query/direct
        (EQSettled SC (in-hole WF (DisjL hole W_2)))
        O)]

      [(evaluate-query/direct
        (EQSettled (DisjR W S) WF)
        O)
       ---------------------------------------------------- "direct form right choice"
       (evaluate-query/direct
        (EQSettled S (in-hole WF (DisjR W hole)))
        O)]

      [(evaluate-query/direct
        (EQSettled
         (DisjR
          (DisjR W_1 (direct-choice-alternate SC))
          (direct-choice-success SC))
         WF)
        O)
       ---------------------------------------------------- "direct reassociate settled right frame"
       (evaluate-query/direct
        (EQSettled SC (in-hole WF (DisjR W_1 hole)))
        O)]

      ;; Failure and delay propagation.
      [(evaluate-query/direct (EQFinal Done FF) O)
       ---------------------------------------------------- "direct finish failure"
       (evaluate-query/direct
        (EQDead (in-hole FF (More hole)))
        O)]

      [(evaluate-query/direct (EQDead LF) O)
       ---------------------------------------------------- "direct dead through fresh"
       (evaluate-query/direct
        (EQDead (in-hole LF (WorkFresh intro hole tag)))
        O)]

      [(evaluate-query/direct (EQDead WF) O)
       ---------------------------------------------------- "direct dead through conjunction"
       (evaluate-query/direct
        (EQDead (in-hole WF (Conj hole g)))
        O)]

      [(evaluate-query/direct (EQContinue W WF) O)
       ---------------------------------------------------- "direct dead skips left"
       (evaluate-query/direct
        (EQDead (in-hole WF (DisjL hole W)))
        O)]

      [(evaluate-query/direct (EQContinue W WF) O)
       ---------------------------------------------------- "direct dead skips right"
       (evaluate-query/direct
        (EQDead (in-hole WF (DisjR W hole)))
        O)]

      [(evaluate-query/direct
        (EQContinue W (in-hole FF (Forced (More hole))))
        O)
       ---------------------------------------------------- "direct force delay"
       (evaluate-query/direct
        (EQDelay W (in-hole FF (More hole)))
        O)]

      [(evaluate-query/direct
        (EQDelay (WorkFresh intro W tag) LF)
        O)
       ---------------------------------------------------- "direct delay through fresh"
       (evaluate-query/direct
        (EQDelay W (in-hole LF (WorkFresh intro hole tag)))
        O)]

      [(evaluate-query/direct (EQDelay (Conj W g) WF) O)
       ---------------------------------------------------- "direct delay through conjunction"
       (evaluate-query/direct
        (EQDelay W (in-hole WF (Conj hole g)))
        O)]

      [(evaluate-query/direct
        (EQDelay (DisjR W_1 W_2) WF)
        O)
       ---------------------------------------------------- "direct delay enters right rail"
       (evaluate-query/direct
        (EQDelay W_1 (in-hole WF (DisjL hole W_2)))
        O)]

      [(evaluate-query/direct
        (EQDelay (DisjL W_1 W_2) WF)
        O)
       ---------------------------------------------------- "direct delay returns left rail"
       (evaluate-query/direct
        (EQDelay W_2 (in-hole WF (DisjR W_1 hole)))
        O)]

      [---------------------------------------------------- "direct final"
       (evaluate-query/direct
        (EQFinal T FF)
        (FinalResult T FF))])

    ;; Five visible fixed-point mode entries.
    (define-judgment-form
      big-step-direct-lang
      #:contract (big-run/direct NW WF O)
      #:mode (big-run/direct I I O)
      [(evaluate-query/direct (EQRun NW WF) O)
       ---------------------------------------------------- "big run/direct"
       (big-run/direct NW WF O)])

    (define-judgment-form
      big-step-direct-lang
      #:contract (big-settled/direct SR WF O)
      #:mode (big-settled/direct I I O)
      [(evaluate-query/direct (EQSettled SR WF) O)
       ---------------------------------------------------- "big settled/direct"
       (big-settled/direct SR WF O)])

    (define-judgment-form
      big-step-direct-lang
      #:contract (big-dead/direct WF O)
      #:mode (big-dead/direct I O)
      [(evaluate-query/direct (EQDead WF) O)
       ---------------------------------------------------- "big dead/direct"
       (big-dead/direct WF O)])

    (define-judgment-form
      big-step-direct-lang
      #:contract (big-delay/direct W WF O)
      #:mode (big-delay/direct I I O)
      [(evaluate-query/direct (EQDelay W WF) O)
       ---------------------------------------------------- "big delay/direct"
       (big-delay/direct W WF O)])

    (define-judgment-form
      big-step-direct-lang
      #:contract (big-final/direct T FF O)
      #:mode (big-final/direct I I O)
      [(evaluate-query/direct (EQFinal T FF) O)
       ---------------------------------------------------- "big final/direct"
       (big-final/direct T FF O)])

    (define-judgment-form
      big-step-direct-lang
      #:contract (promote/direct B O)
      #:mode (promote/direct I O)

      [(big-run/direct NW WF O)
       ---------------------------------------------------- "promote run"
       (promote/direct (BRun NW WF) O)]

      [(big-settled/direct SR WF O)
       ---------------------------------------------------- "promote settled"
       (promote/direct (BSettled SR WF) O)]

      [(big-dead/direct WF O)
       ---------------------------------------------------- "promote dead"
       (promote/direct (BDead WF) O)]

      [(big-delay/direct W WF O)
       ---------------------------------------------------- "promote delay"
       (promote/direct (BDelay W WF) O)]

      [(big-final/direct T FF O)
       ---------------------------------------------------- "promote final"
       (promote/direct (BFinal T FF) O)])

    (define-judgment-form
      big-step-direct-lang
      #:contract (big-step/direct F O)
      #:mode (big-step/direct I O)

      [(wf-frontier/K F)
       (evaluate-query/direct (EQRoot F hole) O)
       ---------------------------------------------------- "direct root big-step"
       (big-step/direct F O)])))
