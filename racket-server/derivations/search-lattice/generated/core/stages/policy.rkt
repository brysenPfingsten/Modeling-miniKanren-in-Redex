#lang racket

(require "../../../framework/core-stage-schema.rkt")

(provide generated-core-compression-policy)

;; Compression is representation-neutral.  A producer may fuse with its one
;; structural follower; allocation and all other structural transitions are
;; retained as singleton observations.
(define-selected-compression-policy generated-core-compression-policy
  #:settled-producers
  (succeed
   unify-success
   disequality-success)
  #:dead-producers
  (fail
   unify-violates-disequality
   unify-fail
   disequality-fail)
  #:settled-followers
  (conj-return
   finish-success)
  #:dead-followers
  (conj-fail
   finish-failure)
  #:singletons
  (expand-conjunction
   allocate-fresh
   conj-return
   conj-fail
   finish-success
   finish-failure)
  #:retained-observation rule-labels
  #:maximum-span 2)
