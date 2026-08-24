#lang racket

(require "../../../../framework/core-stage-schema.rkt"
         "../../../../framework/delay-schema.rkt"
         "../../../../framework/disjunction-schema.rkt"
         "../../../../framework/search-join-schema.rkt"
         "../../source/feature-order/n.rkt"
         (prefix-in delay-source: "../../../delay/source/n.rkt")
         (prefix-in core: "../../../core/stages/n.rkt"))

(provide search/reverse-delay-stage-extension/N
         search/reverse-delay-staged-row/N
         search/reverse-disjunction-stage-extension/N
         search/reverse-children-staged-row/N
         search/reverse-join-stage-extension/N
         search/reverse-staged-row/N)

(define-generated-delay-stage-extension search/reverse-delay-stage-extension/N
  #:source delay-source:generated-delay-n-source
  #:dependencies-from generated-search-reverse-n-source)

(apply-selected-stage-extension search/reverse-delay-staged-row/N
  #:extension search/reverse-delay-stage-extension/N
  #:base core:core/staged-row/N)

(define-generated-disjunction-stage-extension
  search/reverse-disjunction-stage-extension/N
  #:source generated-search-reverse-n-child-source
  #:dependencies-from generated-search-reverse-n-source)

(apply-selected-stage-extension search/reverse-children-staged-row/N
  #:extension search/reverse-disjunction-stage-extension/N
  #:base search/reverse-delay-staged-row/N)

(define-generated-search-join-stage-extension
  search/reverse-join-stage-extension/N
  #:source generated-search-reverse-n-source)

(apply-selected-stage-extension search/reverse-staged-row/N
  #:extension search/reverse-join-stage-extension/N
  #:base search/reverse-children-staged-row/N)
