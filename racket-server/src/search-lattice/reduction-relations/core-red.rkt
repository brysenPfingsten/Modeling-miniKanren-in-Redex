#lang racket

(require redex/reduction-semantics
         (only-in "../languages/core-lang.rkt"
                  core-lang
                  invalid?
                  owners-append
                  unify
                  walk)
         (only-in "./private/common.rkt"
                  subst-goal-host)
         "./private/step-utils.rkt")

(provide work/base
         work/raw
         frontier/base
         frontier/raw
         allocate/base
         core-red
         step-once)

(check-redundancy #t)

;; Raw named clauses are kept separate from their grammatical context closures
;; so feature and scheduler cells can reuse them without a host dispatcher.
;; The exported assembled relations below are the source semantics.
(define work/raw
  (reduction-relation
   core-lang
   #:domain any
   [--> (Work owners (g_1 ∧ g_2 tag) (state sub dis trail tag_1))
        (Conj owners (Work (Owners) g_1 (state sub dis trail tag_1)) g_2)
        "expand-conjunction"]
   [--> (Work owners (succeed tag) σ)
        (Returned owners σ)
        "succeed"]
   [--> (Work owners (fail tag) σ)
        (Dead owners)
        "fail"]
   [--> (Conj owners_outer (Returned owners_inner σ) g)
        (Work (owners-append owners_outer owners_inner) g σ)
        "conj-return"]
   [--> (Conj owners_outer (Dead owners_inner) g)
        (Dead (owners-append owners_outer owners_inner))
        "conj-fail"]
   [--> (Work owners (t_1 =? t_2 tag) (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
        (Returned owners (state sub_1 dis ((t_3 =? t_4 tag_1) ... (t_1 =? t_2 tag)) tag_2))
        (where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
        (where #f (invalid? sub_1 dis))
        "unify-success"]
   [--> (Work owners (t_1 =? t_2 tag) (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
        (Dead owners)
        (where sub_1 (unify (walk t_1 sub) (walk t_2 sub) sub))
        (where #t (invalid? sub_1 dis))
        "unify-violates-disequality"]
   [--> (Work owners (t_1 =? t_2 tag) (state sub dis trail tag_2))
        (Dead owners)
        (where #f (unify (walk t_1 sub) (walk t_2 sub) sub))
        "unify-fail"]
   [--> (Work owners (t_1 != t_2 tag) (state sub dis trail tag_2))
        (Returned owners (state sub dis_1 trail tag_2))
        (where dis_1 ((t_1 t_2) ,@(term dis)))
        (where #f (invalid? sub dis_1))
        "disequality-success"]
   [--> (Work owners (t_1 != t_2 tag) (state sub dis trail tag_2))
        (Dead owners)
        (where dis_1 ((t_1 t_2) ,@(term dis)))
        (where #t (invalid? sub dis_1))
        "disequality-fail"]))

(define frontier/raw
  (reduction-relation
   core-lang
   #:domain any
   [--> (More (Returned owners σ))
        (Last owners (Answer (Owners) σ))
        "finish-success"]
   [--> (More (Dead owners))
        (Done owners)
        "finish-failure"]))

;; Allocation is a whole-frontier relation rather than a leaf closure under
;; WorkFocus. F_support names the complete live frontier used for freshness.
(define allocate/base
  (reduction-relation
   core-lang
   #:domain F
   [--> (name F_support (in-hole WorkFocus (Work owners (∃ (x_bound ...) g tag) σ)))
        (in-hole WorkFocus (Work (owners-append owners (Owners (Owner (u_new ...) tag))) g_new σ))
        (where (u_new ...) ,(variables-not-in (term F_support) (make-list (length (term (x_bound ...))) 'u:0)))
        (where g_new ,(subst-goal-host (term g) (term ((x_bound u_new) ...))))
        "allocate-fresh"]))

(define work/base
  (context-closure work/raw core-lang WorkFocus))

(define frontier/base
  (context-closure frontier/raw core-lang SpineContext))

(define core-red
  (extend-reduction-relation
   (union-reduction-relations work/base frontier/base allocate/base)
   core-lang
   #:domain F))

(define (step-once prog)
  (step-once/deterministic core-red prog))
