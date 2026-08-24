#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "../private/shared.rkt"
         (prefix-in core: "../../core/n/source.rkt"))

(provide subst-goal/disjunction/n
         work/raw/disjunction/n
         frontier/raw/disjunction/n
         allocate/raw/disjunction/n
         allocate/base/disjunction/n
         work/base/disjunction/n
         frontier/base/disjunction/n
         disjunction-n-oracle-red
         raw-successors/disjunction/n
         trace/disjunction/n)

(check-redundancy #t)

(define (lexical-variable?/n datum)
  (and (symbol? datum)
       (regexp-match? #rx"^x:" (symbol->string datum))))

(define (subst-term/disjunction/n term bindings)
  (match term
    [(? lexical-variable?/n x)
     (match (assoc x bindings)
       [(list _ level) level]
       [#f x])]
    [`(,left : ,right)
     `(,(subst-term/disjunction/n left bindings)
       :
       ,(subst-term/disjunction/n right bindings))]
    [_ term]))

(define-metafunction disjunction-n-oracle-lang
  subst-goal/disjunction/n : g alloc -> g
  [(subst-goal/disjunction/n g ((x lv) ...))
   ,(substitute-goal/disjunction
     (term g)
     (term ((x lv) ...))
     subst-term/disjunction/n
     'subst-goal/disjunction/n)])

;; Numeric worlds copy the incoming next-bearing state at choice creation;
;; allocations in incomparable siblings therefore reuse the same interval.
(define work/raw/disjunction/n
  (extend-reduction-relation
   core:work/raw/n
   disjunction-n-oracle-lang
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

(define frontier/raw/disjunction/n
  (extend-reduction-relation
   core:frontier/raw/n
   disjunction-n-oracle-lang
   #:domain any

   [--> (More (DisjL (Returned σ) W))
        (Emit (Answer σ) (More W))
        "commit-choice-answer"]))

(core:define-allocation/n
  allocate/raw/disjunction/n
  allocate/base/disjunction/n
  disjunction-n-oracle-lang
  subst-goal/disjunction/n)

(define work/base/disjunction/n
  (context-closure
   work/raw/disjunction/n
   disjunction-n-oracle-lang
   WorkFocus))

(define frontier/base/disjunction/n
  (context-closure
   frontier/raw/disjunction/n
   disjunction-n-oracle-lang
   SpineContext))

(define disjunction-n-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/disjunction/n
    frontier/base/disjunction/n
    allocate/base/disjunction/n)
   disjunction-n-oracle-lang
   #:domain F))

(define (raw-successors/disjunction/n frontier)
  (raw-named-successors disjunction-n-oracle-red frontier))

(define (trace/disjunction/n frontier [fuel 64])
  (finite-named-trace disjunction-n-oracle-red frontier fuel))
