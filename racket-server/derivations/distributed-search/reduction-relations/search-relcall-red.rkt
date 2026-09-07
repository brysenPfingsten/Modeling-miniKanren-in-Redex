#lang racket

(require redex/reduction-semantics
         "../languages/search-relcall-lang.rkt"
         "../../../src/search-lattice/reduction-relations/private/common.rkt"
         "../../../src/search-lattice/reduction-relations/private/context-pipeline.rkt"
         "../../../src/search-lattice/reduction-relations/private/step-utils.rkt"
         "./search-red.rkt")

(provide search-distributed-relcall-expand/raw
         search-distributed-relcall-red
         step-once)

(check-redundancy #t)

(define-lift-search-to-relcall under-Gamma
  search-distributed-red
  distributed-search-relcall-lang)

(define search-distributed-relcall-expand/raw
  (reduction-relation
   distributed-search-relcall-lang
   #:domain any
   [--> (Γ (in-hole EarlyWF (Work owners (r t ... tag) σ)))
        (Γ (in-hole EarlyWF (Work owners g_new σ)))
        (where g_new
               ,(instantiate-call-host (term Γ) (term r) (term (t ...))))
        "expand-relcall"]))

(define search-distributed-relcall-red
  (extend-reduction-relation
   (union-reduction-relations under-Gamma
                              search-distributed-relcall-expand/raw)
   distributed-search-relcall-lang
   #:domain config))

(define (step-once prog)
  (step-once/deterministic search-distributed-relcall-red prog))
