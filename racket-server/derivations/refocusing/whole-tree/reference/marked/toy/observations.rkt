#lang racket

(require redex/reduction-semantics
         "../observation-language-schema.rkt"
         "../observation-schema.rkt"
         "./kernel.rkt"
         "./language.rkt")

(provide pk-toy-observation-lang
         frontier-split/toy
         restore-frontier/toy
         frontier-prefix-events/toy
         answer-payloads/toy
         answer-states/toy
         scoped-answers/toy
         forced-events/toy
         residual/toy
         trace-labels/toy
         rule-cost/toy
         force-count/toy
         allocation-edge/toy
         allocation-events/toy
         observation-prefix/toy
         frontier-delta/toy)

(check-redundancy #t)

(define-pk-observation-language
  pk-toy-observation-lang
  pk-toy-lang)

(define-pk-observations
  pk-toy-observation-lang
  frontier-split/toy
  restore-frontier/toy
  frontier-prefix-events/toy
  answer-payloads/toy
  answer-states/toy
  scoped-answers/toy
  forced-events/toy
  residual/toy
  trace-labels/toy
  rule-cost/toy
  force-count/toy
  whole-marker-support/toy
  kernel-open-fresh/toy
  allocation-edge/toy
  allocation-events/toy
  observation-prefix/toy
  frontier-delta/toy)
