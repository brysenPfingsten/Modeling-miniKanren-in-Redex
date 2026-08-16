#lang racket

(require redex/reduction-semantics
         "../wf-schema.rkt"
         "./kernel.rkt"
         "./language.rkt")

(provide wf-goal/toy
         wf-answer-at/toy
         wf-work-at/toy
         wf-frontier-at/toy
         wf-frontier/toy)

(define-pk-well-formedness
  pk-toy-lang
  wf-atomic/toy
  wf-state-at/toy
  wf-goal/toy
  wf-answer-at/toy
  wf-work-at/toy
  wf-frontier-at/toy
  wf-frontier/toy)
