#lang racket

(require redex/reduction-semantics
         "../../../core-definitions.rkt"
         "../../../extensions/l4-railroad-syntax.rkt")

(check-redundancy #t)

(provide L4/K
         extend-with-rail-rules)

;; Determinism invariant:
;; railroad rules must be structurally disjoint from other scheduler rules.
;; Do not introduce dynamic precedence fences that inspect available rule names.

(define (extend-with-rail-rules base-rel)
  (extend-reduction-relation
    base-rel
    L4/K
    [--> (Γ (in-hole Ksched ((delay s_1) <-+ s_2)) as)
         (Γ (in-hole Ksched (delay (s_1 +-> s_2))) as)
         "rail/enter-right"]

    [--> (Γ (in-hole Ksched (s_2 +-> (delay s_1))) as)
         (Γ (in-hole Ksched (delay (s_2 <-+ s_1))) as)
         "rail/return-left"]

    [--> (Γ (in-hole K (s_left +-> (⊤ σ_new))) as)
         (Γ (in-hole K s_left)
            (append-answer as σ_new))
         "rail/promote-right-answer"]

    [--> (Γ (in-hole K (s_left +-> (empty-tree))) as)
         (Γ (in-hole K s_left) as)
         "rail/skip-right-fail"]))
