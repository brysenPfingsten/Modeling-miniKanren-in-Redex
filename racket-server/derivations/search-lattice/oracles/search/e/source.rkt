#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "../private/shared.rkt"
         (prefix-in core: "../../core/e/source.rkt"))

(provide subst-goal/search/e
         work/delta/delay/search/e
         work/delta/disjunction/search/e
         frontier/delta/delay/search/e
         frontier/delta/disjunction/search/e
         allocate/raw/search/e
         allocate/base/search/e
         work/base/search/e
         frontier/base/search/e
         search-e-oracle-red
         search-e-oracle-red/disjunction-first
         raw-successors/search/e
         raw-successors/search/e/disjunction-first
         trace/search/e)

(check-redundancy #t)

(define (subst-goal/search/e goal substitutions)
  (substitute-goal/search
   goal
   substitutions
   core:subst-term/lexical/e
   'subst-goal/search/e))

(define work/delta/delay/search/e
  (reduction-relation
   search-e-oracle-lang
   #:domain any
   [--> (Work (suspend g tag) σ)
        (PendingDelay (Work g σ))
        "suspend-goal"]
   [--> (Conj (PendingDelay W) g)
        (PendingDelay (Conj W g))
        "bubble-delay-through-conj"]))

(define frontier/delta/delay/search/e
  (reduction-relation
   search-e-oracle-lang
   #:domain any
   [--> (More (PendingDelay W))
        (Forced (More W))
        "force-delay"]))

(define work/delta/disjunction/search/e
  (reduction-relation
   search-e-oracle-lang
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

(define frontier/delta/disjunction/search/e
  (reduction-relation
   search-e-oracle-lang
   #:domain any
   [--> (More (DisjL (Returned σ) W))
        (Emit (Answer σ) (More W))
        "commit-choice-answer"]))

(define work/raw/core/search/e
  (extend-reduction-relation
   core:work/raw/e
   search-e-oracle-lang
   #:domain any))

(define frontier/raw/core/search/e
  (extend-reduction-relation
   core:frontier/raw/e
   search-e-oracle-lang
   #:domain any))

(define work/raw/search/e
  (union-reduction-relations
   work/raw/core/search/e
   work/delta/delay/search/e
   work/delta/disjunction/search/e))

(define work/raw/search/e/disjunction-first
  (union-reduction-relations
   work/raw/core/search/e
   work/delta/disjunction/search/e
   work/delta/delay/search/e))

(define frontier/raw/search/e
  (union-reduction-relations
   frontier/raw/core/search/e
   frontier/delta/delay/search/e
   frontier/delta/disjunction/search/e))

(define frontier/raw/search/e/disjunction-first
  (union-reduction-relations
   frontier/raw/core/search/e
   frontier/delta/disjunction/search/e
   frontier/delta/delay/search/e))

(core:define-allocation/e
  allocate/raw/search/e
  allocate/base/search/e
  search-e-oracle-lang
  subst-goal/search/e)

(define work/base/search/e
  (context-closure work/raw/search/e search-e-oracle-lang WorkFocus))

(define work/base/search/e/disjunction-first
  (context-closure
   work/raw/search/e/disjunction-first
   search-e-oracle-lang
   WorkFocus))

(define frontier/base/search/e
  (context-closure frontier/raw/search/e search-e-oracle-lang SpineContext))

(define frontier/base/search/e/disjunction-first
  (context-closure
   frontier/raw/search/e/disjunction-first
   search-e-oracle-lang
   SpineContext))

(define search-e-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/search/e
    frontier/base/search/e
    allocate/base/search/e)
   search-e-oracle-lang
   #:domain F))

(define search-e-oracle-red/disjunction-first
  (extend-reduction-relation
   (union-reduction-relations
    work/base/search/e/disjunction-first
    frontier/base/search/e/disjunction-first
    allocate/base/search/e)
   search-e-oracle-lang
   #:domain F))

(define (raw-successors/search/e frontier)
  (raw-named-successors search-e-oracle-red frontier))

(define (raw-successors/search/e/disjunction-first frontier)
  (raw-named-successors search-e-oracle-red/disjunction-first frontier))

(define (trace/search/e frontier [fuel 64])
  (finite-named-trace search-e-oracle-red frontier fuel))
