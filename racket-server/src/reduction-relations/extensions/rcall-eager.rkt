#lang racket

(require redex/reduction-semantics
         "./common.rkt"
         "./core-l1.rkt")

(check-redundancy #t)

(provide call-eager-extra/l1
         Rcall-eager)

(define call-eager-extra/l1
  (reduction-relation
    L1/K
    #:domain config
    [--> (Γ ans* (in-hole Kcall ((r t ... tag) σ)))
         (Γ ans* (in-hole Kcall (delay (proceed (g_new σ)))))
         (where g_new ,(instantiate-call-host (term Γ) (term r) (term (t ...))))
         "call/eager-suspend-expanded"]

    [--> (Γ ans* (delay (proceed (g σ))))
         (Γ ans* (proceed (g σ)))
         "call/eager-invoke-delay"]

    [--> (Γ ans* (delay s_1))
         (Γ ans* s_1)
         (side-condition (not (redex-match? L1/K (proceed pr) (term s_1))))
         "call/invoke-delay"]

    [--> (Γ ans* (in-hole Kcall (proceed (g σ))))
         (Γ ans* (in-hole Kcall (g σ)))
         "call/eager-resume-goal"]

    [--> (Γ ans* (in-hole Kcall ((delay s_1) × g c)))
         (Γ ans* (in-hole Kcall (delay (s_1 × g c))))
         "call/delay-through-conj"]))

(define base-l1/k
  (extend-reduction-relation
    core-base-l1
    L1/K))

(define Rcall-eager
  (union-reduction-relations
   call-eager-extra/l1
   base-l1/k))
