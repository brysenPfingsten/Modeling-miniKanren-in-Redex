#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../../../framework/delay-schema.rkt"
         "../source/n.rkt"
         (prefix-in core: "../../core/stages/n.rkt"))

(provide delay/stage-extension/N
         delay/staged-row/N
         J-core->delay/D/N
         J-core->delay/Z/N
         J-core->delay/M/N
         J-core->delay/B/N
         J-core->delay/Big/N)

(define-generated-delay-stage-extension delay/stage-extension/N
  #:source generated-delay-n-source)

(apply-selected-stage-extension delay/staged-row/N
  #:extension delay/stage-extension/N
  #:base core:core/staged-row/N)

(define (J-core->delay/D/N value)
  (unless (redex-match? core:generated-core-stage-n-decomposition-lang D value)
    (raise-argument-error 'J-core->delay/D/N "core N D" value))
  value)

(define (J-core->delay/Z/N value)
  (unless (redex-match? core:generated-core-stage-n-refocused-lang Z value)
    (raise-argument-error 'J-core->delay/Z/N "core N Z" value))
  value)

(define (J-core->delay/M/N value)
  (unless (redex-match? core:generated-core-stage-n-machine-lang M value)
    (raise-argument-error 'J-core->delay/M/N "core N M" value))
  value)

(define (J-core->delay/B/N value)
  (unless (redex-match? core:generated-core-stage-n-compressed-lang B value)
    (raise-argument-error 'J-core->delay/B/N "core N B" value))
  value)

(define (J-core->delay/Big/N value)
  (unless (redex-match? core:generated-core-stage-n-big-lang Big value)
    (raise-argument-error 'J-core->delay/Big/N "core N Big" value))
  value)
