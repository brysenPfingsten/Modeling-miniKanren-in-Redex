#lang racket

(require racket/list
         redex/reduction-semantics
         "./language.rkt")

(provide kernel-fresh
         kernel-substitute
         kernel-put
         kernel-resume
         kernel-freeze
         distinct-names?
         wf-goal/toy
         wf-answer/toy
         wf-work/toy
         wf-frontier/toy)

;; This module is the toy kernel instantiation.  Host Racket performs only
;; opaque kernel operations (fresh-name choice and capture-avoiding lexical
;; substitution); it never selects a control rule.

(define (x-symbol? value)
  (and (symbol? value)
       (regexp-match? #rx"^x:" (symbol->string value))))

(define (u-symbol? value)
  (and (symbol? value)
       (regexp-match? #rx"^u:" (symbol->string value))))

(define (logical-vars-in datum [vars '()])
  (match datum
    [(? u-symbol? u)
     (if (member u vars) vars (cons u vars))]
    [(cons first rest)
     (logical-vars-in first (logical-vars-in rest vars))]
    [_ vars]))

(define (fresh-u-symbol used [n 0])
  (define candidate
    (string->symbol (format "u:~a" n)))
  (if (member candidate used)
      (fresh-u-symbol used (add1 n))
      candidate))

(define (fresh-u-list used lexical)
  (define-values (reversed _used)
    (for/fold ([reversed '()]
               [used* used])
              ([_x (in-list lexical)])
      (define u
        (fresh-u-symbol used*))
      (values (cons u reversed)
              (cons u used*))))
  (reverse reversed))

(define (drop-shadowed-bindings lexical bindings)
  (filter (lambda (binding)
            (not (member (first binding) lexical)))
          bindings))

(define (substitute-payload payload bindings)
  (match payload
    [(? x-symbol? x)
     (match (assoc x bindings)
       [(list _ u) u]
       [_ x])]
    [`(,first : ,rest)
     `(,(substitute-payload first bindings)
       :
       ,(substitute-payload rest bindings))]
    [_ payload]))

(define (substitute-goal/host goal bindings)
  (match goal
    [`(succeed ,tag)
     `(succeed ,tag)]
    [`(fail ,tag)
     `(fail ,tag)]
    [`(put ,payload ,tag)
     `(put ,(substitute-payload payload bindings) ,tag)]
    [`(fresh ,lexical ,body ,tag)
     `(fresh ,lexical
             ,(substitute-goal/host
               body
               (drop-shadowed-bindings lexical bindings))
             ,tag)]
    [`(conj ,left ,right ,tag)
     `(conj ,(substitute-goal/host left bindings)
            ,(substitute-goal/host right bindings)
            ,tag)]
    [`(disj ,left ,right ,tag)
     `(disj ,(substitute-goal/host left bindings)
            ,(substitute-goal/host right bindings)
            ,tag)]
    [`(suspend ,body ,tag)
     `(suspend ,(substitute-goal/host body bindings) ,tag)]))

(define-metafunction redex-column-source-lang
  kernel-fresh : lexical F -> intro
  [(kernel-fresh (x ...) F)
   ,(fresh-u-list (logical-vars-in (term F)) (term (x ...)))])

(define-metafunction redex-column-source-lang
  kernel-substitute : g ((x u) ...) -> g
  [(kernel-substitute g ((x u) ...))
   ,(substitute-goal/host (term g) (term ((x u) ...)))])

(define-metafunction redex-column-source-lang
  kernel-put : p st -> st
  [(kernel-put p_new (state p_old)) (state p_new)])

(define-metafunction redex-column-source-lang
  kernel-resume : S g -> W
  [(kernel-resume (Returned st) g)
   (Work g st)]
  [(kernel-resume (WorkFresh intro S tag) g)
   (WorkFresh intro (kernel-resume S g) tag)])

(define-metafunction redex-column-source-lang
  kernel-freeze : S -> A
  [(kernel-freeze (Returned st))
   (Answer st)]
  [(kernel-freeze (WorkFresh intro S tag))
   (AnswerFresh intro (kernel-freeze S) tag)])

(define (distinct-names? names)
  (= (length names)
     (length (remove-duplicates names))))

(define-judgment-form
  redex-column-source-lang
  #:contract (wf-goal/toy g)
  #:mode (wf-goal/toy I)
  [---------------- "wf succeed/toy"
   (wf-goal/toy (succeed tag))]
  [---------------- "wf fail/toy"
   (wf-goal/toy (fail tag))]
  [---------------- "wf put/toy"
   (wf-goal/toy (put p tag))]
  [(where #t ,(distinct-names? (term (x ...))))
   (wf-goal/toy g)
   ---------------- "wf fresh/toy"
   (wf-goal/toy (fresh (x ...) g tag))]
  [(wf-goal/toy g_1)
   (wf-goal/toy g_2)
   ---------------- "wf conj/toy"
   (wf-goal/toy (conj g_1 g_2 tag))]
  [(wf-goal/toy g_1)
   (wf-goal/toy g_2)
   ---------------- "wf disj/toy"
   (wf-goal/toy (disj g_1 g_2 tag))]
  [(wf-goal/toy g)
   ---------------- "wf suspend/toy"
   (wf-goal/toy (suspend g tag))])

(define-judgment-form
  redex-column-source-lang
  #:contract (wf-answer/toy A)
  #:mode (wf-answer/toy I)
  [---------------- "wf answer/toy"
   (wf-answer/toy (Answer st))]
  [(where #t ,(distinct-names? (term (u ...))))
   (wf-answer/toy A)
   ---------------- "wf answer fresh/toy"
   (wf-answer/toy (AnswerFresh (u ...) A tag))])

(define-judgment-form
  redex-column-source-lang
  #:contract (wf-work/toy W)
  #:mode (wf-work/toy I)
  [(wf-goal/toy g)
   ---------------- "wf work/toy"
   (wf-work/toy (Work g st))]
  [---------------- "wf returned/toy"
   (wf-work/toy (Returned st))]
  [---------------- "wf dead/toy"
   (wf-work/toy Dead)]
  [(where #t ,(distinct-names? (term (u ...))))
   (wf-work/toy W)
   ---------------- "wf work fresh/toy"
   (wf-work/toy (WorkFresh (u ...) W tag))]
  [(wf-work/toy W)
   (wf-goal/toy g)
   ---------------- "wf conjunction/toy"
   (wf-work/toy (Conj W g))]
  [(wf-work/toy W)
   ---------------- "wf pending delay/toy"
   (wf-work/toy (PendingDelay W))]
  [(wf-work/toy W_1)
   (wf-work/toy W_2)
   ---------------- "wf left disjunction/toy"
   (wf-work/toy (DisjL W_1 W_2))]
  [(wf-work/toy W_1)
   (wf-work/toy W_2)
   ---------------- "wf right disjunction/toy"
   (wf-work/toy (DisjR W_1 W_2))])

(define-judgment-form
  redex-column-source-lang
  #:contract (wf-frontier/toy F)
  #:mode (wf-frontier/toy I)
  [(wf-work/toy W)
   ---------------- "wf more/toy"
   (wf-frontier/toy (More W))]
  [---------------- "wf done/toy"
   (wf-frontier/toy Done)]
  [(wf-answer/toy A)
   ---------------- "wf last/toy"
   (wf-frontier/toy (Last A))]
  [(where #t ,(distinct-names? (term (u ...))))
   (wf-frontier/toy F)
   ---------------- "wf frontier fresh/toy"
   (wf-frontier/toy (FrontierFresh (u ...) F tag))]
  [(wf-answer/toy A)
   (wf-frontier/toy F)
   ---------------- "wf emit/toy"
   (wf-frontier/toy (Emit A F))]
  [(wf-frontier/toy F)
   ---------------- "wf forced/toy"
   (wf-frontier/toy (Forced F))])

