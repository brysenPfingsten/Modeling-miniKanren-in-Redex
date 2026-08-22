#lang racket

(require redex/reduction-semantics
         "./language.rkt")

(provide state-support/e
         u-member-oracle/e?
         wf-support-oracle/e?
         wf-t-oracle/e?
         wf-sub-oracle/e?
         wf-dis-oracle/e?
         wf-state-oracle/e?
         wf-g-oracle/e?
         wf-A-oracle/e?
         wf-S-oracle/e?
         live-support-oracle/e?
         dead-left-oracle/e?
         wf-W-oracle/e?
         wf-F-oracle/e?
         wf-core-oracle/e?)

(check-redundancy #t)

(define (symbols-in/e datum [acc (set)])
  (match datum
    ['() acc]
    [(? symbol?) (set-add acc datum)]
    [(cons first rest)
     (symbols-in/e first (symbols-in/e rest acc))]
    [_ acc]))

(define (substitution-acyclic?/e pairs)
  (define domain (map first pairs))
  (define adjacency
    (for/hash ([(u term*) (in-dict pairs)])
      (match-define (list term) term*)
      (values
       u
       (for/set ([v (in-set (symbols-in/e term))]
                 #:when (member v domain))
         v))))
  (define visiting (make-hash))
  (define visited (make-hash))
  (define (visit/e u)
    (cond
      [(hash-ref visited u #f) #t]
      [(hash-ref visiting u #f) #f]
      [else
       (hash-set! visiting u #t)
       (define acyclic?
         (for/and ([v (in-set (hash-ref adjacency u (set)))])
           (visit/e v)))
       (hash-remove! visiting u)
       (when acyclic?
         (hash-set! visited u #t))
       acyclic?]))
  (for/and ([u (in-list domain)])
    (visit/e u)))

(define (duplicate-free-support?/e support)
  (match support
    [`(Support ,u ...)
     (= (length u) (length (remove-duplicates u)))]
    [_ #f]))

(define-metafunction core-e-oracle-lang
  state-support/e : σ -> support
  [(state-support/e (state support sub dis trail tag)) support])

(define-metafunction core-e-oracle-lang
  acyclic-sub?/e : sub -> boolean
  [(acyclic-sub?/e sub)
   ,(substitution-acyclic?/e (term sub))])

(define-judgment-form
  core-e-oracle-lang
  #:contract (u-member-oracle/e? u support)
  #:mode (u-member-oracle/e? I I)
  [---------------------------------------------------- "runtime atom is in state support"
   (u-member-oracle/e? u (Support u_1 ... u u_2 ...))])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-support-oracle/e? support)
  #:mode (wf-support-oracle/e? I)
  [(where #t ,(duplicate-free-support?/e (term support)))
   ---------------------------------------------------- "ordered duplicate-free support"
   (wf-support-oracle/e? support)])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-t-oracle/e? t (x ...) support)
  #:mode (wf-t-oracle/e? I I I)

  [(u-member-oracle/e? u support)
   ---------------------------------------------------- "runtime atom is allocated/e"
   (wf-t-oracle/e? u (x_bound ...) support)]

  [---------------------------------------------------- "primitive term/e"
   (wf-t-oracle/e? pt (x_bound ...) support)]

  [(wf-t-oracle/e? t_1 (x_bound ...) support)
   (wf-t-oracle/e? t_2 (x_bound ...) support)
   ---------------------------------------------------- "pair term/e"
   (wf-t-oracle/e? (t_1 : t_2) (x_bound ...) support)]

  [---------------------------------------------------- "bound lexical variable/e"
   (wf-t-oracle/e? x (x_1 ... x x_2 ...) support)])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-sub-oracle/e? sub support)
  #:mode (wf-sub-oracle/e? I I)
  [(u-member-oracle/e? u support) ...
   (wf-t-oracle/e? t () support) ...
   (where #t (acyclic-sub?/e ([u t] ...)))
   ---------------------------------------------------- "substitution closed by state support/e"
   (wf-sub-oracle/e? ([u t] ...) support)])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-dis-oracle/e? dis support)
  #:mode (wf-dis-oracle/e? I I)

  [---------------------------------------------------- "empty disequality store/e"
   (wf-dis-oracle/e? () support)]

  [(wf-t-oracle/e? t_1 () support)
   (wf-t-oracle/e? t_2 () support)
   (wf-dis-oracle/e? ((t_3 t_4) ...) support)
   ---------------------------------------------------- "disequality store pair/e"
   (wf-dis-oracle/e? ((t_1 t_2) (t_3 t_4) ...) support)])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-trail-oracle/e? trail support sub sub)
  #:mode (wf-trail-oracle/e? I I I I)

  [---------------------------------------------------- "empty trail/e"
   (wf-trail-oracle/e? () support sub sub)]

  [(wf-t-oracle/e? t_1 () support)
   (wf-t-oracle/e? t_2 () support)
   (where sub_2
          (unify/e (walk/e t_1 sub_acc) (walk/e t_2 sub_acc) sub_acc))
   (wf-trail-oracle/e? (eq_rest ...) support sub_2 sub)
   ---------------------------------------------------- "unification trail step/e"
   (wf-trail-oracle/e?
    ((t_1 =? t_2 tag) eq_rest ...)
    support
    sub_acc
    sub)])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-state-oracle/e? σ)
  #:mode (wf-state-oracle/e? I)
  [(wf-support-oracle/e? support)
   (wf-sub-oracle/e? sub support)
   (wf-dis-oracle/e? dis support)
   (wf-trail-oracle/e? trail support () sub)
   ---------------------------------------------------- "state closed by its sole support/e"
   (wf-state-oracle/e? (state support sub dis trail tag))])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-g-oracle/e? g (x ...) support)
  #:mode (wf-g-oracle/e? I I I)

  [---------------------------------------------------- "succeed goal/e"
   (wf-g-oracle/e? (succeed tag) (x_bound ...) support)]

  [---------------------------------------------------- "fail goal/e"
   (wf-g-oracle/e? (fail tag) (x_bound ...) support)]

  [(wf-t-oracle/e? t_1 (x_bound ...) support)
   (wf-t-oracle/e? t_2 (x_bound ...) support)
   ---------------------------------------------------- "unification goal/e"
   (wf-g-oracle/e? (t_1 =? t_2 tag) (x_bound ...) support)]

  [(wf-t-oracle/e? t_1 (x_bound ...) support)
   (wf-t-oracle/e? t_2 (x_bound ...) support)
   ---------------------------------------------------- "disequality goal/e"
   (wf-g-oracle/e? (t_1 != t_2 tag) (x_bound ...) support)]

  [(wf-g-oracle/e?
    g
    (x_fresh ... x_bound ...)
    support)
   ---------------------------------------------------- "fresh goal/e"
   (wf-g-oracle/e?
    (∃ (x_fresh ...) g tag)
    (x_bound ...)
    support)]

  [(wf-g-oracle/e? g_1 (x_bound ...) support)
   (wf-g-oracle/e? g_2 (x_bound ...) support)
   ---------------------------------------------------- "conjunction goal/e"
   (wf-g-oracle/e?
    (g_1 ∧ g_2 tag)
    (x_bound ...)
    support)])

;; A failed left conjunct has discarded its state exactly as the frozen
;; carrier contract requires.  The continuation can never run, so these two
;; judgments retain only its lexical-closure obligation.  They deliberately
;; do not invent a replacement support for its runtime atoms.
(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-unreachable-t-oracle/e? t (x ...))
  #:mode (wf-unreachable-t-oracle/e? I I)

  [---------------------------------------------------- "unreachable runtime atom/e"
   (wf-unreachable-t-oracle/e? u (x_bound ...))]

  [---------------------------------------------------- "unreachable primitive/e"
   (wf-unreachable-t-oracle/e? pt (x_bound ...))]

  [(wf-unreachable-t-oracle/e? t_1 (x_bound ...))
   (wf-unreachable-t-oracle/e? t_2 (x_bound ...))
   ---------------------------------------------------- "unreachable pair/e"
   (wf-unreachable-t-oracle/e? (t_1 : t_2) (x_bound ...))]

  [---------------------------------------------------- "unreachable bound lexical variable/e"
   (wf-unreachable-t-oracle/e? x (x_1 ... x x_2 ...))])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-unreachable-g-oracle/e? g (x ...))
  #:mode (wf-unreachable-g-oracle/e? I I)

  [---------------------------------------------------- "unreachable succeed/e"
   (wf-unreachable-g-oracle/e? (succeed tag) (x_bound ...))]

  [---------------------------------------------------- "unreachable fail/e"
   (wf-unreachable-g-oracle/e? (fail tag) (x_bound ...))]

  [(wf-unreachable-t-oracle/e? t_1 (x_bound ...))
   (wf-unreachable-t-oracle/e? t_2 (x_bound ...))
   ---------------------------------------------------- "unreachable unification/e"
   (wf-unreachable-g-oracle/e? (t_1 =? t_2 tag) (x_bound ...))]

  [(wf-unreachable-t-oracle/e? t_1 (x_bound ...))
   (wf-unreachable-t-oracle/e? t_2 (x_bound ...))
   ---------------------------------------------------- "unreachable disequality/e"
   (wf-unreachable-g-oracle/e? (t_1 != t_2 tag) (x_bound ...))]

  [(wf-unreachable-g-oracle/e?
    g
    (x_fresh ... x_bound ...))
   ---------------------------------------------------- "unreachable fresh/e"
   (wf-unreachable-g-oracle/e?
    (∃ (x_fresh ...) g tag)
    (x_bound ...))]

  [(wf-unreachable-g-oracle/e? g_1 (x_bound ...))
   (wf-unreachable-g-oracle/e? g_2 (x_bound ...))
   ---------------------------------------------------- "unreachable conjunction/e"
   (wf-unreachable-g-oracle/e?
    (g_1 ∧ g_2 tag)
    (x_bound ...))])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-A-oracle/e? A)
  #:mode (wf-A-oracle/e? I)
  [(wf-state-oracle/e? σ)
   ---------------------------------------------------- "answer/e"
   (wf-A-oracle/e? (Answer σ))])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-S-oracle/e? S)
  #:mode (wf-S-oracle/e? I)
  [(wf-state-oracle/e? σ)
   ---------------------------------------------------- "returned/e"
   (wf-S-oracle/e? (Returned σ))])

(define-judgment-form
  core-e-oracle-lang
  #:contract (live-support-oracle/e? W support)
  #:mode (live-support-oracle/e? I O)

  [---------------------------------------------------- "work exposes state support/e"
   (live-support-oracle/e?
    (Work g (state support sub dis trail tag))
    support)]

  [---------------------------------------------------- "return exposes state support/e"
   (live-support-oracle/e?
    (Returned (state support sub dis trail tag))
    support)]

  [(live-support-oracle/e? W support)
   ---------------------------------------------------- "live support through conjunction/e"
   (live-support-oracle/e? (Conj W g) support)])

(define-judgment-form
  core-e-oracle-lang
  #:contract (dead-left-oracle/e? W)
  #:mode (dead-left-oracle/e? I)

  [---------------------------------------------------- "dead leaf/e"
   (dead-left-oracle/e? (Dead))]

  [(dead-left-oracle/e? W)
   (wf-unreachable-g-oracle/e? g ())
   ---------------------------------------------------- "dead conjunction path/e"
   (dead-left-oracle/e? (Conj W g))])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-W-oracle/e? W)
  #:mode (wf-W-oracle/e? I)

  [(wf-state-oracle/e? σ)
   (where support (state-support/e σ))
   (wf-g-oracle/e? g () support)
   ---------------------------------------------------- "work/e"
   (wf-W-oracle/e? (Work g σ))]

  [(wf-state-oracle/e? σ)
   ---------------------------------------------------- "returned work/e"
   (wf-W-oracle/e? (Returned σ))]

  [---------------------------------------------------- "dead work/e"
   (wf-W-oracle/e? (Dead))]

  [(wf-W-oracle/e? W)
   (live-support-oracle/e? W support)
   (wf-g-oracle/e? g () support)
   ---------------------------------------------------- "live conjunction/e"
   (wf-W-oracle/e? (Conj W g))]

  [(wf-W-oracle/e? W)
   (dead-left-oracle/e? W)
   (wf-unreachable-g-oracle/e? g ())
   ---------------------------------------------------- "unreachable dead conjunction/e"
   (wf-W-oracle/e? (Conj W g))])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-F-oracle/e? F)
  #:mode (wf-F-oracle/e? I)

  [(wf-W-oracle/e? W)
   ---------------------------------------------------- "unfinished frontier/e"
   (wf-F-oracle/e? (More W))]

  [(wf-A-oracle/e? A)
   ---------------------------------------------------- "last answer/e"
   (wf-F-oracle/e? (Last A))]

  [---------------------------------------------------- "done/e"
   (wf-F-oracle/e? (Done))])

(define-judgment-form
  core-e-oracle-lang
  #:contract (wf-core-oracle/e? F)
  #:mode (wf-core-oracle/e? I)
  [(wf-F-oracle/e? F)
   ---------------------------------------------------- "core E root"
   (wf-core-oracle/e? F)])
