#lang racket

(require redex/reduction-semantics
         "../languages/rail-lang.rkt"
         "./core-wf.rkt"
         "./wf-schema.rkt")

(provide wf-goal/rail?
         wf-answer/rail?
         wf-settled/rail?
         wf-work/rail?
         wf-frontier/rail?
         wf-cfg/rail?)

(check-redundancy #t)

;; In production, rail is the only scheduler fiber whose carrier extends
;; ordinary search: DisjR records its right-active phase. The remaining clauses
;; are exactly the literal delay/disjunction union checked by search-wf.rkt.
(define-search-well-formedness
  rail-lang
  wf-goal/rail?
  wf-answer/rail?
  wf-settled/rail?
  wf-work/rail?
  wf-frontier/rail?
  wf-cfg/rail?
  "wf disjunction goal/rail"
  "wf suspended goal/rail"
  "wf pending delay/rail"
  "wf left-active choice/rail"
  "wf forced frontier/rail"
  "wf emitted frontier/rail"
  (
   [(wf-owner-stack? owners intro_visible intro_body)
    (wf-work/rail? W_1 intro_body)
    (wf-work/rail? W_2 intro_body)
    ---------------------------------------------------- "wf right-active choice/rail"
    (wf-work/rail? (DisjR owners W_1 W_2) intro_visible)]))
