#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "../private/shared.rkt"
         (prefix-in core: "../../core/n/source.rkt"))

(provide subst-goal/search/n
         work/delta/delay/search/n
         work/delta/disjunction/search/n
         frontier/delta/delay/search/n
         frontier/delta/disjunction/search/n
         allocate/raw/search/n
         allocate/base/search/n
         work/base/search/n
         frontier/base/search/n
         search-n-oracle-red
         search-n-oracle-red/disjunction-first
         raw-successors/search/n
         raw-successors/search/n/disjunction-first
         trace/search/n)

(check-redundancy #t)

(define (lexical-variable?/n datum)
  (and (symbol? datum)
       (regexp-match? #rx"^x:" (symbol->string datum))))

(define (subst-term/search/n term bindings)
  (match term
    [(? lexical-variable?/n x)
     (match (assoc x bindings)
       [(list _ level) level]
       [#f x])]
    [`(,left : ,right)
     `(,(subst-term/search/n left bindings)
       :
       ,(subst-term/search/n right bindings))]
    [_ term]))

(define-metafunction search-n-oracle-lang
  subst-goal/search/n : g alloc -> g
  [(subst-goal/search/n g ((x lv) ...))
   ,(substitute-goal/search
     (term g)
     (term ((x lv) ...))
     subst-term/search/n
     'subst-goal/search/n)])

(define work/delta/delay/search/n
  (reduction-relation
   search-n-oracle-lang
   #:domain any
   [--> (Work (suspend g tag) σ)
        (PendingDelay (Work g σ))
        "suspend-goal"]
   [--> (Conj (PendingDelay W) g)
        (PendingDelay (Conj W g))
        "bubble-delay-through-conj"]))

(define frontier/delta/delay/search/n
  (reduction-relation
   search-n-oracle-lang
   #:domain any
   [--> (More (PendingDelay W))
        (Forced (More W))
        "force-delay"]))

(define work/delta/disjunction/search/n
  (reduction-relation
   search-n-oracle-lang
   #:domain any

   [--> (Work (g_1 ∨ g_2 tag) σ)
        (DisjL (Work g_1 σ)
               (Work g_2 σ))
        "expand-disjunction"]

   [--> (DisjL (Dead next) W)
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

(define frontier/delta/disjunction/search/n
  (reduction-relation
   search-n-oracle-lang
   #:domain any
   [--> (More (DisjL (Returned σ) W))
        (Emit (Answer σ) (More W))
        "commit-choice-answer"]))

(define work/raw/core/search/n
  (extend-reduction-relation
   core:work/raw/n
   search-n-oracle-lang
   #:domain any))

(define frontier/raw/core/search/n
  (extend-reduction-relation
   core:frontier/raw/n
   search-n-oracle-lang
   #:domain any))

(define work/raw/search/n
  (union-reduction-relations
   work/raw/core/search/n
   work/delta/delay/search/n
   work/delta/disjunction/search/n))

(define work/raw/search/n/disjunction-first
  (union-reduction-relations
   work/raw/core/search/n
   work/delta/disjunction/search/n
   work/delta/delay/search/n))

(define frontier/raw/search/n
  (union-reduction-relations
   frontier/raw/core/search/n
   frontier/delta/delay/search/n
   frontier/delta/disjunction/search/n))

(define frontier/raw/search/n/disjunction-first
  (union-reduction-relations
   frontier/raw/core/search/n
   frontier/delta/disjunction/search/n
   frontier/delta/delay/search/n))

(core:define-allocation/n
  allocate/raw/search/n
  allocate/base/search/n
  search-n-oracle-lang
  subst-goal/search/n)

(define work/base/search/n
  (context-closure work/raw/search/n search-n-oracle-lang WorkFocus))

(define work/base/search/n/disjunction-first
  (context-closure
   work/raw/search/n/disjunction-first
   search-n-oracle-lang
   WorkFocus))

(define frontier/base/search/n
  (context-closure frontier/raw/search/n search-n-oracle-lang SpineContext))

(define frontier/base/search/n/disjunction-first
  (context-closure
   frontier/raw/search/n/disjunction-first
   search-n-oracle-lang
   SpineContext))

(define search-n-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/search/n
    frontier/base/search/n
    allocate/base/search/n)
   search-n-oracle-lang
   #:domain F))

(define search-n-oracle-red/disjunction-first
  (extend-reduction-relation
   (union-reduction-relations
    work/base/search/n/disjunction-first
    frontier/base/search/n/disjunction-first
    allocate/base/search/n)
   search-n-oracle-lang
   #:domain F))

(define (raw-successors/search/n frontier)
  (raw-named-successors search-n-oracle-red frontier))

(define (raw-successors/search/n/disjunction-first frontier)
  (raw-named-successors search-n-oracle-red/disjunction-first frontier))

(define (trace/search/n frontier [fuel 64])
  (finite-named-trace search-n-oracle-red frontier fuel))
