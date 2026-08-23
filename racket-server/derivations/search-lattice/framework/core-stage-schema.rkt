#lang racket

(require "./core-source-schema.rkt"
         "./core-stage-renderers.rkt")

(provide define-generated-core-stage-instance
         define-selected-compression-policy
         define-selected-decomposition-stage
         define-selected-refocused-stage
         define-selected-machine-isomorphism-stage
         define-selected-compressed-stage
         define-selected-fixed-point-stage
         define-selected-staged-row
         define-selected-stage-extension
         apply-selected-stage-extension
         define-decomposition-representation-map
         define-refocused-representation-map
         define-machine-representation-map
         define-compressed-representation-map
         define-fixed-point-representation-map)

(module test-support racket
  (require (submod "./core-stage-renderers.rkt" test-support))
  (provide assert-selected-staged-row-metadata))

;; The source interface retains the selected representation views and the one
;; shared rule inventory.  Instantiation feeds those views directly to the
;; selected renderer; there is no intermediate source-shaped adapter.
(define-syntax-rule
  (define-generated-core-stage-instance
    #:source-interface source-interface
    #:instance instance)
  (source-interface
   #:instantiate-with define-selected-core-instance
   #:instance instance))
