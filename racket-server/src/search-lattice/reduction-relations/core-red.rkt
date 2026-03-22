#lang racket

(require redex/reduction-semantics
         "../languages/core-lang.rkt"
         "./private/context-pipeline.rkt"
         "./private/core-common.rkt"
         "./private/step-utils.rkt")

(provide core-red
         step-once)

(check-redundancy #t)

(define core-redex/search (extend-core-redex core-lang))
(define-search-frontier/one-stage core-frontier/search core-redex/search core-lang K)

(define core-red core-frontier/search)

(define (step-once prog)
  (step-once/deterministic core-red prog))
