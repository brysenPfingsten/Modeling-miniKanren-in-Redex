#lang racket

(require redex/reduction-semantics
         "../languages/core-lang.rkt"
         "../languages/rail-fused-lang.rkt"
         "./private/common.rkt"
         "./private/step-utils.rkt"
         "./search-base-fused-red.rkt")

(provide rail-fused-local/base
         rail-fused-local/under-QSpine
         rail-fused-frontier/base
         rail-fused-red
         step-once)

(check-redundancy #t)

(define lifted-search-base-fused-red
  (extend-reduction-relation
   search-base-fused-red
   rail-fused-lang))

(define rail-fused-local/base
  (reduction-relation
   rail-fused-lang
   #:domain cfg
   [--> (in-hole KBranch (in-hole KWork ((delay delayed_1) <-+ search_2)))
        (in-hole KBranch (in-hole KWork (delay (delayed_1 +-> search_2))))
        "rail-fused/enter-right"]
   [--> (in-hole KBranch (in-hole KWork (search_2 +-> (delay delayed_1))))
        (in-hole KBranch (in-hole KWork (delay (search_2 <-+ delayed_1))))
        "rail-fused/return-left"]))

(define rail-fused-frontier/base
  (reduction-relation
   rail-fused-lang
   #:domain cfg
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> (Freshened c_1
                                                    (((in-hole QFront (⊤ σ_new))
                                                      <-+ search_mid)
                                                     <-+ search_right) tag_1)))))
        (in-hole QSpine
                 ((Freshened c_1
                             (in-hole QFront (⊤ σ_new)) tag_1)
                  + (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (Freshened c_1
                                                       (search_mid <-+ search_right) tag_1))))))
        "rail-fused/bubble-scoped-right-answer"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> (Freshened c_1
                                                    ((in-hole QFront (⊤ σ_new))
                                                     <-+ search_right) tag_1)))))
        (in-hole QSpine
                 ((Freshened c_1
                             (in-hole QFront (⊤ σ_new)) tag_1)
                  + (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (Freshened c_1 search_right tag_1))))))
        "rail-fused/promote-scoped-right-answer"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> (Freshened c_1
                                                    (((empty-tree) <-+ search_mid)
                                                     <-+ search_right) tag_1)))))
        (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> (Freshened c_1
                                                    (search_mid <-+ search_right) tag_1)))))
        "rail-fused/bubble-scoped-right-fail"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> (Freshened c_1
                                                    ((empty-tree) <-+ search_right) tag_1)))))
        (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> (Freshened c_1 search_right tag_1)))))
        "rail-fused/skip-scoped-right-left-fail"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> (((in-hole QFront (⊤ σ_new))
                                          <-+ search_mid)
                                         <-+ search_right)))))
        (in-hole QSpine
                 ((in-hole QFront (⊤ σ_new))
                  + (in-hole KBranch
                             (in-hole KWork
                                      (search_left
                                       +-> (search_mid <-+ search_right))))))
        "rail-fused/bubble-right-left-answer"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> ((in-hole QFront (⊤ σ_new))
                                          <-+ search_right)))))
        (in-hole QSpine
                 ((in-hole QFront (⊤ σ_new))
                  + (in-hole KBranch
                             (in-hole KWork
                                      (search_left +-> search_right)))))
        "rail-fused/promote-right-left-answer"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> (((empty-tree) <-+ search_mid)
                                          <-+ search_right)))))
        (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> (search_mid <-+ search_right)))))
        "rail-fused/bubble-right-left-fail"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> ((empty-tree) <-+ search_right)))))
        (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork (search_left +-> search_right))))
        "rail-fused/skip-right-left-fail"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left +-> (in-hole QFront (⊤ σ_new))))))
        (in-hole QSpine
                 ((in-hole QFront (⊤ σ_new))
                  + (in-hole KBranch
                             (in-hole KWork search_left))))
        "rail-fused/promote-right-observable"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left +-> (Freshened c_1 (empty-tree) tag_1)))))
        (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork search_left)))
        "rail-fused/skip-scoped-right-fail"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left +-> (empty-tree)))))
        (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork search_left)))
        "rail-fused/skip-right-fail"]))

(define rail-fused-local/under-QSpine
  (context-closure rail-fused-local/base rail-fused-lang QSpine))

(define rail-fused-red
  (union-reduction-relations
   lifted-search-base-fused-red
   rail-fused-local/under-QSpine
   rail-fused-frontier/base))

(define (step-once prog)
  (step-once/deterministic rail-fused-red prog))
