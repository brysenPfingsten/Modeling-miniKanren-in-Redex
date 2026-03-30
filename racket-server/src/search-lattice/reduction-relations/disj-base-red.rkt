#lang racket

(require redex/reduction-semantics
         "../languages/disj-lang.rkt"
         "./core-red.rkt")

(provide disj-base-core
         disj-goal-local/under-QSpine
         disj-frontier/local-base
         disj-frontier/base)

(check-redundancy #t)

(define core-base/disj
  (extend-core-redex disj-lang))

(define core-local/disj
  (context-closure core-base/disj disj-lang KWork))

(define disj-base-core
  (context-closure core-local/disj disj-lang QSpine))

(define disj-goal-local/base
  (reduction-relation
   disj-lang
   #:domain cfg
   [--> (in-hole KWork ((g_1 ∨ g_2 tag) σ))
        (in-hole KWork ((g_1 σ) <-+ (g_2 σ)))
        "disj/goal-to-tree"]))

(define disj-goal-local/under-QSpine
  (context-closure disj-goal-local/base disj-lang QSpine))

(define disj-frontier/local-base
  (reduction-relation
   disj-lang
   #:domain cfg
   [--> ((promoted_i <-+ search_mid) <-+ search_right)
        (promoted_i <-+ (search_mid <-+ search_right))
        "disj/reassociate-left-answer"]
   [--> (promoted_i <-+ search_right)
        (promoted_i + search_right)
        "disj/promote-left-answer"]
   [--> (((empty-tree) <-+ search_mid) <-+ search_right)
        (search_mid <-+ search_right)
        "disj/erase-left-fail"]
   [--> ((empty-tree) <-+ search_right)
        search_right
        "disj/erase-left-fail-top"]))

(define disj-frontier/base
  (context-closure disj-frontier/local-base disj-lang QSpine))
