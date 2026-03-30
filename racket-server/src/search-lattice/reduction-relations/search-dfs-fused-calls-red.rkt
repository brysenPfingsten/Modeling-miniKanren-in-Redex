#lang racket

(require redex/reduction-semantics
         "../languages/search-base-fused-calls-lang.rkt"
         "./search-base-fused-calls-red.rkt"
         "./private/step-utils.rkt"
         )

(provide search-dfs-fused-calls-extra
         search-dfs-fused-calls-red
         step-once)

(check-redundancy #t)

(define search-dfs-fused-calls-extra
  (reduction-relation
   search-base-fused-calls-lang
   #:domain config
   [--> (Γ (in-hole QSpine (in-hole KBranch (in-hole KWork ((delay runnable-search_1) <-+ search_2)))))
        (Γ (in-hole QSpine (in-hole KBranch (in-hole KWork (delay (runnable-search_1 <-+ search_2))))))
        "search-dfs-fused-calls/delay-through-left"]))

(define search-dfs-fused-calls-red
  (union-reduction-relations
   search-base-fused-calls-red
   search-dfs-fused-calls-extra))

(define (step-once prog)
  (step-once/deterministic search-dfs-fused-calls-red prog))
