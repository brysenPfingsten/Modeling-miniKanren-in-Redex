#lang racket

(require redex/reduction-semantics)

(provide core-n-oracle-lang
         walk/n
         occurs?/n
         extend/n
         unify/n
         invalid?/n
         allocate-interval/n
         advance-next/n
         subst-goal/n)

(check-redundancy #t)

;; This is a direct numeric source language, not an extension or projection of
;; either named representation.  A bare natural in a term is a runtime logic
;; variable.  Object-language numeric data is explicitly wrapped as (nat n),
;; so the two domains remain syntactically disjoint.
(define-language core-n-oracle-lang
  [d (x_!_ ...)]
  [alloc ((x lv) ...)]

  [eq (t =? t tag)]

  [g eq
     (t != t tag)
     (succeed tag)
     (fail tag)
     (∃ d g tag)
     (g ∧ g tag)]

  [t x
     lv
     pt
     (t : t)]

  [pt (sym string)
      (nat number)
      boolean
      (str string)
      empty]

  [x (variable-prefix x:)]
  [lv natural]
  [next natural]
  [tag (label string)]

  [σ (state next sub dis trail tag)]
  [sub ((lv_!_ t) ...)]
  [dis ((t t) ...)]
  [maybe-sub sub #f]
  [trail (eq ...)]

  [A (Answer σ)]
  [S (Returned σ)]
  [W (Work g σ)
     (Returned σ)
     (Dead next)
     (Conj W g)]
  [F (Last A)
     (Done next)
     (More W)]

  [WorkPath hole
            (Conj WorkPath g)]
  [SpineContext hole]
  [WorkFocus (in-hole SpineContext (More WorkPath))]

  #:binding-forms
  (∃ (x ...) g #:refers-to (shadow x ...)))

(define-metafunction core-n-oracle-lang
  walk/n : t sub -> t
  [(walk/n lv (name sub (_ ... [lv t] _ ...))) (walk/n t sub)]
  [(walk/n t _) t])

(define-relation core-n-oracle-lang
  occurs?/n ⊆ lv × t × sub
  [(occurs?/n lv (t : _) sub) (occurs?/n lv (walk/n t sub) sub)]
  [(occurs?/n lv (_ : t) sub) (occurs?/n lv (walk/n t sub) sub)]
  [(occurs?/n lv lv sub)])

(define-metafunction core-n-oracle-lang
  extend/n : lv t sub -> maybe-sub
  [(extend/n lv t sub) #f
   (side-condition (judgment-holds (occurs?/n lv t sub)))]
  [(extend/n lv t sub) ([lv t] ,@(term sub))
   (side-condition (not (judgment-holds (occurs?/n lv t sub))))])

(define-metafunction core-n-oracle-lang
  unify/n : t t sub -> maybe-sub
  [(unify/n lv_1 lv_1 sub) sub]
  [(unify/n lv t sub) (extend/n lv t sub)]
  [(unify/n t lv sub) (extend/n lv t sub)]
  [(unify/n (t_1a : t_1b) (t_2a : t_2b) sub)
   (unify/n (walk/n t_1b sub_1) (walk/n t_2b sub_1) sub_1)
   (where sub_1 (unify/n (walk/n t_1a sub) (walk/n t_2a sub) sub))]
  [(unify/n t_1 t_1 sub) sub]
  [(unify/n _ _ _) #f])

(define-metafunction core-n-oracle-lang
  invalid?/n : sub dis -> boolean
  [(invalid?/n sub ()) #f]
  [(invalid?/n sub ((t_1 t_2) (t_3 t_4) ...))
   #t
   (where sub (unify/n (walk/n t_1 sub) (walk/n t_2 sub) sub))]
  [(invalid?/n sub ((t_1 t_2) (t_3 t_4) ...))
   (invalid?/n sub ((t_3 t_4) ...))])

(define-metafunction core-n-oracle-lang
  allocate-interval/n : next d -> (lv ...)
  [(allocate-interval/n next (x ...))
   ,(build-list (length (term (x ...)))
                (lambda (offset) (+ (term next) offset)))])

(define-metafunction core-n-oracle-lang
  advance-next/n : next d -> next
  [(advance-next/n next (x ...))
   ,(+ (term next) (length (term (x ...))))])

(define (lexical-variable? datum)
  (and (symbol? datum)
       (regexp-match? #rx"^x:" (symbol->string datum))))

(define (subst-term/n/host t bindings)
  (match t
    [(? lexical-variable? x)
     (match (assoc x bindings)
       [(list _ lv) lv]
       [_ x])]
    [`(,t_1 : ,t_2)
     `(,(subst-term/n/host t_1 bindings)
       :
       ,(subst-term/n/host t_2 bindings))]
    [_ t]))

(define (without-shadowed-bindings binders bindings)
  (for/list ([binding (in-list bindings)]
             #:unless (member (first binding) binders))
    binding))

;; Simultaneous binder-local substitution.  Runtime levels and unrelated
;; lexical variables are untouched, and nested binders shadow outer bindings.
(define (subst-goal/n/host g bindings)
  (match g
    [`(succeed ,tag) `(succeed ,tag)]
    [`(fail ,tag) `(fail ,tag)]
    [`(,t_1 =? ,t_2 ,tag)
     `(,(subst-term/n/host t_1 bindings)
       =?
       ,(subst-term/n/host t_2 bindings)
       ,tag)]
    [`(,t_1 != ,t_2 ,tag)
     `(,(subst-term/n/host t_1 bindings)
       !=
       ,(subst-term/n/host t_2 bindings)
       ,tag)]
    [`(,g_1 ∧ ,g_2 ,tag)
     `(,(subst-goal/n/host g_1 bindings)
       ∧
       ,(subst-goal/n/host g_2 bindings)
       ,tag)]
    [`(∃ ,binders ,g_body ,tag)
     `(∃ ,binders
         ,(subst-goal/n/host
           g_body
           (without-shadowed-bindings binders bindings))
         ,tag)]
    [_
     (error 'subst-goal/n
            "unsupported numeric-core goal form: ~e"
            g)]))

(define-metafunction core-n-oracle-lang
  subst-goal/n : g alloc -> g
  [(subst-goal/n g ((x lv) ...))
   ,(subst-goal/n/host (term g) (term ((x lv) ...)))])

(module+ test
  (require rackunit)

  (check-true (redex-match? core-n-oracle-lang t (term 0)))
  (check-true (redex-match? core-n-oracle-lang pt (term (nat 0))))
  (check-false (redex-match? core-n-oracle-lang lv (term (nat 0))))
  (check-equal? (term (allocate-interval/n 3 (x:a x:b x:c)))
                '(3 4 5))
  (check-equal? (term (allocate-interval/n 3 ())) '())
  (check-equal? (term (advance-next/n 3 (x:a x:b x:c))) 6)
  (check-equal?
   (term
    (subst-goal/n
     (∃ (x:outer)
        ((x:outer =? x:free (label "nested"))
         ∧
         (0 =? x:free (label "mixed"))
         (label "and"))
        (label "shadow"))
     ((x:outer 4) (x:free 5))))
   (term
    (∃ (x:outer)
       ((x:outer =? 5 (label "nested"))
        ∧
        (0 =? 5 (label "mixed"))
        (label "and"))
       (label "shadow")))))
