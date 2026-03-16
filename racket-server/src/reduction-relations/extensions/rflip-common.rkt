#lang racket

(require redex/reduction-semantics
         "./core-l3.rkt")

(check-redundancy #t)

(provide extend-with-flip-rules)

(define (extend-with-flip-rules base-rel)
  (extend-reduction-relation
    base-rel
    L3/K
    [--> (Γ (in-hole Kdelay (delay s_1)))
         (Γ (in-hole Kdelay s_1))
         (side-condition (not (redex-match? L3/K (proceed pr) (term s_1))))
         "flip/invoke-delay"]

    [--> (Γ (in-hole Ksched ((delay s_1) <-+ s_2)))
         (Γ (in-hole Ksched (delay (s_2 <-+ s_1))))
         "flip/delay-swap-left"]))
