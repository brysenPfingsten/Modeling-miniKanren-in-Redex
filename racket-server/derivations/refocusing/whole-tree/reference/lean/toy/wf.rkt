#lang racket

(require redex/reduction-semantics
         "../wf-schema.rkt"
         "./kernel.rkt"
         "./language.rkt")

(provide wf-goal/lean-toy
         wf-answer/lean-toy
         wf-work/lean-toy
         wf-frontier/lean-toy)

(define-lean-well-formedness
  lean-toy-lang
  wf-atomic/lean-toy
  wf-state/lean-toy
  wf-goal/lean-toy
  wf-answer/lean-toy
  wf-work/lean-toy
  wf-frontier/lean-toy)
