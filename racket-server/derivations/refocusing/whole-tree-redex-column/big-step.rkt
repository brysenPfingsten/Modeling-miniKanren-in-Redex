#lang racket

(require redex/reduction-semantics
         "./big-step-language.rkt"
         "./kernel-toy.rkt")

(provide redex-column-big-step-direct-lang
         evaluate-query/direct
         big-run/direct
         big-settled/direct
         big-dead/direct
         big-delay/direct
         big-final/direct
         promote/direct
         big-step/direct)

(check-redundancy #t)

;; EQ terms are derivation program points, not semantic states.  They let one
;; Redex judgment state the mutually recursive promoted evaluator without a
;; host-language dispatcher.  NF is the positive complement of WorkFresh at
;; the outer constructor and is used only to make after-unfinished disjoint.
(define-extended-language redex-column-big-step-direct-lang
  redex-column-big-step-lang
  [NF (Work g st)
      (Returned st)
      Dead
      (Conj W g)
      (PendingDelay W)
      (DisjL W W)
      (DisjR W W)]
  ;; Running work whose outer constructor is not WorkFresh.  This makes the
  ;; More-boundary dispatcher disjoint from its WorkFresh-priority clause.
  [NR (Work g st)
      (Conj W g)
      (DisjL NW W)
      (DisjL Dead W)
      (DisjL (PendingDelay W) W)
      (DisjL SC W)
      (DisjR W NW)
      (DisjR W Dead)
      (DisjR W (PendingDelay W))
      (DisjR W SC)]
  [EQ (EQRoot F FF)
      (EQContinue W WF)
      (EQAfter W WF)
      (EQRun NW WF)
      (EQLocal NR WF)
      (EQAtomic g st WF)
      (EQFresh intro W tag WF+)
      (EQConj W g WF)
      (EQLeft W W WF)
      (EQRight W W WF)
      (EQSettled SR WF)
      (EQDead WF)
      (EQDelay W WF)
      (EQFinal T FF)])

(define-metafunction redex-column-big-step-direct-lang
  direct-choice-success : SC -> S
  [(direct-choice-success (DisjL S W)) S]
  [(direct-choice-success (DisjR W S)) S])

(define-metafunction redex-column-big-step-direct-lang
  direct-choice-alternate : SC -> W
  [(direct-choice-alternate (DisjL S W)) W]
  [(direct-choice-alternate (DisjR W S)) W])

;; Fixed-point promotion of the five compressed control modes.  Recursive
;; premises mention only derivation queries and the final result; there are no
;; B states, spans, transition relations, earlier-stage calls, or host control
;; dispatchers in this artifact.
(define-judgment-form
  redex-column-big-step-direct-lang
  #:contract (evaluate-query/direct EQ O)
  #:mode (evaluate-query/direct I O)

  ;; Root entry accumulates an actual F-to-F context.
  [(evaluate-query/direct
    (EQRoot F (in-hole FF (Emit A hole)))
    O)
   ---------------------------------------------------- "direct root emit"
   (evaluate-query/direct (EQRoot (Emit A F) FF) O)]

  [(evaluate-query/direct
    (EQRoot F
            (in-hole FF
                     (FrontierFresh intro hole tag)))
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

  ;; Constructor-erased residual dispatcher.
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

  ;; Fixed-point image of after-unfinished.  The first clause performs the
  ;; statically known More-boundary exposure.  NF and WF+ make the two stop
  ;; cases positive and disjoint.
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

  [(evaluate-query/direct
    (EQContinue NF (in-hole FF (More hole)))
    O)
   ---------------------------------------------------- "direct after root nonfresh"
   (evaluate-query/direct
    (EQAfter NF (in-hole FF (More hole)))
    O)]

  [(evaluate-query/direct (EQContinue W WF+) O)
   ---------------------------------------------------- "direct after nonroot"
   (evaluate-query/direct (EQAfter W WF+) O)]

  ;; Downward run dispatcher, with More-boundary priority.
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

  [(evaluate-query/direct
    (EQLocal NR (in-hole FF (More hole)))
    O)
   ---------------------------------------------------- "direct run root nonfresh"
   (evaluate-query/direct
    (EQRun NR (in-hole FF (More hole)))
    O)]

  [(evaluate-query/direct
    (EQFresh intro W tag WF+)
    O)
   ---------------------------------------------------- "direct run nonroot fresh"
   (evaluate-query/direct
    (EQRun (WorkFresh intro W tag) WF+)
    O)]

  [(evaluate-query/direct (EQLocal NR WF+) O)
   ---------------------------------------------------- "direct run nonroot nonfresh"
   (evaluate-query/direct (EQRun NR WF+) O)]

  ;; Local constructor dispatcher.
  [(evaluate-query/direct (EQAtomic g st WF) O)
   ---------------------------------------------------- "direct local atomic"
   (evaluate-query/direct (EQLocal (Work g st) WF) O)]

  [(evaluate-query/direct (EQConj W g WF) O)
   ---------------------------------------------------- "direct local conjunction"
   (evaluate-query/direct (EQLocal (Conj W g) WF) O)]

  [(evaluate-query/direct (EQLeft W_1 W_2 WF) O)
   ---------------------------------------------------- "direct local left"
   (evaluate-query/direct (EQLocal (DisjL W_1 W_2) WF) O)]

  [(evaluate-query/direct (EQRight W_1 W_2 WF) O)
   ---------------------------------------------------- "direct local right"
   (evaluate-query/direct (EQLocal (DisjR W_1 W_2) WF) O)]

  ;; Atomic kernel producers.
  [(evaluate-query/direct
    (EQSettled (Returned st) WF)
    O)
   ---------------------------------------------------- "direct work succeed"
   (evaluate-query/direct
    (EQAtomic (succeed tag) st WF)
    O)]

  [(evaluate-query/direct (EQDead WF) O)
   ---------------------------------------------------- "direct work fail"
   (evaluate-query/direct
    (EQAtomic (fail tag) st WF)
    O)]

  [(evaluate-query/direct
    (EQSettled (Returned (kernel-put p st)) WF)
    O)
   ---------------------------------------------------- "direct work put"
   (evaluate-query/direct
    (EQAtomic (put p tag) st WF)
    O)]

  [(where F_whole
          (in-hole WF
                   (Work (fresh (x ...) g tag_fresh) st)))
   (where (u_new ...)
          (kernel-fresh (x ...) F_whole))
   (where g_new
          (kernel-substitute g ((x u_new) ...)))
   (evaluate-query/direct
    (EQAfter
     (WorkFresh (u_new ...)
                (Work g_new st)
                tag_fresh)
     WF)
    O)
   ---------------------------------------------------- "direct allocate fresh"
   (evaluate-query/direct
    (EQAtomic (fresh (x ...) g tag_fresh) st WF)
    O)]

  [(evaluate-query/direct
    (EQAfter (Conj (Work g_1 st) g_2) WF)
    O)
   ---------------------------------------------------- "direct expand conjunction"
   (evaluate-query/direct
    (EQAtomic (conj g_1 g_2 tag) st WF)
    O)]

  [(evaluate-query/direct
    (EQAfter
     (DisjL (Work g_1 st) (Work g_2 st))
     WF)
    O)
   ---------------------------------------------------- "direct expand disjunction"
   (evaluate-query/direct
    (EQAtomic (disj g_1 g_2 tag) st WF)
    O)]

  [(evaluate-query/direct
    (EQDelay (Work g st) WF)
    O)
   ---------------------------------------------------- "direct suspend goal"
   (evaluate-query/direct
    (EQAtomic (suspend g tag) st WF)
    O)]

  ;; WorkFresh dispatcher.
  [(evaluate-query/direct
    (EQSettled (WorkFresh intro S tag) WF+)
    O)
   ---------------------------------------------------- "direct fresh success"
   (evaluate-query/direct
    (EQFresh intro S tag WF+)
    O)]

  [(evaluate-query/direct
    (EQSettled
     (DisjL (WorkFresh intro S tag)
            (WorkFresh intro W tag))
     WF+)
    O)
   ---------------------------------------------------- "direct expose left through fresh"
   (evaluate-query/direct
    (EQFresh intro (DisjL S W) tag WF+)
    O)]

  [(evaluate-query/direct
    (EQSettled
     (DisjR (WorkFresh intro W tag)
            (WorkFresh intro S tag))
     WF+)
    O)
   ---------------------------------------------------- "direct expose right through fresh"
   (evaluate-query/direct
    (EQFresh intro (DisjR W S) tag WF+)
    O)]

  [(evaluate-query/direct (EQDead WF+) O)
   ---------------------------------------------------- "direct erase dead fresh"
   (evaluate-query/direct
    (EQFresh intro Dead tag WF+)
    O)]

  [(evaluate-query/direct
    (EQDelay (WorkFresh intro W tag) WF+)
    O)
   ---------------------------------------------------- "direct bubble fresh delay"
   (evaluate-query/direct
    (EQFresh intro (PendingDelay W) tag WF+)
    O)]

  [(evaluate-query/direct
    (EQRun NW
           (in-hole WF+
                    (WorkFresh intro hole tag)))
    O)
   ---------------------------------------------------- "direct descend fresh"
   (evaluate-query/direct
    (EQFresh intro NW tag WF+)
    O)]

  ;; Conjunction dispatcher.
  [(evaluate-query/direct
    (EQAfter (kernel-resume S g) WF)
    O)
   ---------------------------------------------------- "direct conjunction return"
   (evaluate-query/direct (EQConj S g WF) O)]

  [(evaluate-query/direct (EQDead WF) O)
   ---------------------------------------------------- "direct conjunction failure"
   (evaluate-query/direct (EQConj Dead g WF) O)]

  [(evaluate-query/direct
    (EQDelay (Conj W g) WF)
    O)
   ---------------------------------------------------- "direct conjunction delay"
   (evaluate-query/direct
    (EQConj (PendingDelay W) g WF)
    O)]

  [(evaluate-query/direct
    (EQAfter
     (DisjL (kernel-resume S g) (Conj W g))
     WF)
    O)
   ---------------------------------------------------- "direct late distribute left"
   (evaluate-query/direct
    (EQConj (DisjL S W) g WF)
    O)]

  [(evaluate-query/direct
    (EQAfter
     (DisjR (Conj W g) (kernel-resume S g))
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
   ---------------------------------------------------- "direct settled left"
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
   ---------------------------------------------------- "direct settled right"
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

  ;; Settled-result upward dispatcher over indexed actual-hole contexts.
  [(evaluate-query/direct
    (EQFinal (Last (Answer st)) FF)
    O)
   ---------------------------------------------------- "direct finish success"
   (evaluate-query/direct
    (EQSettled (Returned st)
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
              (Emit (kernel-freeze S) (More hole))))
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
              (Emit (kernel-freeze S) (More hole))))
    O)
   ---------------------------------------------------- "direct commit right answer"
   (evaluate-query/direct
    (EQSettled (DisjR W S)
               (in-hole FF (More hole)))
    O)]

  [(evaluate-query/direct
    (EQSettled
     (WorkFresh intro S tag)
     (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct cross fresh success"
   (evaluate-query/direct
    (EQSettled
     S
     (in-hole FF
              (More
               (in-hole TopW
                        (WorkFresh intro hole tag)))))
    O)]

  [(evaluate-query/direct
    (EQSettled
     (DisjL (WorkFresh intro S tag)
            (WorkFresh intro W tag))
     (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct expose left at fresh frame"
   (evaluate-query/direct
    (EQSettled
     (DisjL S W)
     (in-hole FF
              (More
               (in-hole TopW
                        (WorkFresh intro hole tag)))))
    O)]

  [(evaluate-query/direct
    (EQSettled
     (DisjR (WorkFresh intro W tag)
            (WorkFresh intro S tag))
     (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct expose right at fresh frame"
   (evaluate-query/direct
    (EQSettled
     (DisjR W S)
     (in-hole FF
              (More
               (in-hole TopW
                        (WorkFresh intro hole tag)))))
    O)]

  [(evaluate-query/direct
    (EQAfter
     (kernel-resume S g)
     (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct settled through conjunction"
   (evaluate-query/direct
    (EQSettled
     S
     (in-hole FF
              (More (in-hole TopW (Conj hole g)))))
    O)]

  [(evaluate-query/direct
    (EQAfter
     (DisjL (kernel-resume S g) (Conj W g))
     (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct settled left through conjunction"
   (evaluate-query/direct
    (EQSettled
     (DisjL S W)
     (in-hole FF
              (More (in-hole TopW (Conj hole g)))))
    O)]

  [(evaluate-query/direct
    (EQAfter
     (DisjR (Conj W g) (kernel-resume S g))
     (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct settled right through conjunction"
   (evaluate-query/direct
    (EQSettled
     (DisjR W S)
     (in-hole FF
              (More (in-hole TopW (Conj hole g)))))
    O)]

  [(evaluate-query/direct
    (EQSettled (DisjL S W)
               (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct form left choice"
   (evaluate-query/direct
    (EQSettled
     S
     (in-hole FF
              (More (in-hole TopW (DisjL hole W)))))
    O)]

  [(evaluate-query/direct
    (EQSettled
     (DisjL (direct-choice-success SC)
            (DisjL (direct-choice-alternate SC) W_2))
     (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct reassociate settled left frame"
   (evaluate-query/direct
    (EQSettled
     SC
     (in-hole FF
              (More (in-hole TopW (DisjL hole W_2)))))
    O)]

  [(evaluate-query/direct
    (EQSettled (DisjR W S)
               (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct form right choice"
   (evaluate-query/direct
    (EQSettled
     S
     (in-hole FF
              (More (in-hole TopW (DisjR W hole)))))
    O)]

  [(evaluate-query/direct
    (EQSettled
     (DisjR
      (DisjR W_1 (direct-choice-alternate SC))
      (direct-choice-success SC))
     (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct reassociate settled right frame"
   (evaluate-query/direct
    (EQSettled
     SC
     (in-hole FF
              (More (in-hole TopW (DisjR W_1 hole)))))
    O)]

  ;; Failure and delay propagation.
  [(evaluate-query/direct (EQFinal Done FF) O)
   ---------------------------------------------------- "direct finish failure"
   (evaluate-query/direct
    (EQDead (in-hole FF (More hole)))
    O)]

  [(evaluate-query/direct
    (EQDead (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct dead through fresh"
   (evaluate-query/direct
    (EQDead
     (in-hole FF
              (More
               (in-hole TopW
                        (WorkFresh intro hole tag)))))
    O)]

  [(evaluate-query/direct
    (EQDead (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct dead through conjunction"
   (evaluate-query/direct
    (EQDead
     (in-hole FF
              (More (in-hole TopW (Conj hole g)))))
    O)]

  [(evaluate-query/direct
    (EQContinue W (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct dead skips left"
   (evaluate-query/direct
    (EQDead
     (in-hole FF
              (More (in-hole TopW (DisjL hole W)))))
    O)]

  [(evaluate-query/direct
    (EQContinue W (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct dead skips right"
   (evaluate-query/direct
    (EQDead
     (in-hole FF
              (More (in-hole TopW (DisjR W hole)))))
    O)]

  [(evaluate-query/direct
    (EQContinue
     W
     (in-hole FF (Forced (More hole))))
    O)
   ---------------------------------------------------- "direct force delay"
   (evaluate-query/direct
    (EQDelay W (in-hole FF (More hole)))
    O)]

  [(evaluate-query/direct
    (EQDelay
     (WorkFresh intro W tag)
     (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct delay through fresh"
   (evaluate-query/direct
    (EQDelay
     W
     (in-hole FF
              (More
               (in-hole TopW
                        (WorkFresh intro hole tag)))))
    O)]

  [(evaluate-query/direct
    (EQDelay (Conj W g)
             (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct delay through conjunction"
   (evaluate-query/direct
    (EQDelay
     W
     (in-hole FF
              (More (in-hole TopW (Conj hole g)))))
    O)]

  [(evaluate-query/direct
    (EQDelay (DisjR W_1 W_2)
             (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct delay enters right rail"
   (evaluate-query/direct
    (EQDelay
     W_1
     (in-hole FF
              (More (in-hole TopW (DisjL hole W_2)))))
    O)]

  [(evaluate-query/direct
    (EQDelay (DisjL W_1 W_2)
             (in-hole FF (More TopW)))
    O)
   ---------------------------------------------------- "direct delay returns left rail"
   (evaluate-query/direct
    (EQDelay
     W_2
     (in-hole FF
              (More (in-hole TopW (DisjR W_1 hole)))))
    O)]

  ;; Category-specific terminal result.
  [---------------------------------------------------- "direct final"
   (evaluate-query/direct
    (EQFinal T FF)
    (FinalResult T FF))])

;; The five visible entry judgments are the promoted images of the five
;; compressed state constructors.  Their signatures retain only grammatical
;; payloads and indexed contexts.
(define-judgment-form
  redex-column-big-step-direct-lang
  #:contract (big-run/direct NW WF O)
  #:mode (big-run/direct I I O)
  [(evaluate-query/direct (EQRun NW WF) O)
   ---------------------------------------------------- "big run/direct"
   (big-run/direct NW WF O)])

(define-judgment-form
  redex-column-big-step-direct-lang
  #:contract (big-settled/direct SR WF O)
  #:mode (big-settled/direct I I O)
  [(evaluate-query/direct (EQSettled SR WF) O)
   ---------------------------------------------------- "big settled/direct"
   (big-settled/direct SR WF O)])

(define-judgment-form
  redex-column-big-step-direct-lang
  #:contract (big-dead/direct WF O)
  #:mode (big-dead/direct I O)
  [(evaluate-query/direct (EQDead WF) O)
   ---------------------------------------------------- "big dead/direct"
   (big-dead/direct WF O)])

(define-judgment-form
  redex-column-big-step-direct-lang
  #:contract (big-delay/direct W WF O)
  #:mode (big-delay/direct I I O)
  [(evaluate-query/direct (EQDelay W WF) O)
   ---------------------------------------------------- "big delay/direct"
   (big-delay/direct W WF O)])

(define-judgment-form
  redex-column-big-step-direct-lang
  #:contract (big-final/direct T FF O)
  #:mode (big-final/direct I I O)
  [(evaluate-query/direct (EQFinal T FF) O)
   ---------------------------------------------------- "big final/direct"
   (big-final/direct T FF O)])

;; The B-to-promoted artifact is an explicit Redex arrow.  It is deliberately
;; nonrecursive: recursion remains wholly within the B-free mode judgments.
(define-judgment-form
  redex-column-big-step-direct-lang
  #:contract (promote/direct B O)
  #:mode (promote/direct I O)
  [(big-run/direct NW WF O)
   ---------------------------------------------------- "promote run/direct"
   (promote/direct (BRun NW WF) O)]
  [(big-settled/direct SR WF O)
   ---------------------------------------------------- "promote settled/direct"
   (promote/direct (BSettled SR WF) O)]
  [(big-dead/direct WF O)
   ---------------------------------------------------- "promote dead/direct"
   (promote/direct (BDead WF) O)]
  [(big-delay/direct W WF O)
   ---------------------------------------------------- "promote delay/direct"
   (promote/direct (BDelay W WF) O)]
  [(big-final/direct T FF O)
   ---------------------------------------------------- "promote final/direct"
   (promote/direct (BFinal T FF) O)])

(define-judgment-form
  redex-column-big-step-direct-lang
  #:contract (big-step/direct F O)
  #:mode (big-step/direct I O)
  [(wf-frontier/toy F)
   (evaluate-query/direct (EQRoot F hole) O)
   ---------------------------------------------------- "big-step root/direct"
   (big-step/direct F O)])
