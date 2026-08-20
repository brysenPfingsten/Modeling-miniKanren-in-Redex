#lang racket

(require redex/reduction-semantics
         "../languages/search-lang.rkt"
         (only-in "../../../languages/core-lang.rkt" owners-append)
         "../../../reduction-relations/private/step-utils.rkt"
         (prefix-in rail: "../../../reduction-relations/rail-red.rkt")
         (prefix-in distributed-base: "./search-join-base-red.rkt")
         (prefix-in search-base:
                    "../../../reduction-relations/search-join-base-red.rkt")
         (prefix-in disj: "./disj-red.rkt")
         (prefix-in search: "./search-red.rkt"))

(provide rail-distributed-red
         step-once)

(check-redundancy #t)

(define inherited-work
  (context-closure
   (extend-reduction-relation search-base:work/nonchoice/raw
                              distributed-search-lang)
   distributed-search-lang
   EarlyWF))

(define inherited-choice
  (context-closure
   (extend-reduction-relation search-base:work/choice/raw
                              distributed-search-lang)
   distributed-search-lang
   EarlyChoiceWF))

(define right-structural
  (context-closure
   (extend-reduction-relation distributed-base:right-active/work/raw
                              distributed-search-lang)
   distributed-search-lang
   EarlyChoiceWF))

(define inherited-frontier
  (context-closure
   (extend-reduction-relation search-base:frontier/raw
                              distributed-search-lang)
   distributed-search-lang
   SpineContext))

(define right-frontier
  (context-closure
   (extend-reduction-relation distributed-base:right-active/frontier/raw
                              distributed-search-lang)
   distributed-search-lang
   SpineContext))

(define allocate
  (extend-reduction-relation disj:allocate/base distributed-search-lang))

(define distribute-choice
  (context-closure
   (extend-reduction-relation search:distribute-choice/raw
                              distributed-search-lang)
   distributed-search-lang
   EarlyWF))

(define distribute-right
  (let ([raw
         (reduction-relation
          distributed-search-lang
          #:domain any
          [--> (Conj owners_conj (DisjR owners_choice W_1 W_2) g)
               (DisjR (owners-append owners_conj owners_choice)
                      (Conj (Owners) W_1 g)
                      (Conj (Owners) W_2 g))
               "distribute-right-choice"])])
    (context-closure raw distributed-search-lang EarlyWF)))

(define schedule
  (context-closure
   (extend-reduction-relation rail:rail-scheduler/raw distributed-search-lang)
   distributed-search-lang
   EarlyChoiceWF))

(define rail-distributed-red
  (extend-reduction-relation
   (union-reduction-relations
    inherited-work
    inherited-choice
    right-structural
    inherited-frontier
    right-frontier
    allocate
    distribute-choice
    distribute-right
    schedule)
   distributed-search-lang
   #:domain F))

(define (step-once prog)
  (step-once/deterministic rail-distributed-red prog))
