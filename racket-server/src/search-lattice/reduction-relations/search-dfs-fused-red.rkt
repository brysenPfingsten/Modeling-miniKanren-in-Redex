#lang racket

(require redex/reduction-semantics
         "../languages/search-base-fused-lang.rkt"
         "./private/step-utils.rkt"
         "./search-base-fused-red.rkt")

(provide search-dfs-fused-extra
         search-dfs-fused-red
         step-once)

(check-redundancy #t)

(define search-dfs-fused-extra/base
  (reduction-relation
   search-base-fused-lang
   #:domain cfg
   [--> (in-hole KBranch ((delay runnable-search_1) <-+ search_2))
        (in-hole KBranch (delay (runnable-search_1 <-+ search_2)))
        "search-dfs-fused/delay-through-left"]))

(define search-dfs-fused-extra
  (context-closure search-dfs-fused-extra/base search-base-fused-lang QShell))

(define search-dfs-fused-red
  (union-reduction-relations
   search-base-fused-red
   search-dfs-fused-extra))

(define (step-once prog)
  (step-once/deterministic search-dfs-fused-red prog))
