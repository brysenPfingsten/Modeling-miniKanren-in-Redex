#lang racket

(require redex/reduction-semantics
         "./language.rkt")

(provide u-symbol/s?
         logic-variables-in/s
         substitution-acyclic?/s
         acyclic-sub-oracle/s?
         intro-member-oracle/s?
         fresh-intro-extension-oracle/s?
         wf-owner-stack-oracle/s?
         wf-term-oracle/s?
         wf-sub-oracle/s?
         wf-dis-oracle/s?
         wf-trail-to-sub-oracle/s?
         wf-state-oracle/s?
         wf-g-oracle/s?
         wf-A-oracle/s?
         wf-S-oracle/s?
         wf-W-oracle/s?
         wf-F-oracle/s?
         wf-core-oracle/s?)

(check-redundancy #t)

(define (u-symbol/s? datum)
  (and (symbol? datum)
       (regexp-match? #rx"^u:" (symbol->string datum))))

(define (logic-variables-in/s datum [acc '()])
  (match datum
    ['() acc]
    [(? u-symbol/s? u)
     (if (member u acc) acc (cons u acc))]
    [(cons a d)
     (logic-variables-in/s a (logic-variables-in/s d acc))]
    [_ acc]))

(define (substitution-dependencies/s u substitution)
  (match (assoc u substitution)
    [(list _ t)
     (define domain (map first substitution))
     (filter (lambda (dependency) (member dependency domain))
             (logic-variables-in/s t))]
    [#f '()]))

(define (acyclic-from/s u substitution [path '()])
  (and (not (member u path))
       (for/and ([dependency
                  (in-list
                   (substitution-dependencies/s u substitution))])
         (acyclic-from/s dependency substitution (cons u path)))))

(define (substitution-acyclic?/s substitution)
  (for/and ([u (in-list (map first substitution))])
    (acyclic-from/s u substitution)))

(define-metafunction core-s-oracle-lang
  acyclic-sub-oracle/s? : sub -> boolean
  [(acyclic-sub-oracle/s? sub)
   ,(substitution-acyclic?/s (term sub))])

(define-judgment-form
  core-s-oracle-lang
  #:contract (intro-member-oracle/s? u intro)
  #:mode (intro-member-oracle/s? I I)
  [----------------------------------------------- "introduced variable member/s"
   (intro-member-oracle/s? u (u_before ... u u_after ...))])

(define (fresh-intro-extension?/s intro visible)
  (and (= (length intro) (length (remove-duplicates intro)))
       (for/and ([u (in-list intro)])
         (not (member u visible)))))

(define-judgment-form
  core-s-oracle-lang
  #:contract (fresh-intro-extension-oracle/s? intro intro)
  #:mode (fresh-intro-extension-oracle/s? I I)
  [(where #t
          ,(fresh-intro-extension?/s
            (term intro_new)
            (term intro_visible)))
   ----------------------------------------------- "fresh path introduction/s"
   (fresh-intro-extension-oracle/s? intro_new intro_visible)])

;; The third argument is the ordered cumulative support after the Owner
;; sequence.  Each Owner group is preserved even when its intro is empty.
(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-owner-stack-oracle/s? owners intro intro)
  #:mode (wf-owner-stack-oracle/s? I I O)
  [----------------------------------------------- "empty owner sequence/s"
   (wf-owner-stack-oracle/s?
    (Owners)
    intro_visible
    intro_visible)]
  [(fresh-intro-extension-oracle/s? (u_new ...) (u_visible ...))
   (wf-owner-stack-oracle/s?
    (Owners owner_rest ...)
    (u_visible ... u_new ...)
    intro_body)
   ----------------------------------------------- "ordered owner sequence/s"
   (wf-owner-stack-oracle/s?
    (Owners (Owner (u_new ...) tag) owner_rest ...)
    (u_visible ...)
    intro_body)])

(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-term-oracle/s? t (x ...) intro)
  #:mode (wf-term-oracle/s? I I I)
  [(intro-member-oracle/s? u intro_visible)
   ----------------------------------------------- "introduced runtime variable/s"
   (wf-term-oracle/s? u (x_bound ...) intro_visible)]
  [----------------------------------------------- "primitive term/s"
   (wf-term-oracle/s? pt (x_bound ...) intro_visible)]
  [(wf-term-oracle/s? t_1 (x_bound ...) intro_visible)
   (wf-term-oracle/s? t_2 (x_bound ...) intro_visible)
   ----------------------------------------------- "pair term/s"
   (wf-term-oracle/s?
    (t_1 : t_2)
    (x_bound ...)
    intro_visible)]
  [----------------------------------------------- "bound lexical variable/s"
   (wf-term-oracle/s?
    x
    (x_before ... x x_after ...)
    intro_visible)])

(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-sub-oracle/s? sub intro)
  #:mode (wf-sub-oracle/s? I I)
  [(intro-member-oracle/s? u intro_visible) ...
   (wf-term-oracle/s? t () intro_visible) ...
   (where #t (acyclic-sub-oracle/s? ([u t] ...)))
   ----------------------------------------------- "closed acyclic substitution/s"
   (wf-sub-oracle/s? ([u t] ...) intro_visible)])

(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-dis-oracle/s? dis intro)
  #:mode (wf-dis-oracle/s? I I)
  [----------------------------------------------- "empty disequality store/s"
   (wf-dis-oracle/s? () intro_visible)]
  [(wf-term-oracle/s? t_1 () intro_visible)
   (wf-term-oracle/s? t_2 () intro_visible)
   (wf-dis-oracle/s? ((t_3 t_4) ...) intro_visible)
   ----------------------------------------------- "disequality store/s"
   (wf-dis-oracle/s?
    ((t_1 t_2) (t_3 t_4) ...)
    intro_visible)])

;; Replaying the named unification trail from the empty substitution must
;; recover the stored substitution exactly.  This is stronger than mere name
;; coverage and is preserved by the source clauses below.
(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-trail-to-sub-oracle/s? trail intro sub sub)
  #:mode (wf-trail-to-sub-oracle/s? I I I I)
  [----------------------------------------------- "empty trail accumulator/s"
   (wf-trail-to-sub-oracle/s? () intro_visible sub sub)]
  [(wf-term-oracle/s? t_1 () intro_visible)
   (wf-term-oracle/s? t_2 () intro_visible)
   (where sub_next
          (unify/s
           (walk/s t_1 sub_acc)
           (walk/s t_2 sub_acc)
           sub_acc))
   (wf-trail-to-sub-oracle/s?
    (eq_rest ...)
    intro_visible
    sub_next
    sub_final)
   ----------------------------------------------- "replay trail equation/s"
   (wf-trail-to-sub-oracle/s?
    ((t_1 =? t_2 tag) eq_rest ...)
    intro_visible
    sub_acc
    sub_final)])

(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-state-oracle/s? σ intro)
  #:mode (wf-state-oracle/s? I I)
  [(wf-sub-oracle/s? sub intro_visible)
   (wf-dis-oracle/s? dis intro_visible)
   (wf-trail-to-sub-oracle/s?
    (eq ...)
    intro_visible
    ()
    sub)
   ----------------------------------------------- "closed logical state/s"
   (wf-state-oracle/s?
    (state sub dis (eq ...) tag)
    intro_visible)])

(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-g-oracle/s? g (x ...) intro)
  #:mode (wf-g-oracle/s? I I I)
  [----------------------------------------------- "success goal/s"
   (wf-g-oracle/s? (succeed tag) (x_bound ...) intro_visible)]
  [----------------------------------------------- "failure goal/s"
   (wf-g-oracle/s? (fail tag) (x_bound ...) intro_visible)]
  [(wf-term-oracle/s? t_1 (x_bound ...) intro_visible)
   (wf-term-oracle/s? t_2 (x_bound ...) intro_visible)
   ----------------------------------------------- "unification goal/s"
   (wf-g-oracle/s?
    (t_1 =? t_2 tag)
    (x_bound ...)
    intro_visible)]
  [(wf-term-oracle/s? t_1 (x_bound ...) intro_visible)
   (wf-term-oracle/s? t_2 (x_bound ...) intro_visible)
   ----------------------------------------------- "disequality goal/s"
   (wf-g-oracle/s?
    (t_1 != t_2 tag)
    (x_bound ...)
    intro_visible)]
  [(wf-g-oracle/s?
    g
    (x_fresh ... x_bound ...)
    intro_visible)
   ----------------------------------------------- "fresh goal/s"
   (wf-g-oracle/s?
    (∃ (x_fresh ...) g tag)
    (x_bound ...)
    intro_visible)]
  [(wf-g-oracle/s? g_1 (x_bound ...) intro_visible)
   (wf-g-oracle/s? g_2 (x_bound ...) intro_visible)
   ----------------------------------------------- "conjunction goal/s"
   (wf-g-oracle/s?
    (g_1 ∧ g_2 tag)
    (x_bound ...)
    intro_visible)])

(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-A-oracle/s? A intro)
  #:mode (wf-A-oracle/s? I I)
  [(wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-state-oracle/s? σ intro_body)
   ----------------------------------------------- "answer/s"
   (wf-A-oracle/s? (Answer owners σ) intro_visible)])

(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-S-oracle/s? S intro)
  #:mode (wf-S-oracle/s? I I)
  [(wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-state-oracle/s? σ intro_body)
   ----------------------------------------------- "returned work/s"
   (wf-S-oracle/s? (Returned owners σ) intro_visible)])

(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-W-oracle/s? W intro)
  #:mode (wf-W-oracle/s? I I)
  [(wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-g-oracle/s? g () intro_body)
   (wf-state-oracle/s? σ intro_body)
   ----------------------------------------------- "active work/s"
   (wf-W-oracle/s? (Work owners g σ) intro_visible)]
  [(wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-state-oracle/s? σ intro_body)
   ----------------------------------------------- "returned work carrier/s"
   (wf-W-oracle/s? (Returned owners σ) intro_visible)]
  [(wf-owner-stack-oracle/s? owners intro_visible intro_body)
   ----------------------------------------------- "dead work/s"
   (wf-W-oracle/s? (Dead owners) intro_visible)]
  [(wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-W-oracle/s? W intro_body)
   ;; The future right goal exists at this frame's prefix.  Allocations made
   ;; exclusively while running the left child are not in its lexical scope.
   (wf-g-oracle/s? g () intro_body)
   ----------------------------------------------- "conjunction frame/s"
   (wf-W-oracle/s?
    (Conj owners W g)
    intro_visible)])

(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-F-oracle/s? F intro)
  #:mode (wf-F-oracle/s? I I)
  [(wf-W-oracle/s? W intro_visible)
   ----------------------------------------------- "unfinished frontier/s"
   (wf-F-oracle/s? (More W) intro_visible)]
  [(wf-owner-stack-oracle/s? owners intro_visible intro_body)
   ----------------------------------------------- "failed terminal/s"
   (wf-F-oracle/s? (Done owners) intro_visible)]
  [(wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-A-oracle/s? A intro_body)
   ----------------------------------------------- "successful terminal/s"
   (wf-F-oracle/s? (Last owners A) intro_visible)])

(define-judgment-form
  core-s-oracle-lang
  #:contract (wf-core-oracle/s? F)
  #:mode (wf-core-oracle/s? I)
  [(wf-F-oracle/s? F ())
   ----------------------------------------------- "root core S frontier"
   (wf-core-oracle/s? F)])
