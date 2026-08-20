#lang racket

(require redex/reduction-semantics
         "../languages/search-lang.rkt"
         (only-in "../languages/core-lang.rkt" owners-append)
         "./private/step-utils.rkt"
         "./search-red.rkt")

(provide search-flip-extra
         search-flip-red
         step-once)

(check-redundancy #t)

(define search-flip-extra
  (let ([raw
         (reduction-relation
          search-lang
          #:domain any
          [--> (DisjL owners_choice
                       (PendingDelay
                        owners_delay
                        (in-hole WorkOwnerSlot_1 owners_payload))
                       W_2)
               (PendingDelay
                (Owners)
                (DisjL owners_choice
                       W_2
                       (in-hole WorkOwnerSlot_1
                                owners_delayed)))
               (where owners_delayed
                      (owners-append owners_delay owners_payload))
               "flip-delay-left"])])
    (context-closure raw search-lang WorkFocus)))

(define search-flip-red
  (extend-reduction-relation
   (union-reduction-relations search-red search-flip-extra)
   search-lang
   #:domain F))

(define (step-once prog)
  (step-once/deterministic search-flip-red prog))
