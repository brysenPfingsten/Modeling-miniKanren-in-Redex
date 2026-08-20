#lang racket

(require redex/reduction-semantics
         "../languages/search-lang.rkt"
         (only-in "../../../languages/core-lang.rkt" owners-append)
         "./search-join-base-red.rkt"
         "../../../reduction-relations/private/step-utils.rkt")

(provide distribute-choice/raw
         search-distributed-red
         step-once)

(check-redundancy #t)

(define distribute-choice/raw
  (reduction-relation
   distributed-search-lang
   #:domain any
   [--> (Conj owners_conj (DisjL owners_choice W_1 W_2) g)
        (DisjL (owners-append owners_conj owners_choice)
               (Conj (Owners) W_1 g)
               (Conj (Owners) W_2 g))
        "distribute-choice"]))

(define distribute-choice
  (context-closure distribute-choice/raw distributed-search-lang EarlyWF))

(define distribute-right
  (let ([raw
         (reduction-relation
          distributed-search-lang
          #:domain any
          [--> (Conj owners_conj (DisjR owners_choice W_1 W_2) g)
               (DisjR (owners-append owners_conj owners_choice)
                      (Conj (Owners) W_1 g)
                      (Conj (Owners) W_2 g))
               "distribute-right-choice"])])
    (context-closure raw distributed-search-lang EarlyWF)))

(define search-distributed-red
  (extend-reduction-relation
   (union-reduction-relations
    search-distributed-pre-red
    distribute-choice
    distribute-right)
   distributed-search-lang
   #:domain F))

(define (step-once prog)
  (step-once/deterministic search-distributed-red prog))
