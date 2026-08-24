#lang racket

(require "../../../../framework/core-stage-schema.rkt"
         "../../../../framework/delay-schema.rkt"
         "../../../../framework/disjunction-schema.rkt"
         "../../../../framework/search-join-schema.rkt"
         "../../source/feature-order/s.rkt"
         (prefix-in delay-source: "../../../delay/source/s.rkt")
         (prefix-in core: "../../../core/stages/s.rkt"))

(provide search/reverse-delay-stage-extension/S
         search/reverse-delay-staged-row/S
         search/reverse-disjunction-stage-extension/S
         search/reverse-children-staged-row/S
         search/reverse-join-stage-extension/S
         search/reverse-staged-row/S)

(define-generated-delay-stage-extension search/reverse-delay-stage-extension/S
  #:source delay-source:generated-delay-s-source
  #:dependencies-from generated-search-reverse-s-source)

(apply-selected-stage-extension search/reverse-delay-staged-row/S
  #:extension search/reverse-delay-stage-extension/S
  #:base core:core/staged-row/S)

(define-generated-disjunction-stage-extension
  search/reverse-disjunction-stage-extension/S
  #:source generated-search-reverse-s-child-source
  #:dependencies-from generated-search-reverse-s-source)

(apply-selected-stage-extension search/reverse-children-staged-row/S
  #:extension search/reverse-disjunction-stage-extension/S
  #:base search/reverse-delay-staged-row/S)

(define-generated-search-join-stage-extension
  search/reverse-join-stage-extension/S
  #:source generated-search-reverse-s-source)

(apply-selected-stage-extension search/reverse-staged-row/S
  #:extension search/reverse-join-stage-extension/S
  #:base search/reverse-children-staged-row/S)
