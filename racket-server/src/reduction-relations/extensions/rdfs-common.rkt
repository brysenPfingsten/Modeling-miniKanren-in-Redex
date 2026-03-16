#lang racket

(require redex/reduction-semantics
         "./core-l3.rkt")

(check-redundancy #t)

(provide extend-with-dfs-rules)

(define (extend-with-dfs-rules base-rel)
  (extend-reduction-relation
   base-rel
   L3/K
   [--> (Γ (in-hole Ksched ((delay s_1) <-+ s_2)))
        (Γ (in-hole Ksched (delay (s_1 <-+ s_2))))
        "dfs/delay-through-left"]
   [--> (Γ (in-hole Kdelay (delay s_1)))
        (Γ (in-hole Kdelay s_1))
        (side-condition (not (redex-match? L3/K (proceed pr) (term s_1))))
        "dfs/invoke-delay"]))
