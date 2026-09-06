#lang racket

(require redex/reduction-semantics)

(provide core-s-oracle-lang
         owners-append/s
         walk/s
         extend/s
         occurs?/s
         unify/s
         invalid?/s)

(check-redundancy #t)

;; This language is an independent statement of the world-local
;; Owner-decorated core source.  In particular, it neither extends nor imports
;; the production language: it is intended to remain an oracle when the
;; representation strategy is extracted later.
(define-language core-s-oracle-lang
  [d (x_!_ ...)]

  [eq (t =? t tag)]

  [g eq
     (t != t tag)
     (succeed tag)
     (fail tag)
     (∃ d g tag)
     (g ∧ g tag)]

  [t x
     u
     pt
     (t : t)]

  [pt (sym string)
      (nat number)
      boolean
      (str string)
      empty]

  [x (variable-prefix x:)]
  [u (variable-prefix u:)]
  [tag (label string)]

  [σ (state sub dis trail tag)]
  [sub ((u_!_ t) ...)]
  [dis ((t t) ...)]
  [maybe-sub sub #f]
  [trail (eq ...)]

  ;; An Owner is proof-relevant even when intro is empty.  Keeping owner
  ;; groups as syntax preserves binder grouping, tags, and introduction order.
  [intro (u_!_ ...)]
  [owner (Owner intro tag)]
  [owners (Owners owner ...)]

  [A (Answer owners σ)]
  [S (Returned owners σ)]

  [W (Work owners g σ)
     (Returned owners σ)
     (Dead owners)
     (Conj owners W g)]

  [F (Last owners A)
     (Done owners)
     (More W)]

  ;; Core has one active possible-world path.  Every Conj frame contributes
  ;; its Owner groups before the groups on the focused work constructor.
  [WorkPath hole
            (Conj owners WorkPath g)]
  [SpineContext hole]
  [WorkFocus (in-hole SpineContext (More WorkPath))]

  #:binding-forms
  (∃ (x ...) g #:refers-to (shadow x ...)))

(define-metafunction core-s-oracle-lang
  owners-append/s : owners owners -> owners
  [(owners-append/s (Owners owner_outer ...)
                    (Owners owner_inner ...))
   (Owners owner_outer ... owner_inner ...)])

(define-metafunction core-s-oracle-lang
  walk/s : t sub -> t
  [(walk/s u (name sub (_ ... [u t] _ ...))) (walk/s t sub)]
  [(walk/s t _) t])

(define-relation core-s-oracle-lang
  occurs?/s ⊆ u × t × sub
  [(occurs?/s u (t : _) sub) (occurs?/s u (walk/s t sub) sub)]
  [(occurs?/s u (_ : t) sub) (occurs?/s u (walk/s t sub) sub)]
  [(occurs?/s u_1 u_1 sub)])

(define-metafunction core-s-oracle-lang
  extend/s : u t sub -> maybe-sub
  [(extend/s u t sub) #f
   (side-condition (judgment-holds (occurs?/s u t sub)))]
  [(extend/s u t sub) ([u t] ,@(term sub))
   (side-condition (not (judgment-holds (occurs?/s u t sub))))])

(define-metafunction core-s-oracle-lang
  unify/s : t t sub -> maybe-sub
  [(unify/s u_1 u_1 sub) sub]
  [(unify/s u t sub) (extend/s u t sub)]
  [(unify/s t u sub) (extend/s u t sub)]
  [(unify/s (t_1a : t_1b) (t_2a : t_2b) sub)
   (unify/s (walk/s t_1b sub_1) (walk/s t_2b sub_1) sub_1)
   (where sub_1
          (unify/s (walk/s t_1a sub) (walk/s t_2a sub) sub))]
  [(unify/s t_1 t_1 sub) sub]
  [(unify/s _ _ _) #f])

(define-metafunction core-s-oracle-lang
  invalid?/s : sub dis -> boolean
  [(invalid?/s sub ()) #f]
  [(invalid?/s sub ((t_1 t_2) (t_3 t_4) ...))
   #t
   (where sub (unify/s (walk/s t_1 sub) (walk/s t_2 sub) sub))]
  [(invalid?/s sub ((t_1 t_2) (t_3 t_4) ...))
   (invalid?/s sub ((t_3 t_4) ...))])
