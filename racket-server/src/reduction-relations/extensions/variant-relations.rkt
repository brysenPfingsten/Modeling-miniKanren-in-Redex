#lang racket

(require redex/reduction-semantics
         "./rcall-eager.rkt"
         "./rcall-lazy.rkt"
         "./rdisj-left.rkt"
         "./rdfs-nodelay.rkt"
         "./rbase-e.rkt"
         "./rbase-l.rkt"
         "./rbase-l4.rkt"
         "./rflip-e.rkt"
         "./rflip-l.rkt"
         "./rrail-e.rkt"
         "./rrail-l.rkt"
         "./core-l3.rkt")

;; Canonical relation names follow the language/relation lattice:
;; - Rl1-call-{eager,lazy}
;; - Rl2-disj-left
;; - Rl3-pre-{eager,lazy}
;; - Rl3-dfs-{eager,lazy}
;; - Rl3-flip-{eager,lazy}
;; - Rl4-rail-{eager,lazy}
;;
;; Legacy names are preserved as aliases for compatibility with existing tests/tools.
(define Rl1-call-eager Rcall-eager)
(define Rl1-call-lazy  Rcall-lazy)
(define Rl2-disj-left  Rdisj-left)
(define Rl3-pre-eager  Rbase-e)
(define Rl3-pre-lazy   Rbase-l)
(define Rl3-flip-eager Rflip-e)
(define Rl3-flip-lazy  Rflip-l)
(define Rl4-rail-eager Rrail-e)
(define Rl4-rail-lazy  Rrail-l)

(define Rl3-dfs-eager
  (extend-reduction-relation
   Rl3-pre-eager
   L3/K
   [--> (Γ ans* (in-hole K3 ((delay s_1) <-+ s_2)))
        (Γ ans* (in-hole K3 (delay (s_1 <-+ s_2))))
        "dfs/delay-through-left"]
   [--> (Γ ans* (delay s_1))
        (Γ ans* s_1)
        (side-condition (not (redex-match? L3/K (proceed pr) (term s_1))))
        "dfs/invoke-delay"]))

(define Rl3-dfs-lazy
  (extend-reduction-relation
   Rl3-pre-lazy
   L3/K
   [--> (Γ ans* (in-hole K3 ((delay s_1) <-+ s_2)))
        (Γ ans* (in-hole K3 (delay (s_1 <-+ s_2))))
        "dfs/delay-through-left"]
   [--> (Γ ans* (delay s_1))
        (Γ ans* s_1)
        (side-condition (not (redex-match? L3/K (proceed pr) (term s_1))))
        "dfs/invoke-delay"]))

(provide
 ;; Canonical exports
 Rl1-call-eager
 Rl1-call-lazy
 Rl2-disj-left
 Rl3-pre-eager
 Rl3-pre-lazy
 Rl3-dfs-eager
 Rl3-dfs-lazy
 Rl3-flip-eager
 Rl3-flip-lazy
 Rl4-rail-eager
 Rl4-rail-lazy
 ;; Legacy exports
 Rcall-eager
 Rcall-lazy
 Rdisj-left
 Rdfs-nodelay
 Rbase-e
 Rbase-l
 Rbase-l4
 Rflip-e
 Rflip-l
 Rrail-e
 Rrail-l
 ;; Canonical step wrappers
 step-once/Rl1-call-eager
 step-once/Rl1-call-lazy
 step-once/Rl2-disj-left
 step-once/Rl3-pre-eager
 step-once/Rl3-pre-lazy
 step-once/Rl3-dfs-eager
 step-once/Rl3-dfs-lazy
 step-once/Rl3-flip-eager
 step-once/Rl3-flip-lazy
 step-once/Rl4-rail-eager
 step-once/Rl4-rail-lazy
 ;; Legacy step wrappers
 step-once/Rcall-eager
 step-once/Rcall-lazy
 step-once/Rdisj-left
 step-once/Rdfs-nodelay
 step-once/Rbase-e
 step-once/Rbase-l
 step-once/Rbase-l4
 step-once/Rflip-e
 step-once/Rflip-l
 step-once/Rrail-e
 step-once/Rrail-l)

;; Canonical step wrappers.
(define (step-once/Rl1-call-eager prog)
  (apply-reduction-relation/tag-with-names Rl1-call-eager (term ,prog)))

(define (step-once/Rl1-call-lazy prog)
  (apply-reduction-relation/tag-with-names Rl1-call-lazy (term ,prog)))

(define (step-once/Rl2-disj-left prog)
  (apply-reduction-relation/tag-with-names Rl2-disj-left (term ,prog)))

(define (step-once/Rl3-pre-eager prog)
  (apply-reduction-relation/tag-with-names Rl3-pre-eager (term ,prog)))

(define (step-once/Rl3-pre-lazy prog)
  (apply-reduction-relation/tag-with-names Rl3-pre-lazy (term ,prog)))

(define (step-once/Rl3-dfs-eager prog)
  (apply-reduction-relation/tag-with-names Rl3-dfs-eager (term ,prog)))

(define (step-once/Rl3-dfs-lazy prog)
  (apply-reduction-relation/tag-with-names Rl3-dfs-lazy (term ,prog)))

(define (step-once/Rl3-flip-eager prog)
  (apply-reduction-relation/tag-with-names Rl3-flip-eager (term ,prog)))

(define (step-once/Rl3-flip-lazy prog)
  (apply-reduction-relation/tag-with-names Rl3-flip-lazy (term ,prog)))

(define (step-once/Rl4-rail-eager prog)
  (apply-reduction-relation/tag-with-names Rl4-rail-eager (term ,prog)))

(define (step-once/Rl4-rail-lazy prog)
  (apply-reduction-relation/tag-with-names Rl4-rail-lazy (term ,prog)))

;; Legacy wrappers.
(define step-once/Rcall-eager step-once/Rl1-call-eager)
(define step-once/Rcall-lazy  step-once/Rl1-call-lazy)
(define step-once/Rdisj-left  step-once/Rl2-disj-left)
(define step-once/Rdfs-nodelay
  (lambda (prog)
    (apply-reduction-relation/tag-with-names Rdfs-nodelay (term ,prog))))
(define step-once/Rbase-e step-once/Rl3-pre-eager)
(define step-once/Rbase-l step-once/Rl3-pre-lazy)
(define (step-once/Rbase-l4 prog)
  (apply-reduction-relation/tag-with-names Rbase-l4 (term ,prog)))
(define step-once/Rflip-e step-once/Rl3-flip-eager)
(define step-once/Rflip-l step-once/Rl3-flip-lazy)
(define step-once/Rrail-e step-once/Rl4-rail-eager)
(define step-once/Rrail-l step-once/Rl4-rail-lazy)
