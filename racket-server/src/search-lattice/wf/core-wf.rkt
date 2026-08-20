#lang racket

(require redex/reduction-semantics
         "../languages/core-lang.rkt"
         "./kernel-base.rkt"
         "./wf-schema.rkt")

(provide (all-from-out "./kernel-base.rkt")
         wf-goal/core?
         wf-answer/core?
         wf-settled/core?
         wf-work/core?
         wf-frontier/core?
         wf-cfg/core?)

(check-redundancy #t)

(define-well-formedness
  core-lang
  wf-goal/core?
  wf-answer/core?
  wf-settled/core?
  wf-work/core?
  wf-frontier/core?
  wf-cfg/core?
  ()
  ()
  ()
  ())
