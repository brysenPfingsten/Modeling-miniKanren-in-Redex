#lang racket

(require redex/reduction-semantics
         "../languages/disj-lang.rkt"
         (only-in "../../../src/search-lattice/languages/core-lang.rkt" owners-append)
         (prefix-in disj: "../../../src/search-lattice/reduction-relations/disj-base-red.rkt")
         (only-in "../../../src/search-lattice/reduction-relations/private/common.rkt"
                  subst-goal-host)
         "../../../src/search-lattice/reduction-relations/private/step-utils.rkt")

(provide allocate/base
         disj-distributed-red
         step-once)

(check-redundancy #t)

(define distribute-choice
  (let ([raw
         (reduction-relation
          distributed-disj-lang
          #:domain any
          [--> (Conj owners_conj (DisjL owners_choice W_1 W_2) g)
               (DisjL (owners-append owners_conj owners_choice)
                      (Conj (Owners) W_1 g)
                      (Conj (Owners) W_2 g))
               "distribute-choice"])])
    (context-closure raw distributed-disj-lang EarlyWF)))

;; The distributed presentation retains its stricter EarlyWF allocation
;; focus. F_support still names the complete live frontier used for freshness.
(define allocate/base
  (reduction-relation
   distributed-disj-lang
   #:domain F
   [--> (name F_support
              (in-hole EarlyWF
                       (Work owners (∃ (x_bound ...) g tag) σ)))
        (in-hole EarlyWF
                 (Work (owners-append
                        owners
                        (Owners (Owner (u_new ...) tag)))
                       g_new
                       σ))
        (where (u_new ...)
               ,(variables-not-in
                 (term F_support)
                 (make-list (length (term (x_bound ...))) 'u:0)))
        (where g_new
               ,(subst-goal-host (term g)
                                 (term ((x_bound u_new) ...))))
        "allocate-fresh"]))

(define disj-distributed-red
  (extend-reduction-relation
   (union-reduction-relations
    (context-closure disj:work/nonchoice/raw distributed-disj-lang EarlyWF)
    (context-closure disj:work/choice/delta/raw
                     distributed-disj-lang
                     EarlyChoiceWF)
    (context-closure disj:frontier/raw
                     distributed-disj-lang
                     SpineContext)
    allocate/base
    distribute-choice)
   distributed-disj-lang
   #:domain F))

(define (step-once prog)
  (step-once/deterministic disj-distributed-red prog))
