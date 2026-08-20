#lang racket

(require redex/reduction-semantics
         "../languages/search-relcall-lang.rkt"
         "./private/common.rkt"
         "./private/context-pipeline.rkt"
         "./private/step-utils.rkt"
         "./search-red.rkt")

(provide search-relcall-expand/raw
         search-relcall-red
         step-once)

(check-redundancy #t)

(define-lift-search-to-relcall under-Gamma
  search-red
  search-relcall-lang)

(define search-relcall-expand/raw
  (reduction-relation
   search-relcall-lang
   #:domain any
   [--> (Γ (in-hole WorkFocus (Work owners (r t ... tag) σ)))
        (Γ (in-hole WorkFocus (Work owners g_new σ)))
        (where g_new
               ,(instantiate-call-host (term Γ) (term r) (term (t ...))))
        "expand-relcall"]))

(define search-relcall-red
  (extend-reduction-relation
   (union-reduction-relations under-Gamma search-relcall-expand/raw)
   search-relcall-lang
   #:domain config))

(define (step-once prog)
  (step-once/deterministic search-relcall-red prog))
