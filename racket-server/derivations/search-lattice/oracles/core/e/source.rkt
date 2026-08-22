#lang racket

(require redex/reduction-semantics
         "./language.rkt")

(provide subst-term/lexical/e
         subst-goal/lexical/e
         work/raw/e
         frontier/raw/e
         allocate/raw/e
         work/base/e
         frontier/base/e
         allocate/base/e
         core-e-oracle-red
         raw-successors/e
         step-once/e)

(check-redundancy #t)

(define (x-symbol?/e datum)
  (and (symbol? datum)
       (regexp-match? #rx"^x:" (symbol->string datum))))

(define (subst-term/lexical/e term substitution)
  (match term
    [(? x-symbol?/e x)
     (match (assoc x substitution)
       [(list _ replacement) replacement]
       [#f x])]
    [`(,left : ,right)
     `(,(subst-term/lexical/e left substitution)
       :
       ,(subst-term/lexical/e right substitution))]
    [_ term]))

(define (drop-shadowed/e binders substitution)
  (for/list ([(x replacement*) (in-dict substitution)]
             #:unless (member x binders))
    (match-define (list replacement) replacement*)
    (list x replacement)))

;; This substitution crosses precisely the current fresh boundary.  Runtime
;; u atoms and unrelated lexical variables are untouched, and a nested binder
;; removes its shadowed names before recursion.
(define (subst-goal/lexical/e goal substitution)
  (match goal
    [`(succeed ,tag)
     `(succeed ,tag)]
    [`(fail ,tag)
     `(fail ,tag)]
    [`(,left =? ,right ,tag)
     `(,(subst-term/lexical/e left substitution)
       =?
       ,(subst-term/lexical/e right substitution)
       ,tag)]
    [`(,left != ,right ,tag)
     `(,(subst-term/lexical/e left substitution)
       !=
       ,(subst-term/lexical/e right substitution)
       ,tag)]
    [`(,left ∧ ,right ,tag)
     `(,(subst-goal/lexical/e left substitution)
       ∧
       ,(subst-goal/lexical/e right substitution)
       ,tag)]
    [`(∃ ,binders ,body ,tag)
     `(∃ ,binders
         ,(subst-goal/lexical/e
           body
           (drop-shadowed/e binders substitution))
         ,tag)]
    [_
     (error 'subst-goal/lexical/e
            "unsupported core E goal: ~e"
            goal)]))

;; All thirteen clauses are direct Redex equations.  This module imports no
;; production relation, generated descriptor, or prototype E semantics.
(define work/raw/e
  (reduction-relation
   core-e-oracle-lang
   #:domain any

   [--> (Work (g_1 ∧ g_2 tag) σ)
        (Conj (Work g_1 σ) g_2)
        "expand-conjunction"]

   [--> (Work (succeed tag) σ)
        (Returned σ)
        "succeed"]

   [--> (Work
         (fail tag)
         (state support sub dis trail tag_state))
        (Dead support)
        "fail"]

   [--> (Conj (Returned σ) g)
        (Work g σ)
        "conj-return"]

   [--> (Conj (Dead support) g)
        (Dead support)
        "conj-fail"]

   [--> (Work
         (t_1 =? t_2 tag)
         (state support
                sub
                dis
                ((t_3 =? t_4 tag_1) ...)
                tag_2))
        (Returned
         (state support
                sub_1
                dis
                ((t_3 =? t_4 tag_1) ... (t_1 =? t_2 tag))
                tag_2))
        (where sub_1 (unify/e (walk/e t_1 sub) (walk/e t_2 sub) sub))
        (where #f (invalid?/e sub_1 dis))
        "unify-success"]

   [--> (Work
         (t_1 =? t_2 tag)
         (state support sub dis trail tag_2))
        (Dead support)
        (where sub_1 (unify/e (walk/e t_1 sub) (walk/e t_2 sub) sub))
        (where #t (invalid?/e sub_1 dis))
        "unify-violates-disequality"]

   [--> (Work
         (t_1 =? t_2 tag)
         (state support sub dis trail tag_2))
        (Dead support)
        (where #f (unify/e (walk/e t_1 sub) (walk/e t_2 sub) sub))
        "unify-fail"]

   [--> (Work
         (t_1 != t_2 tag)
         (state support sub dis trail tag_2))
        (Returned (state support sub dis_1 trail tag_2))
        (where dis_1 ((t_1 t_2) ,@(term dis)))
        (where #f (invalid?/e sub dis_1))
        "disequality-success"]

   [--> (Work
         (t_1 != t_2 tag)
         (state support sub dis trail tag_2))
        (Dead support)
        (where dis_1 ((t_1 t_2) ,@(term dis)))
        (where #t (invalid?/e sub dis_1))
        "disequality-fail"]))

(define frontier/raw/e
  (reduction-relation
   core-e-oracle-lang
   #:domain any

   [--> (More (Returned σ))
        (Last (Answer σ))
        "finish-success"]

   [--> (More (Dead support))
        (Done support)
        "finish-failure"]))

(define allocate/raw/e
  (reduction-relation
   core-e-oracle-lang
   #:domain any

   [--> (Work
         (∃ (x_bound ...) g tag)
         (state support sub dis trail tag_state))
        (Work
         g_new
         (state support_new sub dis trail tag_state))
        (where (u_new ...) (fresh-intro/e support (x_bound ...)))
        (where support_new (support-extend/e support (u_new ...)))
        (where g_new
               ,(subst-goal/lexical/e
                 (term g)
                 (term ((x_bound u_new) ...))))
        "allocate-fresh"]))

(define work/base/e
  (context-closure work/raw/e core-e-oracle-lang WorkFocus))

(define frontier/base/e
  (context-closure frontier/raw/e core-e-oracle-lang SpineContext))

(define allocate/base/e
  (context-closure allocate/raw/e core-e-oracle-lang WorkFocus))

(define core-e-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/e
    frontier/base/e
    allocate/base/e)
   core-e-oracle-lang
   #:domain F))

;; This function intentionally exposes the raw named proof multiset.  It is
;; separate from the deterministic convenience wrapper so correspondence
;; tests cannot accidentally establish a theorem on deduplicated targets.
(define (raw-successors/e frontier)
  (for/list ([named-step
              (in-list
               (apply-reduction-relation/tag-with-names
                core-e-oracle-red
                frontier))])
    (match-define (list name target) named-step)
    (list (string->symbol (~a name)) target)))

(define (step-once/e frontier)
  (match (raw-successors/e frontier)
    ['() '()]
    [(list only-step) (list only-step)]
    [steps
     (error 'step-once/e
            "nondeterministic core E step set for ~e: ~e"
            frontier
            steps)]))
