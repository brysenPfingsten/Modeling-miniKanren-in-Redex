#lang racket

(require redex/reduction-semantics
         "../languages/rail-lang.rkt"
         (only-in "../languages/core-lang.rkt" owners-append)
         "./private/step-utils.rkt"
         (prefix-in search: "./search-red.rkt"))

(provide right-active/work/raw
         right-active/frontier/raw
         rail-scheduler/raw
         rail-delta-red
         rail-red
         step-once)

(check-redundancy #t)

(define right-active/work/raw
  (reduction-relation
   rail-lang
   #:domain any
   [--> (DisjR owners_choice
               (in-hole WorkOwnerSlot_1 owners_remaining)
               (Dead owners_dead))
        (in-hole WorkOwnerSlot_1
                 owners_survivor)
        (where owners_survivor
               (owners-append owners_choice owners_remaining))
        "skip-right-failure"]
   [--> (DisjL owners_outer
               (DisjR owners_inner
                      (in-hole WorkOwnerSlot_1 owners_left)
                      (Returned owners_answer σ))
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
        "reassociate-left-result/search-join"]
   [--> (DisjR owners_outer
               W_1
               (DisjL owners_inner
                      (Returned owners_answer σ)
                      (in-hole WorkOwnerSlot_1 owners_right)))
        (DisjR
         owners_outer
         (DisjR (Owners)
                W_1
                (in-hole WorkOwnerSlot_1
                         owners_residual))
         (Returned owners_settled σ))
        (where owners_residual
               (owners-append owners_inner owners_right))
        (where owners_settled
               (owners-append owners_inner owners_answer))
        "reassociate-right-result/left-nested"]
   [--> (DisjR owners_outer
               W_1
               (DisjR owners_inner
                      (in-hole WorkOwnerSlot_1 owners_right)
                      (Returned owners_answer σ)))
        (DisjR
         owners_outer
         (DisjR (Owners)
                W_1
                (in-hole WorkOwnerSlot_1
                         owners_residual))
         (Returned owners_settled σ))
        (where owners_residual
               (owners-append owners_inner owners_right))
        (where owners_settled
               (owners-append owners_inner owners_answer))
        "reassociate-right-result/right-nested"]
   [--> (Conj owners_conj
              (DisjR owners_choice
                     W
                     (Returned owners_answer σ))
              g)
        (DisjR owners_joined
               (Conj (Owners) W g)
               (Work owners_answer g σ))
        (where owners_joined
               (owners-append owners_conj owners_choice))
        "resume-right-choice-success"]))

(define right-active/frontier/raw
  (reduction-relation
   rail-lang
   #:domain any
   [--> (More (DisjR owners_choice W (Returned owners_answer σ)))
        (Emit owners_choice (Answer owners_answer σ) (More W))
        "commit-right-choice-answer"]))

(define rail-scheduler/raw
  (reduction-relation
   rail-lang
   #:domain any
   [--> (DisjL owners_choice
               (PendingDelay
                owners_delay
                (in-hole WorkOwnerSlot_1 owners_payload))
               W_2)
        (PendingDelay
         (Owners)
         (DisjR owners_choice
                (in-hole WorkOwnerSlot_1
                         owners_delayed)
                W_2))
        (where owners_delayed
               (owners-append owners_delay owners_payload))
        "rail-enter-right"]
   [--> (DisjR owners_choice
               W_1
               (PendingDelay
                owners_delay
                (in-hole WorkOwnerSlot_1 owners_payload)))
        (PendingDelay
         (Owners)
         (DisjL owners_choice
                W_1
                (in-hole WorkOwnerSlot_1
                         owners_delayed)))
        (where owners_delayed
               (owners-append owners_delay owners_payload))
        "rail-return-left"]))

(define right-active-red
  (union-reduction-relations
   (context-closure right-active/work/raw rail-lang WorkFocus)
   (context-closure right-active/frontier/raw rail-lang SpineContext)))

(define rail-scheduler-red
  (context-closure rail-scheduler/raw rail-lang WorkFocus))

;; This is exactly the rail-local delta. Keeping it separate lets the relcall
;; overlay lift the assembled search-relcall predecessor once, then add only
;; rail-owned behavior under Gamma.
(define rail-delta-red
  (extend-reduction-relation
   (union-reduction-relations right-active-red rail-scheduler-red)
   rail-lang
   #:domain F))

(define lifted-search-red
  (extend-reduction-relation search:search-red rail-lang))

(define rail-red
  (extend-reduction-relation
   (union-reduction-relations
    lifted-search-red
    rail-delta-red)
   rail-lang
   #:domain F))

(define (step-once prog)
  (step-once/deterministic rail-red prog))
