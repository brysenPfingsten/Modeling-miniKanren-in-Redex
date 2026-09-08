#lang racket

(require redex/reduction-semantics
         "../languages/disj-lang.rkt"
         "./core-wf.rkt"
         "./wf-schema.rkt")

(provide wf-goal/disj?
         wf-answer/disj?
         wf-settled/disj?
         wf-work/disj?
         wf-frontier/disj?
         wf-cfg/disj?)

(check-redundancy #t)

(define-well-formedness
  disj-lang
  wf-goal/disj?
  wf-answer/disj?
  wf-settled/disj?
  wf-work/disj?
  wf-frontier/disj?
  wf-cfg/disj?
  (
   [(wf-goal/disj? g_1 (x_bound ...) intro_visible)
    (wf-goal/disj? g_2 (x_bound ...) intro_visible)
    ---------------------------------------------------- "wf disjunction goal/disj"
    (wf-goal/disj?
     (g_1 ∨ g_2 tag)
     (x_bound ...)
     intro_visible)])
  ()
  (
   [(wf-owner-stack? owners intro_visible intro_body)
    (wf-work/disj? W_1 intro_body)
    (wf-work/disj? W_2 intro_body)
    ---------------------------------------------------- "wf left-active choice/disj"
    (wf-work/disj?
     (DisjL owners W_1 W_2)
     intro_visible)])
  (
   [(wf-owner-stack? owners intro_visible intro_body)
    (wf-answer/disj? A intro_body)
    (wf-frontier/disj? F intro_body)
    ---------------------------------------------------- "wf emitted frontier/disj"
    (wf-frontier/disj?
     (Emit owners A F)
     intro_visible)]))
