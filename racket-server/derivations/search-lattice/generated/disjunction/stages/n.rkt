#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../../../framework/disjunction-schema.rkt"
         "../source/n.rkt"
         (prefix-in core: "../../core/stages/n.rkt"))

(provide disjunction/stage-extension/N
         disjunction/staged-row/N
         J-core->disjunction/D/N
         J-core->disjunction/Z/N
         J-core->disjunction/M/N
         J-core->disjunction/B/N
         J-core->disjunction/Big/N)

(define-generated-disjunction-stage-extension disjunction/stage-extension/N
  #:source generated-disjunction-n-source)

(apply-selected-stage-extension disjunction/staged-row/N
  #:extension disjunction/stage-extension/N
  #:base core:core/staged-row/N)

(define (J-core->disjunction/D/N value)
  (unless (redex-match? core:generated-core-stage-n-decomposition-lang D value)
    (raise-argument-error 'J-core->disjunction/D/N "core N D" value))
  value)

(define (J-core->disjunction/Z/N value)
  (unless (redex-match? core:generated-core-stage-n-refocused-lang Z value)
    (raise-argument-error 'J-core->disjunction/Z/N "core N Z" value))
  value)

(define (J-core->disjunction/M/N value)
  (unless (redex-match? core:generated-core-stage-n-machine-lang M value)
    (raise-argument-error 'J-core->disjunction/M/N "core N M" value))
  value)

(define (J-core->disjunction/B/N value)
  (unless (redex-match? core:generated-core-stage-n-compressed-lang B value)
    (raise-argument-error 'J-core->disjunction/B/N "core N B" value))
  value)

(define (J-core->disjunction/Big/N value)
  (unless (redex-match? core:generated-core-stage-n-big-lang Big value)
    (raise-argument-error 'J-core->disjunction/Big/N "core N Big" value))
  value)
