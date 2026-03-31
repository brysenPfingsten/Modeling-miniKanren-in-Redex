#lang racket

(require redex/reduction-semantics
         "../languages/search-base-seq-lang.rkt"
         "./search-base-seq-pre-red.rkt"
         "./private/step-utils.rkt")

(provide search-base-seq-red
         step-once)

(check-redundancy #t)

(define search-base-seq-branch-local/base
  (reduction-relation
   search-base-seq-lang
   #:domain cfg
   [--> (in-hole KBranch ((search_1 <-+ search_2) × g c))
        (in-hole KBranch ((search_1 × g c) <-+ (search_2 × g c)))
        "search-base-seq/distribute-over-conj"]))

(define search-base-seq-branch-local/under-QShell
  (context-closure search-base-seq-branch-local/base search-base-seq-lang QShell))

(define search-base-seq-red
  (union-reduction-relations
   search-base-seq-pre-red
   search-base-seq-branch-local/under-QShell))

(define (step-once prog)
  (step-once/deterministic search-base-seq-red prog))
