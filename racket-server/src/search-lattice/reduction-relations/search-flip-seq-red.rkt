#lang racket

(require redex/reduction-semantics
         "../languages/search-base-seq-lang.rkt"
         "./private/step-utils.rkt"
         "./search-base-seq-red.rkt")

(provide search-flip-seq-extra
         search-flip-seq-red
         step-once)

(check-redundancy #t)

(define search-flip-seq-extra/base
  (reduction-relation
   search-base-seq-lang
   #:domain cfg
   [--> (in-hole KBranch ((delay runnable-search_1) <-+ search_2))
        (in-hole KBranch (delay (search_2 <-+ runnable-search_1)))
        "search-flip-seq/delay-swap-left"]))

(define search-flip-seq-extra
  (context-closure search-flip-seq-extra/base search-base-seq-lang QShell))

(define search-flip-seq-red
  (union-reduction-relations
   search-base-seq-red
   search-flip-seq-extra))

(define (step-once prog)
  (step-once/deterministic search-flip-seq-red prog))
