#lang racket

(require redex/reduction-semantics
         "../languages/search-relcall-lang.rkt"
         (only-in "./search-dfs-red.rkt"
                  search-dfs-extra)
         "./search-relcall-red.rkt"
         "./private/context-pipeline.rkt"
         "./private/step-utils.rkt"
         )

(provide search-dfs-relcall-red
         step-once)

(check-redundancy #t)

(define-lift-search-to-relcall under-Gamma
  search-dfs-extra
  search-relcall-lang)

(define search-dfs-relcall-red
  (extend-reduction-relation
   (union-reduction-relations search-relcall-red under-Gamma)
   search-relcall-lang
   #:domain config))

(define (step-once prog)
  (step-once/deterministic search-dfs-relcall-red prog))
