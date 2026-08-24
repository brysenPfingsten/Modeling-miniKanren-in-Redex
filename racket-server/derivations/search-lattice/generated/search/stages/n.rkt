#lang racket

(require redex/reduction-semantics
         "../../../framework/core-stage-schema.rkt"
         "../../../framework/delay-schema.rkt"
         "../../../framework/disjunction-schema.rkt"
         "../../../framework/search-join-schema.rkt"
         "../source/n.rkt"
         (prefix-in disjunction-source: "../../disjunction/source/n.rkt")
         (prefix-in core: "../../core/stages/n.rkt")
         (prefix-in delay: "../../delay/stages/n.rkt")
         (prefix-in disjunction: "../../disjunction/stages/n.rkt"))

(provide search/disjunction-stage-extension/N
         search/disjunction-staged-row/N
         search/delay-stage-extension/N
         search/children-staged-row/N
         search/join-stage-extension/N
         search/staged-row/N
         J-core->search/D/N J-core->search/Z/N J-core->search/M/N
         J-core->search/B/N J-core->search/Big/N
         J-delay->search/D/N J-delay->search/Z/N J-delay->search/M/N
         J-delay->search/B/N J-delay->search/Big/N
         J-disjunction->search/D/N J-disjunction->search/Z/N
         J-disjunction->search/M/N J-disjunction->search/B/N
         J-disjunction->search/Big/N)

(define-generated-disjunction-stage-extension
  search/disjunction-stage-extension/N
  #:source disjunction-source:generated-disjunction-n-source
  #:dependencies-from generated-search-n-source)

(apply-selected-stage-extension search/disjunction-staged-row/N
  #:extension search/disjunction-stage-extension/N
  #:base core:core/staged-row/N)

(define-generated-delay-stage-extension search/delay-stage-extension/N
  #:source generated-search-n-child-source
  #:dependencies-from generated-search-n-source)

(apply-selected-stage-extension search/children-staged-row/N
  #:extension search/delay-stage-extension/N
  #:base search/disjunction-staged-row/N)

(define-generated-search-join-stage-extension search/join-stage-extension/N
  #:source generated-search-n-source)

(apply-selected-stage-extension search/staged-row/N
  #:extension search/join-stage-extension/N
  #:base search/children-staged-row/N)

(define-syntax-rule (define-embedding name language nonterminal expected)
  (define (name value)
    (unless (redex-match? language nonterminal value)
      (raise-argument-error 'name expected value))
    value))

(define-embedding J-core->search/D/N core:generated-core-stage-n-decomposition-lang D "core N D")
(define-embedding J-core->search/Z/N core:generated-core-stage-n-refocused-lang Z "core N Z")
(define-embedding J-core->search/M/N core:generated-core-stage-n-machine-lang M "core N M")
(define-embedding J-core->search/B/N core:generated-core-stage-n-compressed-lang B "core N B")
(define-embedding J-core->search/Big/N core:generated-core-stage-n-big-lang Big "core N Big")

(define-embedding J-delay->search/D/N delay:delay/stage-extension/N/D-language D "Delay N D")
(define-embedding J-delay->search/Z/N delay:delay/stage-extension/N/Z-language Z "Delay N Z")
(define-embedding J-delay->search/M/N delay:delay/stage-extension/N/M-language M "Delay N M")
(define-embedding J-delay->search/B/N delay:delay/stage-extension/N/B-language B "Delay N B")
(define-embedding J-delay->search/Big/N delay:delay/stage-extension/N/Big-language Big "Delay N Big")

(define-embedding J-disjunction->search/D/N disjunction:disjunction/stage-extension/N/D-language D "Disjunction N D")
(define-embedding J-disjunction->search/Z/N disjunction:disjunction/stage-extension/N/Z-language Z "Disjunction N Z")
(define-embedding J-disjunction->search/M/N disjunction:disjunction/stage-extension/N/M-language M "Disjunction N M")
(define-embedding J-disjunction->search/B/N disjunction:disjunction/stage-extension/N/B-language B "Disjunction N B")
(define-embedding J-disjunction->search/Big/N disjunction:disjunction/stage-extension/N/Big-language Big "Disjunction N Big")
