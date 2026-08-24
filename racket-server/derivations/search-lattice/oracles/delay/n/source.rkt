#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         "../private/shared.rkt"
         (prefix-in core: "../../core/n/source.rkt"))

(provide subst-goal/delay/n
         work/raw/delay/n
         frontier/raw/delay/n
         allocate/raw/delay/n
         allocate/base/delay/n
         work/base/delay/n
         frontier/base/delay/n
         delay-n-oracle-red
         raw-successors/delay/n
         trace/delay/n)

(check-redundancy #t)

(define (lexical-variable?/n datum)
  (and (symbol? datum)
       (regexp-match? #rx"^x:" (symbol->string datum))))

(define (subst-term/delay/n term bindings)
  (match term
    [(? lexical-variable?/n x)
     (match (assoc x bindings)
       [(list _ level) level]
       [#f x])]
    [`(,left : ,right)
     `(,(subst-term/delay/n left bindings)
       :
       ,(subst-term/delay/n right bindings))]
    [_ term]))

(define-metafunction delay-n-oracle-lang
  subst-goal/delay/n : g alloc -> g
  [(subst-goal/delay/n g ((x lv) ...))
   ,(substitute-goal/delay
     (term g)
     (term ((x lv) ...))
     subst-term/delay/n
     'subst-goal/delay/n)])

;; Numeric Delay is stated directly; no E carrier is decoded or consulted.
(define work/raw/delay/n
  (extend-reduction-relation
   core:work/raw/n
   delay-n-oracle-lang
   #:domain any
   [--> (Work (suspend g tag) σ)
        (PendingDelay (Work g σ))
        "suspend-goal"]
   [--> (Conj (PendingDelay W) g)
        (PendingDelay (Conj W g))
        "bubble-delay-through-conj"]))

(define frontier/raw/delay/n
  (extend-reduction-relation
   core:frontier/raw/n
   delay-n-oracle-lang
   #:domain any
   [--> (More (PendingDelay W))
        (Forced (More W))
        "force-delay"]))

(core:define-allocation/n
  allocate/raw/delay/n
  allocate/base/delay/n
  delay-n-oracle-lang
  subst-goal/delay/n)

(define work/base/delay/n
  (context-closure work/raw/delay/n delay-n-oracle-lang WorkFocus))

(define frontier/base/delay/n
  (context-closure frontier/raw/delay/n delay-n-oracle-lang SpineContext))

(define delay-n-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/delay/n
    frontier/base/delay/n
    allocate/base/delay/n)
   delay-n-oracle-lang
   #:domain F))

(define (raw-successors/delay/n frontier)
  (raw-named-successors delay-n-oracle-red frontier))

(define (trace/delay/n frontier [fuel 64])
  (finite-named-trace delay-n-oracle-red frontier fuel))
