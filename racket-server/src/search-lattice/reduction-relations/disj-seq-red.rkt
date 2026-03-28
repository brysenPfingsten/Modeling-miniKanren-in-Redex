#lang racket

(require redex/reduction-semantics
         "../languages/disj-lang.rkt"
         "./disj-base-red.rkt"
         "./private/step-utils.rkt")

(provide disj-seq-local/under-QSpine
         disj-seq-red
         step-once)

(check-redundancy #t)

(define disj-seq-local/base
  (reduction-relation
   disj-lang
   #:domain cfg
   [--> (in-hole KBranch (in-hole KWork ((search_1 <-+ search_2) × g c)))
        (in-hole KBranch (in-hole KWork ((search_1 × g c) <-+ (search_2 × g c))))
        "disj-seq/distribute-over-conj"]))

(define disj-seq-local/under-QSpine
  (context-closure disj-seq-local/base disj-lang QSpine))

(define disj-seq-red
  (union-reduction-relations
   disj-base-core
   disj-goal-local/under-QSpine
   disj-frontier/base
   disj-seq-local/under-QSpine
   ))

(define (step-once prog)
  (step-once/deterministic disj-seq-red prog))
