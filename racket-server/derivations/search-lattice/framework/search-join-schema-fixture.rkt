#lang racket

(require "./core-stage-schema.rkt"
         (submod "./core-stage-schema.rkt" test-support)
         "./search-join-schema.rkt"
         (prefix-in core-source: "../generated/core/source/n.rkt")
         (prefix-in core-stage: "../generated/core/stages/n.rkt"))

(provide search-join-smoke-source
         search-join-smoke-extension
         search-join-smoke-row
         search-join-smoke-owned-rule-labels)

(define-generated-search-join-source search-join-smoke-source
  #:base core-source:generated-core-n-source
  #:owned-rule-labels ())

(define-syntax-rule
  (capture-search-join
    #:base _base-source
    #:owned-rule-labels (owned-label ...)
    output)
  (define output '(owned-label ...)))

(search-join-smoke-source
 #:visit-search-join capture-search-join
 search-join-smoke-owned-rule-labels)

(define-generated-search-join-stage-extension search-join-smoke-extension
  #:source search-join-smoke-source)

(apply-selected-stage-extension search-join-smoke-row
  #:extension search-join-smoke-extension
  #:base core-stage:core/staged-row/N)

(assert-selected-staged-row-metadata
 search-join-smoke-row
 #:same-as core-stage:core/staged-row/N)
