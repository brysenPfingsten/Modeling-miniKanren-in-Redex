#lang racket

(require redex/reduction-semantics
         "../languages/search-relcall-lang.rkt"
         "../../../reduction-relations/private/context-pipeline.rkt"
         "../../../reduction-relations/private/step-utils.rkt"
         (prefix-in rail: "./rail-red.rkt")
         (only-in "./search-relcall-red.rkt"
                  search-distributed-relcall-expand/raw))

(provide rail-distributed-relcall-red
         step-once)

(check-redundancy #t)

(define-lift-search-to-relcall under-Gamma
  rail:rail-distributed-red
  distributed-search-relcall-lang)

(define rail-distributed-relcall-red
  (extend-reduction-relation
   (union-reduction-relations
    under-Gamma
    (extend-reduction-relation search-distributed-relcall-expand/raw
                               distributed-search-relcall-lang))
   distributed-search-relcall-lang
   #:domain config))

(define (step-once prog)
  (step-once/deterministic rail-distributed-relcall-red prog))
