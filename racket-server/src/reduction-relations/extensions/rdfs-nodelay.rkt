#lang racket

(require redex/reduction-semantics
         "./core-l2.rkt")

(check-redundancy #t)

(provide disj-extra/dfs-nodelay
         Rdfs-nodelay)

;; Explicit DFS/no-delay branch:
;; - built from L2 (disjunction syntax present)
;; - no delay/proceed constructors or rules
;; - deterministic left-biased disjunction scheduling
(define disj-extra/dfs-nodelay
  (reduction-relation
    L2/K
    #:domain config
    [--> (Γ (in-hole Kleft (in-hole Kcore ((g_1 ∨ g_2 tag) σ))))
         (Γ (in-hole Kleft (in-hole Kcore ((g_1 σ) <-+ (g_2 σ)))))
         "dfsn/goal-to-tree"]

    [--> (Γ (in-hole Kleft (in-hole Kcore ((s_1 <-+ s_2) × g c))))
         (Γ (in-hole Kleft (in-hole Kcore ((s_1 × g c) <-+ (s_2 × g c)))))
         "dfsn/distribute-over-conj"]

    [--> (Γ (in-hole Kleft (((⊤ σ_new) + s_left_tail) <-+ s_right)))
         (Γ (in-hole Kleft ((⊤ σ_new) + (s_left_tail <-+ s_right))))
         (side-condition
          (null? (apply-reduction-relation core-cfg/l2
                                           (term (Γ s_left_tail)))))
         (side-condition (not (redex-match? L2/K (empty-tree) (term s_left_tail))))
         "dfsn/promote-left-stream"]

    [--> (Γ (in-hole Kleft (((⊤ σ_new) + (empty-tree)) <-+ s_right)))
         (Γ (in-hole Kleft ((⊤ σ_new) + s_right)))
         "dfsn/promote-left-singleton-stream"]

    [--> (Γ (in-hole Kleft ((⊤ σ_new) <-+ s_right)))
         (Γ (in-hole Kleft ((⊤ σ_new) + s_right)))
         "dfsn/promote-left-answer"]

    [--> (Γ (in-hole Kleft ((empty-tree) <-+ s_right)))
         (Γ (in-hole Kleft s_right))
         "dfsn/skip-left-fail"]))

(define Rdfs-nodelay
  (union-reduction-relations
   disj-extra/dfs-nodelay
   core-cfg/l2))
