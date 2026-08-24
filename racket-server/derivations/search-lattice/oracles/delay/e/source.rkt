#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "../private/shared.rkt"
         (prefix-in core: "../../core/e/source.rkt"))

(provide subst-goal/delay/e
         work/raw/delay/e
         frontier/raw/delay/e
         allocate/raw/delay/e
         allocate/base/delay/e
         work/base/delay/e
         frontier/base/delay/e
         delay-e-oracle-red
         raw-successors/delay/e
         trace/delay/e)

(check-redundancy #t)

(define (subst-goal/delay/e goal substitution)
  (substitute-goal/delay
   goal
   substitution
   core:subst-term/lexical/e
   'subst-goal/delay/e))

;; Ownerless E wrappers are direct source equations, not decoded S terms.
(define work/raw/delay/e
  (extend-reduction-relation
   core:work/raw/e
   delay-e-oracle-lang
   #:domain any
   [--> (Work (suspend g tag) σ)
        (PendingDelay (Work g σ))
        "suspend-goal"]
   [--> (Conj (PendingDelay W) g)
        (PendingDelay (Conj W g))
        "bubble-delay-through-conj"]))

(define frontier/raw/delay/e
  (extend-reduction-relation
   core:frontier/raw/e
   delay-e-oracle-lang
   #:domain any
   [--> (More (PendingDelay W))
        (Forced (More W))
        "force-delay"]))

(core:define-allocation/e
  allocate/raw/delay/e
  allocate/base/delay/e
  delay-e-oracle-lang
  subst-goal/delay/e)

(define work/base/delay/e
  (context-closure work/raw/delay/e delay-e-oracle-lang WorkFocus))

(define frontier/base/delay/e
  (context-closure frontier/raw/delay/e delay-e-oracle-lang SpineContext))

(define delay-e-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/delay/e
    frontier/base/delay/e
    allocate/base/delay/e)
   delay-e-oracle-lang
   #:domain F))

(define (raw-successors/delay/e frontier)
  (raw-named-successors delay-e-oracle-red frontier))

(define (trace/delay/e frontier [fuel 64])
  (finite-named-trace delay-e-oracle-red frontier fuel))
