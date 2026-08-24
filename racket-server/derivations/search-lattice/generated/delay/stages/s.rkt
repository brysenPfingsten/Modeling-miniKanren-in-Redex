#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../../../framework/delay-schema.rkt"
         "../source/s.rkt"
         (prefix-in core: "../../core/stages/s.rkt"))

(provide delay/stage-extension/S
         delay/staged-row/S
         J-core->delay/D/S
         J-core->delay/Z/S
         J-core->delay/M/S
         J-core->delay/B/S
         J-core->delay/Big/S)

(define-generated-delay-stage-extension delay/stage-extension/S
  #:source generated-delay-s-source)

(apply-selected-stage-extension delay/staged-row/S
  #:extension delay/stage-extension/S
  #:base core:core/staged-row/S)

(define (J-core->delay/D/S value)
  (unless (redex-match? core:generated-core-stage-s-decomposition-lang D value)
    (raise-argument-error 'J-core->delay/D/S "core S D" value))
  value)

(define (J-core->delay/Z/S value)
  (unless (redex-match? core:generated-core-stage-s-refocused-lang Z value)
    (raise-argument-error 'J-core->delay/Z/S "core S Z" value))
  value)

(define (J-core->delay/M/S value)
  (unless (redex-match? core:generated-core-stage-s-machine-lang M value)
    (raise-argument-error 'J-core->delay/M/S "core S M" value))
  value)

(define (J-core->delay/B/S value)
  (unless (redex-match? core:generated-core-stage-s-compressed-lang B value)
    (raise-argument-error 'J-core->delay/B/S "core S B" value))
  value)

(define (J-core->delay/Big/S value)
  (unless (redex-match? core:generated-core-stage-s-big-lang Big value)
    (raise-argument-error 'J-core->delay/Big/S "core S Big" value))
  value)
