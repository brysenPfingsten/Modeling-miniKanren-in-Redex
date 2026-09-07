#lang racket

(require redex/reduction-semantics
         "../languages/search-lang.rkt"
         (only-in "../../../src/search-lattice/languages/core-lang.rkt" owners-append)
         (prefix-in disj: "./disj-red.rkt")
         (prefix-in search: "factored-search-base.rkt"))

(provide right-active/work/raw
         right-active/frontier/raw
         search-distributed-pre-red)

(check-redundancy #t)

(define right-active/work/raw
  (reduction-relation
   distributed-search-lang
   #:domain any
   [--> (DisjR owners_choice
               (in-hole WorkOwnerSlot_1 owners_remaining)
               (Dead owners_dead))
        (in-hole WorkOwnerSlot_1 owners_survivor)
        (where owners_survivor
               (owners-append owners_choice owners_remaining))
        "skip-right-failure"]
   [--> (DisjL owners_outer
               (DisjR owners_inner
                      (in-hole WorkOwnerSlot_1 owners_left)
                      (Returned owners_answer σ))
               W_2)
        (DisjL owners_outer
               (Returned owners_settled σ)
               (DisjL (Owners)
                      (in-hole WorkOwnerSlot_1 owners_residual)
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
        (DisjR owners_outer
               (DisjR (Owners)
                      W_1
                      (in-hole WorkOwnerSlot_1 owners_residual))
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
        (DisjR owners_outer
               (DisjR (Owners)
                      W_1
                      (in-hole WorkOwnerSlot_1 owners_residual))
               (Returned owners_settled σ))
        (where owners_residual
               (owners-append owners_inner owners_right))
        (where owners_settled
               (owners-append owners_inner owners_answer))
        "reassociate-right-result/right-nested"]))

(define right-active/frontier/raw
  (reduction-relation
   distributed-search-lang
   #:domain any
   [--> (More (DisjR owners_choice W (Returned owners_answer σ)))
        (Emit owners_choice (Answer owners_answer σ) (More W))
        "commit-right-choice-answer"]))

(define search-distributed-pre-red
  (union-reduction-relations
   (context-closure search:work/nonchoice/raw
                    distributed-search-lang
                    EarlyWF)
   (context-closure search:work/choice/raw
                    distributed-search-lang
                    EarlyChoiceWF)
   (context-closure right-active/work/raw
                    distributed-search-lang
                    EarlyChoiceWF)
   (context-closure search:frontier/raw
                    distributed-search-lang
                    SpineContext)
   (context-closure right-active/frontier/raw
                    distributed-search-lang
                    SpineContext)
   (extend-reduction-relation disj:allocate/base
                              distributed-search-lang)))
