#lang racket

(require redex/reduction-semantics
         "../languages/search-lang.rkt"
         (only-in "../../dormant-branch-semantics/source/languages/core-lang.rkt" owners-append)
         "../../dormant-branch-semantics/source/reduction-relations/private/step-utils.rkt"
         "./search-red.rkt")

(provide search-dfs-distributed-extra
         search-dfs-distributed-red
         step-once)

(check-redundancy #t)

(define search-dfs-distributed-extra
  (let ([raw
         (reduction-relation
          distributed-search-lang
          #:domain any
          [--> (DisjL owners_choice
                       (PendingDelay
                        owners_delay
                        (in-hole WorkOwnerSlot_1 owners_payload))
                       W_2)
               (PendingDelay
                (Owners)
                (DisjL owners_choice
                       (in-hole WorkOwnerSlot_1
                                owners_delayed)
                       W_2))
               (where owners_delayed
                      (owners-append owners_delay owners_payload))
               "dfs-delay-left"])])
    (context-closure raw distributed-search-lang EarlyChoiceWF)))

(define search-dfs-distributed-red
  (extend-reduction-relation
   (union-reduction-relations search-distributed-red
                              search-dfs-distributed-extra)
   distributed-search-lang
   #:domain F))

(define (step-once prog)
  (step-once/deterministic search-dfs-distributed-red prog))
