#lang racket

(require redex/reduction-semantics
         "./core-stage-schema.rkt"
         "./disjunction-schema.rkt"
         "./disjunction-schema-source-fixture.rkt"
         (prefix-in stage-n: "../generated/core/stages/n.rkt"))

(provide disjunction/stage-extension/N
         disjunction/staged-row/N)

(define-generated-disjunction-stage-extension disjunction/stage-extension/N
  #:source disjunction-n-smoke-source)

(apply-selected-stage-extension disjunction/staged-row/N
  #:extension disjunction/stage-extension/N
  #:base stage-n:core/staged-row/N)
