#lang racket

(require redex/reduction-semantics
         "../languages/search-base-seq-calls-lang.rkt"
         "./private/common.rkt"
         "./private/context-pipeline.rkt"
         "./private/step-utils.rkt"
         "./search-base-seq-red.rkt")

(provide search-base-seq-calls-red
         step-once)

(check-redundancy #t)

(define-lift-search-to-calls lifted-search-base-seq-red
  (extend-reduction-relation search-base-seq-red search-base-seq-calls-lang)
  search-base-seq-calls-lang)

(define calls-expand/raw
  (reduction-relation
   search-base-seq-calls-lang
   #:domain config
   [--> (Γ (in-hole Q (in-hole KBranch (in-hole KBase ((r t ... tag) σ)))))
        (Γ (in-hole Q (in-hole KBranch (in-hole KBase (g_new σ)))))
        (where g_new
               ,(instantiate-call-host (term Γ) (term r) (term (t ...))))
        "search-base-seq-calls/expand"]))

(define calls-extra calls-expand/raw)

(define search-base-seq-calls-red
  (union-reduction-relations
   lifted-search-base-seq-red
   calls-extra))

(define (step-once prog)
  (step-once/deterministic search-base-seq-calls-red prog))
