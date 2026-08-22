#lang racket

(require redex/reduction-semantics
         "./language.rkt")

(provide state-next/n
         level-below-next/n?
         acyclic-sub?/n
         wf-t-oracle/n?
         wf-sub-oracle/n?
         wf-dis-oracle/n?
         wf-trail-oracle/n?
         wf-state-oracle/n?
         wf-g-oracle/n?
         wf-A-oracle/n?
         wf-S-oracle/n?
         live-next-oracle/n?
         wf-W-oracle/n?
         wf-F-oracle/n?
         wf-core-oracle/n?)

(check-redundancy #t)

(define (runtime-levels-in-term/n term [levels '()])
  (match term
    [`(nat ,_) levels]
    [`(sym ,_) levels]
    [`(str ,_) levels]
    [`(,left : ,right)
     (runtime-levels-in-term/n
      left
      (runtime-levels-in-term/n right levels))]
    [(? exact-nonnegative-integer? level)
     (if (member level levels) levels (cons level levels))]
    [_ levels]))

(define (sub-dependencies/n level substitution)
  (match (assoc level substitution)
    [(list _ term) (runtime-levels-in-term/n term)]
    [#f '()]))

(define (acyclic-from/n? level substitution [path '()])
  (and (not (member level path))
       (for/and ([dependency
                  (in-list (sub-dependencies/n level substitution))]
                 #:when (assoc dependency substitution))
         (acyclic-from/n? dependency substitution (cons level path)))))

(define (substitution-acyclic/n? substitution)
  (for/and ([level (in-list (map first substitution))])
    (acyclic-from/n? level substitution)))

(define-metafunction core-n-oracle-lang
  state-next/n : σ -> next
  [(state-next/n (state next sub dis trail tag)) next])

(define-metafunction core-n-oracle-lang
  acyclic-sub?/n : sub -> boolean
  [(acyclic-sub?/n sub)
   ,(substitution-acyclic/n? (term sub))])

(define-judgment-form
  core-n-oracle-lang
  #:contract (level-below-next/n? lv next)
  #:mode (level-below-next/n? I I)
  [(where #t ,(< (term lv) (term next)))
   ---------------------------------------------------- "level is allocated"
   (level-below-next/n? lv next)])

(define-judgment-form
  core-n-oracle-lang
  #:contract (wf-t-oracle/n? t (x ...) next)
  #:mode (wf-t-oracle/n? I I I)

  [(level-below-next/n? lv next)
   ---------------------------------------------------- "runtime level is allocated/n"
   (wf-t-oracle/n? lv (x_bound ...) next)]

  [---------------------------------------------------- "primitive term/n"
   (wf-t-oracle/n? pt (x_bound ...) next)]

  [(wf-t-oracle/n? t_1 (x_bound ...) next)
   (wf-t-oracle/n? t_2 (x_bound ...) next)
   ---------------------------------------------------- "pair term/n"
   (wf-t-oracle/n? (t_1 : t_2) (x_bound ...) next)]

  [---------------------------------------------------- "bound lexical variable/n"
   (wf-t-oracle/n? x (x_1 ... x x_2 ...) next)])

(define-judgment-form
  core-n-oracle-lang
  #:contract (wf-sub-oracle/n? sub next)
  #:mode (wf-sub-oracle/n? I I)
  [(level-below-next/n? lv next) ...
   (wf-t-oracle/n? t () next) ...
   (where #t (acyclic-sub?/n ((lv t) ...)))
   ---------------------------------------------------- "substitution closed below next/n"
   (wf-sub-oracle/n? ((lv t) ...) next)])

(define-judgment-form
  core-n-oracle-lang
  #:contract (wf-dis-oracle/n? dis next)
  #:mode (wf-dis-oracle/n? I I)

  [---------------------------------------------------- "empty disequalities/n"
   (wf-dis-oracle/n? () next)]

  [(wf-t-oracle/n? t_1 () next)
   (wf-t-oracle/n? t_2 () next)
   (wf-dis-oracle/n? ((t_3 t_4) ...) next)
   ---------------------------------------------------- "disequality store/n"
   (wf-dis-oracle/n? ((t_1 t_2) (t_3 t_4) ...) next)])

(define-judgment-form
  core-n-oracle-lang
  #:contract (wf-trail-oracle/n? trail next sub sub)
  #:mode (wf-trail-oracle/n? I I I I)

  [---------------------------------------------------- "empty trail replay/n"
   (wf-trail-oracle/n? () next sub sub)]

  [(wf-t-oracle/n? t_1 () next)
   (wf-t-oracle/n? t_2 () next)
   (where sub_next
          (unify/n (walk/n t_1 sub_acc)
                   (walk/n t_2 sub_acc)
                   sub_acc))
   (wf-trail-oracle/n? (eq_rest ...) next sub_next sub_final)
   ---------------------------------------------------- "trail replay step/n"
   (wf-trail-oracle/n?
    ((t_1 =? t_2 tag) eq_rest ...)
    next
    sub_acc
    sub_final)])

(define-judgment-form
  core-n-oracle-lang
  #:contract (wf-state-oracle/n? σ)
  #:mode (wf-state-oracle/n? I)
  [(wf-sub-oracle/n? sub next)
   (wf-dis-oracle/n? dis next)
   (wf-trail-oracle/n? trail next () sub)
   ---------------------------------------------------- "state closed below its sole next/n"
   (wf-state-oracle/n? (state next sub dis trail tag))])

(define-judgment-form
  core-n-oracle-lang
  #:contract (wf-g-oracle/n? g (x ...) next)
  #:mode (wf-g-oracle/n? I I I)

  [---------------------------------------------------- "succeed goal/n"
   (wf-g-oracle/n? (succeed tag) (x_bound ...) next)]

  [---------------------------------------------------- "fail goal/n"
   (wf-g-oracle/n? (fail tag) (x_bound ...) next)]

  [(wf-t-oracle/n? t_1 (x_bound ...) next)
   (wf-t-oracle/n? t_2 (x_bound ...) next)
   ---------------------------------------------------- "unification goal/n"
   (wf-g-oracle/n? (t_1 =? t_2 tag) (x_bound ...) next)]

  [(wf-t-oracle/n? t_1 (x_bound ...) next)
   (wf-t-oracle/n? t_2 (x_bound ...) next)
   ---------------------------------------------------- "disequality goal/n"
   (wf-g-oracle/n? (t_1 != t_2 tag) (x_bound ...) next)]

  [(wf-g-oracle/n? g (x_fresh ... x_bound ...) next)
   ---------------------------------------------------- "fresh goal/n"
   (wf-g-oracle/n?
    (∃ (x_fresh ...) g tag)
    (x_bound ...)
    next)]

  [(wf-g-oracle/n? g_1 (x_bound ...) next)
   (wf-g-oracle/n? g_2 (x_bound ...) next)
   ---------------------------------------------------- "conjunction goal/n"
   (wf-g-oracle/n?
    (g_1 ∧ g_2 tag)
    (x_bound ...)
    next)])

(define-judgment-form
  core-n-oracle-lang
  #:contract (wf-A-oracle/n? A)
  #:mode (wf-A-oracle/n? I)
  [(wf-state-oracle/n? σ)
   ---------------------------------------------------- "answer/n"
   (wf-A-oracle/n? (Answer σ))])

(define-judgment-form
  core-n-oracle-lang
  #:contract (wf-S-oracle/n? S)
  #:mode (wf-S-oracle/n? I)
  [(wf-state-oracle/n? σ)
   ---------------------------------------------------- "returned/n"
   (wf-S-oracle/n? (Returned σ))])

(define-judgment-form
  core-n-oracle-lang
  #:contract (live-next-oracle/n? W next)
  #:mode (live-next-oracle/n? I O)

  [---------------------------------------------------- "work exposes next/n"
   (live-next-oracle/n?
    (Work g (state next sub dis trail tag))
    next)]

  [---------------------------------------------------- "return exposes next/n"
   (live-next-oracle/n?
    (Returned (state next sub dis trail tag))
    next)]

  [---------------------------------------------------- "failure exposes retained next/n"
   (live-next-oracle/n? (Dead next) next)]

  [(live-next-oracle/n? W next)
   ---------------------------------------------------- "next through active path/n"
   (live-next-oracle/n? (Conj W g) next)])

(define-judgment-form
  core-n-oracle-lang
  #:contract (wf-W-oracle/n? W)
  #:mode (wf-W-oracle/n? I)

  [(wf-state-oracle/n? σ)
   (where next (state-next/n σ))
   (wf-g-oracle/n? g () next)
   ---------------------------------------------------- "work/n"
   (wf-W-oracle/n? (Work g σ))]

  [(wf-state-oracle/n? σ)
   ---------------------------------------------------- "returned work/n"
   (wf-W-oracle/n? (Returned σ))]

  [---------------------------------------------------- "dead work retains next/n"
   (wf-W-oracle/n? (Dead next))]

  [(wf-W-oracle/n? W)
   (live-next-oracle/n? W next)
   (wf-g-oracle/n? g () next)
   ---------------------------------------------------- "conjunction under exposed next/n"
   (wf-W-oracle/n? (Conj W g))])

(define-judgment-form
  core-n-oracle-lang
  #:contract (wf-F-oracle/n? F)
  #:mode (wf-F-oracle/n? I)

  [(wf-W-oracle/n? W)
   ---------------------------------------------------- "unfinished frontier/n"
   (wf-F-oracle/n? (More W))]

  [(wf-A-oracle/n? A)
   ---------------------------------------------------- "last answer/n"
   (wf-F-oracle/n? (Last A))]

  [---------------------------------------------------- "done retains next/n"
   (wf-F-oracle/n? (Done next))])

(define-judgment-form
  core-n-oracle-lang
  #:contract (wf-core-oracle/n? F)
  #:mode (wf-core-oracle/n? I)
  [(wf-F-oracle/n? F)
   ---------------------------------------------------- "core N root"
   (wf-core-oracle/n? F)])

(module+ test
  (require rackunit)

  (check-true
   (judgment-holds
    (wf-state-oracle/n?
     (state 1 ((0 (sym "cat"))) ()
            ((0 =? (sym "cat") (label "bind")))
            (label "state")))))
  (check-false
   (judgment-holds
    (wf-state-oracle/n?
     (state 1 ((1 (sym "cat"))) ()
            ((1 =? (sym "cat") (label "unallocated")))
            (label "state")))))
  (check-false
   (judgment-holds
    (wf-state-oracle/n?
     (state 2 ((0 1) (1 0)) () () (label "cyclic"))))))
