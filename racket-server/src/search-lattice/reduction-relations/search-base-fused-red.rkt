#lang racket

(require redex/reduction-semantics
         "../languages/search-base-fused-lang.rkt"
         "./search-base-pre-red.rkt"
         "./private/step-utils.rkt")

(provide search-base-fused-red
         step-once)

(check-redundancy #t)

(define search-base-fused-branch-local/base
  (reduction-relation
   search-base-fused-lang
   #:domain cfg
   [--> (in-hole KBranch
                  (in-hole KWork (((in-hole QFront (⊤ σ_new)) <-+ search_rest) × g c)))
        (in-hole KBranch
                 (in-hole KWork ((in-hole QFront (g σ_new)) <-+ (search_rest × g c))))
        "search-base-fused/continue-left-answer"]
   [--> (in-hole KBranch (in-hole KWork (((empty-tree) <-+ search_rest) × g c)))
        (in-hole KBranch (in-hole KWork (search_rest × g c)))
        "search-base-fused/continue-left-fail"]))

(define search-base-fused-branch-local/under-QSpine
  (context-closure search-base-fused-branch-local/base search-base-fused-lang QSpine))

(define search-base-fused-red
  (union-reduction-relations
   search-base-fused-pre-red
   search-base-fused-branch-local/under-QSpine))

(define (step-once prog)
  (step-once/deterministic search-base-fused-red prog))
