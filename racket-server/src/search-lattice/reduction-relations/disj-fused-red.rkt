#lang racket

(require redex/reduction-semantics
         "../languages/disj-fused-lang.rkt"
         "./disj-base-red.rkt"
         "./private/step-utils.rkt")

(provide disj-fused-local/under-QShell
         disj-fused-red
         step-once)

(check-redundancy #t)

(define disj-fused-local/base
  (reduction-relation
   disj-fused-lang
   #:domain cfg
   [--> (in-hole KLate (((in-hole QFresh (⊤ σ_new)) <-+ search_rest) × g c))
        (in-hole KLate ((in-hole QFresh (g σ_new)) <-+ (search_rest × g c)))
        "disj-fused/continue-left-answer"]
   [--> (in-hole KLate (((empty-tree) <-+ search_rest) × g c))
        (in-hole KLate (search_rest × g c))
        "disj-fused/continue-left-fail"]))

(define disj-fused-local/under-QShell
  (context-closure disj-fused-local/base disj-fused-lang QShell))

(define lifted-disj-core-local/base
  (extend-reduction-relation disj-core-local/base disj-fused-lang))

(define lifted-disj-goal-local/base
  (extend-reduction-relation disj-goal-local/base disj-fused-lang))

(define lifted-disj-frontier/local-base
  (extend-reduction-relation disj-frontier/local-base disj-fused-lang))

(define disj-core-local/under-late
  (context-closure lifted-disj-core-local/base disj-fused-lang KLate))

(define disj-goal-local/under-late
  (context-closure lifted-disj-goal-local/base disj-fused-lang KLate))

(define disj-base-core
  (context-closure disj-core-local/under-late disj-fused-lang QShell))

(define disj-goal-local/under-QShell
  (context-closure disj-goal-local/under-late disj-fused-lang QShell))

(define disj-frontier/base
  (context-closure lifted-disj-frontier/local-base disj-fused-lang QShell))

(define disj-fused-red
  (union-reduction-relations
   disj-base-core
   disj-goal-local/under-QShell
   disj-frontier/base
   disj-fused-local/under-QShell
   ))

(define (step-once prog)
  (step-once/deterministic disj-fused-red prog))
