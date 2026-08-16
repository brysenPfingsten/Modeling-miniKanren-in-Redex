#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "./kernel-toy.rkt")

(provide redex-column-decomposition-lang
         decompose/redex
         contract/redex
         decomposed-step/spec
         decomposed-steps/spec
         decomposition-image
         reachable-decomposition/via
         plug-D
         plug-C
         contract-label
         decompose-one
         decomposed-red/direct)

(check-redundancy #t)

;; BR is a whole More-boundary redex.  LFR is a branch-local WorkFresh
;; redex.  LR contains every other local work redex.  These are grammatical
;; classes used by the decomposition judgment, not runtime phase tags.
(define-extended-language redex-column-decomposition-lang
  redex-column-source-lang
  [T Done (Last A)]
  [BR (WorkFresh intro W tag)
      (Returned st)
      Dead
      (PendingDelay W)
      (DisjL S W)
      (DisjR W S)]
  [LFR (WorkFresh intro SC tag)
       (WorkFresh intro Dead tag)
       (WorkFresh intro (PendingDelay W) tag)]
  [LR (Work g st)
      (Conj S g)
      (Conj Dead g)
      (Conj (PendingDelay W) g)
      (Conj SC g)
      (DisjL Dead W)
      (DisjL (PendingDelay W) W)
      (DisjL SC W)
      (DisjR W Dead)
      (DisjR W (PendingDelay W))
      (DisjR W SC)]

  [D (DecWork W WF)
     (DecFrontier T FF)]
  [C (ContractWork ell W WF)
     (ContractFrontier ell F FF)]
  [Labels (ell ...)])

(define-metafunction redex-column-decomposition-lang
  plug-D : D -> F
  [(plug-D (DecWork W WF))
   (in-hole WF W)]
  [(plug-D (DecFrontier T FF))
   (in-hole FF T)])

(define-metafunction redex-column-decomposition-lang
  plug-C : C -> F
  [(plug-C (ContractWork ell W WF))
   (in-hole WF W)]
  [(plug-C (ContractFrontier ell F FF))
   (in-hole FF F)])

(define-metafunction redex-column-decomposition-lang
  contract-label : C -> ell
  [(contract-label (ContractWork ell W WF)) ell]
  [(contract-label (ContractFrontier ell F FF)) ell])

(define-metafunction redex-column-decomposition-lang
  decomposition-choice-success : SC -> S
  [(decomposition-choice-success (DisjL S W)) S]
  [(decomposition-choice-success (DisjR W S)) S])

(define-metafunction redex-column-decomposition-lang
  decomposition-choice-alternate : SC -> W
  [(decomposition-choice-alternate (DisjL S W)) W]
  [(decomposition-choice-alternate (DisjR W S)) W])

;; This is the primary decomposition artifact.  It is a Redex judgment over
;; actual-hole contexts, not an ordered Racket traversal.  The three redex
;; clauses are disjoint on source-image terms because WF+ excludes the More
;; boundary and LR excludes WorkFresh.
(define-judgment-form
  redex-column-decomposition-lang
  #:contract (decompose/redex F D)
  #:mode (decompose/redex I O)

  [---------------------------------------------------- "decompose More boundary"
   (decompose/redex
    (in-hole FF (More BR))
    (DecWork BR (in-hole FF (More hole))))]

  [---------------------------------------------------- "decompose local WorkFresh"
   (decompose/redex
    (in-hole WF+ LFR)
    (DecWork LFR WF+))]

  [---------------------------------------------------- "decompose local work"
   (decompose/redex
    (in-hole WF LR)
    (DecWork LR WF))]

  [---------------------------------------------------- "decompose terminal frontier"
   (decompose/redex
    (in-hole FF T)
    (DecFrontier T FF))])

;; Contraction is separately relational.  Its output constructor records the
;; grammatical category of both replacement and retained context.
(define-judgment-form
  redex-column-decomposition-lang
  #:contract (contract/redex D C)
  #:mode (contract/redex I O)

  [---------------------------------------------------- "contract expose frontier fresh"
   (contract/redex
    (DecWork (WorkFresh intro W tag)
             (in-hole FF (More hole)))
    (ContractFrontier
     (expose-frontier-fresh core)
     (FrontierFresh intro (More W) tag)
     FF))]

  [---------------------------------------------------- "contract finish success"
   (contract/redex
    (DecWork (Returned st) (in-hole FF (More hole)))
    (ContractFrontier
     (finish-success core)
     (Last (Answer st))
     FF))]

  [---------------------------------------------------- "contract finish failure"
   (contract/redex
    (DecWork Dead (in-hole FF (More hole)))
    (ContractFrontier (finish-failure core) Done FF))]

  [---------------------------------------------------- "contract force delay"
   (contract/redex
    (DecWork (PendingDelay W) (in-hole FF (More hole)))
    (ContractFrontier (force-delay delay) (Forced (More W)) FF))]

  [---------------------------------------------------- "contract commit left answer"
   (contract/redex
    (DecWork (DisjL S W) (in-hole FF (More hole)))
    (ContractFrontier
     (commit-choice-answer disj)
     (Emit (kernel-freeze S) (More W))
     FF))]

  [---------------------------------------------------- "contract commit right answer"
   (contract/redex
    (DecWork (DisjR W S) (in-hole FF (More hole)))
    (ContractFrontier
     (commit-right-choice-answer search-join)
     (Emit (kernel-freeze S) (More W))
     FF))]

  [---------------------------------------------------- "contract work succeed"
   (contract/redex
    (DecWork (Work (succeed tag) st) WF)
    (ContractWork (work-succeed core) (Returned st) WF))]

  [---------------------------------------------------- "contract work fail"
   (contract/redex
    (DecWork (Work (fail tag) st) WF)
    (ContractWork (work-fail core) Dead WF))]

  [---------------------------------------------------- "contract work put"
   (contract/redex
    (DecWork (Work (put p tag) st) WF)
    (ContractWork (work-put core) (Returned (kernel-put p st)) WF))]

  [(where F_whole
          (in-hole WF (Work (fresh (x ...) g tag_fresh) st)))
   (where (u_new ...) (kernel-fresh (x ...) F_whole))
   (where g_new
          (kernel-substitute g ((x u_new) ...)))
   ---------------------------------------------------- "contract allocate fresh"
   (contract/redex
    (DecWork (Work (fresh (x ...) g tag_fresh) st) WF)
    (ContractWork
     (allocate-fresh core)
     (WorkFresh (u_new ...) (Work g_new st) tag_fresh)
     WF))]

  [---------------------------------------------------- "contract expand conjunction"
   (contract/redex
    (DecWork (Work (conj g_1 g_2 tag) st) WF)
    (ContractWork
     (expand-conjunction core)
     (Conj (Work g_1 st) g_2)
     WF))]

  [---------------------------------------------------- "contract expand disjunction"
   (contract/redex
    (DecWork (Work (disj g_1 g_2 tag) st) WF)
    (ContractWork
     (expand-disjunction disj)
     (DisjL (Work g_1 st) (Work g_2 st))
     WF))]

  [---------------------------------------------------- "contract suspend goal"
   (contract/redex
    (DecWork (Work (suspend g tag) st) WF)
    (ContractWork
     (suspend-goal delay)
     (PendingDelay (Work g st))
     WF))]

  [---------------------------------------------------- "contract expose left choice through fresh"
   (contract/redex
    (DecWork (WorkFresh intro (DisjL S W) tag) WF+)
    (ContractWork
     (expose-choice-through-work-fresh disj)
     (DisjL (WorkFresh intro S tag)
            (WorkFresh intro W tag))
     WF+))]

  [---------------------------------------------------- "contract expose right choice through fresh"
   (contract/redex
    (DecWork (WorkFresh intro (DisjR W S) tag) WF+)
    (ContractWork
     (expose-choice-through-work-fresh search-join)
     (DisjR (WorkFresh intro W tag)
            (WorkFresh intro S tag))
     WF+))]

  [---------------------------------------------------- "contract erase dead fresh"
   (contract/redex
    (DecWork (WorkFresh intro Dead tag) WF+)
    (ContractWork (erase-dead-fresh core) Dead WF+))]

  [---------------------------------------------------- "contract bubble delay through fresh"
   (contract/redex
    (DecWork (WorkFresh intro (PendingDelay W) tag) WF+)
    (ContractWork
     (bubble-delay-through-fresh delay)
     (PendingDelay (WorkFresh intro W tag))
     WF+))]

  [---------------------------------------------------- "contract conjunction return"
   (contract/redex
    (DecWork (Conj S g) WF)
    (ContractWork (conj-return core) (kernel-resume S g) WF))]

  [---------------------------------------------------- "contract conjunction failure"
   (contract/redex
    (DecWork (Conj Dead g) WF)
    (ContractWork (conj-fail core) Dead WF))]

  [---------------------------------------------------- "contract bubble delay through conjunction"
   (contract/redex
    (DecWork (Conj (PendingDelay W) g) WF)
    (ContractWork
     (bubble-delay-through-conj delay)
     (PendingDelay (Conj W g))
     WF))]

  [---------------------------------------------------- "contract late distribute left"
   (contract/redex
    (DecWork (Conj (DisjL S W) g) WF)
    (ContractWork
     (late-distribute-settled disj)
     (DisjL (kernel-resume S g) (Conj W g))
     WF))]

  [---------------------------------------------------- "contract late distribute right"
   (contract/redex
    (DecWork (Conj (DisjR W S) g) WF)
    (ContractWork
     (late-distribute-right-settled search-join)
     (DisjR (Conj W g) (kernel-resume S g))
     WF))]

  [---------------------------------------------------- "contract skip left failure"
   (contract/redex
    (DecWork (DisjL Dead W) WF)
    (ContractWork (skip-left-failure disj) W WF))]

  [---------------------------------------------------- "contract enter right rail"
   (contract/redex
    (DecWork (DisjL (PendingDelay W_1) W_2) WF)
    (ContractWork
     (rail-enter-right search-join)
     (PendingDelay (DisjR W_1 W_2))
     WF))]

  [---------------------------------------------------- "contract reassociate left"
   (contract/redex
    (DecWork (DisjL SC W_2) WF)
    (ContractWork
     (reassociate-left-result disj)
     (DisjL (decomposition-choice-success SC)
            (DisjL (decomposition-choice-alternate SC) W_2))
     WF))]

  [---------------------------------------------------- "contract skip right failure"
   (contract/redex
    (DecWork (DisjR W Dead) WF)
    (ContractWork (skip-right-failure search-join) W WF))]

  [---------------------------------------------------- "contract return to left rail"
   (contract/redex
    (DecWork (DisjR W_1 (PendingDelay W_2)) WF)
    (ContractWork
     (rail-return-left search-join)
     (PendingDelay (DisjL W_1 W_2))
     WF))]

  [---------------------------------------------------- "contract reassociate right"
   (contract/redex
    (DecWork (DisjR W_1 SC) WF)
    (ContractWork
     (reassociate-right-result search-join)
     (DisjR (DisjR W_1 (decomposition-choice-alternate SC))
            (decomposition-choice-success SC))
     WF))])

;; These functional views remain Redex-internal: their output variables are
;; bound by the decomposition judgment.  Totality and single-valuedness are
;; separate executable laws, so no host dispatcher chooses a focus.
(define-metafunction redex-column-decomposition-lang
  decompose-one : F -> D
  [(decompose-one F) D
   (judgment-holds (decompose/redex F D))])

(define-metafunction redex-column-decomposition-lang
  next-decomposition : C -> D
  [(next-decomposition C) D
   (where F (plug-C C))
   (judgment-holds (decompose/redex F D))])

;; Compositional specification: contract one decomposed redex, reconstruct its
;; result, and ask the decomposition judgment for the next unique focus.
(define-judgment-form
  redex-column-decomposition-lang
  #:contract (decomposed-step/spec D ell D)
  #:mode (decomposed-step/spec I O O)
  [(contract/redex D_1 C)
   (where ell (contract-label C))
   (where F (plug-C C))
   (decompose/redex F D_2)
   ---------------------------------------------------- "decomposed step specification"
   (decomposed-step/spec D_1 ell D_2)])

(define-judgment-form
  redex-column-decomposition-lang
  #:contract (decomposed-steps/spec D Labels D)
  #:mode (decomposed-steps/spec I O O)
  [---------------------------------------------------- "zero decomposed steps"
   (decomposed-steps/spec D () D)]
  [(decomposed-step/spec D_0 ell D_1)
   (decomposed-steps/spec D_1 (ell_rest ...) D_2)
   ---------------------------------------------------- "one or more decomposed steps"
   (decomposed-steps/spec D_0 (ell ell_rest ...) D_2)])

(define-judgment-form
  redex-column-decomposition-lang
  #:contract (decomposition-image F D)
  #:mode (decomposition-image I O)
  [(decompose/redex F D)
   ---------------------------------------------------- "decomposition image"
   (decomposition-image F D)])

(define-judgment-form
  redex-column-decomposition-lang
  #:contract (reachable-decomposition/via F Labels D)
  #:mode (reachable-decomposition/via I O O)
  [(decompose/redex F D_0)
   (decomposed-steps/spec D_0 Labels D)
   ---------------------------------------------------- "reachable decomposition with trace"
   (reachable-decomposition/via F Labels D)])

;; The direct presentation repeats the contractum clauses rather than invoking
;; contract/redex.  Each clause then invokes the judgment-backed Redex
;; metafunction solely for the root re-decomposition common to this stage.
(define decomposed-red/direct
  (reduction-relation
   redex-column-decomposition-lang
   #:domain D

   [--> (DecWork (WorkFresh intro W tag)
                 (in-hole FF (More hole)))
        (next-decomposition
         (ContractFrontier
          (expose-frontier-fresh core)
          (FrontierFresh intro (More W) tag)
          FF))
        "expose-frontier-fresh/core"]
   [--> (DecWork (Returned st) (in-hole FF (More hole)))
        (next-decomposition
         (ContractFrontier
          (finish-success core)
          (Last (Answer st))
          FF))
        "finish-success/core"]
   [--> (DecWork Dead (in-hole FF (More hole)))
        (next-decomposition
         (ContractFrontier (finish-failure core) Done FF))
        "finish-failure/core"]
   [--> (DecWork (PendingDelay W) (in-hole FF (More hole)))
        (next-decomposition
         (ContractFrontier (force-delay delay) (Forced (More W)) FF))
        "force-delay/delay"]
   [--> (DecWork (DisjL S W) (in-hole FF (More hole)))
        (next-decomposition
         (ContractFrontier
          (commit-choice-answer disj)
          (Emit (kernel-freeze S) (More W))
          FF))
        "commit-choice-answer/disj"]
   [--> (DecWork (DisjR W S) (in-hole FF (More hole)))
        (next-decomposition
         (ContractFrontier
          (commit-right-choice-answer search-join)
          (Emit (kernel-freeze S) (More W))
          FF))
        "commit-right-choice-answer/search-join"]

   [--> (DecWork (Work (succeed tag) st) WF)
        (next-decomposition
         (ContractWork (work-succeed core) (Returned st) WF))
        "work-succeed/core"]
   [--> (DecWork (Work (fail tag) st) WF)
        (next-decomposition
         (ContractWork (work-fail core) Dead WF))
        "work-fail/core"]
   [--> (DecWork (Work (put p tag) st) WF)
        (next-decomposition
         (ContractWork (work-put core) (Returned (kernel-put p st)) WF))
        "work-put/core"]
   [--> (name D_whole
              (DecWork (Work (fresh (x ...) g tag_fresh) st) WF))
        (next-decomposition
         (ContractWork
          (allocate-fresh core)
          (WorkFresh (u_new ...) (Work g_new st) tag_fresh)
          WF))
        (where F_whole
               (plug-D D_whole))
        (where (u_new ...) (kernel-fresh (x ...) F_whole))
        (where g_new
               (kernel-substitute g ((x u_new) ...)))
        "allocate-fresh/core"]
   [--> (DecWork (Work (conj g_1 g_2 tag) st) WF)
        (next-decomposition
         (ContractWork
          (expand-conjunction core)
          (Conj (Work g_1 st) g_2)
          WF))
        "expand-conjunction/core"]
   [--> (DecWork (Work (disj g_1 g_2 tag) st) WF)
        (next-decomposition
         (ContractWork
          (expand-disjunction disj)
          (DisjL (Work g_1 st) (Work g_2 st))
          WF))
        "expand-disjunction/disj"]
   [--> (DecWork (Work (suspend g tag) st) WF)
        (next-decomposition
         (ContractWork
          (suspend-goal delay)
          (PendingDelay (Work g st))
          WF))
        "suspend-goal/delay"]

   [--> (DecWork (WorkFresh intro (DisjL S W) tag) WF+)
        (next-decomposition
         (ContractWork
          (expose-choice-through-work-fresh disj)
          (DisjL (WorkFresh intro S tag)
                 (WorkFresh intro W tag))
          WF+))
        "expose-choice-through-work-fresh/disj"]
   [--> (DecWork (WorkFresh intro (DisjR W S) tag) WF+)
        (next-decomposition
         (ContractWork
          (expose-choice-through-work-fresh search-join)
          (DisjR (WorkFresh intro W tag)
                 (WorkFresh intro S tag))
          WF+))
        "expose-choice-through-work-fresh/search-join"]
   [--> (DecWork (WorkFresh intro Dead tag) WF+)
        (next-decomposition
         (ContractWork (erase-dead-fresh core) Dead WF+))
        "erase-dead-fresh/core"]
   [--> (DecWork (WorkFresh intro (PendingDelay W) tag) WF+)
        (next-decomposition
         (ContractWork
          (bubble-delay-through-fresh delay)
          (PendingDelay (WorkFresh intro W tag))
          WF+))
        "bubble-delay-through-fresh/delay"]

   [--> (DecWork (Conj S g) WF)
        (next-decomposition
         (ContractWork (conj-return core) (kernel-resume S g) WF))
        "conj-return/core"]
   [--> (DecWork (Conj Dead g) WF)
        (next-decomposition
         (ContractWork (conj-fail core) Dead WF))
        "conj-fail/core"]
   [--> (DecWork (Conj (PendingDelay W) g) WF)
        (next-decomposition
         (ContractWork
          (bubble-delay-through-conj delay)
          (PendingDelay (Conj W g))
          WF))
        "bubble-delay-through-conj/delay"]
   [--> (DecWork (Conj (DisjL S W) g) WF)
        (next-decomposition
         (ContractWork
          (late-distribute-settled disj)
          (DisjL (kernel-resume S g) (Conj W g))
          WF))
        "late-distribute-settled/disj"]
   [--> (DecWork (Conj (DisjR W S) g) WF)
        (next-decomposition
         (ContractWork
          (late-distribute-right-settled search-join)
          (DisjR (Conj W g) (kernel-resume S g))
          WF))
        "late-distribute-right-settled/search-join"]

   [--> (DecWork (DisjL Dead W) WF)
        (next-decomposition
         (ContractWork (skip-left-failure disj) W WF))
        "skip-left-failure/disj"]
   [--> (DecWork (DisjL (PendingDelay W_1) W_2) WF)
        (next-decomposition
         (ContractWork
          (rail-enter-right search-join)
          (PendingDelay (DisjR W_1 W_2))
          WF))
        "rail-enter-right/search-join"]
   [--> (DecWork (DisjL SC W_2) WF)
        (next-decomposition
         (ContractWork
          (reassociate-left-result disj)
          (DisjL (decomposition-choice-success SC)
                 (DisjL (decomposition-choice-alternate SC) W_2))
          WF))
        "reassociate-left-result/disj"]

   [--> (DecWork (DisjR W Dead) WF)
        (next-decomposition
         (ContractWork (skip-right-failure search-join) W WF))
        "skip-right-failure/search-join"]
   [--> (DecWork (DisjR W_1 (PendingDelay W_2)) WF)
        (next-decomposition
         (ContractWork
          (rail-return-left search-join)
          (PendingDelay (DisjL W_1 W_2))
          WF))
        "rail-return-left/search-join"]
   [--> (DecWork (DisjR W_1 SC) WF)
        (next-decomposition
         (ContractWork
          (reassociate-right-result search-join)
          (DisjR (DisjR W_1 (decomposition-choice-alternate SC))
                 (decomposition-choice-success SC))
          WF))
        "reassociate-right-result/search-join"]))
