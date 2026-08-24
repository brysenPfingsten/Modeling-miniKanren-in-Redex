#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "../private/shared.rkt"
         (prefix-in core: "../../core/e/source.rkt"))

(provide subst-goal/disjunction/e
         work/raw/disjunction/e
         frontier/raw/disjunction/e
         allocate/raw/disjunction/e
         allocate/base/disjunction/e
         work/base/disjunction/e
         frontier/base/disjunction/e
         disjunction-e-oracle-red
         raw-successors/disjunction/e
         trace/disjunction/e)

(check-redundancy #t)

(define (subst-goal/disjunction/e goal substitution)
  (substitute-goal/disjunction
   goal
   substitution
   core:subst-term/lexical/e
   'subst-goal/disjunction/e))

;; E states each branch independently and copies the complete incoming state
;; at choice creation.  Choice and Emit themselves are ownerless.
(define work/raw/disjunction/e
  (extend-reduction-relation
   core:work/raw/e
   disjunction-e-oracle-lang
   #:domain any

   [--> (Work (g_1 ∨ g_2 tag) σ)
        (DisjL (Work g_1 σ)
               (Work g_2 σ))
        "expand-disjunction"]

   [--> (DisjL (Dead support) W)
        W
        "skip-left-failure"]

   [--> (DisjL (DisjL (Returned σ) W_left) W_right)
        (DisjL (Returned σ)
               (DisjL W_left W_right))
        "reassociate-left-result"]

   [--> (Conj (DisjL (Returned σ) W) g)
        (DisjL (Work g σ)
               (Conj W g))
        "resume-left-choice-success"]))

(define frontier/raw/disjunction/e
  (extend-reduction-relation
   core:frontier/raw/e
   disjunction-e-oracle-lang
   #:domain any

   [--> (More (DisjL (Returned σ) W))
        (Emit (Answer σ) (More W))
        "commit-choice-answer"]))

(core:define-allocation/e
  allocate/raw/disjunction/e
  allocate/base/disjunction/e
  disjunction-e-oracle-lang
  subst-goal/disjunction/e)

(define work/base/disjunction/e
  (context-closure
   work/raw/disjunction/e
   disjunction-e-oracle-lang
   WorkFocus))

(define frontier/base/disjunction/e
  (context-closure
   frontier/raw/disjunction/e
   disjunction-e-oracle-lang
   SpineContext))

(define disjunction-e-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/disjunction/e
    frontier/base/disjunction/e
    allocate/base/disjunction/e)
   disjunction-e-oracle-lang
   #:domain F))

(define (raw-successors/disjunction/e frontier)
  (raw-named-successors disjunction-e-oracle-red frontier))

(define (trace/disjunction/e frontier [fuel 64])
  (finite-named-trace disjunction-e-oracle-red frontier fuel))
