#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../../../framework/delay-schema.rkt"
         "../source/e.rkt"
         (prefix-in core: "../../core/stages/e.rkt"))

(provide delay/stage-extension/E
         delay/staged-row/E
         J-core->delay/D/E
         J-core->delay/Z/E
         J-core->delay/M/E
         J-core->delay/B/E
         J-core->delay/Big/E)

(define-generated-delay-stage-extension delay/stage-extension/E
  #:source generated-delay-e-source)

(apply-selected-stage-extension delay/staged-row/E
  #:extension delay/stage-extension/E
  #:base core:core/staged-row/E)

(define (J-core->delay/D/E value)
  (unless (redex-match? core:generated-core-stage-e-decomposition-lang D value)
    (raise-argument-error 'J-core->delay/D/E "core E D" value))
  value)

(define (J-core->delay/Z/E value)
  (unless (redex-match? core:generated-core-stage-e-refocused-lang Z value)
    (raise-argument-error 'J-core->delay/Z/E "core E Z" value))
  value)

(define (J-core->delay/M/E value)
  (unless (redex-match? core:generated-core-stage-e-machine-lang M value)
    (raise-argument-error 'J-core->delay/M/E "core E M" value))
  value)

(define (J-core->delay/B/E value)
  (unless (redex-match? core:generated-core-stage-e-compressed-lang B value)
    (raise-argument-error 'J-core->delay/B/E "core E B" value))
  value)

(define (J-core->delay/Big/E value)
  (unless (redex-match? core:generated-core-stage-e-big-lang Big value)
    (raise-argument-error 'J-core->delay/Big/E "core E Big" value))
  value)
