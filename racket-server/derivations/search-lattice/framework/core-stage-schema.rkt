#lang racket

(require "./core-source-schema.rkt"
         (only-in "./stage-generators.rkt"
                  define-derivation-instance))

(provide define-generated-core-stage-instance)

;; This is the only selected-source bridge into the checkpointed horizontal
;; transformer.  Its public invocation names a source interface, not a single
;; carrier/environment slot.  The interface expands the shared rule IR to the
;; legacy descriptor privately, and the existing stage generator remains
;; unchanged.
(define-syntax-rule
  (define-generated-core-stage-instance
    #:source-interface source-interface
    #:instance instance)
  (source-interface
   #:lower-with define-derivation-instance
   #:instance instance))
