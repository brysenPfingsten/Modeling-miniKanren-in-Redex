#lang racket

(require redex/reduction-semantics
         (prefix-in shared: "../../../../shared/kernel.rkt")
         (only-in "../../../../../../src/search-lattice/wf/kernel-base.rkt"
                  substitution-acyclic?)
         "../shared-host.rkt"
         "./language.rkt")

(provide kernel-step/lean-mk
         kernel-initial-state/lean-mk
         kernel-open-fresh/lean-mk
         canonical-goal->control/lean-mk
         kernel-observe/lean-mk
         wf-atomic/lean-mk
         wf-state/lean-mk)

(define (drop-shadowed-bindings lexical bindings)
  (filter (lambda (binding)
            (not (member (first binding) lexical)))
          bindings))

(define (substitute-goal/lean-mk goal bindings)
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
             ,(substitute-goal/lean-mk
               body
               (drop-shadowed-bindings lexical bindings))
             ,tag)]
    [`(conj ,left ,right ,tag)
     `(conj ,(substitute-goal/lean-mk left bindings)
            ,(substitute-goal/lean-mk right bindings)
            ,tag)]
    [`(disj ,left ,right ,tag)
     `(disj ,(substitute-goal/lean-mk left bindings)
            ,(substitute-goal/lean-mk right bindings)
            ,tag)]
    [`(suspend ,body ,tag)
     `(suspend ,(substitute-goal/lean-mk body bindings) ,tag)]))

(define-metafunction lean-mk-lang
  kernel-initial-state/lean-mk : -> kst
  [(kernel-initial-state/lean-mk)
   (state () () () (label "s"))])

(define-metafunction lean-mk-lang
  kernel-open-fresh/lean-mk : lexical g intro -> fresh-result
  [(kernel-open-fresh/lean-mk (x ...) g (u_used ...))
   (OpenedFresh (u_new ...) g_new)
   (where (u_new ...)
          ,(fresh-u-list (term (u_used ...)) (term (x ...))))
   (where g_new
          ,(substitute-goal/lean-mk
            (term g)
            (term ((x u_new) ...))))])

(define-metafunction lean-mk-lang
  canonical-goal->control/lean-mk : cg -> g
  [(canonical-goal->control/lean-mk (succeed tag))
   (succeed tag)]
  [(canonical-goal->control/lean-mk (fail tag))
   (fail tag)]
  [(canonical-goal->control/lean-mk (t_1 =? t_2 tag))
   (t_1 =? t_2 tag)]
  [(canonical-goal->control/lean-mk (t_1 != t_2 tag))
   (t_1 != t_2 tag)]
  [(canonical-goal->control/lean-mk (∃ lexical cg tag))
   (fresh lexical (canonical-goal->control/lean-mk cg) tag)]
  [(canonical-goal->control/lean-mk (cg_1 ∧ cg_2 tag))
   (conj (canonical-goal->control/lean-mk cg_1)
         (canonical-goal->control/lean-mk cg_2)
         tag)]
  [(canonical-goal->control/lean-mk (cg_1 ∨ cg_2 tag))
   (disj (canonical-goal->control/lean-mk cg_1)
         (canonical-goal->control/lean-mk cg_2)
         tag)]
  [(canonical-goal->control/lean-mk (suspend cg tag))
   (suspend (canonical-goal->control/lean-mk cg) tag)])

(define-judgment-form
  lean-mk-lang
  #:contract (kernel-step/lean-mk katom kst kresult kell)
  #:mode (kernel-step/lean-mk I I O O)
  [---------------------------------------------------- "mk succeed"
   (kernel-step/lean-mk (succeed tag)
                        kst
                        (KernelSuccess kst)
                        (kernel succeed core))]
  [---------------------------------------------------- "mk fail"
   (kernel-step/lean-mk (fail tag)
                        kst
                        KernelFailure
                        (kernel fail core))]
  [(where sub_new
          ,(shared:unify (term t_1) (term t_2) (term sub)))
   (where #f ,(shared:invalid? (term sub_new) (term dis)))
   ---------------------------------------------------- "mk unify success"
   (kernel-step/lean-mk
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
   (kernel-step/lean-mk
    (t_1 =? t_2 tag_goal)
    (state sub dis trail tag_state)
    KernelFailure
    (kernel unify-violates-disequality core))]
  [(where #f ,(shared:unify (term t_1) (term t_2) (term sub)))
   ---------------------------------------------------- "mk unify fail"
   (kernel-step/lean-mk
    (t_1 =? t_2 tag_goal)
    (state sub dis trail tag_state)
    KernelFailure
    (kernel unify-fail core))]
  [(where dis_new ((t_1 t_2) . dis))
   (where #f ,(shared:invalid? (term sub) (term dis_new)))
   ---------------------------------------------------- "mk disequality success"
   (kernel-step/lean-mk
    (t_1 != t_2 tag_goal)
    (state sub dis trail tag_state)
    (KernelSuccess (state sub dis_new trail tag_state))
    (kernel disequality-success core))]
  [(where dis_new ((t_1 t_2) . dis))
   (where #t ,(shared:invalid? (term sub) (term dis_new)))
   ---------------------------------------------------- "mk disequality fail"
   (kernel-step/lean-mk
    (t_1 != t_2 tag_goal)
    (state sub dis trail tag_state)
    KernelFailure
    (kernel disequality-fail core))])

(define-judgment-form
  lean-mk-lang
  #:contract (name-member/lean-mk any (any ...))
  #:mode (name-member/lean-mk I I)
  [---------------------------------------------------- "member"
   (name-member/lean-mk any_1 (any_2 ... any_1 any_3 ...))])

(define-judgment-form
  lean-mk-lang
  #:contract (wf-term/lean-mk t lexical)
  #:mode (wf-term/lean-mk I I)
  [(name-member/lean-mk x (x_bound ...))
   ---------------------------------------------------- "bound lexical variable"
   (wf-term/lean-mk x (x_bound ...))]
  [---------------------------------------------------- "runtime logical variable"
   (wf-term/lean-mk u lexical)]
  [---------------------------------------------------- "primitive"
   (wf-term/lean-mk pt lexical)]
  [(wf-term/lean-mk t_1 lexical)
   (wf-term/lean-mk t_2 lexical)
   ---------------------------------------------------- "pair"
   (wf-term/lean-mk (t_1 : t_2) lexical)])

(define-judgment-form
  lean-mk-lang
  #:contract (wf-atomic/lean-mk katom lexical)
  #:mode (wf-atomic/lean-mk I I)
  [---------------------------------------------------- "wf mk succeed"
   (wf-atomic/lean-mk (succeed tag) lexical)]
  [---------------------------------------------------- "wf mk fail"
   (wf-atomic/lean-mk (fail tag) lexical)]
  [(wf-term/lean-mk t_1 lexical)
   (wf-term/lean-mk t_2 lexical)
   ---------------------------------------------------- "wf mk equality"
   (wf-atomic/lean-mk (t_1 =? t_2 tag) lexical)]
  [(wf-term/lean-mk t_1 lexical)
   (wf-term/lean-mk t_2 lexical)
   ---------------------------------------------------- "wf mk disequality"
   (wf-atomic/lean-mk (t_1 != t_2 tag) lexical)])

(define-judgment-form
  lean-mk-lang
  #:contract (wf-sub/lean-mk sub)
  #:mode (wf-sub/lean-mk I)
  [(wf-term/lean-mk t ()) ...
   (where #t ,(substitution-acyclic? (term ((u t) ...))))
   ---------------------------------------------------- "wf c-free substitution"
   (wf-sub/lean-mk ((u t) ...))])

(define-judgment-form
  lean-mk-lang
  #:contract (wf-dis/lean-mk dis)
  #:mode (wf-dis/lean-mk I)
  [---------------------------------------------------- "wf empty disequality store"
   (wf-dis/lean-mk ())]
  [(wf-term/lean-mk t_1 ())
   (wf-term/lean-mk t_2 ())
   (wf-dis/lean-mk ((t_3 t_4) ...))
   ---------------------------------------------------- "wf disequality store"
   (wf-dis/lean-mk ((t_1 t_2) (t_3 t_4) ...))])

(define-judgment-form
  lean-mk-lang
  #:contract (wf-trail->sub/lean-mk trail sub sub)
  #:mode (wf-trail->sub/lean-mk I I I)
  [---------------------------------------------------- "empty trail"
   (wf-trail->sub/lean-mk () sub sub)]
  [(wf-term/lean-mk t_1 ())
   (wf-term/lean-mk t_2 ())
   (where sub_next
          ,(shared:unify (term t_1) (term t_2) (term sub_acc)))
   (wf-trail->sub/lean-mk (eq_rest ...) sub_next sub_final)
   ---------------------------------------------------- "replay unification trail"
   (wf-trail->sub/lean-mk ((t_1 =? t_2 tag) eq_rest ...)
                          sub_acc
                          sub_final)])

(define-judgment-form
  lean-mk-lang
  #:contract (wf-state/lean-mk kst)
  #:mode (wf-state/lean-mk I)
  [(wf-sub/lean-mk sub)
   (wf-dis/lean-mk dis)
   (wf-trail->sub/lean-mk trail () sub)
   (where #f ,(shared:invalid? (term sub) (term dis)))
   ---------------------------------------------------- "wf c-free lean state"
   (wf-state/lean-mk (state sub dis trail tag))])

(define-metafunction lean-mk-lang
  kernel-observe/lean-mk : intro kst -> observation
  [(kernel-observe/lean-mk (u_query ...)
                           (state sub dis trail tag))
   ,(shared:reify-query-values (term (u_query ...)) (term sub))])
