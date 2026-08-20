#lang racket

(require redex/reduction-semantics
         "../languages/delay-lang.rkt"
         "./core-wf.rkt"
         "./wf-schema.rkt")

(provide wf-goal/delay?
         wf-answer/delay?
         wf-settled/delay?
         wf-work/delay?
         wf-frontier/delay?
         wf-cfg/delay?)

(check-redundancy #t)

(define-well-formedness
  delay-lang
  wf-goal/delay?
  wf-answer/delay?
  wf-settled/delay?
  wf-work/delay?
  wf-frontier/delay?
  wf-cfg/delay?
  (
   [(wf-goal/delay? g (x_bound ...) intro_visible)
    ---------------------------------------------------- "wf suspended goal/delay"
    (wf-goal/delay?
     (suspend g tag)
     (x_bound ...)
     intro_visible)])
  ()
  (
   [(wf-owner-stack? owners intro_visible intro_body)
    (wf-work/delay? W intro_body)
    ---------------------------------------------------- "wf pending delay/delay"
    (wf-work/delay? (PendingDelay owners W) intro_visible)])
  (
   [(wf-owner-stack? owners intro_visible intro_body)
    (wf-frontier/delay? F intro_body)
    ---------------------------------------------------- "wf forced frontier/delay"
    (wf-frontier/delay? (Forced owners F) intro_visible)]))
