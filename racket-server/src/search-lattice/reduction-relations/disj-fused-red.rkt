#lang racket

(require redex/reduction-semantics
         "../languages/disj-lang.rkt"
         "./disj-base-red.rkt"
         "./private/step-utils.rkt")

(provide disj-fused-local/under-QSpine
         disj-fused-red
         step-once)

(check-redundancy #t)

(define-metafunction
  disj-lang
  promoted->search : promoted g -> search
  [(promoted->search (⊤ σ_new) g)
   (g σ_new)]
  [(promoted->search (Freshened c_1 promoted_i tag_1) g)
   (Freshened c_1 (promoted->search promoted_i g) tag_1)])

(define disj-fused-local/base
  (reduction-relation
   disj-lang
   #:domain cfg
   [--> (in-hole KWork ((promoted_i <-+ search_rest) × g c))
        (in-hole KWork ((promoted->search promoted_i g)
                        <-+
                        (search_rest × g c)))
        "disj-fused/continue-left-answer"]
   [--> (in-hole KWork (((empty-tree) <-+ search_rest) × g c))
        (in-hole KWork (search_rest × g c))
        "disj-fused/continue-left-fail"]))

(define disj-fused-local/under-QSpine
  (context-closure disj-fused-local/base disj-lang QSpine))

(define disj-fused-red
  (union-reduction-relations
   disj-base-core
   disj-goal-local/under-QSpine
   disj-frontier/base
   disj-fused-local/under-QSpine
   ))

(define (step-once prog)
  (step-once/deterministic disj-fused-red prog))
