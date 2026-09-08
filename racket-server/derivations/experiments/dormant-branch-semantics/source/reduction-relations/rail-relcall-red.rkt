#lang racket

(require redex/reduction-semantics
         "../languages/rail-relcall-lang.rkt"
         "./private/context-pipeline.rkt"
         "./private/step-utils.rkt"
         (prefix-in rail: "./rail-red.rkt")
         (prefix-in search: "./search-relcall-red.rkt"))

(provide rail-relcall-red
         step-once)

(check-redundancy #t)

(define lifted-search-relcall-red
  (extend-reduction-relation
   search:search-relcall-red
   rail-relcall-lang))

(define-lift-search-to-relcall rail-delta/under-Gamma
  rail:rail-delta-red
  rail-relcall-lang)

(define rail-relcall-red
  (extend-reduction-relation
   (union-reduction-relations
    lifted-search-relcall-red
    rail-delta/under-Gamma)
   rail-relcall-lang
   #:domain config))

(define (step-once prog)
  (step-once/deterministic rail-relcall-red prog))
