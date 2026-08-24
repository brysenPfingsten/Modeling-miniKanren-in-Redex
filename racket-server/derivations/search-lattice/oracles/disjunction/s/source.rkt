#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "../private/shared.rkt"
         (only-in "../../core/s/language.rkt" owners-append/s)
         (prefix-in core: "../../core/s/source.rkt"))

(provide subst-goal/disjunction/s
         work-focus-prefix-support/disjunction/s
         work/raw/disjunction/s
         frontier/raw/disjunction/s
         allocate/base/disjunction/s
         work/base/disjunction/s
         frontier/base/disjunction/s
         disjunction-s-oracle-red
         raw-successors/disjunction/s
         trace/disjunction/s)

(check-redundancy #t)

(define (subst-goal/disjunction/s goal substitutions)
  (substitute-goal/disjunction
   goal
   substitutions
   core:subst-term/s
   'subst-goal/disjunction/s))

(define (redex-hole/s? datum)
  (equal? datum (term hole)))

;; Allocation reads only the unique active-world prefix.  In particular it
;; descends through the left child of DisjL and the residual of Emit, never
;; through an incomparable sibling or a settled answer.
(define (work-focus-prefix-support/disjunction/s work-focus [support '()])
  (match work-focus
    [(? redex-hole/s?) support]
    [`(More ,work-path)
     (work-focus-prefix-support/disjunction/s work-path support)]
    [`(Conj ,owners ,work-path ,_goal)
     (work-focus-prefix-support/disjunction/s
      work-path
      (core:extend-support-with-owners/s owners support))]
    [`(DisjL ,owners ,work-path ,_right)
     (work-focus-prefix-support/disjunction/s
      work-path
      (core:extend-support-with-owners/s owners support))]
    [`(Emit ,owners ,_answer ,spine-context)
     (work-focus-prefix-support/disjunction/s
      spine-context
      (core:extend-support-with-owners/s owners support))]
    [_
     (error 'work-focus-prefix-support/disjunction/s
            "expected a Disjunction S work-focus context, received ~e"
            work-focus)]))

;; These four direct work equations plus the direct frontier equation below
;; are the complete neutral Disjunction layer.  The inherited core equations
;; remain the independently stated S source semantics.
(define work/raw/disjunction/s
  (extend-reduction-relation
   core:work/raw/s
   disjunction-s-oracle-lang
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

(define frontier/raw/disjunction/s
  (extend-reduction-relation
   core:frontier/raw/s
   disjunction-s-oracle-lang
   #:domain any

   [--> (More
         (DisjL owners_choice
                (Returned owners_answer σ)
                W))
        (Emit owners_choice
              (Answer owners_answer σ)
              (More W))
        "commit-choice-answer"]))

;; Reuse the core allocation equation, instantiated with this feature's goal
;; traversal and active-path view.
(core:define-allocation/base/s
  allocate/base/disjunction/s
  disjunction-s-oracle-lang
  subst-goal/disjunction/s
  work-focus-prefix-support/disjunction/s)

(define work/base/disjunction/s
  (context-closure
   work/raw/disjunction/s
   disjunction-s-oracle-lang
   WorkFocus))

(define frontier/base/disjunction/s
  (context-closure
   frontier/raw/disjunction/s
   disjunction-s-oracle-lang
   SpineContext))

(define disjunction-s-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/disjunction/s
    frontier/base/disjunction/s
    allocate/base/disjunction/s)
   disjunction-s-oracle-lang
   #:domain F))

(define (raw-successors/disjunction/s frontier)
  (raw-named-successors disjunction-s-oracle-red frontier))

(define (trace/disjunction/s frontier [fuel 64])
  (finite-named-trace disjunction-s-oracle-red frontier fuel))
