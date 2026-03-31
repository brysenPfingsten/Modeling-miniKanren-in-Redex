#lang racket

(require redex/reduction-semantics
         "../languages/disj-lang.rkt"
         "./core-red.rkt")

(provide disj-core-local/base
         disj-goal-local/base
         disj-frontier/local-base)

(check-redundancy #t)

(define core-base/disj
  (extend-core-redex disj-lang))

(define disj-core-local/base
  (context-closure core-base/disj disj-lang KLocal))
(define disj-goal-local/base
  (reduction-relation
   disj-lang
   #:domain cfg
   [--> (in-hole KLocal ((g_1 ∨ g_2 tag) σ))
        (in-hole KLocal ((g_1 σ) <-+ (g_2 σ)))
        "disj/goal-to-tree"]))

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
