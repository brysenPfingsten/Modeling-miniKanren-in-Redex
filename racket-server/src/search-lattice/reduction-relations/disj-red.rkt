#lang racket

(require redex/reduction-semantics
         "../languages/disj-lang.rkt"
         (only-in "../languages/core-lang.rkt" owners-append)
         (prefix-in disj: "./disj-base-red.rkt")
         "./private/step-utils.rkt")

(provide disj-red
         step-once)

(check-redundancy #t)

(define resume-choice-success
  (let ([raw
         (reduction-relation
          disj-lang
          #:domain any
          [--> (Conj owners_conj
                     (DisjL owners_choice
                            (Returned owners_answer σ)
                            W)
                     g)
               (DisjL (owners-append owners_conj owners_choice)
                      (Work owners_answer g σ)
                      (Conj (Owners) W g))
               "resume-left-choice-success"])])
    (context-closure raw disj-lang WorkFocus)))

(define disj-red
  (extend-reduction-relation
   (union-reduction-relations
    disj:work/base
    disj:frontier/base
    disj:allocate/base
    resume-choice-success)
   disj-lang
   #:domain F))

(define (step-once prog)
  (step-once/deterministic disj-red prog))
