#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../../../framework/disjunction-schema.rkt"
         "../source/e.rkt"
         (prefix-in core: "../../core/stages/e.rkt"))

(provide disjunction/stage-extension/E
         disjunction/staged-row/E
         J-core->disjunction/D/E
         J-core->disjunction/Z/E
         J-core->disjunction/M/E
         J-core->disjunction/B/E
         J-core->disjunction/Big/E)

(define-generated-disjunction-stage-extension disjunction/stage-extension/E
  #:source generated-disjunction-e-source)

(apply-selected-stage-extension disjunction/staged-row/E
  #:extension disjunction/stage-extension/E
  #:base core:core/staged-row/E)

(define (J-core->disjunction/D/E value)
  (unless (redex-match? core:generated-core-stage-e-decomposition-lang D value)
    (raise-argument-error 'J-core->disjunction/D/E "core E D" value))
  value)

(define (J-core->disjunction/Z/E value)
  (unless (redex-match? core:generated-core-stage-e-refocused-lang Z value)
    (raise-argument-error 'J-core->disjunction/Z/E "core E Z" value))
  value)

(define (J-core->disjunction/M/E value)
  (unless (redex-match? core:generated-core-stage-e-machine-lang M value)
    (raise-argument-error 'J-core->disjunction/M/E "core E M" value))
  value)

(define (J-core->disjunction/B/E value)
  (unless (redex-match? core:generated-core-stage-e-compressed-lang B value)
    (raise-argument-error 'J-core->disjunction/B/E "core E B" value))
  value)

(define (J-core->disjunction/Big/E value)
  (unless (redex-match? core:generated-core-stage-e-big-lang Big value)
    (raise-argument-error 'J-core->disjunction/Big/E "core E Big" value))
  value)
