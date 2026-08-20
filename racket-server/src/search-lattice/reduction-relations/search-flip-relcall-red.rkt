#lang racket

(require redex/reduction-semantics
         "../languages/search-relcall-lang.rkt"
         (only-in "./search-flip-red.rkt"
                  search-flip-extra)
         "./search-relcall-red.rkt"
         "./private/context-pipeline.rkt"
         "./private/step-utils.rkt"
         )

(provide search-flip-relcall-red
         step-once)

(check-redundancy #t)

(define-lift-search-to-relcall under-Gamma
  search-flip-extra
  search-relcall-lang)

(define search-flip-relcall-red
  (extend-reduction-relation
   (union-reduction-relations search-relcall-red under-Gamma)
   search-relcall-lang
   #:domain config))

(define (step-once prog)
  (step-once/deterministic search-flip-relcall-red prog))
