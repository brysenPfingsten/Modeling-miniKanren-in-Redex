#lang racket

(require redex/reduction-semantics
         (only-in "../../../../src/search-lattice/languages/core-lang.rkt"
                  core-lang
                  invalid?
                  owners-append
                  unify
                  walk)
         (only-in "../../../../src/search-lattice/reduction-relations/private/common.rkt"
                  subst-goal-host)
         "./private/support-kernel.rkt")

(provide core-s-big-lang
         readback-Big/s
         big-dispatch/direct/s
         big-run/direct/s
         big-settled/direct/s
         big-dead/direct/s
         big-final/direct/s
         big-evaluate/direct/s)

(check-redundancy #t)

;; The promoted evaluator has one result category in core.  Its private
;; dispatcher ranges only over the existing source work grammar and retained
;; WorkFocus; no transition-state sum or phase tag is introduced.
(define-extended-language core-s-big-lang
  core-lang
  [RunW (Work owners g σ)]
  [T (Last owners A)
     (Done owners)]
  [Big (BigFinal T)])

(define-metafunction core-s-big-lang
  readback-Big/s : Big -> F
  [(readback-Big/s (BigFinal T))
   T])

;; Fixed-point promotion distributes the strict driver into the semantic
;; clauses.  Every recursive premise below is a direct tail call over a core
;; carrier and its retained context.  The first clause is administrative
;; descent through an already-present conjunction; the remaining clauses are
;; the independently stated images of the thirteen core rules.
(define-judgment-form
  core-s-big-lang
  #:contract (big-dispatch/direct/s W WorkFocus Big)
  #:mode (big-dispatch/direct/s I I O)

  [(big-dispatch/direct/s
    W
    (in-hole WorkFocus (Conj owners hole g))
    Big)
   ---------------------------------------------------- "big descend existing conjunction/S"
   (big-dispatch/direct/s
    (Conj owners W g)
    WorkFocus
    Big)]

  [(big-dispatch/direct/s
    (Work (Owners) g_1 σ)
    (in-hole WorkFocus (Conj owners hole g_2))
    Big)
   ---------------------------------------------------- "big expand conjunction/S"
   (big-dispatch/direct/s
    (Work owners (g_1 ∧ g_2 tag) σ)
    WorkFocus
    Big)]

  [(big-dispatch/direct/s
    (Returned owners σ)
    WorkFocus
    Big)
   ---------------------------------------------------- "big succeed/S"
   (big-dispatch/direct/s
    (Work owners (succeed tag) σ)
    WorkFocus
    Big)]

  [(big-dispatch/direct/s
    (Dead owners)
    WorkFocus
    Big)
   ---------------------------------------------------- "big fail/S"
   (big-dispatch/direct/s
    (Work owners (fail tag) σ)
    WorkFocus
    Big)]

  [(where (u_new ...)
          ,(fresh-intro/separated/host
            (term WorkFocus)
            (term (Work owners (∃ (x_bound ...) g tag) σ))
            (term (x_bound ...))))
   (where g_new
          ,(subst-goal-host
            (term g)
            (term ((x_bound u_new) ...))))
   (big-dispatch/direct/s
    (Work
     (owners-append owners (Owners (Owner (u_new ...) tag)))
     g_new
     σ)
    WorkFocus
    Big)
   ---------------------------------------------------- "big allocate fresh/S"
   (big-dispatch/direct/s
    (Work owners (∃ (x_bound ...) g tag) σ)
    WorkFocus
    Big)]

  [(where sub_1
          (unify (walk t_1 sub) (walk t_2 sub) sub))
   (where #f (invalid? sub_1 dis))
   (big-dispatch/direct/s
    (Returned
     owners
     (state sub_1
            dis
            ((t_3 =? t_4 tag_1) ... (t_1 =? t_2 tag))
            tag_2))
    WorkFocus
    Big)
   ---------------------------------------------------- "big unification success/S"
   (big-dispatch/direct/s
    (Work
     owners
     (t_1 =? t_2 tag)
     (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
    WorkFocus
    Big)]

  [(where sub_1
          (unify (walk t_1 sub) (walk t_2 sub) sub))
   (where #t (invalid? sub_1 dis))
   (big-dispatch/direct/s
    (Dead owners)
    WorkFocus
    Big)
   ---------------------------------------------------- "big unification violates disequality/S"
   (big-dispatch/direct/s
    (Work
     owners
     (t_1 =? t_2 tag)
     (state sub dis ((t_3 =? t_4 tag_1) ...) tag_2))
    WorkFocus
    Big)]

  [(where #f
          (unify (walk t_1 sub) (walk t_2 sub) sub))
   (big-dispatch/direct/s
    (Dead owners)
    WorkFocus
    Big)
   ---------------------------------------------------- "big unification failure/S"
   (big-dispatch/direct/s
    (Work
     owners
     (t_1 =? t_2 tag)
     (state sub dis trail tag_2))
    WorkFocus
    Big)]

  [(where dis_1 ((t_1 t_2) ,@(term dis)))
   (where #f (invalid? sub dis_1))
   (big-dispatch/direct/s
    (Returned owners (state sub dis_1 trail tag_2))
    WorkFocus
    Big)
   ---------------------------------------------------- "big disequality success/S"
   (big-dispatch/direct/s
    (Work
     owners
     (t_1 != t_2 tag)
     (state sub dis trail tag_2))
    WorkFocus
    Big)]

  [(where dis_1 ((t_1 t_2) ,@(term dis)))
   (where #t (invalid? sub dis_1))
   (big-dispatch/direct/s
    (Dead owners)
    WorkFocus
    Big)
   ---------------------------------------------------- "big disequality failure/S"
   (big-dispatch/direct/s
    (Work
     owners
     (t_1 != t_2 tag)
     (state sub dis trail tag_2))
    WorkFocus
    Big)]

  [(big-dispatch/direct/s
    (Work (owners-append owners_outer owners_inner) g σ)
    WorkFocus
    Big)
   ---------------------------------------------------- "big conjunction return/S"
   (big-dispatch/direct/s
    (Returned owners_inner σ)
    (in-hole WorkFocus (Conj owners_outer hole g))
    Big)]

  [(big-dispatch/direct/s
    (Dead (owners-append owners_outer owners_inner))
    WorkFocus
    Big)
   ---------------------------------------------------- "big conjunction failure/S"
   (big-dispatch/direct/s
    (Dead owners_inner)
    (in-hole WorkFocus (Conj owners_outer hole g))
    Big)]

  [---------------------------------------------------- "big finish success/S"
   (big-dispatch/direct/s
    (Returned owners σ)
    (More hole)
    (BigFinal (Last owners (Answer (Owners) σ))))]

  [---------------------------------------------------- "big finish failure/S"
   (big-dispatch/direct/s
    (Dead owners)
    (More hole)
    (BigFinal (Done owners)))])

;; Public promoted entries mirror the four canonical control payloads.  They
;; are thin Redex judgments over the direct dispatcher, not host procedures.
(define-judgment-form
  core-s-big-lang
  #:contract (big-run/direct/s RunW WorkFocus Big)
  #:mode (big-run/direct/s I I O)

  [(big-dispatch/direct/s RunW WorkFocus Big)
   ---------------------------------------------------- "big run entry/S"
   (big-run/direct/s RunW WorkFocus Big)])

(define-judgment-form
  core-s-big-lang
  #:contract (big-settled/direct/s S WorkFocus Big)
  #:mode (big-settled/direct/s I I O)

  [(big-dispatch/direct/s S WorkFocus Big)
   ---------------------------------------------------- "big settled entry/S"
   (big-settled/direct/s S WorkFocus Big)])

(define-judgment-form
  core-s-big-lang
  #:contract (big-dead/direct/s owners WorkFocus Big)
  #:mode (big-dead/direct/s I I O)

  [(big-dispatch/direct/s (Dead owners) WorkFocus Big)
   ---------------------------------------------------- "big dead entry/S"
   (big-dead/direct/s owners WorkFocus Big)])

(define-judgment-form
  core-s-big-lang
  #:contract (big-final/direct/s T Big)
  #:mode (big-final/direct/s I O)

  [---------------------------------------------------- "big final entry/S"
   (big-final/direct/s T (BigFinal T))])

(define-judgment-form
  core-s-big-lang
  #:contract (big-evaluate/direct/s F Big)
  #:mode (big-evaluate/direct/s I O)

  [(big-dispatch/direct/s W (More hole) Big)
   ---------------------------------------------------- "big work frontier entry/S"
   (big-evaluate/direct/s (More W) Big)]

  [(big-final/direct/s T Big)
   ---------------------------------------------------- "big terminal frontier entry/S"
   (big-evaluate/direct/s T Big)])

(module+ test
  (require rackunit)

  (define sigma/s
    (term (state () () () (label "state"))))

  (define succeed-source/s
    (term
     (More
      (Work
       (Owners)
       (succeed (label "yes"))
       ,sigma/s))))

  (define succeed-result/s
    (term
     (BigFinal
      (Last
       (Owners)
       (Answer (Owners) ,sigma/s)))))

  (check-equal?
   (length
    (build-derivations
     (big-evaluate/direct/s ,succeed-source/s Big)))
   1)
  (check-equal?
   (judgment-holds
    (big-evaluate/direct/s ,succeed-source/s Big)
    Big)
   (list succeed-result/s))

  (check-equal?
   (judgment-holds
    (big-run/direct/s
     (Work (Owners) (succeed (label "yes")) ,sigma/s)
     (More hole)
     Big)
    Big)
   (list succeed-result/s))
  (check-equal?
   (judgment-holds
    (big-settled/direct/s
     (Returned (Owners) ,sigma/s)
     (More hole)
     Big)
    Big)
   (list succeed-result/s))
  (check-equal?
   (judgment-holds
    (big-dead/direct/s
     (Owners)
     (More hole)
     Big)
    Big)
   (list (term (BigFinal (Done (Owners))))))
  (check-equal?
   (judgment-holds
    (big-final/direct/s
     (Done (Owners))
     Big)
    Big)
   (list (term (BigFinal (Done (Owners))))))

  (define allocation-source/s
    (term
     (More
      (Conj
       (Owners (Owner (u:0) (label "outer")))
       (Work
        (Owners (Owner (u:2) (label "inner")))
        (∃ (x:q)
           (x:q =? (nat 1) (label "body"))
           (label "fresh"))
        ,sigma/s)
       (succeed (label "right"))))))

  (define allocation-results/s
    (judgment-holds
     (big-evaluate/direct/s ,allocation-source/s Big)
     Big))

  (check-equal? (length allocation-results/s) 1)
  (check-equal?
   (term (readback-Big/s ,(first allocation-results/s)))
   (term
    (Last
     (Owners
      (Owner (u:0) (label "outer"))
      (Owner (u:2) (label "inner"))
      (Owner (u:1) (label "fresh")))
     (Answer
      (Owners)
      (state ((u:1 (nat 1)))
             ()
             ((u:1 =? (nat 1) (label "body")))
             (label "state"))))))

  ;; The source grammar's d nonterminal enforces distinct lexical binders at
  ;; the public boundary; the evaluator adds no weaker compatibility test.
  (check-false
   (redex-match?
    core-s-big-lang
    F
    (term
     (More
      (Work
       (Owners)
       (∃ (x:q x:q)
          (succeed (label "body"))
          (label "duplicate"))
       ,sigma/s))))))
