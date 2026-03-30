#lang racket

(require redex/reduction-semantics
         "../languages/core-lang.rkt"
         "../languages/rail-seq-lang.rkt"
         "./private/common.rkt"
         "./private/step-utils.rkt"
         "./search-base-seq-red.rkt")

(provide rail-seq-local/base
         rail-seq-local/under-QSpine
         rail-seq-frontier/base
         rail-seq-red
         step-once)

(check-redundancy #t)

(define lifted-search-base-seq-red
  (extend-reduction-relation
   search-base-seq-red
   rail-seq-lang))

(define rail-seq-local/base
  (reduction-relation
   rail-seq-lang
   #:domain cfg
   [--> (in-hole KBranch (in-hole KWork ((delay runnable-search_1) <-+ search_2)))
        (in-hole KBranch (in-hole KWork (delay (runnable-search_1 +-> search_2))))
        "rail-seq/enter-right"]
   [--> (in-hole KBranch (in-hole KWork (search_2 +-> (delay runnable-search_1))))
        (in-hole KBranch (in-hole KWork (delay (search_2 <-+ runnable-search_1))))
        "rail-seq/return-left"]))

(define rail-seq-frontier/base
  (reduction-relation
   rail-seq-lang
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
        "rail-seq/bubble-scoped-right-answer"]
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
        "rail-seq/promote-scoped-right-answer"]
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
        "rail-seq/bubble-scoped-right-fail"]
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
        "rail-seq/skip-scoped-right-left-fail"]
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
        "rail-seq/bubble-right-left-answer"]
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
        "rail-seq/promote-right-left-answer"]
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
        "rail-seq/bubble-right-left-fail"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left
                                    +-> ((empty-tree) <-+ search_right)))))
        (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork (search_left +-> search_right))))
        "rail-seq/skip-right-left-fail"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left +-> (in-hole QFront (⊤ σ_new))))))
        (in-hole QSpine
                 ((in-hole QFront (⊤ σ_new))
                  + (in-hole KBranch
                             (in-hole KWork search_left))))
        "rail-seq/promote-right-observable"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left +-> (Freshened c_1 (empty-tree) tag_1)))))
        (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork search_left)))
        "rail-seq/skip-scoped-right-fail"]
   [--> (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork
                                   (search_left +-> (empty-tree)))))
        (in-hole QSpine
                 (in-hole KBranch
                          (in-hole KWork search_left)))
        "rail-seq/skip-right-fail"]))

(define rail-seq-local/under-QSpine
  (context-closure rail-seq-local/base rail-seq-lang QSpine))

(define rail-seq-red
  (union-reduction-relations
   lifted-search-base-seq-red
   rail-seq-local/under-QSpine
   rail-seq-frontier/base))

(define (step-once prog)
  (step-once/deterministic rail-seq-red prog))
