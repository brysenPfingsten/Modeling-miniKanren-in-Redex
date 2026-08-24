#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../../../framework/disjunction-schema.rkt"
         "../source/s.rkt"
         (prefix-in core: "../../core/stages/s.rkt"))

(provide disjunction/stage-extension/S
         disjunction/staged-row/S
         J-core->disjunction/D/S
         J-core->disjunction/Z/S
         J-core->disjunction/M/S
         J-core->disjunction/B/S
         J-core->disjunction/Big/S)

(define-generated-disjunction-stage-extension disjunction/stage-extension/S
  #:source generated-disjunction-s-source)

(apply-selected-stage-extension disjunction/staged-row/S
  #:extension disjunction/stage-extension/S
  #:base core:core/staged-row/S)

(define (J-core->disjunction/D/S value)
  (unless (redex-match? core:generated-core-stage-s-decomposition-lang D value)
    (raise-argument-error 'J-core->disjunction/D/S "core S D" value))
  value)

(define (J-core->disjunction/Z/S value)
  (unless (redex-match? core:generated-core-stage-s-refocused-lang Z value)
    (raise-argument-error 'J-core->disjunction/Z/S "core S Z" value))
  value)

(define (J-core->disjunction/M/S value)
  (unless (redex-match? core:generated-core-stage-s-machine-lang M value)
    (raise-argument-error 'J-core->disjunction/M/S "core S M" value))
  value)

(define (J-core->disjunction/B/S value)
  (unless (redex-match? core:generated-core-stage-s-compressed-lang B value)
    (raise-argument-error 'J-core->disjunction/B/S "core S B" value))
  value)

(define (J-core->disjunction/Big/S value)
  (unless (redex-match? core:generated-core-stage-s-big-lang Big value)
    (raise-argument-error 'J-core->disjunction/Big/S "core S Big" value))
  value)
