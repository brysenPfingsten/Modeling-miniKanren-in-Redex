#lang racket

(require redex/reduction-semantics
         "../languages/relcall-lang.rkt"
         "./core-wf.rkt"
         "./relcall-wf-schema.rkt")

(provide wf-goal/relcall?
         wf-answer/relcall?
         wf-settled/relcall?
         wf-work/relcall?
         wf-frontier/relcall?
         wf-rel-env/relcall?
         wf-config/relcall?)

(check-redundancy #t)

(define-relcall-well-formedness
  relcall-lang
  wf-goal/relcall?
  wf-answer/relcall?
  wf-settled/relcall?
  wf-work/relcall?
  wf-frontier/relcall?
  wf-rel-env/relcall?
  wf-config/relcall?
  (
   [(wf-goal/relcall? g Γ (x_bound ...) intro_visible)
    ---------------------------------------------------- "wf suspended goal/relcall"
    (wf-goal/relcall?
     (suspend g tag)
     Γ
     (x_bound ...)
     intro_visible)])
  ()
  (
   [(wf-owner-stack? owners intro_visible intro_body)
    (wf-work/relcall? W Γ intro_body)
    ---------------------------------------------------- "wf pending delay/relcall"
    (wf-work/relcall?
     (PendingDelay owners W)
     Γ
     intro_visible)])
  (
   [(wf-owner-stack? owners intro_visible intro_body)
    (wf-frontier/relcall? F Γ intro_body)
    ---------------------------------------------------- "wf forced frontier/relcall"
    (wf-frontier/relcall?
     (Forced owners F)
     Γ
     intro_visible)]))
