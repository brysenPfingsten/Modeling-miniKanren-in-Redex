#lang racket

(require redex/reduction-semantics
         "../observation-language-schema.rkt"
         "../observation-schema.rkt"
         "./kernel.rkt"
         "./language.rkt")

(provide pk-mk-observation-lang
         frontier-split/mk
         restore-frontier/mk
         frontier-prefix-events/mk
         answer-payloads/mk
         answer-states/mk
         query-answers/mk
         scoped-answers/mk
         forced-events/mk
         residual/mk
         trace-labels/mk
         rule-cost/mk
         force-count/mk
         allocation-edge/mk
         allocation-events/mk
         observation-prefix/mk
         frontier-delta/mk)

(check-redundancy #t)

(define-pk-observation-language
  pk-mk-observation-lang
  pk-mk-lang)

(define-pk-observations
  pk-mk-observation-lang
  frontier-split/mk
  restore-frontier/mk
  frontier-prefix-events/mk
  answer-payloads/mk
  answer-states/mk
  scoped-answers/mk
  forced-events/mk
  residual/mk
  trace-labels/mk
  rule-cost/mk
  force-count/mk
  whole-marker-support/mk
  kernel-open-fresh/mk
  allocation-edge/mk
  allocation-events/mk
  observation-prefix/mk
  frontier-delta/mk)

;; Query observations are indexed by the caller's explicit query variables.
;; Ownership wrappers remain inspectable through scoped-answers/mk; they do
;; not silently enlarge the requested query.
(define-metafunction pk-mk-observation-lang
  query-answers/mk : F intro -> (observation ...)
  [(query-answers/mk F intro)
   ((kernel-observe/mk intro kst) ...)
   (where (kst ...) (answer-states/mk F))])
