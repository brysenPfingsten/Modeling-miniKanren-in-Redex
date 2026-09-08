#lang racket

(require redex/reduction-semantics)

(provide core-lang
         owners-append
         unify
         walk
         extend
         occurs?
         invalid?)

(check-redundancy #t)

;; The runtime carrier is phase-stratified. W is unfinished work and F is the
;; whole answer frontier. The distinction is grammatical
(define-language core-lang
  [d (x_!_ ...)]

  [eq (t =? t tag)]

  ;; Goal vocabulary
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
  [trail (eq ...)] ;; disequalities are stored separately in dis
  [intro (u_!_ ...)]
  [owner (Owner intro tag)]
  [owners (Owners owner ...)]

  [A (Answer owners σ)]

  ;; Settled success is a derived grammatical subset of W.
  [S (Returned owners σ)]

  [W (Work owners g σ)
     (Returned owners σ)
     (Dead owners)
     (Conj owners W g)]

  [F (Last owners A)
     (Done owners)
     (More W)]

  ;; Select the leading owner field of exactly one work constructor. Feature
  ;; languages extend this slot when they add work constructors.
  [WorkOwnerSlot (Work hole g σ)
                 (Returned hole σ)
                 (Dead hole)
                 (Conj hole W g)]

  [WorkPath hole (Conj owners WorkPath g)]

  [SpineContext hole]

  [WorkFocus (in-hole SpineContext (More WorkPath))]

  #:binding-forms
  (∃ (x ...) g #:refers-to (shadow x ...)))

(define-metafunction core-lang
  owners-append : owners owners -> owners
  [(owners-append (Owners owner_outer ...) (Owners owner_inner ...))
   (Owners owner_outer ... owner_inner ...)])

(define-metafunction core-lang
  walk : t sub -> t
  [(walk u (name sub (_ ... [u t] _ ...))) (walk t sub)]
  [(walk t _) t])

(define-metafunction core-lang
  invalid? : sub dis -> boolean
  [(invalid? sub ()) #f]
  [(invalid? sub ((t_1 t_2) (t_3 t_4) ...))
   #t
   (where sub (unify (walk t_1 sub) (walk t_2 sub) sub))]
  [(invalid? sub ((t_1 t_2) (t_3 t_4) ...))
   (invalid? sub ((t_3 t_4) ...))])

(define-relation core-lang
  occurs? ⊆ u × t × sub
  [(occurs? u (t : _) sub) (occurs? u (walk t sub) sub)]
  [(occurs? u (_ : t) sub) (occurs? u (walk t sub) sub)]
  [(occurs? u_1 u_1 sub)])

(define-metafunction core-lang
  extend : u t sub -> maybe-sub
  [(extend u t sub) #f
   (side-condition (judgment-holds (occurs? u t sub)))]
  [(extend u t sub) ([u t] ,@(term sub))
   (side-condition (not (judgment-holds (occurs? u t sub))))])

(define-metafunction core-lang
  unify : t t sub -> maybe-sub
  [(unify u_1 u_1 sub) sub]
  [(unify u t sub) (extend u t sub)]
  [(unify t u sub) (extend u t sub)]
  [(unify (t_1a : t_1b) (t_2a : t_2b) sub)
   (unify (walk t_1b sub_1) (walk t_2b sub_1) sub_1)
   (where sub_1 (unify (walk t_1a sub) (walk t_2a sub) sub))]
  [(unify t_1 t_1 sub) sub]
  [(unify _ _ _) #f])
