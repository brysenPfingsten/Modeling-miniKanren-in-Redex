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
    [--> (Γ (in-hole K ((r t ... tag) σ)))
         (Γ (in-hole K (delay (proceed (g_new σ)))))
         (where g_new ,(instantiate-call-host (term Γ) (term r) (term (t ...))))
         "call/eager-suspend-expanded"]

    [--> (Γ (delay (proceed (g σ))))
         (Γ (proceed (g σ)))
         "call/eager-invoke-delay"]

    [--> (Γ (delay s_1))
         (Γ s_1)
         (side-condition (not (redex-match? L1/K (proceed pr) (term s_1))))
         "call/invoke-delay"]

    [--> (Γ (in-hole K (proceed (g σ))))
         (Γ (in-hole K (g σ)))
         "call/eager-resume-goal"]

    [--> (Γ (in-hole K ((delay s_1) × g c)))
         (Γ (in-hole K (delay (s_1 × g c))))
         "call/delay-through-conj"]))

(define Rcall-eager
  (union-reduction-relations
   call-eager-extra/l1
   core-cfg/l1))
