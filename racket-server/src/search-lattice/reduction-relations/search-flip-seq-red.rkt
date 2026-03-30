#lang racket

(require redex/reduction-semantics
         "../languages/search-base-lang.rkt"
         "./private/step-utils.rkt"
         "./search-base-seq-red.rkt")

(provide search-flip-seq-extra
         search-flip-seq-red
         step-once)

(check-redundancy #t)

(define search-flip-seq-extra/base
  (reduction-relation
   search-base-lang
   #:domain cfg
   [--> (in-hole KWork ((delay runnable-search_1) <-+ search_2))
        (in-hole KWork (delay (search_2 <-+ runnable-search_1)))
        "search-flip-seq/delay-swap-left"]))

(define search-flip-seq-extra/under-KBranch
  (context-closure search-flip-seq-extra/base search-base-lang KBranch))

(define search-flip-seq-extra
  (context-closure search-flip-seq-extra/under-KBranch search-base-lang QSpine))

(define search-flip-seq-red
  (union-reduction-relations
   search-base-seq-red
   search-flip-seq-extra))

(define (step-once prog)
  (step-once/deterministic search-flip-seq-red prog))
