#lang racket

(require redex/reduction-semantics
         (prefix-in shared: "../shared/kernel.rkt")
         (only-in "../../../src/search-lattice/wf/kernel-base.rkt"
                  substitution-acyclic?)
         "./kernel-interface.rkt")

(provide redex-column-mk-kernel-lang
         kernel-initial-state/mk
         kernel-step/mk
         kernel-fresh/mk
         kernel-substitute/mk
         kernel-open-fresh/mk
         canonical-goal->column/mk
         kernel-observe/mk
         wf-atomic-goal/mk
         wf-goal/mk
         wf-state-at/mk
         wf-answer-at/mk)

;; This is the c-free miniKanren kernel selected for P[Kmk].  The state carries
;; substitution, disequality store, unification history, and provenance, but
;; no cached ambient scope `c`.  Ambient scope is supplied to well-formedness
;; as an index and will ultimately be derived from WorkFresh/FrontierFresh
;; contexts by the generic control column.
(define-extended-language redex-column-mk-kernel-lang
  redex-column-kernel-interface-lang
  [pt (sym string)
      (nat number)
      boolean
      (str string)
      empty]
  [t x
     u
     pt
     (t : t)]
  [x (variable-prefix x:)]
  [u (variable-prefix u:)]
  [tag (label string)]
  [lexical (x_!_ ...)]
  [intro (u_!_ ...)]
  [bindings ((x u) ...)]
  [sub ((u_!_ t) ...)]
  [dis ((t t) ...)]
  [eq (t =? t tag)]
  [trail (eq ...)]

  [kst (state sub dis trail tag)]
  [katom (succeed tag)
         (fail tag)
         (t =? t tag)
         (t != t tag)]
  [g katom
     (fresh lexical g tag)
     (conj g g tag)
     (disj g g tag)
     (suspend g tag)]

  ;; Canonical production syntax is translated only at the adapter boundary;
  ;; the shared control carrier keeps its existing constructor vocabulary.
  [cg (succeed tag)
      (fail tag)
      (t =? t tag)
      (t != t tag)
      (∃ lexical cg tag)
      (cg ∧ cg tag)
      (cg ∨ cg tag)
      (suspend cg tag)]

  [kresult (KernelSuccess kst)
           KernelFailure]
  [kname succeed
         fail
         unify-success
         unify-violates-disequality
         unify-fail
         disequality-success
         disequality-fail]
  [kell (kernel kname core)]
  [fresh-result (OpenedFresh intro g)]
  [answer (Answer kst)
          (AnswerFresh intro answer tag)]
  [observation (t ...)])

(define (drop-shadowed-bindings lexical bindings)
  (filter (lambda (binding)
            (not (member (first binding) lexical)))
          bindings))

(define (substitute-goal/mk goal bindings)
  (match goal
    [`(succeed ,tag)
     `(succeed ,tag)]
    [`(fail ,tag)
     `(fail ,tag)]
    [`(,left =? ,right ,tag)
     `(,(shared:subst-term left bindings)
       =?
       ,(shared:subst-term right bindings)
       ,tag)]
    [`(,left != ,right ,tag)
     `(,(shared:subst-term left bindings)
       !=
       ,(shared:subst-term right bindings)
       ,tag)]
    [`(fresh ,lexical ,body ,tag)
     `(fresh ,lexical
             ,(substitute-goal/mk
               body
               (drop-shadowed-bindings lexical bindings))
             ,tag)]
    [`(conj ,left ,right ,tag)
     `(conj ,(substitute-goal/mk left bindings)
            ,(substitute-goal/mk right bindings)
            ,tag)]
    [`(disj ,left ,right ,tag)
     `(disj ,(substitute-goal/mk left bindings)
            ,(substitute-goal/mk right bindings)
            ,tag)]
    [`(suspend ,body ,tag)
     `(suspend ,(substitute-goal/mk body bindings) ,tag)]))

(define (fresh-extension? introduced outer)
  (and (= (length introduced)
          (length (remove-duplicates introduced)))
       (for/and ([name (in-list introduced)])
         (not (member name outer)))))

(define-metafunction redex-column-mk-kernel-lang
  kernel-initial-state/mk : -> kst
  [(kernel-initial-state/mk)
   (state () () () (label "s"))])

;; `used` is a control-derived support list, not a cached field in kst.
(define-metafunction redex-column-mk-kernel-lang
  kernel-fresh/mk : lexical intro -> intro
  [(kernel-fresh/mk (x ...) (u_used ...))
   ,(shared:fresh-u-list (term (u_used ...)) (term (x ...)))])

(define-metafunction redex-column-mk-kernel-lang
  kernel-substitute/mk : g bindings -> g
  [(kernel-substitute/mk g ((x u) ...))
   ,(substitute-goal/mk (term g) (term ((x u) ...)))])

(define-metafunction redex-column-mk-kernel-lang
  kernel-open-fresh/mk : lexical g intro -> fresh-result
  [(kernel-open-fresh/mk (x ...) g (u_used ...))
   (OpenedFresh (u_new ...)
                (kernel-substitute/mk g ((x u_new) ...)))
   (where (u_new ...)
          (kernel-fresh/mk (x ...) (u_used ...)))])

(define-metafunction redex-column-mk-kernel-lang
  canonical-goal->column/mk : cg -> g
  [(canonical-goal->column/mk (succeed tag))
   (succeed tag)]
  [(canonical-goal->column/mk (fail tag))
   (fail tag)]
  [(canonical-goal->column/mk (t_1 =? t_2 tag))
   (t_1 =? t_2 tag)]
  [(canonical-goal->column/mk (t_1 != t_2 tag))
   (t_1 != t_2 tag)]
  [(canonical-goal->column/mk (∃ lexical cg tag))
   (fresh lexical (canonical-goal->column/mk cg) tag)]
  [(canonical-goal->column/mk (cg_1 ∧ cg_2 tag))
   (conj (canonical-goal->column/mk cg_1)
         (canonical-goal->column/mk cg_2)
         tag)]
  [(canonical-goal->column/mk (cg_1 ∨ cg_2 tag))
   (disj (canonical-goal->column/mk cg_1)
         (canonical-goal->column/mk cg_2)
         tag)]
  [(canonical-goal->column/mk (suspend cg tag))
   (suspend (canonical-goal->column/mk cg) tag)])

;; Kernel-owned rule selection remains a Redex judgment.  Host Racket is used
;; only for unification and the disequality validity predicate.
(define-judgment-form
  redex-column-mk-kernel-lang
  #:contract (kernel-step/mk katom kst kresult kell)
  #:mode (kernel-step/mk I I O O)
  [---------------------------------------------------- "mk succeed"
   (kernel-step/mk (succeed tag)
                   kst
                   (KernelSuccess kst)
                   (kernel succeed core))]
  [---------------------------------------------------- "mk fail"
   (kernel-step/mk (fail tag)
                   kst
                   KernelFailure
                   (kernel fail core))]
  [(where sub_new
          ,(shared:unify (term t_1) (term t_2) (term sub)))
   (where #f ,(shared:invalid? (term sub_new) (term dis)))
   ---------------------------------------------------- "mk unify success"
   (kernel-step/mk
    (t_1 =? t_2 tag_goal)
    (state sub dis (eq_old ...) tag_state)
    (KernelSuccess
     (state sub_new
            dis
            (eq_old ... (t_1 =? t_2 tag_goal))
            tag_state))
    (kernel unify-success core))]
  [(where sub_new
          ,(shared:unify (term t_1) (term t_2) (term sub)))
   (where #t ,(shared:invalid? (term sub_new) (term dis)))
   ---------------------------------------------------- "mk unify violates disequality"
   (kernel-step/mk
    (t_1 =? t_2 tag_goal)
    (state sub dis trail tag_state)
    KernelFailure
    (kernel unify-violates-disequality core))]
  [(where #f ,(shared:unify (term t_1) (term t_2) (term sub)))
   ---------------------------------------------------- "mk unify fail"
   (kernel-step/mk
    (t_1 =? t_2 tag_goal)
    (state sub dis trail tag_state)
    KernelFailure
    (kernel unify-fail core))]
  [(where dis_new ((t_1 t_2) . dis))
   (where #f ,(shared:invalid? (term sub) (term dis_new)))
   ---------------------------------------------------- "mk disequality success"
   (kernel-step/mk
    (t_1 != t_2 tag_goal)
    (state sub dis trail tag_state)
    (KernelSuccess (state sub dis_new trail tag_state))
    (kernel disequality-success core))]
  [(where dis_new ((t_1 t_2) . dis))
   (where #t ,(shared:invalid? (term sub) (term dis_new)))
   ---------------------------------------------------- "mk disequality fail"
   (kernel-step/mk
    (t_1 != t_2 tag_goal)
    (state sub dis trail tag_state)
    KernelFailure
    (kernel disequality-fail core))])

(define-judgment-form
  redex-column-mk-kernel-lang
  #:contract (name-member/mk any (any ...))
  #:mode (name-member/mk I I)
  [---------------------------------------------------- "member"
   (name-member/mk any_1 (any_2 ... any_1 any_3 ...))])

(define-judgment-form
  redex-column-mk-kernel-lang
  #:contract (wf-term/mk t lexical intro)
  #:mode (wf-term/mk I I I)
  [(name-member/mk x (x_bound ...))
   ---------------------------------------------------- "bound lexical variable"
   (wf-term/mk x (x_bound ...) intro)]
  [(name-member/mk u (u_bound ...))
   ---------------------------------------------------- "owned logical variable"
   (wf-term/mk u lexical (u_bound ...))]
  [---------------------------------------------------- "primitive"
   (wf-term/mk pt lexical intro)]
  [(wf-term/mk t_1 lexical intro)
   (wf-term/mk t_2 lexical intro)
   ---------------------------------------------------- "pair"
   (wf-term/mk (t_1 : t_2) lexical intro)])

(define-judgment-form
  redex-column-mk-kernel-lang
  #:contract (wf-atomic-goal/mk katom lexical intro)
  #:mode (wf-atomic-goal/mk I I I)
  [---------------------------------------------------- "wf mk succeed"
   (wf-atomic-goal/mk (succeed tag) lexical intro)]
  [---------------------------------------------------- "wf mk fail"
   (wf-atomic-goal/mk (fail tag) lexical intro)]
  [(wf-term/mk t_1 lexical intro)
   (wf-term/mk t_2 lexical intro)
   ---------------------------------------------------- "wf mk equality"
   (wf-atomic-goal/mk (t_1 =? t_2 tag) lexical intro)]
  [(wf-term/mk t_1 lexical intro)
   (wf-term/mk t_2 lexical intro)
   ---------------------------------------------------- "wf mk disequality"
   (wf-atomic-goal/mk (t_1 != t_2 tag) lexical intro)])

(define-judgment-form
  redex-column-mk-kernel-lang
  #:contract (wf-goal/mk g lexical intro)
  #:mode (wf-goal/mk I I I)
  [(wf-atomic-goal/mk katom lexical intro)
   ---------------------------------------------------- "wf atomic mk goal"
   (wf-goal/mk katom lexical intro)]
  [(where #t
          ,(fresh-extension? (term (x_new ...))
                             (term (x_outer ...))))
   (wf-goal/mk g (x_new ... x_outer ...) intro)
   ---------------------------------------------------- "wf source fresh"
   (wf-goal/mk (fresh (x_new ...) g tag)
               (x_outer ...)
               intro)]
  [(wf-goal/mk g_1 lexical intro)
   (wf-goal/mk g_2 lexical intro)
   ---------------------------------------------------- "wf source conjunction"
   (wf-goal/mk (conj g_1 g_2 tag) lexical intro)]
  [(wf-goal/mk g_1 lexical intro)
   (wf-goal/mk g_2 lexical intro)
   ---------------------------------------------------- "wf source disjunction"
   (wf-goal/mk (disj g_1 g_2 tag) lexical intro)]
  [(wf-goal/mk g lexical intro)
   ---------------------------------------------------- "wf source suspension"
   (wf-goal/mk (suspend g tag) lexical intro)])

(define-judgment-form
  redex-column-mk-kernel-lang
  #:contract (wf-sub/mk sub intro)
  #:mode (wf-sub/mk I I)
  [(name-member/mk u (u_bound ...)) ...
   (wf-term/mk t () (u_bound ...)) ...
   (where #t ,(substitution-acyclic? (term ((u t) ...))))
   ---------------------------------------------------- "wf c-free substitution"
   (wf-sub/mk ((u t) ...) (u_bound ...))])

(define-judgment-form
  redex-column-mk-kernel-lang
  #:contract (wf-dis/mk dis intro)
  #:mode (wf-dis/mk I I)
  [---------------------------------------------------- "wf empty disequality store"
   (wf-dis/mk () intro)]
  [(wf-term/mk t_1 () intro)
   (wf-term/mk t_2 () intro)
   (wf-dis/mk ((t_3 t_4) ...) intro)
   ---------------------------------------------------- "wf disequality store"
   (wf-dis/mk ((t_1 t_2) (t_3 t_4) ...) intro)])

(define-judgment-form
  redex-column-mk-kernel-lang
  #:contract (wf-trail->sub/mk trail intro sub sub)
  #:mode (wf-trail->sub/mk I I I I)
  [---------------------------------------------------- "empty trail"
   (wf-trail->sub/mk () intro sub sub)]
  [(wf-term/mk t_1 () intro)
   (wf-term/mk t_2 () intro)
   (where sub_next
          ,(shared:unify (term t_1) (term t_2) (term sub_acc)))
   (wf-trail->sub/mk (eq_rest ...) intro sub_next sub_final)
   ---------------------------------------------------- "replay unification trail"
   (wf-trail->sub/mk ((t_1 =? t_2 tag) eq_rest ...)
                     intro
                     sub_acc
                     sub_final)])

(define-judgment-form
  redex-column-mk-kernel-lang
  #:contract (wf-state-at/mk kst intro)
  #:mode (wf-state-at/mk I I)
  [(wf-sub/mk sub intro)
   (wf-dis/mk dis intro)
   (wf-trail->sub/mk trail intro () sub)
   (where #f ,(shared:invalid? (term sub) (term dis)))
   ---------------------------------------------------- "wf c-free state at marker scope"
   (wf-state-at/mk (state sub dis trail tag) intro)])

(define-judgment-form
  redex-column-mk-kernel-lang
  #:contract (wf-answer-at/mk answer intro)
  #:mode (wf-answer-at/mk I I)
  [(wf-state-at/mk kst intro)
   ---------------------------------------------------- "wf raw mk answer"
   (wf-answer-at/mk (Answer kst) intro)]
  [(where #t
          ,(fresh-extension? (term (u_new ...))
                             (term (u_outer ...))))
   (wf-answer-at/mk answer (u_new ... u_outer ...))
   ---------------------------------------------------- "wf marked mk answer"
   (wf-answer-at/mk (AnswerFresh (u_new ...) answer tag)
                    (u_outer ...))])

(define-metafunction redex-column-mk-kernel-lang
  kernel-observe/mk : intro kst -> observation
  [(kernel-observe/mk (u_query ...)
                      (state sub dis trail tag))
   ,(shared:reify-query-values (term (u_query ...)) (term sub))])
