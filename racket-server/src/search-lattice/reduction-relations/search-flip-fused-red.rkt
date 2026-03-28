#lang racket

(require redex/reduction-semantics
         "../languages/search-base-fused-lang.rkt"
         "./private/step-utils.rkt"
         "./search-base-fused-red.rkt")

(provide search-flip-fused-extra
         search-flip-fused-red
         step-once)

(check-redundancy #t)

(define search-flip-fused-extra
  (reduction-relation
   search-base-fused-lang
   #:domain cfg
   [--> (in-hole QSpine (in-hole KBranch (in-hole KWork ((delay delayed_1) <-+ search_2))))
        (in-hole QSpine (in-hole KBranch (in-hole KWork (delay (search_2 <-+ delayed_1)))))
        "search-flip-fused/delay-swap-left"]))

(define search-flip-fused-red
  (union-reduction-relations
   search-base-fused-red
   search-flip-fused-extra))

(define (step-once prog)
  (step-once/deterministic search-flip-fused-red prog))
