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

(define lifted-search-base-seq-red
  (extend-reduction-relation
   search-base-seq-red
   rail-seq-lang))

(define rail-extra
  (reduction-relation
   rail-seq-lang
   #:domain f
   [--> (in-hole KScopePath (in-hole K ((delay f_1) <-+ f_2)))
        (in-hole KScopePath (in-hole K (delay (f_1 +-> f_2))))
        "rail-seq/enter-right"]
   [--> (in-hole KScopePath (in-hole K (f_2 +-> (delay f_1))))
        (in-hole KScopePath (in-hole K (delay (f_2 <-+ f_1))))
        "rail-seq/return-left"]))

(define rail-frontier-extra
  (reduction-relation
   rail-seq-lang
   #:domain f
   [--> (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> ((⊤ σ_new) <-+ f_right)))))
        (in-hole Q (in-hole KScopePath (in-hole K ((⊤ σ_new) + (f_left +-> f_right)))))
        "rail-seq/promote-right-left-answer"]
   [--> (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> ((empty-tree) <-+ f_right)))))
        (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> f_right))))
        "rail-seq/skip-right-left-fail"]
   [--> (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> (pref_1 + f_right)))))
        (in-hole Q (in-hole KScopePath (in-hole K (pref_1 + (f_left +-> f_right)))))
        "rail-seq/continue-right-prefix"]
   [--> (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> pref_1))))
        (in-hole Q (in-hole KScopePath (in-hole K (pref_1 + f_left))))
        "rail-seq/promote-right-observable"]
   [--> (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> (empty-tree)))))
        (in-hole Q (in-hole KScopePath (in-hole K f_left)))
        "rail-seq/skip-right-fail"]))

(define rail-local
  (context-closure rail-extra rail-seq-lang Q))

(define rail-seq-red
  (union-reduction-relations
   rail-local
   rail-frontier-extra
   lifted-search-base-seq-red))

(define (step-once prog)
  (step-once/deterministic rail-seq-red prog))
