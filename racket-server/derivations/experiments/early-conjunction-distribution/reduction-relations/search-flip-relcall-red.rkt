#lang racket

(require redex/reduction-semantics
         "../languages/search-relcall-lang.rkt"
         (only-in "./search-flip-red.rkt"
                  search-flip-distributed-extra)
         "./search-relcall-red.rkt"
         "../../dormant-branch-semantics/source/reduction-relations/private/context-pipeline.rkt"
         "../../dormant-branch-semantics/source/reduction-relations/private/step-utils.rkt"
         )

(provide search-flip-distributed-relcall-red
         step-once)

(check-redundancy #t)

(define-lift-search-to-relcall under-Gamma
  search-flip-distributed-extra
  distributed-search-relcall-lang)

(define search-flip-distributed-relcall-red
  (extend-reduction-relation
   (union-reduction-relations search-distributed-relcall-red under-Gamma)
   distributed-search-relcall-lang
   #:domain config))

(define (step-once prog)
  (step-once/deterministic search-flip-distributed-relcall-red prog))
