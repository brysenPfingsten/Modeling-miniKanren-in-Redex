#lang racket

(require redex/reduction-semantics
         "../languages/rail-calls-lang.rkt"
         "./private/step-utils.rkt"
         "./search-base-seq-calls-red.rkt")

(provide rail-seq-calls-local/base
         rail-seq-calls-frontier/base
         rail-seq-calls-red
         step-once)

(check-redundancy #t)

(define lifted-search-base-seq-calls-red
  (extend-reduction-relation
   search-base-seq-calls-red
   rail-calls-lang))

(define rail-seq-calls-local/base
  (reduction-relation
   rail-calls-lang
   #:domain config
   [--> (Γ (in-hole QSpine (in-hole KWork ((delay runnable-search_1) <-+ search_2))))
        (Γ (in-hole QSpine (in-hole KWork (delay (runnable-search_1 +-> search_2)))))
        "rail-seq-calls/enter-right"]
   [--> (Γ (in-hole QSpine (in-hole KWork (search_2 +-> (delay runnable-search_1)))))
        (Γ (in-hole QSpine (in-hole KWork (delay (search_2 <-+ runnable-search_1)))))
        "rail-seq-calls/return-left"]))

(define rail-seq-calls-frontier/base
  (reduction-relation
   rail-calls-lang
   #:domain config
   [--> (Γ (in-hole QSpine (in-hole KWork (search_left +-> (Freshened c_1 (((in-hole QFront (⊤ σ_new)) <-+ search_mid) <-+ search_right) tag_1)))))
        (Γ (in-hole QSpine ((Freshened c_1 (in-hole QFront (⊤ σ_new)) tag_1) + (in-hole KWork (search_left +-> (Freshened c_1 (search_mid <-+ search_right) tag_1))))))
        "rail-seq-calls/bubble-scoped-right-answer"]
   [--> (Γ (in-hole QSpine (in-hole KWork (search_left +-> (Freshened c_1 ((in-hole QFront (⊤ σ_new)) <-+ search_right) tag_1)))))
        (Γ (in-hole QSpine ((Freshened c_1 (in-hole QFront (⊤ σ_new)) tag_1) + (in-hole KWork (search_left +-> (Freshened c_1 search_right tag_1))))))
        "rail-seq-calls/promote-scoped-right-answer"]
   [--> (Γ (in-hole QSpine (in-hole KWork (search_left +-> (Freshened c_1 (((empty-tree) <-+ search_mid) <-+ search_right) tag_1)))))
        (Γ (in-hole QSpine (in-hole KWork (search_left +-> (Freshened c_1 (search_mid <-+ search_right) tag_1)))))
        "rail-seq-calls/bubble-scoped-right-fail"]
   [--> (Γ (in-hole QSpine (in-hole KWork (search_left +-> (Freshened c_1 ((empty-tree) <-+ search_right) tag_1)))))
        (Γ (in-hole QSpine (in-hole KWork (search_left +-> (Freshened c_1 search_right tag_1)))))
        "rail-seq-calls/skip-scoped-right-left-fail"]
   [--> (Γ (in-hole QSpine (in-hole KWork (search_left +-> (((in-hole QFront (⊤ σ_new)) <-+ search_mid) <-+ search_right)))))
        (Γ (in-hole QSpine ((in-hole QFront (⊤ σ_new)) + (in-hole KWork (search_left +-> (search_mid <-+ search_right))))))
        "rail-seq-calls/bubble-right-left-answer"]
   [--> (Γ (in-hole QSpine (in-hole KWork (search_left +-> ((in-hole QFront (⊤ σ_new)) <-+ search_right)))))
        (Γ (in-hole QSpine ((in-hole QFront (⊤ σ_new)) + (in-hole KWork (search_left +-> search_right)))))
        "rail-seq-calls/promote-right-left-answer"]
   [--> (Γ (in-hole QSpine (in-hole KWork (search_left +-> (((empty-tree) <-+ search_mid) <-+ search_right)))))
        (Γ (in-hole QSpine (in-hole KWork (search_left +-> (search_mid <-+ search_right)))))
        "rail-seq-calls/bubble-right-left-fail"]
   [--> (Γ (in-hole QSpine (in-hole KWork (search_left +-> ((empty-tree) <-+ search_right)))))
        (Γ (in-hole QSpine (in-hole KWork (search_left +-> search_right))))
        "rail-seq-calls/skip-right-left-fail"]
   [--> (Γ (in-hole QSpine (in-hole KWork (search_left +-> (in-hole QFront (⊤ σ_new))))))
        (Γ (in-hole QSpine ((in-hole QFront (⊤ σ_new)) + (in-hole KWork search_left))))
        "rail-seq-calls/promote-right-observable"]
   [--> (Γ (in-hole QSpine (in-hole KWork (search_left +-> (Freshened c_1 (empty-tree) tag_1)))))
        (Γ (in-hole QSpine (in-hole KWork search_left)))
        "rail-seq-calls/skip-scoped-right-fail"]
   [--> (Γ (in-hole QSpine (in-hole KWork (search_left +-> (empty-tree)))))
        (Γ (in-hole QSpine (in-hole KWork search_left)))
        "rail-seq-calls/skip-right-fail"]))

(define rail-seq-calls-red
  (union-reduction-relations
   lifted-search-base-seq-calls-red
   rail-seq-calls-local/base
   rail-seq-calls-frontier/base))

(define (step-once prog)
  (step-once/deterministic rail-seq-calls-red prog))
