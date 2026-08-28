#lang racket

(require redex/reduction-semantics
         "../wf-schema.rkt"
         "./kernel.rkt"
         "./language.rkt")

(provide wf-goal/lean-mk
         wf-answer/lean-mk
         wf-work/lean-mk
         wf-frontier/lean-mk)

(define-lean-well-formedness
  lean-mk-lang
  wf-atomic/lean-mk
  wf-state/lean-mk
  wf-goal/lean-mk
  wf-answer/lean-mk
  wf-work/lean-mk
  wf-frontier/lean-mk)
