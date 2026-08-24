#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../../../framework/delay-schema.rkt"
         "../../../framework/disjunction-schema.rkt"
         "../../../framework/search-join-schema.rkt"
         "../source/e.rkt"
         (prefix-in disjunction-source: "../../disjunction/source/e.rkt")
         (prefix-in core: "../../core/stages/e.rkt")
         (prefix-in delay: "../../delay/stages/e.rkt")
         (prefix-in disjunction: "../../disjunction/stages/e.rkt"))

(provide search/disjunction-stage-extension/E
         search/disjunction-staged-row/E
         search/delay-stage-extension/E
         search/children-staged-row/E
         search/join-stage-extension/E
         search/staged-row/E
         J-core->search/D/E J-core->search/Z/E J-core->search/M/E
         J-core->search/B/E J-core->search/Big/E
         J-delay->search/D/E J-delay->search/Z/E J-delay->search/M/E
         J-delay->search/B/E J-delay->search/Big/E
         J-disjunction->search/D/E J-disjunction->search/Z/E
         J-disjunction->search/M/E J-disjunction->search/B/E
         J-disjunction->search/Big/E)

(define-generated-disjunction-stage-extension
  search/disjunction-stage-extension/E
  #:source disjunction-source:generated-disjunction-e-source
  #:dependencies-from generated-search-e-source)

(apply-selected-stage-extension search/disjunction-staged-row/E
  #:extension search/disjunction-stage-extension/E
  #:base core:core/staged-row/E)

(define-generated-delay-stage-extension search/delay-stage-extension/E
  #:source generated-search-e-child-source
  #:dependencies-from generated-search-e-source)

(apply-selected-stage-extension search/children-staged-row/E
  #:extension search/delay-stage-extension/E
  #:base search/disjunction-staged-row/E)

(define-generated-search-join-stage-extension search/join-stage-extension/E
  #:source generated-search-e-source)

(apply-selected-stage-extension search/staged-row/E
  #:extension search/join-stage-extension/E
  #:base search/children-staged-row/E)

(define-syntax-rule (define-embedding name language nonterminal expected)
  (define (name value)
    (unless (redex-match? language nonterminal value)
      (raise-argument-error 'name expected value))
    value))

(define-embedding J-core->search/D/E core:generated-core-stage-e-decomposition-lang D "core E D")
(define-embedding J-core->search/Z/E core:generated-core-stage-e-refocused-lang Z "core E Z")
(define-embedding J-core->search/M/E core:generated-core-stage-e-machine-lang M "core E M")
(define-embedding J-core->search/B/E core:generated-core-stage-e-compressed-lang B "core E B")
(define-embedding J-core->search/Big/E core:generated-core-stage-e-big-lang Big "core E Big")

(define-embedding J-delay->search/D/E delay:delay/stage-extension/E/D-language D "Delay E D")
(define-embedding J-delay->search/Z/E delay:delay/stage-extension/E/Z-language Z "Delay E Z")
(define-embedding J-delay->search/M/E delay:delay/stage-extension/E/M-language M "Delay E M")
(define-embedding J-delay->search/B/E delay:delay/stage-extension/E/B-language B "Delay E B")
(define-embedding J-delay->search/Big/E delay:delay/stage-extension/E/Big-language Big "Delay E Big")

(define-embedding J-disjunction->search/D/E disjunction:disjunction/stage-extension/E/D-language D "Disjunction E D")
(define-embedding J-disjunction->search/Z/E disjunction:disjunction/stage-extension/E/Z-language Z "Disjunction E Z")
(define-embedding J-disjunction->search/M/E disjunction:disjunction/stage-extension/E/M-language M "Disjunction E M")
(define-embedding J-disjunction->search/B/E disjunction:disjunction/stage-extension/E/B-language B "Disjunction E B")
(define-embedding J-disjunction->search/Big/E disjunction:disjunction/stage-extension/E/Big-language Big "Disjunction E Big")
