#lang racket

(require redex/reduction-semantics
         "../languages/search-base-lang.rkt"
         "./search-base-pre-red.rkt"
         "./private/step-utils.rkt")

(provide search-base-seq-red
         step-once)

(check-redundancy #t)

(define search-base-seq-branch-local/base
  (reduction-relation
   search-base-lang
   #:domain cfg
   [--> (in-hole KWork ((search_1 <-+ search_2) × g c))
        (in-hole KWork ((search_1 × g c) <-+ (search_2 × g c)))
        "search-base-seq/distribute-over-conj"]))

(define search-base-seq-branch-local/under-KBranch
  (context-closure search-base-seq-branch-local/base search-base-lang KBranch))

(define search-base-seq-branch-local/under-QSpine
  (context-closure search-base-seq-branch-local/under-KBranch search-base-lang QSpine))

(define search-base-seq-red
  (union-reduction-relations
   search-base-pre-red
   search-base-seq-branch-local/under-QSpine))

(define (step-once prog)
  (step-once/deterministic search-base-seq-red prog))
