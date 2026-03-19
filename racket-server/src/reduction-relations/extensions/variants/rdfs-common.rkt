#lang racket

(require redex/reduction-semantics
         "../../../extensions/l3-union-base.rkt")

(check-redundancy #t)

(provide extend-with-dfs-rules)

(define (extend-with-dfs-rules base-rel)
  (extend-reduction-relation
   base-rel
   L3/K
   [--> (Γ (in-hole Ksched ((delay s_1) <-+ s_2)) as)
        (Γ (in-hole Ksched (delay (s_1 <-+ s_2))) as)
        "dfs/delay-through-left"]))
