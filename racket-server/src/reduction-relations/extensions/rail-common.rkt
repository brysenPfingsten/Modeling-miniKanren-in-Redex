#lang racket

(require redex/reduction-semantics
         "../../extensions/l4-railroad-syntax.rkt")

(check-redundancy #t)

(provide L4/K
         lift-l3-to-l4
         extend-with-rail-rules)

(define-extended-language L4/K
  L4
  ;; Base stepping context in railroad syntax:
  ;; - left branch for <-+
  ;; - right branch for +-> (rail mode)
  ;; - never descend through delay
  [K ::= hole
         (K × g c)
         (K <-+ s)
         (s +-> K)
         ((⊤ σ) + K)]
  ;; Core staged contexts inherited from L3/K relations.
  [Kcore ::= hole
             (Kcore × g c)]
  [Kleft ::= hole
             (Kleft <-+ s)
             (s +-> Kleft)
             ((⊤ σ) + Kleft)]
  [Kcall ::= hole
             (Kcall × g c)]
  ;; Delay invocation context: top-level or under answer-stream tails only.
  [Kdelay ::= hole
              ((⊤ σ) + Kdelay)])

(define (lift-l3-to-l4 rel)
  (extend-reduction-relation rel L4/K))

(define (extend-with-rail-rules base-rel)
  (extend-reduction-relation
    base-rel
    L4/K
    [--> (Γ (in-hole Kdelay (delay s_1)))
         (Γ (in-hole Kdelay s_1))
         (side-condition (not (redex-match? L4/K (proceed pr) (term s_1))))
         "rail/invoke-delay"]

    [--> (Γ (in-hole K ((delay s_1) <-+ s_2)))
         (Γ (in-hole K (delay (s_1 +-> s_2))))
         "rail/enter-right"]

    [--> (Γ (in-hole K (s_2 +-> (delay s_1))))
         (Γ (in-hole K (delay (s_2 <-+ s_1))))
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
