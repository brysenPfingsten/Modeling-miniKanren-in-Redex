#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../../../framework/delay-schema.rkt"
         "../../../framework/disjunction-schema.rkt"
         "../../../framework/search-join-schema.rkt"
         "../source/s.rkt"
         (prefix-in disjunction-source: "../../disjunction/source/s.rkt")
         (prefix-in core: "../../core/stages/s.rkt")
         (prefix-in delay: "../../delay/stages/s.rkt")
         (prefix-in disjunction: "../../disjunction/stages/s.rkt"))

(provide search/disjunction-stage-extension/S
         search/disjunction-staged-row/S
         search/delay-stage-extension/S
         search/children-staged-row/S
         search/join-stage-extension/S
         search/staged-row/S
         J-core->search/D/S J-core->search/Z/S J-core->search/M/S
         J-core->search/B/S J-core->search/Big/S
         J-delay->search/D/S J-delay->search/Z/S J-delay->search/M/S
         J-delay->search/B/S J-delay->search/Big/S
         J-disjunction->search/D/S J-disjunction->search/Z/S
         J-disjunction->search/M/S J-disjunction->search/B/S
         J-disjunction->search/Big/S)

;; Each child keeps its own truthful source language, while its recursive
;; subst/focus/transfer dependencies are late-bound to the completed Search
;; source.  This is what lets an inherited Disjunction rule transfer through a
;; PendingDelay and an inherited Delay rule transfer through a DisjL.
(define-generated-disjunction-stage-extension
  search/disjunction-stage-extension/S
  #:source disjunction-source:generated-disjunction-s-source
  #:dependencies-from generated-search-s-source)

(apply-selected-stage-extension search/disjunction-staged-row/S
  #:extension search/disjunction-stage-extension/S
  #:base core:core/staged-row/S)

(define-generated-delay-stage-extension search/delay-stage-extension/S
  #:source generated-search-s-child-source
  #:dependencies-from generated-search-s-source)

(apply-selected-stage-extension search/children-staged-row/S
  #:extension search/delay-stage-extension/S
  #:base search/disjunction-staged-row/S)

(define-generated-search-join-stage-extension search/join-stage-extension/S
  #:source generated-search-s-source)

(apply-selected-stage-extension search/staged-row/S
  #:extension search/join-stage-extension/S
  #:base search/children-staged-row/S)

(define-syntax-rule (define-embedding name language nonterminal expected)
  (define (name value)
    (unless (redex-match? language nonterminal value)
      (raise-argument-error 'name expected value))
    value))

(define-embedding J-core->search/D/S core:generated-core-stage-s-decomposition-lang D "core S D")
(define-embedding J-core->search/Z/S core:generated-core-stage-s-refocused-lang Z "core S Z")
(define-embedding J-core->search/M/S core:generated-core-stage-s-machine-lang M "core S M")
(define-embedding J-core->search/B/S core:generated-core-stage-s-compressed-lang B "core S B")
(define-embedding J-core->search/Big/S core:generated-core-stage-s-big-lang Big "core S Big")

(define-embedding J-delay->search/D/S delay:delay/stage-extension/S/D-language D "Delay S D")
(define-embedding J-delay->search/Z/S delay:delay/stage-extension/S/Z-language Z "Delay S Z")
(define-embedding J-delay->search/M/S delay:delay/stage-extension/S/M-language M "Delay S M")
(define-embedding J-delay->search/B/S delay:delay/stage-extension/S/B-language B "Delay S B")
(define-embedding J-delay->search/Big/S delay:delay/stage-extension/S/Big-language Big "Delay S Big")

(define-embedding J-disjunction->search/D/S disjunction:disjunction/stage-extension/S/D-language D "Disjunction S D")
(define-embedding J-disjunction->search/Z/S disjunction:disjunction/stage-extension/S/Z-language Z "Disjunction S Z")
(define-embedding J-disjunction->search/M/S disjunction:disjunction/stage-extension/S/M-language M "Disjunction S M")
(define-embedding J-disjunction->search/B/S disjunction:disjunction/stage-extension/S/B-language B "Disjunction S B")
(define-embedding J-disjunction->search/Big/S disjunction:disjunction/stage-extension/S/Big-language Big "Disjunction S Big")
