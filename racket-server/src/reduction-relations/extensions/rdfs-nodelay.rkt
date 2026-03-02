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
    [--> (Γ ans* (in-hole Kleft (in-hole Kcore ((g_1 ∨ g_2 tag) σ))))
         (Γ ans* (in-hole Kleft (in-hole Kcore ((g_1 σ) <-+ (g_2 σ)))))
         "dfsn/goal-to-tree"]

    [--> (Γ ans* (in-hole Kleft (in-hole Kcore ((s_1 <-+ s_2) × g c))))
         (Γ ans* (in-hole Kleft (in-hole Kcore ((s_1 × g c) <-+ (s_2 × g c)))))
         "dfsn/distribute-over-conj"]

    [--> (Γ (σ ...) (in-hole Kleft ((⊤ σ_new) <-+ s_right)))
         (Γ (σ ... σ_new) (in-hole Kleft s_right))
         "dfsn/collect-left-answer"]

    [--> (Γ ans* (in-hole Kleft ((empty-tree) <-+ s_right)))
         (Γ ans* (in-hole Kleft s_right))
         "dfsn/skip-left-fail"]))

(define base-l2/k
  (extend-reduction-relation
    core-base-l2
    L2/K))

(define Rdfs-nodelay
  (union-reduction-relations
   disj-extra/dfs-nodelay
   base-l2/k))

