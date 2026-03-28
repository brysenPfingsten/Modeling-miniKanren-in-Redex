#lang racket

(require redex/reduction-semantics
         "../languages/search-base-fused-lang.rkt"
         "./private/step-utils.rkt"
         "./search-base-fused-red.rkt")

(provide search-dfs-fused-extra
         search-dfs-fused-red
         step-once)

(check-redundancy #t)

(define search-dfs-fused-extra
  (reduction-relation
   search-base-fused-lang
   #:domain cfg
   [--> (in-hole QSpine (in-hole KBranch (in-hole KWork ((delay delayed_1) <-+ search_2))))
        (in-hole QSpine (in-hole KBranch (in-hole KWork (delay (delayed_1 <-+ search_2)))))
        "search-dfs-fused/delay-through-left"]))

(define search-dfs-fused-red
  (union-reduction-relations
   search-base-fused-red
   search-dfs-fused-extra))

(define (step-once prog)
  (step-once/deterministic search-dfs-fused-red prog))
