#lang racket

(require redex/reduction-semantics
         "./core-l2.rkt")

(check-redundancy #t)

(provide L2/K
         disj-extra/l2
         Rdisj-left)

(define-extended-language L2/K
  L2
  [K ::= hole
         (K × g c)
         (K <-+ s)]
  [K2 ::= K])

(define disj-extra/l2
  (reduction-relation
    L2/K
    #:domain config
    [--> (Γ ans* (in-hole K ((g_1 ∨ g_2 tag) σ)))
         (Γ ans* (in-hole K ((g_1 σ) <-+ (g_2 σ))))
         "disj/goal-to-tree"]

    [--> (Γ ans* (in-hole K ((s_1 <-+ s_2) × g c)))
         (Γ ans* (in-hole K ((s_1 × g c) <-+ (s_2 × g c))))
         "disj/distribute-over-conj"]

    [--> (Γ (σ ...) ((⊤ σ_new) <-+ s_right))
         (Γ (σ ... σ_new) s_right)
         "disj/collect-left-answer"]

    [--> (Γ ans* ((empty-tree) <-+ s_right))
         (Γ ans* s_right)
         "disj/skip-left-fail"]))

(define base-l2/k
  (extend-reduction-relation
    core-base-l2
    L2/K))

(define Rdisj-left
  (union-reduction-relations
   disj-extra/l2
   base-l2/k))
