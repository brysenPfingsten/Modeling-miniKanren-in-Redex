#lang racket

(require redex/reduction-semantics
         "../languages/rail-relcall-lang.rkt"
         "./core-wf.rkt"
         "./relcall-wf-schema.rkt")

(provide wf-goal/rail-relcall?
         wf-answer/rail-relcall?
         wf-settled/rail-relcall?
         wf-work/rail-relcall?
         wf-frontier/rail-relcall?
         wf-rel-env/rail-relcall?
         wf-config/rail-relcall?)

(check-redundancy #t)

(define-search-relcall-well-formedness
  rail-relcall-lang
  wf-goal/rail-relcall?
  wf-answer/rail-relcall?
  wf-settled/rail-relcall?
  wf-work/rail-relcall?
  wf-frontier/rail-relcall?
  wf-rel-env/rail-relcall?
  wf-config/rail-relcall?
  "wf disjunction goal/rail-relcall"
  "wf suspended goal/rail-relcall"
  "wf pending delay/rail-relcall"
  "wf left-active choice/rail-relcall"
  "wf forced frontier/rail-relcall"
  "wf emitted frontier/rail-relcall"
  (
   [(wf-owner-stack? owners intro_visible intro_body)
    (wf-work/rail-relcall? W_1 Γ intro_body)
    (wf-work/rail-relcall? W_2 Γ intro_body)
    ---------------------------------------------------- "wf right-active choice/rail-relcall"
    (wf-work/rail-relcall?
     (DisjR owners W_1 W_2)
     Γ
     intro_visible)]))
