#lang racket

(require redex/reduction-semantics
         "../control-schema.rkt"
         "../shared-host.rkt"
         "./language.rkt")

(provide kernel-step/toy
         kernel-initial-state/toy
         kernel-open-fresh/toy
         whole-marker-support/toy
         control-resume/toy
         control-freeze/toy
         wf-atomic/toy
         wf-state-at/toy)

(define (drop-shadowed-bindings lexical bindings)
  (filter (lambda (binding)
            (not (member (first binding) lexical)))
          bindings))

(define (substitute-payload/toy payload bindings)
  (match payload
    [(? x-symbol? x)
     (match (assoc x bindings)
       [(list _ u) u]
       [_ x])]
    [`(,first : ,rest)
     `(,(substitute-payload/toy first bindings)
       :
       ,(substitute-payload/toy rest bindings))]
    [_ payload]))

(define (substitute-goal/toy goal bindings)
  (match goal
    [`(succeed ,tag)
     `(succeed ,tag)]
    [`(fail ,tag)
     `(fail ,tag)]
    [`(put ,payload ,tag)
     `(put ,(substitute-payload/toy payload bindings) ,tag)]
    [`(fresh ,lexical ,body ,tag)
     `(fresh ,lexical
             ,(substitute-goal/toy
               body
               (drop-shadowed-bindings lexical bindings))
             ,tag)]
    [`(conj ,left ,right ,tag)
     `(conj ,(substitute-goal/toy left bindings)
            ,(substitute-goal/toy right bindings)
            ,tag)]
    [`(disj ,left ,right ,tag)
     `(disj ,(substitute-goal/toy left bindings)
            ,(substitute-goal/toy right bindings)
            ,tag)]
    [`(suspend ,body ,tag)
     `(suspend ,(substitute-goal/toy body bindings) ,tag)]))

(define-metafunction pk-toy-lang
  kernel-initial-state/toy : -> kst
  [(kernel-initial-state/toy) (state unit)])

(define-metafunction pk-toy-lang
  kernel-open-fresh/toy : lexical g intro -> fresh-result
  [(kernel-open-fresh/toy (x ...) g (u_used ...))
   (OpenedFresh (u_new ...) g_new)
   (where (u_new ...)
          ,(fresh-u-list (term (u_used ...)) (term (x ...))))
   (where g_new
          ,(substitute-goal/toy
            (term g)
            (term ((x u_new) ...))))])

(define-judgment-form
  pk-toy-lang
  #:contract (kernel-step/toy katom kst kresult kell)
  #:mode (kernel-step/toy I I O O)
  [---------------------------------------------------- "toy succeed"
   (kernel-step/toy (succeed tag)
                    kst
                    (KernelSuccess kst)
                    (kernel work-succeed core))]
  [---------------------------------------------------- "toy fail"
   (kernel-step/toy (fail tag)
                    kst
                    KernelFailure
                    (kernel work-fail core))]
  [---------------------------------------------------- "toy put"
   (kernel-step/toy (put p_new tag)
                    (state p_old)
                    (KernelSuccess (state p_new))
                    (kernel work-put core))])

(define (name-in? name names)
  (and (member name names) #t))

(define-judgment-form
  pk-toy-lang
  #:contract (wf-payload/toy p lexical intro)
  #:mode (wf-payload/toy I I I)
  [(where #t ,(name-in? (term x) (term lexical)))
   ---------------------------------------------------- "toy bound lexical"
   (wf-payload/toy x lexical intro)]
  [(where #t ,(name-in? (term u) (term intro)))
   ---------------------------------------------------- "toy owned logical"
   (wf-payload/toy u lexical intro)]
  [---------------------------------------------------- "toy primitive"
   (wf-payload/toy tp lexical intro)]
  [(wf-payload/toy p_1 lexical intro)
   (wf-payload/toy p_2 lexical intro)
   ---------------------------------------------------- "toy pair"
   (wf-payload/toy (p_1 : p_2) lexical intro)])

(define-judgment-form
  pk-toy-lang
  #:contract (wf-atomic/toy katom lexical intro)
  #:mode (wf-atomic/toy I I I)
  [---------------------------------------------------- "wf toy succeed"
   (wf-atomic/toy (succeed tag) lexical intro)]
  [---------------------------------------------------- "wf toy fail"
   (wf-atomic/toy (fail tag) lexical intro)]
  [(wf-payload/toy p lexical intro)
   ---------------------------------------------------- "wf toy put"
   (wf-atomic/toy (put p tag) lexical intro)])

(define-judgment-form
  pk-toy-lang
  #:contract (wf-state-at/toy kst intro)
  #:mode (wf-state-at/toy I I)
  [(wf-payload/toy p () intro)
   ---------------------------------------------------- "wf toy state"
   (wf-state-at/toy (state p) intro)])

(define-pk-control-operations
  pk-toy-lang
  whole-marker-support/toy
  control-resume/toy
  control-freeze/toy)
