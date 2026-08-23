#lang racket

(require "./core-stage-functor-base-fixture.rkt"
         "./core-stage-schema.rkt")

(provide selected-functor/identity-row)

(define-selected-stage-extension selected-functor/identity-extension
  #:identity
  #:feature-singletons ())

(apply-selected-stage-extension selected-functor/identity-row
  #:extension selected-functor/identity-extension
  #:base selected-functor/base-row)
