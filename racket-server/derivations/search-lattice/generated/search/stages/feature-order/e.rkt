#lang racket

(require "../../../../framework/core-stage-schema.rkt"
         "../../../../framework/delay-schema.rkt"
         "../../../../framework/disjunction-schema.rkt"
         "../../../../framework/search-join-schema.rkt"
         "../../source/feature-order/e.rkt"
         (prefix-in delay-source: "../../../delay/source/e.rkt")
         (prefix-in core: "../../../core/stages/e.rkt"))

(provide search/reverse-delay-stage-extension/E
         search/reverse-delay-staged-row/E
         search/reverse-disjunction-stage-extension/E
         search/reverse-children-staged-row/E
         search/reverse-join-stage-extension/E
         search/reverse-staged-row/E)

(define-generated-delay-stage-extension search/reverse-delay-stage-extension/E
  #:source delay-source:generated-delay-e-source
  #:dependencies-from generated-search-reverse-e-source)

(apply-selected-stage-extension search/reverse-delay-staged-row/E
  #:extension search/reverse-delay-stage-extension/E
  #:base core:core/staged-row/E)

(define-generated-disjunction-stage-extension
  search/reverse-disjunction-stage-extension/E
  #:source generated-search-reverse-e-child-source
  #:dependencies-from generated-search-reverse-e-source)

(apply-selected-stage-extension search/reverse-children-staged-row/E
  #:extension search/reverse-disjunction-stage-extension/E
  #:base search/reverse-delay-staged-row/E)

(define-generated-search-join-stage-extension
  search/reverse-join-stage-extension/E
  #:source generated-search-reverse-e-source)

(apply-selected-stage-extension search/reverse-staged-row/E
  #:extension search/reverse-join-stage-extension/E
  #:base search/reverse-children-staged-row/E)
