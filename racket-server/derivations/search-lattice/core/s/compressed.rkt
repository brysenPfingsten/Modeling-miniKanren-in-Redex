#lang racket

(require redex/reduction-semantics
         (only-in "../../../../src/search-lattice/languages/core-lang.rkt"
                  invalid?
                  owners-append
                  unify
                  walk)
         (only-in "../../../../src/search-lattice/reduction-relations/private/common.rkt"
                  subst-goal-host)
         "./private/support-kernel.rkt"
         (only-in "./machine.rkt"
                  core-s-machine-lang))

(provide core-s-compressed-lang
         encode-MB/s
         decode-BM/s
         readback-B/s
         transition-span-labels/s
         compressed-step/direct/s
         compressed-red/direct/s)

(check-redundancy #t)

;; B removes the representational distinction between the exact M redex
;; categories while retaining the complete WorkFocus.  Settled and dead
;; states are public because they are the canonical images of arbitrary exact
;; M control states.  A result-producing BRun edge normally bypasses one such
;; state by fusing exactly its next conjunction or frontier transition.
(define-extended-language core-s-compressed-lang
  core-s-machine-lang

  [NonAllocateGoal eq
                   (t != t tag)
                   (succeed tag)
                   (fail tag)
                   (g ∧ g tag)]

  [ProducerRuleName succeed
                    fail
                    unify-success
                    unify-violates-disequality
                    unify-fail
                    disequality-success
                    disequality-fail]

  [FollowRuleName conj-return
                  conj-fail
                  finish-success
                  finish-failure]

  [SingletonRuleName expand-conjunction
                     allocate-fresh
                     conj-return
                     conj-fail
                     finish-success
                     finish-failure]

  [B (BRun (Work owners g σ) WorkFocus)
     (BSettled (Returned owners σ) WorkFocus)
     (BDead owners WorkFocus)
     (BFinal T)]

  ;; A compressed edge always represents at least one exact transition.
  [TransitionSpan (transition-span RuleName RuleName ...)])

;; Canonicalization from every exact M control state.  In the Conj cases the
;; pending frame moves from the redex into the retained WorkFocus, leaving the
;; settled result as the B focus.
(define-metafunction core-s-compressed-lang
  encode-MB/s : M -> B
  [(encode-MB/s (MFinal T))
   (BFinal T)]
  [(encode-MB/s (MWork (Work owners g σ) WorkFocus))
   (BRun (Work owners g σ) WorkFocus)]
  [(encode-MB/s (MAllocate AR WorkFocus))
   (BRun AR WorkFocus)]
  [(encode-MB/s
    (MWork
     (Conj owners_outer (Returned owners_inner σ) g)
     WorkFocus))
   (BSettled
    (Returned owners_inner σ)
    (in-hole WorkFocus (Conj owners_outer hole g)))]
  [(encode-MB/s
    (MWork
     (Conj owners_outer (Dead owners_inner) g)
     WorkFocus))
   (BDead
    owners_inner
    (in-hole WorkFocus (Conj owners_outer hole g)))]
  [(encode-MB/s
    (MFrontier (More (Returned owners σ)) hole))
   (BSettled (Returned owners σ) (More hole))]
  [(encode-MB/s
    (MFrontier (More (Dead owners)) hole))
   (BDead owners (More hole))])

;; The inverse chooses the exact M redex category determined by the B focus.
;; The nearest pending Conj frame is exposed; root results become frontier
;; redexes.  Allocation is restored to its distinct exact-M category.
(define-metafunction core-s-compressed-lang
  decode-BM/s : B -> M
  [(decode-BM/s (BFinal T))
   (MFinal T)]
  [(decode-BM/s
    (BRun
     (Work owners (∃ (x_bound ...) g tag) σ)
     WorkFocus))
   (MAllocate
    (Work owners (∃ (x_bound ...) g tag) σ)
    WorkFocus)]
  [(decode-BM/s
    (BRun (Work owners NonAllocateGoal σ) WorkFocus))
   (MWork (Work owners NonAllocateGoal σ) WorkFocus)]
  [(decode-BM/s
    (BSettled
     (Returned owners_inner σ)
     (in-hole WorkFocus (Conj owners_outer hole g))))
   (MWork
    (Conj owners_outer (Returned owners_inner σ) g)
    WorkFocus)]
  [(decode-BM/s
    (BSettled (Returned owners σ) (More hole)))
   (MFrontier (More (Returned owners σ)) hole)]
  [(decode-BM/s
    (BDead
     owners_inner
     (in-hole WorkFocus (Conj owners_outer hole g))))
   (MWork
    (Conj owners_outer (Dead owners_inner) g)
    WorkFocus)]
  [(decode-BM/s (BDead owners (More hole)))
   (MFrontier (More (Dead owners)) hole)])

(define-metafunction core-s-compressed-lang
  readback-B/s : B -> F
  [(readback-B/s (BRun W WorkFocus))
   (in-hole WorkFocus W)]
  [(readback-B/s (BSettled S WorkFocus))
   (in-hole WorkFocus S)]
  [(readback-B/s (BDead owners WorkFocus))
   (in-hole WorkFocus (Dead owners))]
  [(readback-B/s (BFinal T))
   T])

(define-metafunction core-s-compressed-lang
  transition-span-labels/s : TransitionSpan -> MLabels
  [(transition-span-labels/s
    (transition-span RuleName_0 RuleName_rest ...))
   (RuleName_0 RuleName_rest ...)])

;; The seven result producers are restated directly.  No clause invokes the M
;; stepper; only the same pure miniKanren kernel algebra is shared.
(define-judgment-form
  core-s-compressed-lang
  #:contract (produce-settled/direct/s W ProducerRuleName S)
  #:mode (produce-settled/direct/s I O O)

  [---------------------------------------------------- "compressed produce succeed/S"
   (produce-settled/direct/s
    (Work owners (succeed tag) σ)
    succeed
    (Returned owners σ))]

  [(where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
   (where #f (invalid? sub_1 dis))
   ---------------------------------------------------- "compressed produce unification success/S"
   (produce-settled/direct/s
    (Work
     owners
     (t_1 =? t_2 tag)
     (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
    unify-success
    (Returned
     owners
     (state sub_1
            dis
            ((t_3 =? t_4 tag_1) ... (t_1 =? t_2 tag))
            tag_2)))]

  [(where dis_1 ((t_1 t_2) ,@(term dis)))
   (where #f (invalid? sub dis_1))
   ---------------------------------------------------- "compressed produce disequality success/S"
   (produce-settled/direct/s
    (Work owners
          (t_1 != t_2 tag)
          (state sub dis trail tag_2))
    disequality-success
    (Returned owners (state sub dis_1 trail tag_2)))])

(define-judgment-form
  core-s-compressed-lang
  #:contract (produce-dead/direct/s W ProducerRuleName owners)
  #:mode (produce-dead/direct/s I O O)

  [---------------------------------------------------- "compressed produce failure/S"
   (produce-dead/direct/s
    (Work owners (fail tag) σ)
    fail
    owners)]

  [(where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
   (where #t (invalid? sub_1 dis))
   ---------------------------------------------------- "compressed produce unification violation/S"
   (produce-dead/direct/s
    (Work
     owners
     (t_1 =? t_2 tag)
     (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
    unify-violates-disequality
    owners)]

  [(where #f (unify (walk t_1 sub) (walk t_2 sub) sub))
   ---------------------------------------------------- "compressed produce unification failure/S"
   (produce-dead/direct/s
    (Work owners
          (t_1 =? t_2 tag)
          (state sub dis trail tag_2))
    unify-fail
    owners)]

  [(where dis_1 ((t_1 t_2) ,@(term dis)))
   (where #t (invalid? sub dis_1))
   ---------------------------------------------------- "compressed produce disequality failure/S"
   (produce-dead/direct/s
    (Work owners
          (t_1 != t_2 tag)
          (state sub dis trail tag_2))
    disequality-fail
    owners)])

;; Exactly one structural follow-up consumes a settled/dead result.  These
;; helpers also define the public one-label transitions from BSettled/BDead.
(define-judgment-form
  core-s-compressed-lang
  #:contract (advance-settled/direct/s S WorkFocus FollowRuleName B)
  #:mode (advance-settled/direct/s I I O O)

  [---------------------------------------------------- "compressed conjunction return/S"
   (advance-settled/direct/s
    (Returned owners_inner σ)
    (in-hole WorkFocus (Conj owners_outer hole g))
    conj-return
    (BRun
     (Work (owners-append owners_outer owners_inner) g σ)
     WorkFocus))]

  [---------------------------------------------------- "compressed finish success/S"
   (advance-settled/direct/s
    (Returned owners σ)
    (More hole)
    finish-success
    (BFinal (Last owners (Answer (Owners) σ))))])

(define-judgment-form
  core-s-compressed-lang
  #:contract (advance-dead/direct/s owners WorkFocus FollowRuleName B)
  #:mode (advance-dead/direct/s I I O O)

  [---------------------------------------------------- "compressed conjunction failure/S"
   (advance-dead/direct/s
    owners_inner
    (in-hole WorkFocus (Conj owners_outer hole g))
    conj-fail
    (BDead
     (owners-append owners_outer owners_inner)
     WorkFocus))]

  [---------------------------------------------------- "compressed finish failure/S"
   (advance-dead/direct/s
    owners
    (More hole)
    finish-failure
    (BFinal (Done owners)))])

(define-judgment-form
  core-s-compressed-lang
  #:contract (compressed-step/direct/s B TransitionSpan B)
  #:mode (compressed-step/direct/s I O O)

  [---------------------------------------------------- "compressed expand conjunction/S"
   (compressed-step/direct/s
    (BRun
     (Work owners
           (g_1 ∧ g_2 tag)
           (state sub dis trail tag_1))
     WorkFocus)
    (transition-span expand-conjunction)
    (BRun
     (Work (Owners) g_1 (state sub dis trail tag_1))
     (in-hole WorkFocus (Conj owners hole g_2))))]

  [(where (u_new ...)
          ,(fresh-intro/separated/host
            (term WorkFocus)
            (term (Work owners (∃ (x_bound ...) g tag) σ))
            (term (x_bound ...))))
   (where g_new
          ,(subst-goal-host
            (term g)
            (term ((x_bound u_new) ...))))
   ---------------------------------------------------- "compressed allocate fresh/S"
   (compressed-step/direct/s
    (BRun
     (Work owners (∃ (x_bound ...) g tag) σ)
     WorkFocus)
    (transition-span allocate-fresh)
    (BRun
     (Work
      (owners-append owners (Owners (Owner (u_new ...) tag)))
      g_new
      σ)
     WorkFocus))]

  [(advance-settled/direct/s
    S
    WorkFocus
    FollowRuleName
    B_1)
   ---------------------------------------------------- "compressed settled follow-up/S"
   (compressed-step/direct/s
    (BSettled S WorkFocus)
    (transition-span FollowRuleName)
    B_1)]

  [(advance-dead/direct/s
    owners
    WorkFocus
    FollowRuleName
    B_1)
   ---------------------------------------------------- "compressed dead follow-up/S"
   (compressed-step/direct/s
    (BDead owners WorkFocus)
    (transition-span FollowRuleName)
    B_1)]

  [(produce-settled/direct/s
    W
    ProducerRuleName
    S)
   (advance-settled/direct/s
    S
    WorkFocus
    FollowRuleName
    B_1)
   ---------------------------------------------------- "compressed settled producer span/S"
   (compressed-step/direct/s
    (BRun W WorkFocus)
    (transition-span ProducerRuleName FollowRuleName)
    B_1)]

  [(produce-dead/direct/s
    W
    ProducerRuleName
    owners)
   (advance-dead/direct/s
    owners
    WorkFocus
    FollowRuleName
    B_1)
   ---------------------------------------------------- "compressed dead producer span/S"
   (compressed-step/direct/s
    (BRun W WorkFocus)
    (transition-span ProducerRuleName FollowRuleName)
    B_1)])

(define-metafunction core-s-compressed-lang
  transition-span->string/s : TransitionSpan -> string
  [(transition-span->string/s TransitionSpan)
   ,(format "~s" (term TransitionSpan))])

;; Named visualization relation only; the judgment above is authoritative.
(define compressed-red/direct/s
  (reduction-relation
   core-s-compressed-lang
   #:domain B
   [--> B_0 B_1
        (judgment-holds
         (compressed-step/direct/s B_0 TransitionSpan B_1))
        (computed-name
         (term (transition-span->string/s TransitionSpan)))]))
