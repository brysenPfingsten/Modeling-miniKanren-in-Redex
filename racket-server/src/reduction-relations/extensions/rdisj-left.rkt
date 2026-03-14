#lang racket

(require redex/reduction-semantics
         "./core-l2.rkt")

(check-redundancy #t)

(provide disj-extra/l2
         Rdisj-left)

(define disj-distribute-only/l2
  (reduction-relation
    L2/K
    #:domain config
    [--> (Γ (in-hole Kleft (in-hole Kcore ((s_1 <-+ s_2) × g c))))
         (Γ (in-hole Kleft (in-hole Kcore ((s_1 × g c) <-+ (s_2 × g c)))))
         "disj/distribute-over-conj"]))

(define disj-extra/l2
  (reduction-relation
    L2/K
    #:domain config
    ;; Stage 1 (inside active branch): core-conjunction contexts.
    ;; Stage 2 (outside): left-disjunction scheduler contexts.
    [--> (Γ (in-hole Kleft (in-hole Kcore ((g_1 ∨ g_2 tag) σ))))
         (Γ (in-hole Kleft (in-hole Kcore ((g_1 σ) <-+ (g_2 σ)))))
         "disj/goal-to-tree"]

    [--> (Γ (in-hole Kleft (in-hole Kcore ((s_1 <-+ s_2) × g c))))
         (Γ (in-hole Kleft (in-hole Kcore ((s_1 × g c) <-+ (s_2 × g c)))))
         "disj/distribute-over-conj"]

    [--> (Γ (in-hole Kleft (((⊤ σ_new) + s_left_tail) <-+ s_right)))
         (Γ (in-hole Kleft ((⊤ σ_new) + (s_left_tail <-+ s_right))))
         (side-condition
          (null? (apply-reduction-relation core-base-l2
                                           (term (Γ s_left_tail)))))
         (side-condition
          (null? (apply-reduction-relation disj-distribute-only/l2
                                           (term (Γ s_left_tail)))))
         (side-condition (not (redex-match? L2/K (empty-tree) (term s_left_tail))))
         "disj/promote-left-stream"]

    [--> (Γ (in-hole Kleft (((⊤ σ_new) + (empty-tree)) <-+ s_right)))
         (Γ (in-hole Kleft ((⊤ σ_new) + s_right)))
         "disj/promote-left-singleton-stream"]

    [--> (Γ (in-hole Kleft ((⊤ σ_new) <-+ s_right)))
         (Γ (in-hole Kleft ((⊤ σ_new) + s_right)))
         "disj/promote-left-answer"]

    [--> (Γ (in-hole Kleft ((empty-tree) <-+ s_right)))
         (Γ (in-hole Kleft s_right))
         "disj/skip-left-fail"]))

(define base-l2/k
  (extend-reduction-relation
    core-base-l2
    L2/K))

(define Rdisj-left
  (union-reduction-relations
   disj-extra/l2
   base-l2/k))
