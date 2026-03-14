#lang racket

(require redex/reduction-semantics
         "./common.rkt"
         "./rdisj-left.rkt"
         "./core-l3.rkt")

(check-redundancy #t)

(provide Rbase-e)

(define call-eager-extra/l3
  (reduction-relation
    L3/K
    #:domain config
    ;; Stage 1 (inside active branch): call contexts from L1.
    ;; Stage 2 (outside): left-disjunction scheduler contexts.
    [--> (Γ (in-hole Kleft (in-hole Kcall ((r t ... tag) σ))))
         (Γ (in-hole Kleft (in-hole Kcall (delay (proceed (g_new σ))))))
         (where g_new ,(instantiate-call-host (term Γ) (term r) (term (t ...))))
         "call/eager-suspend-expanded"]

    [--> (Γ (delay (proceed (g σ))))
         (Γ (proceed (g σ)))
         "call/eager-invoke-delay"]

    [--> (Γ (in-hole Kleft (in-hole Kcall (proceed (g σ)))))
         (Γ (in-hole Kleft (in-hole Kcall (g σ))))
         "call/eager-resume-goal"]

    [--> (Γ (in-hole Kleft (in-hole Kcall ((delay s_1) × g c))))
         (Γ (in-hole Kleft (in-hole Kcall (delay (s_1 × g c)))))
         "call/delay-through-conj"]))

(define call+core-l3/eager
  (union-reduction-relations
   call-eager-extra/l3
   core-base-extra-l3))

(define disj-distribute-only/l3
  (reduction-relation
    L3/K
    #:domain config
    [--> (Γ (in-hole Kleft (in-hole Kcore ((s_1 <-+ s_2) × g c))))
         (Γ (in-hole Kleft (in-hole Kcore ((s_1 × g c) <-+ (s_2 × g c)))))
         "disj/distribute-over-conj"]))

(define disj-extra/l3
  (reduction-relation
    L3/K
    #:domain config
    [--> (Γ (in-hole Kleft (in-hole Kcore ((g_1 ∨ g_2 tag) σ))))
         (Γ (in-hole Kleft (in-hole Kcore ((g_1 σ) <-+ (g_2 σ)))))
         "disj/goal-to-tree"]

    [--> (Γ (in-hole Kleft (in-hole Kcore ((s_1 <-+ s_2) × g c))))
         (Γ (in-hole Kleft (in-hole Kcore ((s_1 × g c) <-+ (s_2 × g c)))))
         "disj/distribute-over-conj"]

    [--> (Γ (in-hole Kleft (((⊤ σ_new) + s_left_tail) <-+ s_right)))
         (Γ (in-hole Kleft ((⊤ σ_new) + (s_left_tail <-+ s_right))))
         (side-condition
          (let ([cfg (term (Γ s_left_tail))])
            (or (not (redex-match? L3/K config cfg))
                (null? (apply-reduction-relation call+core-l3/eager cfg)))))
         (side-condition
          (let ([cfg (term (Γ s_left_tail))])
            (or (not (redex-match? L3/K config cfg))
                (null? (apply-reduction-relation disj-distribute-only/l3 cfg)))))
         (side-condition (not (redex-match? L3/K (empty-tree) (term s_left_tail))))
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

(define Rbase-e
  (union-reduction-relations
   call-eager-extra/l3
   disj-extra/l3
   core-base-extra-l3))
