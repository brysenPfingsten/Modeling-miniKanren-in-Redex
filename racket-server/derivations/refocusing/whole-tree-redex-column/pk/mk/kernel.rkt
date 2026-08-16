#lang racket

(require redex/reduction-semantics
         (prefix-in shared: "../../../shared/kernel.rkt")
         (only-in "../../../../../src/search-lattice/wf/kernel-base.rkt"
                  substitution-acyclic?)
         "../control-schema.rkt"
         "../shared-host.rkt"
         "./language.rkt")

(provide kernel-step/mk
         kernel-initial-state/mk
         kernel-open-fresh/mk
         whole-marker-support/mk
         control-resume/mk
         control-freeze/mk
         canonical-goal->control/mk
         kernel-observe/mk
         wf-atomic/mk
         wf-state-at/mk)

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

(define-metafunction pk-mk-lang
  kernel-initial-state/mk : -> kst
  [(kernel-initial-state/mk)
   (state () () () (label "s"))])

(define-metafunction pk-mk-lang
  kernel-open-fresh/mk : lexical g intro -> fresh-result
  [(kernel-open-fresh/mk (x ...) g (u_used ...))
   (OpenedFresh (u_new ...) g_new)
   (where (u_new ...)
          ,(fresh-u-list (term (u_used ...)) (term (x ...))))
   (where g_new
          ,(substitute-goal/mk
            (term g)
            (term ((x u_new) ...))))])

(define-metafunction pk-mk-lang
  canonical-goal->control/mk : cg -> g
  [(canonical-goal->control/mk (succeed tag))
   (succeed tag)]
  [(canonical-goal->control/mk (fail tag))
   (fail tag)]
  [(canonical-goal->control/mk (t_1 =? t_2 tag))
   (t_1 =? t_2 tag)]
  [(canonical-goal->control/mk (t_1 != t_2 tag))
   (t_1 != t_2 tag)]
  [(canonical-goal->control/mk (∃ lexical cg tag))
   (fresh lexical (canonical-goal->control/mk cg) tag)]
  [(canonical-goal->control/mk (cg_1 ∧ cg_2 tag))
   (conj (canonical-goal->control/mk cg_1)
         (canonical-goal->control/mk cg_2)
         tag)]
  [(canonical-goal->control/mk (cg_1 ∨ cg_2 tag))
   (disj (canonical-goal->control/mk cg_1)
         (canonical-goal->control/mk cg_2)
         tag)]
  [(canonical-goal->control/mk (suspend cg tag))
   (suspend (canonical-goal->control/mk cg) tag)])

;; Atomic rule selection is the only control-relevant decision delegated to K.
(define-judgment-form
  pk-mk-lang
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
  pk-mk-lang
  #:contract (name-member/mk any (any ...))
  #:mode (name-member/mk I I)
  [---------------------------------------------------- "member"
   (name-member/mk any_1 (any_2 ... any_1 any_3 ...))])

(define-judgment-form
  pk-mk-lang
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
  pk-mk-lang
  #:contract (wf-atomic/mk katom lexical intro)
  #:mode (wf-atomic/mk I I I)
  [---------------------------------------------------- "wf mk succeed"
   (wf-atomic/mk (succeed tag) lexical intro)]
  [---------------------------------------------------- "wf mk fail"
   (wf-atomic/mk (fail tag) lexical intro)]
  [(wf-term/mk t_1 lexical intro)
   (wf-term/mk t_2 lexical intro)
   ---------------------------------------------------- "wf mk equality"
   (wf-atomic/mk (t_1 =? t_2 tag) lexical intro)]
  [(wf-term/mk t_1 lexical intro)
   (wf-term/mk t_2 lexical intro)
   ---------------------------------------------------- "wf mk disequality"
   (wf-atomic/mk (t_1 != t_2 tag) lexical intro)])

(define-judgment-form
  pk-mk-lang
  #:contract (wf-sub/mk sub intro)
  #:mode (wf-sub/mk I I)
  [(name-member/mk u (u_bound ...)) ...
   (wf-term/mk t () (u_bound ...)) ...
   (where #t ,(substitution-acyclic? (term ((u t) ...))))
   ---------------------------------------------------- "wf c-free substitution"
   (wf-sub/mk ((u t) ...) (u_bound ...))])

(define-judgment-form
  pk-mk-lang
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
  pk-mk-lang
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
  pk-mk-lang
  #:contract (wf-state-at/mk kst intro)
  #:mode (wf-state-at/mk I I)
  [(wf-sub/mk sub intro)
   (wf-dis/mk dis intro)
   (wf-trail->sub/mk trail intro () sub)
   (where #f ,(shared:invalid? (term sub) (term dis)))
   ---------------------------------------------------- "wf c-free state at marker scope"
   (wf-state-at/mk (state sub dis trail tag) intro)])

(define-metafunction pk-mk-lang
  kernel-observe/mk : intro kst -> observation
  [(kernel-observe/mk (u_query ...)
                      (state sub dis trail tag))
   ,(shared:reify-query-values (term (u_query ...)) (term sub))])

(define-pk-control-operations
  pk-mk-lang
  whole-marker-support/mk
  control-resume/mk
  control-freeze/mk)
