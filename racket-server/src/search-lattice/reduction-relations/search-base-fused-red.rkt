#lang racket

(require redex/reduction-semantics
         "../languages/search-base-fused-lang.rkt"
         "./search-base-fused-pre-red.rkt"
         "./private/step-utils.rkt")

(provide search-base-fused-red
         step-once)

(check-redundancy #t)

(define search-base-fused-branch-local/base
  (reduction-relation
   search-base-fused-lang
   #:domain cfg
   [--> (in-hole KBranch (((in-hole QFresh (⊤ σ_new)) <-+ search_rest) × g c))
        (in-hole KBranch ((in-hole QFresh (g σ_new)) <-+ (search_rest × g c)))
        "search-base-fused/continue-left-answer"]
   [--> (in-hole KBranch (((empty-tree) <-+ search_rest) × g c))
        (in-hole KBranch (search_rest × g c))
        "search-base-fused/continue-left-fail"]))

(define search-base-fused-branch-local/under-QShell
  (context-closure search-base-fused-branch-local/base search-base-fused-lang QShell))

(define search-base-fused-red
  (union-reduction-relations
   search-base-fused-pre-red
   search-base-fused-branch-local/under-QShell))

(define (step-once prog)
  (step-once/deterministic search-base-fused-red prog))
