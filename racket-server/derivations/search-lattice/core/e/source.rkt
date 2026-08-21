#lang racket

(require redex/reduction-semantics
         (only-in "../../../../src/search-lattice/languages/core-lang.rkt"
                  invalid?
                  unify
                  walk)
         (only-in "../../../../src/search-lattice/reduction-relations/private/common.rkt"
                  subst-goal-host)
         (only-in "../../../../src/search-lattice/reduction-relations/private/step-utils.rkt"
                  step-once/deterministic)
         "./language.rkt")

(provide work/raw/e
         frontier/raw/e
         allocate/base/e
         work/base/e
         frontier/base/e
         core-e-red
         step-once/e)

(check-redundancy #t)

;; These clauses are stated directly.  This module deliberately does not
;; import, lift, dispatch through, or project the authoritative S relation.
(define work/raw/e
  (reduction-relation
   core-e-lang
   #:domain any
   [--> (Work support (g_1 ∧ g_2 tag) (state sub dis trail tag_1))
        (Conj support
              (Work support g_1 (state sub dis trail tag_1))
              g_2)
        "expand-conjunction"]
   [--> (Work support (succeed tag) σ)
        (Returned support σ)
        "succeed"]
   [--> (Work support (fail tag) σ)
        (Dead support)
        "fail"]
   [--> (Conj support_outer (Returned support_inner σ) g)
        (Work support_inner g σ)
        "conj-return"]
   [--> (Conj support_outer (Dead support_inner) g)
        (Dead support_inner)
        "conj-fail"]
   [--> (Work support
              (t_1 =? t_2 tag)
              (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
        (Returned
         support
         (state sub_1
                dis
                ((t_3 =? t_4 tag_1) ... (t_1 =? t_2 tag))
                tag_2))
        (where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
        (where #f (invalid? sub_1 dis))
        "unify-success"]
   [--> (Work support
              (t_1 =? t_2 tag)
              (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
        (Dead support)
        (where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
        (where #t (invalid? sub_1 dis))
        "unify-violates-disequality"]
   [--> (Work support
              (t_1 =? t_2 tag)
              (state sub dis trail tag_2))
        (Dead support)
        (where #f (unify (walk t_1 sub) (walk t_2 sub) sub))
        "unify-fail"]
   [--> (Work support
              (t_1 != t_2 tag)
              (state sub dis trail tag_2))
        (Returned support (state sub dis_1 trail tag_2))
        (where dis_1 ((t_1 t_2) ,@(term dis)))
        (where #f (invalid? sub dis_1))
        "disequality-success"]
   [--> (Work support
              (t_1 != t_2 tag)
              (state sub dis trail tag_2))
        (Dead support)
        (where dis_1 ((t_1 t_2) ,@(term dis)))
        (where #t (invalid? sub dis_1))
        "disequality-fail"]))

(define frontier/raw/e
  (reduction-relation
   core-e-lang
   #:domain any
   [--> (More (Returned support σ))
        (Last support (Answer support σ))
        "finish-success"]
   [--> (More (Dead support))
        (Done support)
        "finish-failure"]))

;; E localizes freshness at the focused carrier.  Its Support is cumulative,
;; so on translated well-formed S frontiers it is exactly the live support
;; that S reconstructs by scanning the whole frontier.  The S->E bridge states
;; and checks that premise explicitly; this rule does not retain S's scan.
(define allocate/base/e
  (reduction-relation
   core-e-lang
   #:domain F
   [--> (in-hole WorkFocus
                 (Work support
                       (∃ (x_bound ...) g tag)
                       σ))
        (in-hole WorkFocus
                 (Work
                  (support-append support (Support u_new ...))
                  g_new
                  σ))
        (where (u_new ...)
               ,(variables-not-in
                 (term support)
                 (make-list (length (term (x_bound ...))) 'u:0)))
        (where g_new
               ,(subst-goal-host
                 (term g)
                 (term ((x_bound u_new) ...))))
        "allocate-fresh"]))

(define work/base/e
  (context-closure work/raw/e core-e-lang WorkFocus))

(define frontier/base/e
  (context-closure frontier/raw/e core-e-lang SpineContext))

(define core-e-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/e
    frontier/base/e
    allocate/base/e)
   core-e-lang
   #:domain F))

(define (step-once/e frontier)
  (step-once/deterministic core-e-red frontier))

(module+ test
  (require rackunit)

  (define expected-core-rule-names
    '(expand-conjunction
      succeed
      fail
      conj-return
      conj-fail
      allocate-fresh
      unify-success
      unify-violates-disequality
      unify-fail
      disequality-success
      disequality-fail
      finish-success
      finish-failure))

  (define actual-core-rule-names
    (reduction-relation->rule-names core-e-red))

  (check-equal? (length actual-core-rule-names) 13)
  (check-equal? (length actual-core-rule-names)
                (length (remove-duplicates actual-core-rule-names)))
  (check-equal? (sort actual-core-rule-names symbol<?)
                (sort expected-core-rule-names symbol<?)))
