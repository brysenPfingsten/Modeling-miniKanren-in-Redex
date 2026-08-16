#lang racket

(require redex/reduction-semantics
         "./kernel-toy.rkt"
         "./labels.rkt"
         (only-in "./machine.rkt"
                  redex-column-machine-lang))

(provide redex-column-compressed-lang
         residual-state
         symbolic-path/direct
         compressed-step/direct
         compressed-steps/direct
         initial-compressed-query/direct
         initial-compressed/direct
         compressed-readback
         reachable-compressed/via
         compressed-red/direct)

(check-redundancy #t)

(define-extended-language redex-column-compressed-lang
  redex-column-machine-lang
  [SR S SC]
  ;; Exact grammatical complement of SR within W.  Keeping this
  ;; classification in the transformed language makes downward dispatch a
  ;; Redex grammar decision, with no call back into refocused control.
  [NW (Work g st)
      (WorkFresh intro NW tag)
      (WorkFresh intro Dead tag)
      (WorkFresh intro (PendingDelay W) tag)
      (WorkFresh intro SC tag)
      (Conj W g)
      (DisjL NW W)
      (DisjL Dead W)
      (DisjL (PendingDelay W) W)
      (DisjL SC W)
      (DisjR W NW)
      (DisjR W Dead)
      (DisjR W (PendingDelay W))
      (DisjR W SC)]
  [B (BRun W WF)
     (BSettled SR WF)
     (BDead WF)
     (BDelay W WF)
     (BFinal T FF)]
  [Marks (ell ...)]
  ;; Public certificates are nonempty by grammar, not by a runtime guard.
  [Span (transition-span ell ell ...)]
  [Spans (Span ...)]
  [Path no-path
        (path Marks B)]
  ;; Private derivation program points, never operational states.
  [BQ (BQRun W WF)
      (BQLocal W WF)
      (BQAtomic g st WF)
      (BQFresh intro W tag WF)
      (BQConj W g WF)
      (BQLeft W W WF)
      (BQRight W W WF)
      (BQSettled SR WF)
      (BQDead WF)
      (BQDelay W WF)
      (BQAfter W WF)])

(define-metafunction redex-column-compressed-lang
  compressed-choice-success : SC -> S
  [(compressed-choice-success (DisjL S W)) S]
  [(compressed-choice-success (DisjR W S)) S])

(define-metafunction redex-column-compressed-lang
  compressed-choice-alternate : SC -> W
  [(compressed-choice-alternate (DisjL S W)) W]
  [(compressed-choice-alternate (DisjR W S)) W])

(define-metafunction redex-column-compressed-lang
  residual-state : W WF -> B
  [(residual-state Dead WF) (BDead WF)]
  [(residual-state (PendingDelay W) WF) (BDelay W WF)]
  [(residual-state SR WF) (BSettled SR WF)]
  [(residual-state NW WF) (BRun NW WF)])

(define-metafunction redex-column-compressed-lang
  prepend-path : ell Path -> Path
  [(prepend-path ell no-path) no-path]
  [(prepend-path ell (path (ell_rest ...) B))
   (path (ell ell_rest ...) B)])

;; `after-unfinished` performs the one statically known boundary exposure and
;; otherwise stops at a residual dispatcher.  This is symbolic composition,
;; not exact-machine replay.
(define-metafunction redex-column-compressed-lang
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

;; The authoritative direct compression equations.  All recursion is over BQ
;; derivation queries.  Every source rule is a first-class `ell` datum.
(define-judgment-form
  redex-column-compressed-lang
  #:contract (symbolic-path/direct BQ Path)
  #:mode (symbolic-path/direct I O)

  ;; Downward dispatcher: More has first priority.
  [---------------------------------------------------- "compress root WorkFresh"
   (symbolic-path/direct
    (BQRun (WorkFresh intro W tag)
           (in-hole FF (More hole)))
    (path
     ((expose-frontier-fresh core))
     (residual-state
      W
      (in-hole FF
               (FrontierFresh intro (More hole) tag))))) ]

  [(symbolic-path/direct
    (BQSettled (Returned st) (in-hole FF (More hole)))
    Path)
   ---------------------------------------------------- "compress root returned"
   (symbolic-path/direct
    (BQRun (Returned st) (in-hole FF (More hole)))
    Path)]

  [(symbolic-path/direct
    (BQSettled SC (in-hole FF (More hole)))
    Path)
   ---------------------------------------------------- "compress root settled choice"
   (symbolic-path/direct
    (BQRun SC (in-hole FF (More hole)))
    Path)]

  [(symbolic-path/direct (BQDead (in-hole FF (More hole))) Path)
   ---------------------------------------------------- "compress root dead"
   (symbolic-path/direct
    (BQRun Dead (in-hole FF (More hole)))
    Path)]

  [(symbolic-path/direct
    (BQDelay W (in-hole FF (More hole)))
    Path)
   ---------------------------------------------------- "compress root delay"
   (symbolic-path/direct
    (BQRun (PendingDelay W) (in-hole FF (More hole)))
    Path)]

  [(symbolic-path/direct
    (BQLocal (Work g st) (in-hole FF (More hole)))
    Path)
   ---------------------------------------------------- "compress root atomic"
   (symbolic-path/direct
    (BQRun (Work g st) (in-hole FF (More hole)))
    Path)]

  [(symbolic-path/direct
    (BQLocal (Conj W g) (in-hole FF (More hole)))
    Path)
   ---------------------------------------------------- "compress root conjunction"
   (symbolic-path/direct
    (BQRun (Conj W g) (in-hole FF (More hole)))
    Path)]

  [(symbolic-path/direct
    (BQLeft W_1 W_2 (in-hole FF (More hole)))
    Path)
   ---------------------------------------------------- "compress root left choice"
   (symbolic-path/direct
    (BQRun (DisjL W_1 W_2) (in-hole FF (More hole)))
    Path)]

  [(symbolic-path/direct
    (BQRight W_1 W_2 (in-hole FF (More hole)))
    Path)
   ---------------------------------------------------- "compress root right choice"
   (symbolic-path/direct
    (BQRun (DisjR W_1 W_2) (in-hole FF (More hole)))
    Path)]

  [(symbolic-path/direct (BQLocal W WF+) Path)
   ---------------------------------------------------- "compress nonroot run"
   (symbolic-path/direct (BQRun W WF+) Path)]

  ;; Constructor dispatcher outside the More-priority case.
  [(symbolic-path/direct (BQAtomic g st WF) Path)
   ---------------------------------------------------- "compress local atomic"
   (symbolic-path/direct (BQLocal (Work g st) WF) Path)]

  [(symbolic-path/direct (BQSettled (Returned st) WF) Path)
   ---------------------------------------------------- "compress local returned"
   (symbolic-path/direct (BQLocal (Returned st) WF) Path)]

  [(symbolic-path/direct (BQDead WF) Path)
   ---------------------------------------------------- "compress local dead"
   (symbolic-path/direct (BQLocal Dead WF) Path)]

  [(symbolic-path/direct (BQDelay W WF) Path)
   ---------------------------------------------------- "compress local delay"
   (symbolic-path/direct (BQLocal (PendingDelay W) WF) Path)]

  [(symbolic-path/direct (BQFresh intro W tag WF) Path)
   ---------------------------------------------------- "compress local fresh"
   (symbolic-path/direct
    (BQLocal (WorkFresh intro W tag) WF)
    Path)]

  [(symbolic-path/direct (BQConj W g WF) Path)
   ---------------------------------------------------- "compress local conjunction"
   (symbolic-path/direct (BQLocal (Conj W g) WF) Path)]

  [(symbolic-path/direct (BQLeft W_1 W_2 WF) Path)
   ---------------------------------------------------- "compress local left choice"
   (symbolic-path/direct (BQLocal (DisjL W_1 W_2) WF) Path)]

  [(symbolic-path/direct (BQRight W_1 W_2 WF) Path)
   ---------------------------------------------------- "compress local right choice"
   (symbolic-path/direct (BQLocal (DisjR W_1 W_2) WF) Path)]

  ;; Atomic producer clauses.
  [(symbolic-path/direct
    (BQSettled (Returned st) WF)
    Path_1)
   (where Path_2
          (prepend-path (work-succeed core) Path_1))
   ---------------------------------------------------- "compress work succeed"
   (symbolic-path/direct
    (BQAtomic (succeed tag) st WF)
    Path_2)]

  [(symbolic-path/direct (BQDead WF) Path_1)
   (where Path_2
          (prepend-path (work-fail core) Path_1))
   ---------------------------------------------------- "compress work fail"
   (symbolic-path/direct
    (BQAtomic (fail tag) st WF)
    Path_2)]

  [(symbolic-path/direct
    (BQSettled (Returned (kernel-put p st)) WF)
    Path_1)
   (where Path_2
          (prepend-path (work-put core) Path_1))
   ---------------------------------------------------- "compress work put"
   (symbolic-path/direct
    (BQAtomic (put p tag) st WF)
    Path_2)]

  [(where F_whole
          (in-hole WF
                   (Work (fresh (x ...) g tag_fresh) st)))
   (where (u_new ...) (kernel-fresh (x ...) F_whole))
   (where g_new
          (kernel-substitute g ((x u_new) ...)))
   (where Path_1
          (after-unfinished
           (WorkFresh (u_new ...) (Work g_new st) tag_fresh)
           WF))
   (where Path_2
          (prepend-path (allocate-fresh core) Path_1))
   ---------------------------------------------------- "compress allocate fresh"
   (symbolic-path/direct
    (BQAtomic (fresh (x ...) g tag_fresh) st WF)
    Path_2)]

  [(where Path_1
          (after-unfinished
           (Conj (Work g_1 st) g_2)
           WF))
   (where Path_2
          (prepend-path (expand-conjunction core) Path_1))
   ---------------------------------------------------- "compress expand conjunction"
   (symbolic-path/direct
    (BQAtomic (conj g_1 g_2 tag) st WF)
    Path_2)]

  [(where Path_1
          (after-unfinished
           (DisjL (Work g_1 st) (Work g_2 st))
           WF))
   (where Path_2
          (prepend-path (expand-disjunction disj) Path_1))
   ---------------------------------------------------- "compress expand disjunction"
   (symbolic-path/direct
    (BQAtomic (disj g_1 g_2 tag) st WF)
    Path_2)]

  [(symbolic-path/direct (BQDelay (Work g st) WF) Path_1)
   (where Path_2
          (prepend-path (suspend-goal delay) Path_1))
   ---------------------------------------------------- "compress suspend goal"
   (symbolic-path/direct
    (BQAtomic (suspend g tag) st WF)
    Path_2)]

  ;; WorkFresh dispatcher.
  [(symbolic-path/direct
    (BQSettled (WorkFresh intro S tag) WF)
    Path)
   ---------------------------------------------------- "compress settled fresh success"
   (symbolic-path/direct (BQFresh intro S tag WF) Path)]

  [---------------------------------------------------- "compress expose left through fresh"
   (symbolic-path/direct
    (BQFresh intro (DisjL S W) tag WF)
    (path
     ((expose-choice-through-work-fresh disj))
     (BSettled
      (DisjL (WorkFresh intro S tag)
             (WorkFresh intro W tag))
      WF)))]

  [---------------------------------------------------- "compress expose right through fresh"
   (symbolic-path/direct
    (BQFresh intro (DisjR W S) tag WF)
    (path
     ((expose-choice-through-work-fresh search-join))
     (BSettled
      (DisjR (WorkFresh intro W tag)
             (WorkFresh intro S tag))
      WF)))]

  [---------------------------------------------------- "compress erase dead fresh"
   (symbolic-path/direct
    (BQFresh intro Dead tag WF)
    (path ((erase-dead-fresh core)) (BDead WF)))]

  [---------------------------------------------------- "compress bubble delay through fresh"
   (symbolic-path/direct
    (BQFresh intro (PendingDelay W) tag WF)
    (path
     ((bubble-delay-through-fresh delay))
     (BDelay (WorkFresh intro W tag) WF)))]

  [(symbolic-path/direct
    (BQRun NW
           (in-hole WF (WorkFresh intro hole tag)))
    Path)
   ---------------------------------------------------- "compress descend fresh"
   (symbolic-path/direct (BQFresh intro NW tag WF) Path)]

  ;; Conjunction dispatcher.
  [(where Path_1
          (after-unfinished (kernel-resume S g) WF))
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
           (DisjL (kernel-resume S g) (Conj W g))
           WF))
   (where Path_2
          (prepend-path (late-distribute-settled disj) Path_1))
   ---------------------------------------------------- "compress late distribute left"
   (symbolic-path/direct
    (BQConj (DisjL S W) g WF)
    Path_2)]

  [(where Path_1
          (after-unfinished
           (DisjR (Conj W g) (kernel-resume S g))
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

  ;; Left and right rail dispatchers.
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

  ;; Settled-result upward dispatcher over actual-hole contexts.
  [---------------------------------------------------- "compress finish success"
   (symbolic-path/direct
    (BQSettled (Returned st) (in-hole FF (More hole)))
    (path
     ((finish-success core))
     (BFinal (Last (Answer st)) FF)))]

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
               (Emit (kernel-freeze S) (More hole))))))]

  [---------------------------------------------------- "compress commit right answer"
   (symbolic-path/direct
    (BQSettled (DisjR W S) (in-hole FF (More hole)))
    (path
     ((commit-right-choice-answer search-join))
     (residual-state
      W
      (in-hole FF
               (Emit (kernel-freeze S) (More hole))))))]

  [(symbolic-path/direct
    (BQSettled (WorkFresh intro S tag)
               (in-hole FF (More TopW)))
    Path)
   ---------------------------------------------------- "compress silently cross fresh success"
   (symbolic-path/direct
    (BQSettled
     S
     (in-hole FF
              (More
               (in-hole TopW
                        (WorkFresh intro hole tag)))))
    Path)]

  [---------------------------------------------------- "compress expose left choice at fresh frame"
   (symbolic-path/direct
    (BQSettled
     (DisjL S W)
     (in-hole FF
              (More
               (in-hole TopW
                        (WorkFresh intro hole tag)))))
    (path
     ((expose-choice-through-work-fresh disj))
     (BSettled
      (DisjL (WorkFresh intro S tag)
             (WorkFresh intro W tag))
      (in-hole FF (More TopW)))))]

  [---------------------------------------------------- "compress expose right choice at fresh frame"
   (symbolic-path/direct
    (BQSettled
     (DisjR W S)
     (in-hole FF
              (More
               (in-hole TopW
                        (WorkFresh intro hole tag)))))
    (path
     ((expose-choice-through-work-fresh search-join))
     (BSettled
      (DisjR (WorkFresh intro W tag)
             (WorkFresh intro S tag))
      (in-hole FF (More TopW)))))]

  [(where Path_1
          (after-unfinished
           (kernel-resume S g)
           (in-hole FF (More TopW))))
   (where Path_2
          (prepend-path (conj-return core) Path_1))
   ---------------------------------------------------- "compress settled through conjunction"
   (symbolic-path/direct
    (BQSettled
     S
     (in-hole FF
              (More (in-hole TopW (Conj hole g)))))
    Path_2)]

  [(where Path_1
          (after-unfinished
           (DisjL (kernel-resume S g) (Conj W g))
           (in-hole FF (More TopW))))
   (where Path_2
          (prepend-path (late-distribute-settled disj) Path_1))
   ---------------------------------------------------- "compress settled left through conjunction"
   (symbolic-path/direct
    (BQSettled
     (DisjL S W)
     (in-hole FF
              (More (in-hole TopW (Conj hole g)))))
    Path_2)]

  [(where Path_1
          (after-unfinished
           (DisjR (Conj W g) (kernel-resume S g))
           (in-hole FF (More TopW))))
   (where Path_2
          (prepend-path
           (late-distribute-right-settled search-join)
           Path_1))
   ---------------------------------------------------- "compress settled right through conjunction"
   (symbolic-path/direct
    (BQSettled
     (DisjR W S)
     (in-hole FF
              (More (in-hole TopW (Conj hole g)))))
    Path_2)]

  [(symbolic-path/direct
    (BQSettled (DisjL S W)
               (in-hole FF (More TopW)))
    Path)
   ---------------------------------------------------- "compress silently form left choice"
   (symbolic-path/direct
    (BQSettled
     S
     (in-hole FF
              (More (in-hole TopW (DisjL hole W)))))
    Path)]

  [---------------------------------------------------- "compress reassociate settled left frame"
   (symbolic-path/direct
    (BQSettled
     SC
     (in-hole FF
              (More (in-hole TopW (DisjL hole W_2)))))
    (path
     ((reassociate-left-result disj))
     (BSettled
      (DisjL (compressed-choice-success SC)
             (DisjL (compressed-choice-alternate SC) W_2))
      (in-hole FF (More TopW)))))]

  [(symbolic-path/direct
    (BQSettled (DisjR W S)
               (in-hole FF (More TopW)))
    Path)
   ---------------------------------------------------- "compress silently form right choice"
   (symbolic-path/direct
    (BQSettled
     S
     (in-hole FF
              (More (in-hole TopW (DisjR W hole)))))
    Path)]

  [---------------------------------------------------- "compress reassociate settled right frame"
   (symbolic-path/direct
    (BQSettled
     SC
     (in-hole FF
              (More (in-hole TopW (DisjR W_1 hole)))))
    (path
     ((reassociate-right-result search-join))
     (BSettled
      (DisjR
       (DisjR W_1 (compressed-choice-alternate SC))
       (compressed-choice-success SC))
      (in-hole FF (More TopW)))))]

  ;; Failure and delay propagation dispatchers.
  [---------------------------------------------------- "compress finish failure"
   (symbolic-path/direct
    (BQDead (in-hole FF (More hole)))
    (path ((finish-failure core)) (BFinal Done FF)))]

  [---------------------------------------------------- "compress dead through fresh"
   (symbolic-path/direct
    (BQDead
     (in-hole FF
              (More (in-hole TopW
                             (WorkFresh intro hole tag)))))
    (path
     ((erase-dead-fresh core))
     (BDead (in-hole FF (More TopW)))))]

  [---------------------------------------------------- "compress dead through conjunction"
   (symbolic-path/direct
    (BQDead
     (in-hole FF (More (in-hole TopW (Conj hole g)))))
    (path
     ((conj-fail core))
     (BDead (in-hole FF (More TopW)))))]

  [---------------------------------------------------- "compress dead skips left"
   (symbolic-path/direct
    (BQDead
     (in-hole FF (More (in-hole TopW (DisjL hole W)))))
    (path
     ((skip-left-failure disj))
     (residual-state W (in-hole FF (More TopW)))))]

  [---------------------------------------------------- "compress dead skips right"
   (symbolic-path/direct
    (BQDead
     (in-hole FF (More (in-hole TopW (DisjR W hole)))))
    (path
     ((skip-right-failure search-join))
     (residual-state W (in-hole FF (More TopW)))))]

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
    (BQDelay
     W
     (in-hole FF
              (More (in-hole TopW
                             (WorkFresh intro hole tag)))))
    (path
     ((bubble-delay-through-fresh delay))
     (BDelay
      (WorkFresh intro W tag)
      (in-hole FF (More TopW)))))]

  [---------------------------------------------------- "compress delay through conjunction"
   (symbolic-path/direct
    (BQDelay
     W
     (in-hole FF (More (in-hole TopW (Conj hole g)))))
    (path
     ((bubble-delay-through-conj delay))
     (BDelay (Conj W g) (in-hole FF (More TopW)))))]

  [---------------------------------------------------- "compress delay enters right rail"
   (symbolic-path/direct
    (BQDelay
     W_1
     (in-hole FF (More (in-hole TopW (DisjL hole W_2)))))
    (path
     ((rail-enter-right search-join))
     (BDelay (DisjR W_1 W_2) (in-hole FF (More TopW)))))]

  [---------------------------------------------------- "compress delay returns left rail"
   (symbolic-path/direct
    (BQDelay
     W_2
     (in-hole FF (More (in-hole TopW (DisjR W_1 hole)))))
    (path
     ((rail-return-left search-join))
     (BDelay (DisjL W_1 W_2) (in-hole FF (More TopW)))))])

(define-judgment-form
  redex-column-compressed-lang
  #:contract (compressed-step/direct B Span B)
  #:mode (compressed-step/direct I O O)
  [(symbolic-path/direct
    (BQRun W WF)
    (path (ell_0 ell_rest ...) B_1))
   ---------------------------------------------------- "compressed run step"
   (compressed-step/direct
    (BRun W WF)
    (transition-span ell_0 ell_rest ...)
    B_1)]
  [(symbolic-path/direct
    (BQSettled SR WF)
    (path (ell_0 ell_rest ...) B_1))
   ---------------------------------------------------- "compressed settled step"
   (compressed-step/direct
    (BSettled SR WF)
    (transition-span ell_0 ell_rest ...)
    B_1)]
  [(symbolic-path/direct
    (BQDead WF)
    (path (ell_0 ell_rest ...) B_1))
   ---------------------------------------------------- "compressed dead step"
   (compressed-step/direct
    (BDead WF)
    (transition-span ell_0 ell_rest ...)
    B_1)]
  [(symbolic-path/direct
    (BQDelay W WF)
    (path (ell_0 ell_rest ...) B_1))
   ---------------------------------------------------- "compressed delay step"
   (compressed-step/direct
    (BDelay W WF)
    (transition-span ell_0 ell_rest ...)
    B_1)])

(define-judgment-form
  redex-column-compressed-lang
  #:contract (compressed-steps/direct B Spans B)
  #:mode (compressed-steps/direct I O O)
  [---------------------------------------------------- "zero compressed steps"
   (compressed-steps/direct B () B)]
  [(compressed-step/direct B_0 Span B_1)
   (compressed-steps/direct B_1 (Span_rest ...) B_2)
   ---------------------------------------------------- "one or more compressed steps"
   (compressed-steps/direct B_0 (Span Span_rest ...) B_2)])

(define-judgment-form
  redex-column-compressed-lang
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
  redex-column-compressed-lang
  #:contract (initial-compressed/direct F B)
  #:mode (initial-compressed/direct I O)
  [(initial-compressed-query/direct F hole B)
   ---------------------------------------------------- "initial compressed state"
   (initial-compressed/direct F B)])

(define-metafunction redex-column-compressed-lang
  compressed-readback : B -> F
  [(compressed-readback (BRun W WF)) (in-hole WF W)]
  [(compressed-readback (BSettled SR WF)) (in-hole WF SR)]
  [(compressed-readback (BDead WF)) (in-hole WF Dead)]
  [(compressed-readback (BDelay W WF))
   (in-hole WF (PendingDelay W))]
  [(compressed-readback (BFinal T FF)) (in-hole FF T)])

(define-judgment-form
  redex-column-compressed-lang
  #:contract (reachable-compressed/via F Spans B)
  #:mode (reachable-compressed/via I O O)
  [(wf-frontier/toy F)
   (initial-compressed/direct F B_0)
   (compressed-steps/direct B_0 Spans B)
   ---------------------------------------------------- "reachable compressed state with spans"
   (reachable-compressed/via F Spans B)])

;; Reduction-relation projection for inspectable Redex traces.  The judgment
;; remains authoritative because the dynamic span is first-class output data.
(define compressed-red/direct
  (reduction-relation
   redex-column-compressed-lang
   #:domain B
   [--> B_0 B_1
        (judgment-holds (compressed-step/direct B_0 Span B_1))
        (computed-name (format "~s" (term Span)))]))
