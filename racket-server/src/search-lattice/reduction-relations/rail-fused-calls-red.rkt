#lang racket

(require redex/reduction-semantics
         "../languages/rail-fused-calls-lang.rkt"
         "./private/common.rkt"
         "./private/step-utils.rkt"
         "./search-base-fused-calls-red.rkt")

(provide rail-fused-calls-local/base
         rail-fused-calls-frontier/base
         rail-fused-calls-red
         step-once)

(check-redundancy #t)

(define lifted-search-base-fused-calls-red
  (extend-reduction-relation
   search-base-fused-calls-red
   rail-fused-calls-lang))

(define rail-fused-calls-local/base
  (reduction-relation
   rail-fused-calls-lang
   #:domain config
   [--> (Γ (in-hole QSpine (in-hole KBranch (in-hole KWork ((delay delayed_1) <-+ search_2)))))
        (Γ (in-hole QSpine (in-hole KBranch (in-hole KWork (delay (delayed_1 +-> search_2))))))
        "rail-fused-calls/enter-right"]
   [--> (Γ (in-hole QSpine (in-hole KBranch (in-hole KWork (search_2 +-> (delay delayed_1))))))
        (Γ (in-hole QSpine (in-hole KBranch (in-hole KWork (delay (search_2 <-+ delayed_1))))))
        "rail-fused-calls/return-left"]))

(define rail-fused-calls-frontier/base
  (reduction-relation
   rail-fused-calls-lang
   #:domain config
   [--> (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (Freshened c_1
                                                       (((in-hole QFront (⊤ σ_new))
                                                         <-+ search_mid)
                                                        <-+ search_right) tag_1))))))
        (Γ (in-hole QSpine
                    ((Freshened c_1
                                (in-hole QFront (⊤ σ_new)) tag_1)
                     + (in-hole KBranch
                                (in-hole KWork
                                         (search_left
                                          +-> (Freshened c_1
                                                          (search_mid <-+ search_right) tag_1)))))))
        "rail-fused-calls/bubble-scoped-right-answer"]
   [--> (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (Freshened c_1
                                                       ((in-hole QFront (⊤ σ_new))
                                                        <-+ search_right) tag_1))))))
        (Γ (in-hole QSpine
                    ((Freshened c_1
                                (in-hole QFront (⊤ σ_new)) tag_1)
                     + (in-hole KBranch
                                (in-hole KWork
                                         (search_left
                                          +-> (Freshened c_1 search_right tag_1)))))))
        "rail-fused-calls/promote-scoped-right-answer"]
   [--> (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (Freshened c_1
                                                       (((empty-tree) <-+ search_mid)
                                                        <-+ search_right) tag_1))))))
        (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (Freshened c_1
                                                       (search_mid <-+ search_right) tag_1))))))
        "rail-fused-calls/bubble-scoped-right-fail"]
   [--> (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (Freshened c_1
                                                       ((empty-tree) <-+ search_right) tag_1))))))
        (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (Freshened c_1 search_right tag_1))))))
        "rail-fused-calls/skip-scoped-right-left-fail"]
   [--> (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (((in-hole QFront (⊤ σ_new))
                                             <-+ search_mid)
                                            <-+ search_right))))))
        (Γ (in-hole QSpine
                    ((in-hole QFront (⊤ σ_new))
                     + (in-hole KBranch
                                (in-hole KWork
                                         (search_left
                                          +-> (search_mid <-+ search_right)))))))
        "rail-fused-calls/bubble-right-left-answer"]
   [--> (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> ((in-hole QFront (⊤ σ_new))
                                             <-+ search_right))))))
        (Γ (in-hole QSpine
                    ((in-hole QFront (⊤ σ_new))
                     + (in-hole KBranch
                                (in-hole KWork
                                         (search_left +-> search_right))))))
        "rail-fused-calls/promote-right-left-answer"]
   [--> (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (((empty-tree) <-+ search_mid)
                                             <-+ search_right))))))
        (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (search_mid <-+ search_right))))))
        "rail-fused-calls/bubble-right-left-fail"]
   [--> (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> ((empty-tree) <-+ search_right))))))
        (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork (search_left +-> search_right)))))
        "rail-fused-calls/skip-right-left-fail"]
   [--> (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork (search_left +-> (in-hole QFront (⊤ σ_new)))))))
        (Γ (in-hole QSpine
                    ((in-hole QFront (⊤ σ_new))
                     + (in-hole KBranch
                                (in-hole KWork search_left)))))
        "rail-fused-calls/promote-right-observable"]
   [--> (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork (search_left +-> (Freshened c_1 (empty-tree) tag_1))))))
        (Γ (in-hole QSpine
                    (in-hole KBranch
                             (in-hole KWork search_left))))
        "rail-fused-calls/skip-scoped-right-fail"]
   [--> (Γ (in-hole QSpine (in-hole KBranch (in-hole KWork (search_left +-> (empty-tree))))))
        (Γ (in-hole QSpine (in-hole KBranch (in-hole KWork search_left))))
        "rail-fused-calls/skip-right-fail"]))

(define rail-fused-calls-red
  (union-reduction-relations
   lifted-search-base-fused-calls-red
   rail-fused-calls-local/base
   rail-fused-calls-frontier/base))

(define (step-once prog)
  (step-once/deterministic rail-fused-calls-red prog))
