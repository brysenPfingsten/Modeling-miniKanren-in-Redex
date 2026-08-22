#lang racket

(require "../../../framework/core-source-schema.rkt"
         "./s.rkt"
         "./e.rkt"
         "./n.rkt")

(provide Q-SE/generated
         Q-EN/generated
         Q-SN/generated
         Q-SN-composition/generated?)

;; These maps are emitted from the three selected strategy descriptors.  The
;; direct S-to-N map consumes S's neutral export and N's rebuild hook; it does
;; not call either adjacent map or route through E.
(define-generated-core-representation-maps
  #:s-strategy core-s-representation-strategy
  #:e-strategy core-e-representation-strategy
  #:n-strategy core-n-representation-strategy
  #:Q-SE Q-SE/generated
  #:Q-EN Q-EN/generated
  #:Q-SN Q-SN/generated
  #:composition Q-SN-composition/generated?)
