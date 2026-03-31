#lang racket

(require redex/reduction-semantics
         "../languages/search-base-seq-lang.rkt"
         "./private/step-utils.rkt"
         "./search-base-seq-red.rkt")

(provide search-dfs-seq-extra
         search-dfs-seq-red
         step-once)

(check-redundancy #t)

(define search-dfs-seq-extra/base
  (reduction-relation
   search-base-seq-lang
   #:domain cfg
   [--> (in-hole KBranch ((delay runnable-search_1) <-+ search_2))
        (in-hole KBranch (delay (runnable-search_1 <-+ search_2)))
        "search-dfs-seq/delay-through-left"]))

(define search-dfs-seq-extra
  (context-closure search-dfs-seq-extra/base search-base-seq-lang QShell))

(define search-dfs-seq-red
  (union-reduction-relations
   search-base-seq-red
   search-dfs-seq-extra))

(define (step-once prog)
  (step-once/deterministic search-dfs-seq-red prog))
