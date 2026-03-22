#lang racket

(require redex/reduction-semantics
         "../languages/core-lang.rkt"
         "../languages/rail-fused-lang.rkt"
         "./private/common.rkt"
         "./private/step-utils.rkt"
         "./search-base-fused-red.rkt")

(provide rail-fused-red
         step-once)

(check-redundancy #t)

(define lifted-search-base-fused-red
  (extend-reduction-relation
   search-base-fused-red
   rail-fused-lang))

(define rail-extra
  (reduction-relation
   rail-fused-lang
   #:domain f
   [--> (in-hole K ((delay f_1) <-+ f_2))
        (in-hole K (delay (f_1 +-> f_2)))
        "rail-fused/enter-right"]
   [--> (in-hole K (f_2 +-> (delay f_1)))
        (in-hole K (delay (f_2 <-+ f_1)))
        "rail-fused/return-left"]))

(define rail-frontier-extra
  (reduction-relation
   rail-fused-lang
   #:domain f
   [--> (in-hole Q (in-hole K (f_left +-> ((⊤ σ_new) <-+ f_right))))
        (in-hole Q (in-hole K ((⊤ σ_new) + (f_left +-> f_right))))
        "rail-fused/promote-right-left-answer"]
   [--> (in-hole Q (in-hole K (f_left +-> ((empty-tree) <-+ f_right))))
        (in-hole Q (in-hole K (f_left +-> f_right)))
        "rail-fused/skip-right-left-fail"]
   [--> (in-hole Q (in-hole K (f_left +-> (pref_1 + f_right))))
        (in-hole Q (in-hole K (pref_1 + (f_left +-> f_right))))
        "rail-fused/continue-right-prefix"]
   [--> (in-hole Q (in-hole K (f_left +-> pref_1)))
        (in-hole Q (in-hole K (pref_1 + f_left)))
        "rail-fused/promote-right-observable"]
   [--> (in-hole Q (in-hole K (f_left +-> (empty-tree))))
        (in-hole Q (in-hole K f_left))
        "rail-fused/skip-right-fail"]))

(define rail-local
  (context-closure rail-extra rail-fused-lang Q))

(define rail-fused-red
  (union-reduction-relations
   rail-local
   rail-frontier-extra
   lifted-search-base-fused-red))

(define (step-once prog)
  (step-once/deterministic rail-fused-red prog))
