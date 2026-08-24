#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "../private/shared.rkt"
         (only-in "../../core/s/language.rkt" owners-append/s)
         (prefix-in core: "../../core/s/source.rkt"))

(provide subst-goal/delay/s
         work-focus-prefix-support/delay/s
         work/raw/delay/s
         frontier/raw/delay/s
         allocate/base/delay/s
         work/base/delay/s
         frontier/base/delay/s
         delay-s-oracle-red
         raw-successors/delay/s
         trace/delay/s)

(check-redundancy #t)

(define (subst-goal/delay/s goal substitutions)
  (substitute-goal/delay
   goal
   substitutions
   core:subst-term/s
   'subst-goal/delay/s))

;; Delay extends the unique active-world prefix with Forced spine owners.  All
;; core WorkFocus shapes remain owned by the core view; no allocation equation
;; is repeated here.
(define (work-focus-prefix-support/delay/s work-focus [support '()])
  (match work-focus
    [`(Forced ,owners ,spine-context)
     (work-focus-prefix-support/delay/s
      spine-context
      (core:extend-support-with-owners/s owners support))]
    [_
     (core:work-focus-prefix-support/s work-focus support)]))

;; These are the three direct Delay equations for the Owner carrier.  The
;; inherited ten work and two frontier equations remain the independently
;; stated core S oracle equations.
(define work/raw/delay/s
  (extend-reduction-relation
   core:work/raw/s
   delay-s-oracle-lang
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
               (in-hole WorkOwnerSlot_1 owners_attached)
               g))
        (where owners_attached
               (owners-append/s owners_delay owners_payload))
        "bubble-delay-through-conj"]))

(define frontier/raw/delay/s
  (extend-reduction-relation
   core:frontier/raw/s
   delay-s-oracle-lang
   #:domain any
   [--> (More (PendingDelay owners W))
        (Forced owners (More W))
        "force-delay"]))

;; The core allocation equation is instantiated, not copied.  Delay supplies
;; only its recursive goal traversal and its extended WorkFocus-prefix view.
(core:define-allocation/base/s
  allocate/base/delay/s
  delay-s-oracle-lang
  subst-goal/delay/s
  work-focus-prefix-support/delay/s)

(define work/base/delay/s
  (context-closure work/raw/delay/s delay-s-oracle-lang WorkFocus))

(define frontier/base/delay/s
  (context-closure frontier/raw/delay/s delay-s-oracle-lang SpineContext))

(define delay-s-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/delay/s
    frontier/base/delay/s
    allocate/base/delay/s)
   delay-s-oracle-lang
   #:domain F))

(define (raw-successors/delay/s frontier)
  (raw-named-successors delay-s-oracle-red frontier))

(define (trace/delay/s frontier [fuel 64])
  (finite-named-trace delay-s-oracle-red frontier fuel))
