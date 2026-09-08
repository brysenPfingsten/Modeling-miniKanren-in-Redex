#lang racket

(require redex/reduction-semantics
         "../languages/delay-lang.rkt"
         (only-in "../languages/core-lang.rkt" owners-append)
         (prefix-in core: "./core-red.rkt")
         "./private/step-utils.rkt")

(provide work/delta/raw
         frontier/delta/raw
         work/delta
         frontier/delta
         work/raw
         frontier/raw
         allocate/base
         work/base
         frontier/base
         delay-red
         step-once)

(check-redundancy #t)

(define work/delta/raw
  (reduction-relation
   delay-lang
   #:domain any
   [--> (Work owners (suspend g tag) σ)
        (PendingDelay owners (Work (Owners) g σ))
        "suspend-goal"]
   [--> (Conj owners_outer
              (PendingDelay owners_delay
                            (in-hole WorkOwnerSlot_1 owners_payload))
              g)
        (PendingDelay
         owners_outer
         (Conj (Owners)
               (in-hole WorkOwnerSlot_1
                        owners_attached)
               g))
        (where owners_attached
               (owners-append owners_delay owners_payload))
        "bubble-delay-through-conj"]))

(define frontier/delta/raw
  (reduction-relation
   delay-lang
   #:domain any
   [--> (More (PendingDelay owners W))
        (Forced owners (More W))
        "force-delay"]))

(define work/raw
  (union-reduction-relations
   (extend-reduction-relation core:work/raw delay-lang)
   work/delta/raw))

(define frontier/raw
  (union-reduction-relations
   (extend-reduction-relation core:frontier/raw delay-lang)
   frontier/delta/raw))

(define allocate/base
  (extend-reduction-relation core:allocate/base delay-lang))

(define work/delta
  (context-closure work/delta/raw delay-lang WorkFocus))

(define frontier/delta
  (context-closure frontier/delta/raw delay-lang SpineContext))

(define work/base
  (context-closure work/raw delay-lang WorkFocus))

(define frontier/base
  (context-closure frontier/raw delay-lang SpineContext))

(define delay-red
  (extend-reduction-relation
   (union-reduction-relations work/base frontier/base allocate/base)
   delay-lang
   #:domain F))

(define (step-once prog)
  (step-once/deterministic delay-red prog))
