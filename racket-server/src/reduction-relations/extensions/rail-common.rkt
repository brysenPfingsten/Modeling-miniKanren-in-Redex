#lang racket

(require redex/reduction-semantics
         "./context-l3.rkt")

(check-redundancy #t)

(provide L4/K
         extend-with-rail-rules)

;; Determinism invariant:
;; railroad rules must be structurally disjoint from other scheduler rules.
;; Do not introduce dynamic precedence fences that inspect available rule names.

;; L4/K is a strict context/language extension of L3/K:
;; add right-pointing disjunction syntax and allow scheduler/strategy
;; contexts to descend through +-> positions.
(define-extended-language L4/K
  L3/K
  [s .... (s +-> s)]
  [K .... (s +-> K)]
  [Kleft .... (s +-> Kleft)]
  [Ksched .... (s +-> Ksched)])

(define (extend-with-rail-rules base-rel)
  (extend-reduction-relation
    base-rel
    L4/K
    [--> (Γ (in-hole Kdelay (delay s_1)))
         (Γ (in-hole Kdelay s_1))
         (side-condition (not (redex-match? L4/K (proceed pr) (term s_1))))
         "rail/invoke-delay"]

    [--> (Γ (in-hole Ksched ((delay s_1) <-+ s_2)))
         (Γ (in-hole Ksched (delay (s_1 +-> s_2))))
         "rail/enter-right"]

    [--> (Γ (in-hole Ksched (s_2 +-> (delay s_1))))
         (Γ (in-hole Ksched (delay (s_2 <-+ s_1))))
         "rail/return-left"]

    [--> (Γ (in-hole K (s_left +-> ((⊤ σ_new) + (⊤ σ_tail)))))
         (Γ (in-hole K ((⊤ σ_new) + (s_left +-> (⊤ σ_tail)))))
         "rail/promote-right-stream"]

    [--> (Γ (in-hole K (s_left +-> ((⊤ σ_new) + (empty-tree)))))
         (Γ (in-hole K ((⊤ σ_new) + s_left)))
         "rail/promote-right-singleton-stream"]

    [--> (Γ (in-hole K (s_left +-> (⊤ σ_new))))
         (Γ (in-hole K ((⊤ σ_new) + s_left)))
         "rail/promote-right-answer"]

    [--> (Γ (in-hole K (s_left +-> (empty-tree))))
         (Γ (in-hole K s_left))
         "rail/skip-right-fail"]))
