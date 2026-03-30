#lang racket

(require redex/reduction-semantics
         "../languages/disj-lang.rkt"
         "./disj-base-red.rkt"
         "./private/step-utils.rkt")

(provide disj-fused-local/under-QSpine
         disj-fused-red
         step-once)

(check-redundancy #t)

(define disj-fused-local/base
  (reduction-relation
   disj-lang
   #:domain cfg
   [--> (in-hole KWork (((in-hole QFresh (⊤ σ_new)) <-+ search_rest) × g c))
        (in-hole KWork ((in-hole QFresh (g σ_new)) <-+ (search_rest × g c)))
        "disj-fused/continue-left-answer"]
   [--> (in-hole KWork (((empty-tree) <-+ search_rest) × g c))
        (in-hole KWork (search_rest × g c))
        "disj-fused/continue-left-fail"]))

(define disj-fused-local/under-KBranch
  (context-closure disj-fused-local/base disj-lang KBranch))

(define disj-fused-local/under-QSpine
  (context-closure disj-fused-local/under-KBranch disj-lang QSpine))

(define disj-fused-red
  (union-reduction-relations
   disj-base-core
   disj-goal-local/under-QSpine
   disj-frontier/base
   disj-fused-local/under-QSpine
   ))

(define (step-once prog)
  (step-once/deterministic disj-fused-red prog))
