#lang racket

(require redex/reduction-semantics
         "./language.rkt")

(provide work/raw/n
         frontier/raw/n
         allocate/raw/n
         work/base/n
         frontier/base/n
         allocate/base/n
         core-n-oracle-red
         raw-successors/n
         step-once/n)

(check-redundancy #t)

;; All thirteen clauses are stated directly over the numeric oracle language.
;; This module does not import a named source relation or a generated rule
;; table.
(define work/raw/n
  (reduction-relation
   core-n-oracle-lang
   #:domain any
   [--> (Work
         (g_1 ∧ g_2 tag)
         (state next sub dis trail tag_1))
        (Conj
         (Work g_1 (state next sub dis trail tag_1))
         g_2)
        "expand-conjunction"]
   [--> (Work (succeed tag) σ)
        (Returned σ)
        "succeed"]
   [--> (Work
         (fail tag)
         (state next sub dis trail tag_1))
        (Dead next)
        "fail"]
   [--> (Conj (Returned σ) g)
        (Work g σ)
        "conj-return"]
   [--> (Conj (Dead next) g)
        (Dead next)
        "conj-fail"]
   [--> (Work
         (t_1 =? t_2 tag)
         (state next sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
        (Returned
         (state next
                sub_1
                dis
                ((t_3 =? t_4 tag_1) ... (t_1 =? t_2 tag))
                tag_2))
        (where sub_1 (unify/n (walk/n t_1 sub) (walk/n t_2 sub) sub))
        (where #f (invalid?/n sub_1 dis))
        "unify-success"]
   [--> (Work
         (t_1 =? t_2 tag)
         (state next sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
        (Dead next)
        (where sub_1 (unify/n (walk/n t_1 sub) (walk/n t_2 sub) sub))
        (where #t (invalid?/n sub_1 dis))
        "unify-violates-disequality"]
   [--> (Work
         (t_1 =? t_2 tag)
         (state next sub dis trail tag_2))
        (Dead next)
        (where #f (unify/n (walk/n t_1 sub) (walk/n t_2 sub) sub))
        "unify-fail"]
   [--> (Work
         (t_1 != t_2 tag)
         (state next sub dis trail tag_2))
        (Returned (state next sub dis_1 trail tag_2))
        (where dis_1 ((t_1 t_2) ,@(term dis)))
        (where #f (invalid?/n sub dis_1))
        "disequality-success"]
   [--> (Work
         (t_1 != t_2 tag)
         (state next sub dis trail tag_2))
        (Dead next)
        (where dis_1 ((t_1 t_2) ,@(term dis)))
        (where #t (invalid?/n sub dis_1))
        "disequality-fail"]))

(define frontier/raw/n
  (reduction-relation
   core-n-oracle-lang
   #:domain any
   [--> (More (Returned σ))
        (Last (Answer σ))
        "finish-success"]
   [--> (More (Dead next))
        (Done next)
        "finish-failure"]))

(define allocate/raw/n
  (reduction-relation
   core-n-oracle-lang
   #:domain any
   [--> (Work
         (∃ (x_bound ...) g tag)
         (state next_0 sub dis trail tag_state))
        (Work
         g_new
         (state next_1 sub dis trail tag_state))
        (where (lv_new ...)
               (allocate-interval/n next_0 (x_bound ...)))
        (where next_1
               (advance-next/n next_0 (x_bound ...)))
        (where g_new
               (subst-goal/n g ((x_bound lv_new) ...)))
        "allocate-fresh"]))

(define work/base/n
  (context-closure work/raw/n core-n-oracle-lang WorkFocus))

(define frontier/base/n
  (context-closure frontier/raw/n core-n-oracle-lang SpineContext))

(define allocate/base/n
  (context-closure allocate/raw/n core-n-oracle-lang WorkFocus))

(define core-n-oracle-red
  (extend-reduction-relation
   (union-reduction-relations
    work/base/n
    frontier/base/n
    allocate/base/n)
   core-n-oracle-lang
   #:domain F))

(define (raw-successors/n frontier)
  (for/list ([named-step
              (in-list
               (apply-reduction-relation/tag-with-names
                core-n-oracle-red
                frontier))])
    (match-define (list name target) named-step)
    (list (string->symbol (~a name)) target)))

(define (step-once/n frontier)
  (match (raw-successors/n frontier)
    ['() '()]
    [(list only-step) (list only-step)]
    [steps
     (error 'step-once/n
            "nondeterministic core N step set for ~e: ~e"
            frontier
            steps)]))

(module+ test
  (require rackunit)

  (define expected-rule-names
    '(allocate-fresh
      conj-fail
      conj-return
      disequality-fail
      disequality-success
      expand-conjunction
      fail
      finish-failure
      finish-success
      succeed
      unify-fail
      unify-success
      unify-violates-disequality))

  (define actual-rule-names
    (map (lambda (name) (string->symbol (~a name)))
         (reduction-relation->rule-names core-n-oracle-red)))

  (check-equal? (length actual-rule-names) 13)
  (check-equal? (length actual-rule-names)
                (length (remove-duplicates actual-rule-names)))
  (check-equal? (sort actual-rule-names symbol<?)
                expected-rule-names))
