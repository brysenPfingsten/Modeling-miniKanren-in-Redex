#lang racket

(require redex/reduction-semantics
         "../languages/core-lang.rkt"
         "../languages/rail-seq-lang.rkt"
         "./private/common.rkt"
         "./private/step-utils.rkt"
         "./search-base-seq-red.rkt")

(provide rail-seq-red
         step-once)

(check-redundancy #t)

(define rail-seq-red
  (extend-reduction-relation
   search-base-seq-red
   rail-seq-lang
   [--> (in-hole P (in-hole KDisj ((delay f_1) <-+ f_2)))
        (in-hole P (in-hole KDisj (delay (f_1 +-> f_2))))
        "rail-seq/enter-right"]
   [--> (in-hole P (in-hole KDisj (f_2 +-> (delay f_1))))
        (in-hole P (in-hole KDisj (delay (f_2 <-+ f_1))))
        "rail-seq/return-left"]
   [--> (in-hole P (in-hole KDisj (in-hole K (f_left +-> ((⊤ σ_new) <-+ f_right)))))
        (in-hole P (in-hole KDisj (in-hole K ((⊤ σ_new) + (f_left +-> f_right)))))
        "rail-seq/promote-right-left-answer"]
   [--> (in-hole P (in-hole KDisj (in-hole K (f_left +-> ((empty-tree) <-+ f_right)))))
        (in-hole P (in-hole KDisj (in-hole K (f_left +-> f_right))))
        "rail-seq/skip-right-left-fail"]
   [--> (in-hole P (in-hole KDisj (in-hole K (f_left +-> (evt + f_right)))))
        (in-hole P (in-hole KDisj (in-hole K (evt + (f_left +-> f_right)))))
        "rail-seq/continue-right-prefix"]
   [--> (in-hole P (in-hole KDisj (in-hole K (f_left +-> (⊤ σ_new)))))
        (in-hole P (in-hole KDisj (in-hole K ((⊤ σ_new) + f_left))))
        "rail-seq/promote-right-answer"]
   [--> (in-hole P (in-hole KDisj (in-hole K (f_left +-> (empty-tree)))))
        (in-hole P (in-hole KDisj (in-hole K f_left)))
        "rail-seq/skip-right-fail"]))

(define (step-once prog)
  (step-once/deterministic rail-seq-red prog))
