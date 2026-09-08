#lang racket

(require redex/reduction-semantics
         "../languages/search-lang.rkt"
         (prefix-in delay: "./delay-red.rkt")
         (prefix-in disj: "./disj-red.rkt")
         "./private/step-utils.rkt")

(provide search-red
         step-once)

(check-redundancy #t)

(define search-red
  (extend-reduction-relation
   (union-reduction-relations
    (extend-reduction-relation disj:disj-red search-lang)
    (context-closure
     (extend-reduction-relation delay:work/delta/raw search-lang)
     search-lang
     WorkFocus)
    (context-closure
     (extend-reduction-relation delay:frontier/delta/raw search-lang)
     search-lang
     SpineContext))
   search-lang
   #:domain F))

(define (step-once prog)
  (step-once/deterministic search-red prog))
