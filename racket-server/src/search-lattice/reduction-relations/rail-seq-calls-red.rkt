#lang racket

(require redex/reduction-semantics
         "../languages/rail-seq-calls-lang.rkt"
         "./private/common.rkt"
         "./private/step-utils.rkt"
         "./search-base-seq-calls-red.rkt")

(provide rail-seq-calls-red
         step-once)

(check-redundancy #t)

(define rail-seq-calls-red
  (extend-reduction-relation
   search-base-seq-calls-red
   rail-seq-calls-lang
   [--> (Γ (in-hole Q (in-hole KScopePath (in-hole K ((delay f_1) <-+ f_2)))))
        (Γ (in-hole Q (in-hole KScopePath (in-hole K (delay (f_1 +-> f_2))))))
        "rail-seq-calls/enter-right"]
   [--> (Γ (in-hole Q (in-hole KScopePath (in-hole K (f_2 +-> (delay f_1))))))
        (Γ (in-hole Q (in-hole KScopePath (in-hole K (delay (f_2 <-+ f_1))))))
        "rail-seq-calls/return-left"]
   [--> (Γ (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> ((⊤ σ_new) <-+ f_right))))))
        (Γ (in-hole Q (in-hole KScopePath (in-hole K ((⊤ σ_new) + (f_left +-> f_right))))))
        "rail-seq-calls/promote-right-left-answer"]
   [--> (Γ (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> ((empty-tree) <-+ f_right))))))
        (Γ (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> f_right)))))
        "rail-seq-calls/skip-right-left-fail"]
   [--> (Γ (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> ((Freshened c_1 tag_1) + f_right))))))
        (Γ (in-hole Q (in-hole KScopePath (in-hole K ((Freshened c_1 tag_1) + (f_left +-> f_right))))))
        "rail-seq-calls/continue-right-freshened-prefix"]
   [--> (Γ (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> ((ScopeEnd c_1) + f_right))))))
        (Γ (in-hole Q (in-hole KScopePath (in-hole K ((ScopeEnd c_1) + (f_left +-> f_right))))))
        "rail-seq-calls/continue-right-scope-end-prefix"]
   [--> (Γ (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> ((⊤ σ_new) + f_right))))))
        (Γ (in-hole Q (in-hole KScopePath (in-hole K ((⊤ σ_new) + (f_left +-> f_right))))))
        "rail-seq-calls/continue-right-prefix"]
   [--> (Γ (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> (⊤ σ_new))))))
        (Γ (in-hole Q (in-hole KScopePath (in-hole K ((⊤ σ_new) + f_left)))))
        "rail-seq-calls/promote-right-observable"]
   [--> (Γ (in-hole Q (in-hole KScopePath (in-hole K (f_left +-> (empty-tree))))))
        (Γ (in-hole Q (in-hole KScopePath (in-hole K f_left))))
        "rail-seq-calls/skip-right-fail"]))

(define (step-once prog)
  (step-once/deterministic rail-seq-calls-red prog))
