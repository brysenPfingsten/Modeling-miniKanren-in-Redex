#lang racket

(require rackunit
         redex/reduction-semantics
         "../languages/core-lang.rkt")

(provide lvar-member?
         lvars-subset?
         lvars-fresh-extension?
         wf-owner-stack?
         wf-term?
         wf-sub?
         wf-dis?
         wf-trail-unify*s-to-sub
         wf-sub/wf+equiv-trail?
         wf-state?
         symbols-in/set
         substitution-acyclic?
         acyclic-sub?)

(check-redundancy #t)

(define (symbols-in/set t [acc (set)])
  (match t
    ['() acc]
    [(? symbol?) (set-add acc t)]
    [(cons a d) (symbols-in/set a (symbols-in/set d acc))]
    [_ acc]))

(define (substitution-acyclic? pairs)
  (define dom (map first pairs))
  (define adj
    (for/hash ([(u t*) (in-dict pairs)])
      (match-define (list t) t*)
      (values u
              (for/set ([v (in-set (symbols-in/set t))]
                        #:when (member v dom))
                v))))
  (define visiting (make-hash))
  (define visited (make-hash))
  (define (visit u)
    (cond
      [(hash-ref visited u #f) #t]
      [(hash-ref visiting u #f) #f]
      [else
       (hash-set! visiting u #t)
       (define ok
         (for/and ([v (in-set (hash-ref adj u (set)))])
           (visit v)))
       (hash-remove! visiting u)
       (when ok (hash-set! visited u #t))
       ok]))
  (for/and ([u dom]) (visit u)))

(define-metafunction core-lang
  acyclic-sub? : sub -> boolean
  [(acyclic-sub? sub)
   ,(substitution-acyclic? (term sub))])

(define-judgment-form
  core-lang
  #:contract (lvar-member? u intro)
  #:mode (lvar-member? I I)
  [-------- "lvar member"
   (lvar-member? u (u_1 ... u u_2 ...))])

(define-judgment-form
  core-lang
  #:contract (lvars-subset? intro intro)
  #:mode (lvars-subset? I I)
  [------------------- "empty subset"
   (lvars-subset? () intro)]
  [(lvar-member? u intro_2)
   (lvars-subset? (u_rest ...) intro_2)
   ------------------- "cons subset"
   (lvars-subset? (u u_rest ...) intro_2)])

(define (lvars-fresh-extension?/host intro visible-intros)
  (and (= (length intro)
          (length (remove-duplicates intro)))
       (for/and ([u (in-list intro)])
         (not (member u visible-intros)))))

(define-judgment-form
  core-lang
  #:contract (lvars-fresh-extension? intro intro)
  #:mode (lvars-fresh-extension? I I)
  [(where #t
          ,(lvars-fresh-extension?/host
            (term intro_new)
            (term intro_visible)))
   ------------------- "fresh visible introduction"
   (lvars-fresh-extension? intro_new intro_visible)])

(define-judgment-form
  core-lang
  #:contract (wf-owner-stack? owners intro intro)
  #:mode (wf-owner-stack? I I O)
  [------------------- "empty owner stack"
   (wf-owner-stack? (Owners) intro_visible intro_visible)]
  [(lvars-fresh-extension? (u_new ...) (u_visible ...))
   (wf-owner-stack?
    (Owners owner_rest ...)
    (u_visible ... u_new ...)
    intro_body)
   ------------------- "well-formed owner stack"
   (wf-owner-stack?
    (Owners (Owner (u_new ...) tag) owner_rest ...)
    (u_visible ...)
    intro_body)])

(define-judgment-form
  core-lang
  #:contract (wf-term? t (x ...) intro)
  #:mode (wf-term? I I I)
  [(lvar-member? u intro)
   -------------- "logic variable is visibly introduced"
   (wf-term? u (x ...) intro)]
  [-------------- "primitive terms are well formed"
   (wf-term? pt (x ...) intro)]
  [(wf-term? t_2 (x ...) intro)
   (wf-term? t_1 (x ...) intro)
   -------------- "pairs are componentwise well formed"
   (wf-term? (t_1 : t_2) (x ...) intro)]
  [-------------- "lexical variable is bound"
   (wf-term? x_2 (x_1 ... x_2 x_3 ...) intro)])

(define-judgment-form
  core-lang
  #:contract (wf-sub? sub intro)
  #:mode (wf-sub? I I)
  [(wf-term? t () intro) ...
   (lvar-member? u intro) ...
   (where #t (acyclic-sub? ([u t] ...)))
   ------------------ "substitution is closed under visible introductions"
   (wf-sub? ([u t] ...) intro)])

(define-judgment-form
  core-lang
  #:contract (wf-dis? dis intro)
  #:mode (wf-dis? I I)
  [------------------ "empty disequality store"
   (wf-dis? () intro)]
  [(wf-term? t_1 () intro)
   (wf-term? t_2 () intro)
   (wf-dis? ((t_3 t_4) ...) intro)
   ------------------ "well-formed disequality pair"
   (wf-dis? ((t_1 t_2) (t_3 t_4) ...) intro)])

(define-judgment-form
  core-lang
  #:contract (wf-trail-unify*s-to-sub (eq ...) intro sub sub)
  #:mode (wf-trail-unify*s-to-sub I I I I)
  [------------------- "empty trail yields accumulator"
   (wf-trail-unify*s-to-sub () intro sub sub)]
  [(where sub_acc2 (unify (walk t_1 sub_acc) (walk t_2 sub_acc) sub_acc))
   (wf-term? t_1 () intro)
   (wf-term? t_2 () intro)
   (wf-trail-unify*s-to-sub (eq ...) intro sub_acc2 sub)
   ------------------- "trail step is well formed and unifies"
   (wf-trail-unify*s-to-sub
    ((t_1 =? t_2 tag) eq ...)
    intro
    sub_acc
    sub)])

(define-judgment-form
  core-lang
  #:contract (wf-sub/wf+equiv-trail? sub intro trail)
  #:mode (wf-sub/wf+equiv-trail? I I I)
  [(wf-sub? sub intro)
   (wf-trail-unify*s-to-sub (eq ...) intro () sub)
   ------------------- "substitution agrees with trail"
   (wf-sub/wf+equiv-trail? sub intro (eq ...))])

(define-judgment-form
  core-lang
  #:contract (wf-state? σ intro)
  #:mode (wf-state? I I)
  [(wf-sub/wf+equiv-trail? sub intro trail)
   (wf-dis? dis intro)
   ----------------------- "state is closed under visible introductions"
   (wf-state? (state sub dis trail tag) intro)])

(module+ test
  (check-true (judgment-holds (lvar-member? u:0 (u:0))))
  (check-equal?
   (judgment-holds
    (wf-owner-stack?
     (Owners
      (Owner (u:0 u:1) (label "outer"))
      (Owner (u:2) (label "inner")))
     ()
     intro_body)
    intro_body)
   '((u:0 u:1 u:2)))
  (check-equal?
   (judgment-holds
    (wf-owner-stack?
     (Owners (Owner () (label "empty")))
     (u:0)
     intro_body)
    intro_body)
   '((u:0)))
  (check-false
   (judgment-holds
    (wf-owner-stack?
     (Owners
      (Owner (u:0) (label "outer"))
      (Owner (u:0) (label "inner")))
     ()
     intro_body)))
  (check-true (judgment-holds (wf-term? (sym "a") () ())))
  (check-true (judgment-holds (wf-sub? ((u:0 (sym "x"))) (u:0))))
  (check-true
   (judgment-holds
    (wf-state? (state () () () (label "state")) ()))))
