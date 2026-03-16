#lang racket

(require redex/reduction-semantics
         "./core-l3.rkt")

(check-redundancy #t)

(provide disj-distribute-only/l3
         make-disj-extra/l3)

(define disj-distribute-only/l3
  (reduction-relation
    L3/K
    #:domain config
    [--> (Γ (in-hole Kleft (in-hole Kcore ((g_1 ∨ g_2 tag) σ))))
         (Γ (in-hole Kleft (in-hole Kcore ((g_1 σ) <-+ (g_2 σ)))))
         "disj/goal-to-tree"]
    [--> (Γ (in-hole Kleft (in-hole Kcore ((s_1 <-+ s_2) × g c))))
         (Γ (in-hole Kleft (in-hole Kcore ((s_1 × g c) <-+ (s_2 × g c)))))
         (side-condition (redex-match? L3/K s (term s_1)))
         (side-condition (redex-match? L3/K s (term s_2)))
         "disj/distribute-over-conj"]))

(define disj-scheduler-only/l3
  (reduction-relation
    L3/K
    #:domain config
    [--> (Γ (in-hole Kleft (((⊤ σ_new) + s_left_tail) <-+ s_right)))
         (Γ (in-hole Kleft ((⊤ σ_new) + (s_left_tail <-+ s_right))))
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

(define (make-disj-extra/l3 call+core-rel)
  (reduction-relation
    L3/K
    #:domain config
    [--> (Γ (in-hole Kleft (in-hole Kcore ((g_1 ∨ g_2 tag) σ))))
         (Γ (in-hole Kleft (in-hole Kcore ((g_1 σ) <-+ (g_2 σ)))))
         "disj/goal-to-tree"]

    [--> (Γ (in-hole Kleft (in-hole Kcore ((s_1 <-+ s_2) × g c))))
         (Γ (in-hole Kleft (in-hole Kcore ((s_1 × g c) <-+ (s_2 × g c)))))
         (side-condition (redex-match? L3/K s (term s_1)))
         (side-condition (redex-match? L3/K s (term s_2)))
         "disj/distribute-over-conj"]

    [--> (Γ (in-hole Kleft (((⊤ σ_new) + s_left_tail) <-+ s_right)))
         (Γ (in-hole Kleft ((⊤ σ_new) + (s_left_tail <-+ s_right))))
         (side-condition
          (let ([cfg (term (Γ s_left_tail))])
            (or (not (redex-match? L3/K config cfg))
                (null? (apply-reduction-relation call+core-rel cfg)))))
         (side-condition
          (let ([cfg (term (Γ s_left_tail))])
            (or (not (redex-match? L3/K config cfg))
                (null? (apply-reduction-relation disj-distribute-only/l3 cfg)))))
         (side-condition
          (let ([cfg (term (Γ s_left_tail))])
            (or (not (redex-match? L3/K config cfg))
                (null? (apply-reduction-relation disj-scheduler-only/l3 cfg)))))
         (side-condition
          (not (redex-match? L3/K ((delay s_1) <-+ s_2) (term s_left_tail))))
         (side-condition
          (not (match (term s_left_tail)
                 [`(,_ +-> ,_) #t]
                 [_ #f])))
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
