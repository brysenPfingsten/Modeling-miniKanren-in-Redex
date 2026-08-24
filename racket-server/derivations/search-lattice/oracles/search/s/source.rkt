#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "../private/shared.rkt"
         (only-in "../../core/s/language.rkt" owners-append/s)
         (prefix-in core: "../../core/s/source.rkt"))

(provide subst-goal/search/s
         work-focus-prefix-support/search/s
         work/delta/delay/search/s
         work/delta/disjunction/search/s
         frontier/delta/delay/search/s
         frontier/delta/disjunction/search/s
         allocate/base/search/s
         work/base/search/s
         frontier/base/search/s
         search-s-oracle-red
         search-s-oracle-red/disjunction-first
         raw-successors/search/s
         raw-successors/search/s/disjunction-first
         trace/search/s)

(check-redundancy #t)

(define (subst-goal/search/s goal substitutions)
  (substitute-goal/search
   goal
   substitutions
   core:subst-term/s
   'subst-goal/search/s))

(define (redex-hole/s? datum)
  (equal? datum (term hole)))

;; Allocation follows the sole active world: through Forced and Emit residuals,
;; then the active-left DisjL path.  It never crosses PendingDelay or visits a
;; sibling or settled answer.
(define (work-focus-prefix-support/search/s work-focus [support '()])
  (match work-focus
    [(? redex-hole/s?) support]
    [`(More ,work-path)
     (work-focus-prefix-support/search/s work-path support)]
    [`(Conj ,owners ,work-path ,_goal)
     (work-focus-prefix-support/search/s
      work-path
      (core:extend-support-with-owners/s owners support))]
    [`(DisjL ,owners ,work-path ,_right)
     (work-focus-prefix-support/search/s
      work-path
      (core:extend-support-with-owners/s owners support))]
    [`(Forced ,owners ,spine-context)
     (work-focus-prefix-support/search/s
      spine-context
      (core:extend-support-with-owners/s owners support))]
    [`(Emit ,owners ,_answer ,spine-context)
     (work-focus-prefix-support/search/s
      spine-context
      (core:extend-support-with-owners/s owners support))]
    [_
     (error 'work-focus-prefix-support/search/s
            "expected a Search S work-focus context, received ~e"
            work-focus)]))

;; Delay contributes exactly its three independently owned equations.
(define work/delta/delay/search/s
  (reduction-relation
   search-s-oracle-lang
   #:domain any

   [--> (Work owners (suspend g tag) σ)
        (PendingDelay owners (Work (Owners) g σ))
        "suspend-goal"]

   [--> (Conj owners_outer
              (PendingDelay owners_delay
                            (in-hole WorkOwnerSlot_1 owners_payload))
              g)
        (PendingDelay
         owners_outer
         (Conj (Owners)
               (in-hole WorkOwnerSlot_1 owners_attached)
               g))
        (where owners_attached
               (owners-append/s owners_delay owners_payload))
        "bubble-delay-through-conj"]))

(define frontier/delta/delay/search/s
  (reduction-relation
   search-s-oracle-lang
   #:domain any
   [--> (More (PendingDelay owners W))
        (Forced owners (More W))
        "force-delay"]))

;; Disjunction contributes exactly its five independently owned equations.
(define work/delta/disjunction/search/s
  (reduction-relation
   search-s-oracle-lang
   #:domain any

   [--> (Work owners (g_1 ∨ g_2 tag) σ)
        (DisjL owners
               (Work (Owners) g_1 σ)
               (Work (Owners) g_2 σ))
        "expand-disjunction"]

   [--> (DisjL owners_choice
               (Dead owners_dead)
               (in-hole WorkOwnerSlot_1 owners_remaining))
        (in-hole WorkOwnerSlot_1
                 (owners-append/s owners_choice owners_remaining))
        "skip-left-failure"]

   [--> (DisjL owners_outer
               (DisjL owners_inner
                      (Returned owners_answer σ)
                      (in-hole WorkOwnerSlot_1 owners_left))
               W_2)
        (DisjL
         owners_outer
         (Returned (owners-append/s owners_inner owners_answer) σ)
         (DisjL
          (Owners)
          (in-hole WorkOwnerSlot_1
                   (owners-append/s owners_inner owners_left))
          W_2))
        "reassociate-left-result"]

   [--> (Conj owners_conj
              (DisjL owners_choice
                     (Returned owners_answer σ)
                     W)
              g)
        (DisjL (owners-append/s owners_conj owners_choice)
               (Work owners_answer g σ)
               (Conj (Owners) W g))
        "resume-left-choice-success"]))

(define frontier/delta/disjunction/search/s
  (reduction-relation
   search-s-oracle-lang
   #:domain any
   [--> (More
         (DisjL owners_choice
                (Returned owners_answer σ)
                W))
        (Emit owners_choice
              (Answer owners_answer σ)
              (More W))
        "commit-choice-answer"]))

;; Reinterpret core once over the joined grammar, then union each feature delta
;; once.  The alternate order is an independent commutation witness; neither
;; relation duplicates core and neither contains a Search-owned rule.
(define work/raw/core/search/s
  (extend-reduction-relation
   core:work/raw/s
   search-s-oracle-lang
   #:domain any))

(define frontier/raw/core/search/s
  (extend-reduction-relation
   core:frontier/raw/s
   search-s-oracle-lang
   #:domain any))

(define work/raw/search/s
  (union-reduction-relations
   work/raw/core/search/s
   work/delta/delay/search/s
   work/delta/disjunction/search/s))

(define work/raw/search/s/disjunction-first
  (union-reduction-relations
   work/raw/core/search/s
   work/delta/disjunction/search/s
   work/delta/delay/search/s))

(define frontier/raw/search/s
  (union-reduction-relations
   frontier/raw/core/search/s
   frontier/delta/delay/search/s
   frontier/delta/disjunction/search/s))

(define frontier/raw/search/s/disjunction-first
  (union-reduction-relations
   frontier/raw/core/search/s
   frontier/delta/disjunction/search/s
   frontier/delta/delay/search/s))

(core:define-allocation/base/s
  allocate/base/search/s
  search-s-oracle-lang
  subst-goal/search/s
  work-focus-prefix-support/search/s)

(define work/base/search/s
  (context-closure work/raw/search/s search-s-oracle-lang WorkFocus))

(define work/base/search/s/disjunction-first
  (context-closure
   work/raw/search/s/disjunction-first
   search-s-oracle-lang
   WorkFocus))

(define frontier/base/search/s
  (context-closure frontier/raw/search/s search-s-oracle-lang SpineContext))

(define frontier/base/search/s/disjunction-first
  (context-closure
   frontier/raw/search/s/disjunction-first
   search-s-oracle-lang
   SpineContext))

(define search-s-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/search/s
    frontier/base/search/s
    allocate/base/search/s)
   search-s-oracle-lang
   #:domain F))

(define search-s-oracle-red/disjunction-first
  (extend-reduction-relation
   (union-reduction-relations
    work/base/search/s/disjunction-first
    frontier/base/search/s/disjunction-first
    allocate/base/search/s)
   search-s-oracle-lang
   #:domain F))

(define (raw-successors/search/s frontier)
  (raw-named-successors search-s-oracle-red frontier))

(define (raw-successors/search/s/disjunction-first frontier)
  (raw-named-successors search-s-oracle-red/disjunction-first frontier))

(define (trace/search/s frontier [fuel 64])
  (finite-named-trace search-s-oracle-red frontier fuel))
