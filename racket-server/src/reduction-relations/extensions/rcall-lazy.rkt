#lang racket

(require redex/reduction-semantics
         "./common.rkt"
         "./core-l1.rkt")

(check-redundancy #t)

(provide call-lazy-extra/l1
         Rcall-lazy)

(define call-lazy-extra/l1
  (reduction-relation
    L1/K
    #:domain config
    [--> (Γ (in-hole Kcall ((r t ... tag) σ)))
         (Γ (in-hole Kcall (delay (proceed ((r t ... tag) σ)))))
         "call/lazy-suspend-call"]

    [--> (Γ (delay (proceed ((r t ... tag) σ))))
         (Γ (proceed ((r t ... tag) σ)))
         "call/lazy-invoke-delay"]

    [--> (Γ (delay s_1))
         (Γ s_1)
         (side-condition (not (redex-match? L1/K (proceed pr) (term s_1))))
         "call/invoke-delay"]

    [--> (Γ (in-hole Kcall (proceed ((r t ... tag) σ))))
         (Γ (in-hole Kcall (g_new σ)))
         (where g_new ,(instantiate-call-host (term Γ) (term r) (term (t ...))))
         "call/lazy-expand-on-resume"]

    [--> (Γ (in-hole Kcall ((delay s_1) × g c)))
         (Γ (in-hole Kcall (delay (s_1 × g c))))
         "call/delay-through-conj"]))

(define Rcall-lazy
  (union-reduction-relations
   call-lazy-extra/l1
   core-cfg/l1))
