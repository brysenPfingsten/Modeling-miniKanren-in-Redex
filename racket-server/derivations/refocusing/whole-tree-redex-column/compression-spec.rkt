#lang racket

(require redex/reduction-semantics
         "./compressed.rkt"
         (only-in "./kernel-toy.rkt"
                  wf-frontier/toy)
         (only-in "./machine.rkt"
                  machine-refocus-query/direct
                  machine-step/direct))

(provide redex-column-compression-spec-lang
         decode-BM
         replay-labels/exact
         replay-span/exact
         replay-spans/exact
         root-fresh-machine
         not-root-fresh-machine
         corridor-continue-first
         corridor-stop-first
         corridor-continue-second
         corridor-stop-second
         compressed-step/spec
         compression-step-square
         compression-steps-square
         reachable-compression-correspondence)

(check-redundancy #t)

;; These classes state the canonical corridor policy as Redex syntax.  A
;; producer always crosses one following exact-machine edge.  An unfinished
;; constructor-production edge crosses a following root WorkFresh exposure,
;; but otherwise ends the corridor.  The remaining labels always end it.
(define-extended-language redex-column-compression-spec-lang
  redex-column-compressed-lang
  [ProducerFollowup
   (work-succeed core)
   (work-fail core)
   (work-put core)
   (suspend-goal delay)]
  [AfterUnfinished
   (allocate-fresh core)
   (expand-conjunction core)
   (expand-disjunction disj)
   (conj-return core)
   (late-distribute-settled disj)
   (late-distribute-right-settled search-join)]
  [OtherFirst
   (expose-frontier-fresh core)
   (finish-success core)
   (finish-failure core)
   (force-delay delay)
   (commit-choice-answer disj)
   (commit-right-choice-answer search-join)
   (expose-choice-through-work-fresh disj)
   (expose-choice-through-work-fresh search-join)
   (erase-dead-fresh core)
   (bubble-delay-through-fresh delay)
   (conj-fail core)
   (bubble-delay-through-conj delay)
   (skip-left-failure disj)
   (rail-enter-right search-join)
   (reassociate-left-result disj)
   (skip-right-failure search-join)
   (rail-return-left search-join)
   (reassociate-right-result search-join)]
  [NotAfter ProducerFollowup OtherFirst]
  ;; A root-fresh complement needs a constructor class for the Work payload
  ;; immediately below More.  WorkFresh is intentionally absent.
  [NonFreshRoot
   (Work g st)
   (Returned st)
   Dead
   (Conj W g)
   (PendingDelay W)
   (DisjL W W)
   (DisjR W W)])

;; Decode a residual compressed control mode by running only the exact
;; machine's retained-context refocuser.  This is a correspondence relation,
;; not a transition implementation, and it never invokes compressed control.
(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (decode-BM B M)
  #:mode (decode-BM I O)

  [(machine-refocus-query/direct
    (MQWork NW TopW FF)
    M)
   ---------------------------------------------------- "decode running residual"
   (decode-BM
    (BRun NW (in-hole FF (More TopW)))
    M)]

  [(machine-refocus-query/direct
    (MQWork SR TopW FF)
    M)
   ---------------------------------------------------- "decode settled residual"
   (decode-BM
    (BSettled SR (in-hole FF (More TopW)))
    M)]

  [(machine-refocus-query/direct
    (MQWork Dead TopW FF)
    M)
   ---------------------------------------------------- "decode dead residual"
   (decode-BM
    (BDead (in-hole FF (More TopW)))
    M)]

  [(machine-refocus-query/direct
    (MQWork (PendingDelay W) TopW FF)
    M)
   ---------------------------------------------------- "decode delayed residual"
   (decode-BM
    (BDelay W (in-hole FF (More TopW)))
    M)]

  [---------------------------------------------------- "decode final residual"
   (decode-BM (BFinal T FF) (MFrontier T FF))])

;; Exact, label-sensitive replay is explicit rather than delegated to an
;; unlabelled reflexive-transitive closure.
(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (replay-labels/exact M MLabels M)
  #:mode (replay-labels/exact I I O)

  [---------------------------------------------------- "replay no exact labels"
   (replay-labels/exact M () M)]

  [(machine-step/direct M_0 ell M_1)
   (replay-labels/exact M_1 (ell_rest ...) M_2)
   ---------------------------------------------------- "replay one exact label"
   (replay-labels/exact M_0 (ell ell_rest ...) M_2)])

(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (replay-span/exact M Span M)
  #:mode (replay-span/exact I I O)

  [(replay-labels/exact M_0 (ell_0 ell_rest ...) M_1)
   ---------------------------------------------------- "replay nonempty span"
   (replay-span/exact
    M_0
    (transition-span ell_0 ell_rest ...)
    M_1)])

(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (replay-spans/exact M Spans M)
  #:mode (replay-spans/exact I I O)

  [---------------------------------------------------- "replay no spans"
   (replay-spans/exact M () M)]

  [(replay-span/exact M_0 Span M_1)
   (replay-spans/exact M_1 (Span_rest ...) M_2)
   ---------------------------------------------------- "replay one span"
   (replay-spans/exact M_0 (Span Span_rest ...) M_2)])

;; Root freshness is an exact machine-state shape.  Its complement is also
;; grammatical: either a non-fresh payload is immediately below More, or at
;; least one ordinary W frame lies between the payload and More, or the state
;; is already a frontier state.
(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (root-fresh-machine M)
  #:mode (root-fresh-machine I)

  [---------------------------------------------------- "root WorkFresh machine state"
   (root-fresh-machine
    (MWork
     (WorkFresh intro W tag)
     (in-hole FF (More hole))))])

(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (not-root-fresh-machine M)
  #:mode (not-root-fresh-machine I)

  [---------------------------------------------------- "nonfresh root machine state"
   (not-root-fresh-machine
    (MWork NonFreshRoot (in-hole FF (More hole))))]

  [---------------------------------------------------- "machine state below ordinary frame"
   (not-root-fresh-machine (MWork W WF+))]

  [---------------------------------------------------- "frontier machine state is not root fresh"
   (not-root-fresh-machine (MFrontier T FF))])

;; The first exact edge either stops a one-step span or mandates a second
;; edge.  The clauses are disjoint because the label classes and root-shape
;; judgments are disjoint.
(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (corridor-continue-first ell M)
  #:mode (corridor-continue-first I I)

  [---------------------------------------------------- "producer requires followup"
   (corridor-continue-first ProducerFollowup M)]

  [(root-fresh-machine M)
   ---------------------------------------------------- "unfinished result exposes root fresh"
   (corridor-continue-first AfterUnfinished M)])

(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (corridor-stop-first ell M)
  #:mode (corridor-stop-first I I)

  [---------------------------------------------------- "ordinary first edge stops"
   (corridor-stop-first OtherFirst M)]

  [(not-root-fresh-machine M)
   ---------------------------------------------------- "unfinished result has no root exposure"
   (corridor-stop-first AfterUnfinished M)])

;; Only an unfinished-producing second edge followed by a root WorkFresh can
;; extend a producer corridor to its third and final exact edge.
(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (corridor-continue-second ell M)
  #:mode (corridor-continue-second I I)

  [(root-fresh-machine M)
   ---------------------------------------------------- "second edge exposes root fresh"
   (corridor-continue-second AfterUnfinished M)])

(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (corridor-stop-second ell M)
  #:mode (corridor-stop-second I I)

  [---------------------------------------------------- "non-producing second edge stops"
   (corridor-stop-second NotAfter M)]

  [(not-root-fresh-machine M)
   ---------------------------------------------------- "second unfinished result has no exposure"
   (corridor-stop-second AfterUnfinished M)])

;; This specification is compositionally obtained from exact marked-machine
;; edges.  It returns the exact endpoint, avoiding any assumption that the
;; compressed decoder has an inverse outside its reachable image.
(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (compressed-step/spec B Span M)
  #:mode (compressed-step/spec I O O)

  [(decode-BM B_0 M_0)
   (machine-step/direct M_0 ell_1 M_1)
   (corridor-continue-first ell_1 M_1)
   (machine-step/direct M_1 ell_2 M_2)
   (corridor-continue-second ell_2 M_2)
   (machine-step/direct M_2 ell_3 M_3)
   ---------------------------------------------------- "canonical three-edge corridor"
   (compressed-step/spec
    B_0
    (transition-span ell_1 ell_2 ell_3)
    M_3)]

  [(decode-BM B_0 M_0)
   (machine-step/direct M_0 ell_1 M_1)
   (corridor-continue-first ell_1 M_1)
   (machine-step/direct M_1 ell_2 M_2)
   (corridor-stop-second ell_2 M_2)
   ---------------------------------------------------- "canonical two-edge corridor"
   (compressed-step/spec
    B_0
    (transition-span ell_1 ell_2)
    M_2)]

  [(decode-BM B_0 M_0)
   (machine-step/direct M_0 ell_1 M_1)
   (corridor-stop-first ell_1 M_1)
   ---------------------------------------------------- "canonical one-edge corridor"
   (compressed-step/spec
    B_0
    (transition-span ell_1)
    M_1)])

;; The executable commuting square keeps the direct target B_1 and both exact
;; endpoints visible.  Specification agreement and exact replay are separate
;; premises so tests can interrogate either obligation independently.
(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (compression-step-square B Span B M M)
  #:mode (compression-step-square I O O O O)

  [(decode-BM B_0 M_0)
   (compressed-step/direct B_0 Span B_1)
   (decode-BM B_1 M_1)
   (compressed-step/spec B_0 Span M_1)
   (replay-span/exact M_0 Span M_1)
   ---------------------------------------------------- "compressed/exact commuting square"
   (compression-step-square B_0 Span B_1 M_0 M_1)])

;; The path square exposes every intermediate decoder agreement, rather than
;; checking only the two endpoints of a concatenated trace.
(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (compression-steps-square B Spans B M M)
  #:mode (compression-steps-square I O O O O)

  [(decode-BM B M)
   ---------------------------------------------------- "empty compressed/exact path square"
   (compression-steps-square B () B M M)]

  [(compression-step-square B_0 Span B_1 M_0 M_1)
   (compression-steps-square
    B_1
    (Span_rest ...)
    B_2
    M_1
    M_2)
   ---------------------------------------------------- "nonempty compressed/exact path square"
   (compression-steps-square
    B_0
    (Span Span_rest ...)
    B_2
    M_0
    M_2)])

;; Reachable-path correspondence is explicitly restricted to well-formed toy
;; roots, so duplicate-binder syntax never silently enters the theorem domain.
;; This is a metatheoretic image judgment; no image tag is stored in a B or M
;; state.
(define-judgment-form
  redex-column-compression-spec-lang
  #:contract (reachable-compression-correspondence F Spans B M)
  #:mode (reachable-compression-correspondence I O O O)

  [(wf-frontier/toy F)
   (initial-compressed/direct F B_0)
   (compression-steps-square B_0 Spans B_1 M_0 M_1)
   ---------------------------------------------------- "reachable compressed/exact image"
   (reachable-compression-correspondence F Spans B_1 M_1)])
