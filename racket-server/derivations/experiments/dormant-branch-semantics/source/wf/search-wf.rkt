#lang racket

(require redex/reduction-semantics
         "../languages/search-lang.rkt"
         "./core-wf.rkt"
         "./wf-schema.rkt")

(provide wf-goal/search?
         wf-answer/search?
         wf-settled/search?
         wf-work/search?
         wf-frontier/search?
         wf-cfg/search?)

(check-redundancy #t)

(define-search-well-formedness
  search-lang
  wf-goal/search?
  wf-answer/search?
  wf-settled/search?
  wf-work/search?
  wf-frontier/search?
  wf-cfg/search?
  "wf disjunction goal/search"
  "wf suspended goal/search"
  "wf pending delay/search"
  "wf left-active choice/search"
  "wf forced frontier/search"
  "wf emitted frontier/search"
  ())
