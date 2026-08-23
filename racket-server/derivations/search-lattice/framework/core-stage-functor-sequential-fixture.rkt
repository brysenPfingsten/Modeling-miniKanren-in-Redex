#lang racket

(require "./core-stage-functor-base-fixture.rkt"
         "./core-stage-extension-query-fixture.rkt"
         "./core-stage-functor-probe-fixture.rkt"
         "./core-stage-schema.rkt")

(provide selected-functor/query-row
         selected-functor/probe-row)

;; Stage Delta1 against the generated base, then stage Delta2 against the
;; actual result interface.  Probe's target is Query, so a mistaken second
;; application against the original base cannot type-check.
(apply-selected-stage-extension selected-functor/query-row
  #:extension selected-foreign/query-extension
  #:base selected-functor/base-row)

(apply-selected-stage-extension selected-functor/probe-row
  #:extension selected-functor/probe-extension
  #:base selected-functor/query-row)
