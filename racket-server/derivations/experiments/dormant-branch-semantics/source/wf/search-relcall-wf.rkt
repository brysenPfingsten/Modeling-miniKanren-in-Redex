#lang racket

(require redex/reduction-semantics
         "../languages/search-relcall-lang.rkt"
         "./core-wf.rkt"
         "./relcall-wf-schema.rkt")

(provide wf-goal/search-relcall?
         wf-answer/search-relcall?
         wf-settled/search-relcall?
         wf-work/search-relcall?
         wf-frontier/search-relcall?
         wf-rel-env/search-relcall?
         wf-config/search-relcall?)

(check-redundancy #t)

(define-search-relcall-well-formedness
  search-relcall-lang
  wf-goal/search-relcall?
  wf-answer/search-relcall?
  wf-settled/search-relcall?
  wf-work/search-relcall?
  wf-frontier/search-relcall?
  wf-rel-env/search-relcall?
  wf-config/search-relcall?
  "wf disjunction goal/search-relcall"
  "wf suspended goal/search-relcall"
  "wf pending delay/search-relcall"
  "wf left-active choice/search-relcall"
  "wf forced frontier/search-relcall"
  "wf emitted frontier/search-relcall"
  ())
