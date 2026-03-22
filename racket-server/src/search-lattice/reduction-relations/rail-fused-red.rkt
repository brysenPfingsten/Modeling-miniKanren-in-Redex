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

(define rail-fused-red
  (extend-reduction-relation
   search-base-fused-red
   rail-fused-lang
   [--> (in-hole P (in-hole K ((delay f_1) <-+ f_2)))
        (in-hole P (in-hole K (delay (f_1 +-> f_2))))
        "rail-fused/enter-right"]
   [--> (in-hole P (in-hole K (f_2 +-> (delay f_1))))
        (in-hole P (in-hole K (delay (f_2 <-+ f_1))))
        "rail-fused/return-left"]
   [--> (in-hole P (in-hole K (f_left +-> ((⊤ σ_new) <-+ f_right))))
        (in-hole P (in-hole K ((⊤ σ_new) + (f_left +-> f_right))))
        "rail-fused/promote-right-left-answer"]
   [--> (in-hole P (in-hole K (f_left +-> ((empty-tree) <-+ f_right))))
        (in-hole P (in-hole K (f_left +-> f_right)))
        "rail-fused/skip-right-left-fail"]
   [--> (in-hole P (in-hole K (f_left +-> (evt + f_right))))
        (in-hole P (in-hole K (evt + (f_left +-> f_right))))
        "rail-fused/continue-right-prefix"]
   [--> (in-hole P (in-hole K (f_left +-> (⊤ σ_new))))
        (in-hole P (in-hole K ((⊤ σ_new) + f_left)))
        "rail-fused/promote-right-answer"]
   [--> (in-hole P (in-hole K (f_left +-> (empty-tree))))
        (in-hole P (in-hole K f_left))
        "rail-fused/skip-right-fail"]))

(define (step-once prog)
  (step-once/deterministic rail-fused-red prog))
