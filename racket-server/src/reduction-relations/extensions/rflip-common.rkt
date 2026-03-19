#lang racket

(require redex/reduction-semantics
         "../../extensions/l3-union-base.rkt")

(check-redundancy #t)

(provide extend-with-flip-rules)

(define (extend-with-flip-rules base-rel)
  (extend-reduction-relation
    base-rel
    L3/K
    [--> (Γ (in-hole Ksched ((delay s_1) <-+ s_2)) as)
         (Γ (in-hole Ksched (delay (s_2 <-+ s_1))) as)
         "flip/delay-swap-left"]))
