#lang racket

(require redex/reduction-semantics
         "../languages/disj-lang.rkt"
         "./core-red.rkt")

(provide disj-base-core
         disj-goal-local/under-QSpine
         disj-frontier/base)

(check-redundancy #t)

(define core-base/disj
  (extend-core-redex disj-lang))

(define core-local/disj
  (context-closure core-base/disj disj-lang KWork))

(define core-branch/disj
  (context-closure core-local/disj disj-lang KBranch))

(define disj-base-core
  (context-closure core-branch/disj disj-lang QSpine))

(define disj-goal-local/base
  (reduction-relation
   disj-lang
   #:domain cfg
   [--> (in-hole KBranch (in-hole KWork ((g_1 ∨ g_2 tag) σ)))
        (in-hole KBranch (in-hole KWork ((g_1 σ) <-+ (g_2 σ))))
        "disj/goal-to-tree"]))

(define disj-goal-local/under-QSpine
  (context-closure disj-goal-local/base disj-lang QSpine))

(define disj-frontier/base
  (reduction-relation
   disj-lang
   #:domain cfg
   [--> (in-hole QSpine
                  (((promoted_i <-+ search_mid)
                    <-+ search_right)))
        (in-hole QSpine
                 (promoted_i
                  + (search_mid <-+ search_right)))
        "disj/bubble-left-answer"]
   [--> (in-hole QSpine
                  (promoted_i <-+ search_right))
        (in-hole QSpine
                 (promoted_i + search_right))
        "disj/promote-left-answer"]
   [--> (in-hole QSpine
                  ((((empty-tree) <-+ search_mid) <-+ search_right)))
        (in-hole QSpine
                 (search_mid <-+ search_right))
        "disj/bubble-left-fail"]
   [--> (in-hole QSpine
                  ((empty-tree) <-+ search_right))
        (in-hole QSpine search_right)
        "disj/skip-left-fail"]))
