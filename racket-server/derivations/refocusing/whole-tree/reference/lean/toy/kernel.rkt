#lang racket

(require redex/reduction-semantics
         "../shared-host.rkt"
         "./language.rkt")

(provide kernel-step/lean-toy
         kernel-initial-state/lean-toy
         kernel-open-fresh/lean-toy
         wf-atomic/lean-toy
         wf-state/lean-toy)

(define (drop-shadowed-bindings lexical bindings)
  (filter (lambda (binding)
            (not (member (first binding) lexical)))
          bindings))

(define (substitute-payload/lean-toy payload bindings)
  (match payload
    [(? x-symbol? x)
     (match (assoc x bindings)
       [(list _ u) u]
       [_ x])]
    [`(,first : ,rest)
     `(,(substitute-payload/lean-toy first bindings)
       :
       ,(substitute-payload/lean-toy rest bindings))]
    [_ payload]))

(define (substitute-goal/lean-toy goal bindings)
  (match goal
    [`(succeed ,tag)
     `(succeed ,tag)]
    [`(fail ,tag)
     `(fail ,tag)]
    [`(put ,payload ,tag)
     `(put ,(substitute-payload/lean-toy payload bindings) ,tag)]
    [`(fresh ,lexical ,body ,tag)
     `(fresh ,lexical
             ,(substitute-goal/lean-toy
               body
               (drop-shadowed-bindings lexical bindings))
             ,tag)]
    [`(conj ,left ,right ,tag)
     `(conj ,(substitute-goal/lean-toy left bindings)
            ,(substitute-goal/lean-toy right bindings)
            ,tag)]
    [`(disj ,left ,right ,tag)
     `(disj ,(substitute-goal/lean-toy left bindings)
            ,(substitute-goal/lean-toy right bindings)
            ,tag)]
    [`(suspend ,body ,tag)
     `(suspend ,(substitute-goal/lean-toy body bindings) ,tag)]))

(define-metafunction lean-toy-lang
  kernel-initial-state/lean-toy : -> kst
  [(kernel-initial-state/lean-toy) (state unit)])

(define-metafunction lean-toy-lang
  kernel-open-fresh/lean-toy : lexical g intro -> fresh-result
  [(kernel-open-fresh/lean-toy (x ...) g (u_used ...))
   (OpenedFresh (u_new ...) g_new)
   (where (u_new ...)
          ,(fresh-u-list (term (u_used ...)) (term (x ...))))
   (where g_new
          ,(substitute-goal/lean-toy
            (term g)
            (term ((x u_new) ...))))])

(define-judgment-form
  lean-toy-lang
  #:contract (kernel-step/lean-toy katom kst kresult kell)
  #:mode (kernel-step/lean-toy I I O O)
  [---------------------------------------------------- "toy succeed"
   (kernel-step/lean-toy (succeed tag)
                         kst
                         (KernelSuccess kst)
                         (kernel work-succeed core))]
  [---------------------------------------------------- "toy fail"
   (kernel-step/lean-toy (fail tag)
                         kst
                         KernelFailure
                         (kernel work-fail core))]
  [---------------------------------------------------- "toy put"
   (kernel-step/lean-toy (put p_new tag)
                         (state p_old)
                         (KernelSuccess (state p_new))
                         (kernel work-put core))])

(define (name-in? name names)
  (and (member name names) #t))

(define-judgment-form
  lean-toy-lang
  #:contract (wf-payload/lean-toy p lexical)
  #:mode (wf-payload/lean-toy I I)
  [(where #t ,(name-in? (term x) (term lexical)))
   ---------------------------------------------------- "toy bound lexical"
   (wf-payload/lean-toy x lexical)]
  [---------------------------------------------------- "toy runtime logical"
   (wf-payload/lean-toy u lexical)]
  [---------------------------------------------------- "toy primitive"
   (wf-payload/lean-toy tp lexical)]
  [(wf-payload/lean-toy p_1 lexical)
   (wf-payload/lean-toy p_2 lexical)
   ---------------------------------------------------- "toy pair"
   (wf-payload/lean-toy (p_1 : p_2) lexical)])

(define-judgment-form
  lean-toy-lang
  #:contract (wf-atomic/lean-toy katom lexical)
  #:mode (wf-atomic/lean-toy I I)
  [---------------------------------------------------- "wf toy succeed"
   (wf-atomic/lean-toy (succeed tag) lexical)]
  [---------------------------------------------------- "wf toy fail"
   (wf-atomic/lean-toy (fail tag) lexical)]
  [(wf-payload/lean-toy p lexical)
   ---------------------------------------------------- "wf toy put"
   (wf-atomic/lean-toy (put p tag) lexical)])

(define-judgment-form
  lean-toy-lang
  #:contract (wf-state/lean-toy kst)
  #:mode (wf-state/lean-toy I)
  [(wf-payload/lean-toy p ())
   ---------------------------------------------------- "wf toy state"
   (wf-state/lean-toy (state p))])
