#lang racket

(require redex/reduction-semantics)

(provide core-e-oracle-lang
         support-prefix?/e
         support-extend/e
         fresh-intro/e
         walk/e
         extend/e
         occurs?/e
         unify/e
         invalid?/e)

(check-redundancy #t)

;; This is the independently stated state-local E language.  In particular,
;; it neither extends the production language nor imports the checkpointed
;; support-decorated-node prototype.
(define-language core-e-oracle-lang
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

  ;; Support is ordered allocation history.  Duplicate-freedom and closure
  ;; are semantic WF obligations rather than extra carrier decorations.
  [support (Support u_!_ ...)]
  [σ (state support sub dis trail tag)]
  [sub ((u_!_ t) ...)]
  [dis ((t t) ...)]
  [maybe-sub sub #f]
  [trail (eq ...)]
  [intro (u_!_ ...)]

  [A (Answer σ)]
  [S (Returned σ)]
  [W (Work g σ)
     (Returned σ)
     (Dead support)
     (Conj W g)]
  [F (Last A)
     (Done support)
     (More W)]

  [WorkPath hole
            (Conj WorkPath g)]
  [SpineContext hole]
  [WorkFocus (in-hole SpineContext (More WorkPath))]

  #:binding-forms
  (∃ (x ...) g #:refers-to (shadow x ...)))

(define (support-prefix?/host prefix extension)
  (match* (prefix extension)
    [(`(Support ,u_prefix ...) `(Support ,u_extension ...))
     (and (<= (length u_prefix) (length u_extension))
          (equal? u_prefix (take u_extension (length u_prefix))))]
    [(_ _) #f]))

(define (fresh-us/host support count [candidate 0] [reversed-intro '()])
  (cond
    [(zero? count) (reverse reversed-intro)]
    [else
     (define u (string->symbol (format "u:~a" candidate)))
     (if (member u support)
         (fresh-us/host support count (add1 candidate) reversed-intro)
         (fresh-us/host
          support
          (sub1 count)
          (add1 candidate)
          (cons u reversed-intro)))]))

(define-metafunction core-e-oracle-lang
  support-prefix?/e : support support -> boolean
  [(support-prefix?/e support_prefix support_extension)
   ,(support-prefix?/host
     (term support_prefix)
     (term support_extension))])

(define-metafunction core-e-oracle-lang
  support-extend/e : support intro -> support
  [(support-extend/e (Support u_visible ...) (u_new ...))
   (Support u_visible ... u_new ...)])

;; Allocation is the first count canonical u atoms absent from this state's
;; support.  No incomparable world's carrier is inspected.
(define-metafunction core-e-oracle-lang
  fresh-intro/e : support d -> intro
  [(fresh-intro/e (Support u_visible ...) (x_bound ...))
   ,(fresh-us/host
     (term (u_visible ...))
     (length (term (x_bound ...))))])

(define-metafunction core-e-oracle-lang
  walk/e : t sub -> t
  [(walk/e u (name sub (_ ... [u t] _ ...))) (walk/e t sub)]
  [(walk/e t _) t])

(define-relation core-e-oracle-lang
  occurs?/e ⊆ u × t × sub
  [(occurs?/e u (t : _) sub) (occurs?/e u (walk/e t sub) sub)]
  [(occurs?/e u (_ : t) sub) (occurs?/e u (walk/e t sub) sub)]
  [(occurs?/e u_1 u_1 sub)])

(define-metafunction core-e-oracle-lang
  extend/e : u t sub -> maybe-sub
  [(extend/e u t sub) #f
   (side-condition (judgment-holds (occurs?/e u t sub)))]
  [(extend/e u t sub) ([u t] ,@(term sub))
   (side-condition (not (judgment-holds (occurs?/e u t sub))))])

(define-metafunction core-e-oracle-lang
  unify/e : t t sub -> maybe-sub
  [(unify/e u_1 u_1 sub) sub]
  [(unify/e u t sub) (extend/e u t sub)]
  [(unify/e t u sub) (extend/e u t sub)]
  [(unify/e (t_1a : t_1b) (t_2a : t_2b) sub)
   (unify/e (walk/e t_1b sub_1) (walk/e t_2b sub_1) sub_1)
   (where sub_1 (unify/e (walk/e t_1a sub) (walk/e t_2a sub) sub))]
  [(unify/e t_1 t_1 sub) sub]
  [(unify/e _ _ _) #f])

(define-metafunction core-e-oracle-lang
  invalid?/e : sub dis -> boolean
  [(invalid?/e sub ()) #f]
  [(invalid?/e sub ((t_1 t_2) (t_3 t_4) ...))
   #t
   (where sub (unify/e (walk/e t_1 sub) (walk/e t_2 sub) sub))]
  [(invalid?/e sub ((t_1 t_2) (t_3 t_4) ...))
   (invalid?/e sub ((t_3 t_4) ...))])
