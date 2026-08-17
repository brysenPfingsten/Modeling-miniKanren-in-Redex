#lang racket

(require redex/reduction-semantics
         "../wf-schema.rkt"
         "./kernel.rkt"
         "./language.rkt")

(provide wf-goal/mk
         wf-answer-at/mk
         wf-work-at/mk
         wf-frontier-at/mk
         wf-frontier/mk)

(define-pk-well-formedness
  pk-mk-lang
  wf-atomic/mk
  wf-state-at/mk
  wf-goal/mk
  wf-answer-at/mk
  wf-work-at/mk
  wf-frontier-at/mk
  wf-frontier/mk)
