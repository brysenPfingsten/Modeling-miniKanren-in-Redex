#lang racket

(require redex/reduction-semantics
         "../languages/disj-lang.rkt"
         (only-in "../languages/core-lang.rkt" owners-append)
         (prefix-in core: "./core-red.rkt"))

(provide work/nonchoice/delta/raw
         work/choice/delta/raw
         work/delta/raw
         frontier/delta/raw
         work/nonchoice/raw
         work/raw
         frontier/raw
         allocate/base
         work/base
         frontier/base)

(check-redundancy #t)

(define work/nonchoice/delta/raw
  (reduction-relation
   disj-lang
   #:domain any
   [--> (Work owners (g_1 ∨ g_2 tag) σ)
        (DisjL owners (Work (Owners) g_1 σ) (Work (Owners) g_2 σ))
        "expand-disjunction"]))

(define work/choice/delta/raw
  (reduction-relation
   disj-lang
   #:domain any
   [--> (DisjL owners_choice
               (Dead owners_dead)
               (in-hole WorkOwnerSlot_1 owners_remaining))
        (in-hole WorkOwnerSlot_1
                 owners_survivor)
        (where owners_survivor
               (owners-append owners_choice owners_remaining))
        "skip-left-failure"]
   [--> (DisjL owners_outer
               (DisjL owners_inner
                      (Returned owners_answer σ)
                      (in-hole WorkOwnerSlot_1 owners_left))
               W_2)
        (DisjL
         owners_outer
         (Returned owners_settled σ)
         (DisjL (Owners)
                (in-hole WorkOwnerSlot_1
                         owners_residual)
                W_2))
        (where owners_settled
               (owners-append owners_inner owners_answer))
        (where owners_residual
               (owners-append owners_inner owners_left))
        "reassociate-left-result"]))

(define work/delta/raw
  (union-reduction-relations
   work/nonchoice/delta/raw
   work/choice/delta/raw))

(define frontier/delta/raw
  (reduction-relation
   disj-lang
   #:domain any
   [--> (More (DisjL owners_choice (Returned owners_answer σ) W))
        (Emit owners_choice (Answer owners_answer σ) (More W))
        "commit-choice-answer"]))

(define work/nonchoice/raw
  (union-reduction-relations
   (extend-reduction-relation core:work/raw disj-lang)
   work/nonchoice/delta/raw))

(define work/raw
  (union-reduction-relations
   work/nonchoice/raw
   work/choice/delta/raw))

(define frontier/raw
  (union-reduction-relations
   (extend-reduction-relation core:frontier/raw disj-lang)
   frontier/delta/raw))

(define allocate/base
  (extend-reduction-relation core:allocate/base disj-lang))

(define work/base
  (context-closure work/raw disj-lang WorkFocus))

(define frontier/base
  (context-closure frontier/raw disj-lang SpineContext))
