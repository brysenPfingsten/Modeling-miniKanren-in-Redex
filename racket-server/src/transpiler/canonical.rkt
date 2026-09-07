#lang racket

(require "./ast.rkt"
         "./profile.rkt"
         "./program.rkt"
         "../search-strategy.rkt")

(provide parse-prog/canonical (struct-out query-info))

;; Query identity belongs to compilation, not to a scan of a changing search
;; tree. The initial fresh runs in the empty world and allocates these names
;; in binder order. Keep the surface names and source tag for inspection too.
(struct query-info (names variables tag limit) #:transparent)

(define (id->label id)
  `(label ,id))

(define (konst->canonical-term const)
  (match const
    [(struct konst (s)) #:when (symbol? s) `(sym ,(symbol->string s))]
    [(struct konst (s)) #:when (string? s) `(str ,s)]
    [(struct konst (b)) #:when (boolean? b) b]
    [(struct konst (n)) #:when (number? n) `(nat ,n)]))

(define (unwrap-symbolish v who)
  (match v
    [(? symbol? sym) sym]
    [(struct var ((? symbol? sym))) sym]
    [(struct relname ((? symbol? sym))) sym]
    [_ (error who "expected symbol-like value, got ~a" v)]))

(define (next-hidden-id counter)
  (values (string-append "hidden:y" (number->string counter)) (add1 counter)))

(define (transpile-canonical/list exprs source-ids hidden-count [acc '()])
  (match exprs
    ['() (values (reverse acc) hidden-count)]
    [(cons expr rest)
     (define-values (compiled next-hidden)
       (transpile-canonical expr source-ids hidden-count))
     (transpile-canonical/list rest source-ids next-hidden (cons compiled acc))]))

(define (transpile-canonical expr source-ids hidden-count)
  (match expr
    [(fresh vars goal)
     (define-values (compiled-vars next-hidden)
       (transpile-canonical/list vars source-ids hidden-count))
     (define-values (compiled-goal final-hidden)
       (transpile-canonical goal source-ids next-hidden))
     (values `(∃ ,compiled-vars ,compiled-goal ,(id->label (hash-ref source-ids expr)))
             final-hidden)]
    [(or (conj left right) (disj left right))
     (define-values (compiled-left next-hidden)
       (transpile-canonical left source-ids hidden-count))
     (define-values (compiled-right final-hidden)
       (transpile-canonical right source-ids next-hidden))
     (values `(,compiled-left ,(if (conj? expr) '∧ '∨) ,compiled-right
                              ,(id->label (hash-ref source-ids expr)))
             final-hidden)]
    [(or (unify left right) (diseq left right))
     (define-values (compiled-left next-hidden)
       (transpile-canonical left source-ids hidden-count))
     (define-values (compiled-right final-hidden)
       (transpile-canonical right source-ids next-hidden))
     (values `(,compiled-left ,(if (unify? expr) '=? '!=) ,compiled-right
                              ,(id->label (hash-ref source-ids expr)))
             final-hidden)]
    [(or (succeed) (fail))
     (values `(,(if (succeed? expr) 'succeed 'fail) ,(id->label (hash-ref source-ids expr)))
             hidden-count)]
    [(delay-goal goal)
     (define-values (compiled next-hidden)
       (transpile-canonical goal source-ids hidden-count))
     (values `(suspend ,compiled ,(id->label (hash-ref source-ids expr))) next-hidden)]
    [(compiled-delay-goal goal)
     (define-values (id next-hidden) (next-hidden-id hidden-count))
     (define-values (compiled final-hidden)
       (transpile-canonical goal source-ids next-hidden))
     (values `(suspend ,compiled ,(id->label id)) final-hidden)]
    [(relcall name arguments)
     (define-values (compiled-name next-hidden)
       (transpile-canonical name source-ids hidden-count))
     (define-values (compiled-arguments final-hidden)
       (transpile-canonical/list arguments source-ids next-hidden))
     (values `(,compiled-name ,@compiled-arguments ,(id->label (hash-ref source-ids expr)))
             final-hidden)]
    [(nil) (values 'empty hidden-count)]
    [(konst _) (values (konst->canonical-term expr) hidden-count)]
    [(kons left right)
     (define-values (compiled-left next-hidden)
       (transpile-canonical left source-ids hidden-count))
     (define-values (compiled-right final-hidden)
       (transpile-canonical right source-ids next-hidden))
     (values `(,compiled-left : ,compiled-right) final-hidden)]
    [(struct var (name))
     (values (string->symbol
              (string-append "x:" (symbol->string (unwrap-symbolish name 'transpile-canonical))))
             hidden-count)]
    [(relname name)
     (values (string->symbol
              (string-append "r:" (symbol->string (unwrap-symbolish name 'transpile-canonical))))
             hidden-count)]
    [(defrel name vars goal)
     (define-values (compiled-name next-hidden)
       (transpile-canonical name source-ids hidden-count))
     (define-values (compiled-vars body-hidden)
       (transpile-canonical/list vars source-ids next-hidden))
     (define-values (compiled-goal final-hidden)
       (transpile-canonical goal source-ids body-hidden))
     (values `(,compiled-name ,compiled-vars ,compiled-goal) final-hidden)]
    [(run _ vars goal)
     (define-values (compiled-vars next-hidden)
       (transpile-canonical/list vars source-ids hidden-count))
     (define-values (compiled-goal final-hidden)
       (transpile-canonical goal source-ids next-hidden))
     (values `(∃ ,compiled-vars ,compiled-goal ,(id->label (hash-ref source-ids expr)))
             final-hidden)]))

;; Folded-away source syntax has no target goal to select. The remaining
;; labels come from the identity map; this only filters unused display tags.
(define (configuration-labels configuration [acc '()])
  (match configuration
    [`(label ,id) (if (member id acc) acc (cons id acc))]
    [(cons left right) (configuration-labels right (configuration-labels left acc))]
    [_ acc]))

(define (parse-prog/canonical lst
                              #:source-mode [source-mode default-source-mode]
                              #:compile-profile [compile-profile #f]
                              #:search-strategy [strategy default-search-strategy])
  (define-values (ast display-ast _profile source-ids)
    (prepare-program lst source-mode compile-profile))
  (match-define (prog relations (and query (run limit names _))) ast)
  (define-values (compiled-relations hidden-count)
    (transpile-canonical/list relations source-ids 0))
  (define-values (compiled-goal _hidden)
    (transpile-canonical query source-ids hidden-count))
  (define initial-state '(state () () () (label "s")))
  ;; Both models start from the same lowered source. Only initialization
  ;; chooses a carrier; no running configuration is translated between them.
  (define compiled-config
    (match (normalize-search-strategy strategy)
      [(strict-search)
       `(program ,compiled-relations (commit (eval (Owners) ,compiled-goal ,initial-state)))]
      [(search-strategy _)
       `(,compiled-relations (More (Work (Owners) ,compiled-goal ,initial-state)))]))
  (define used-labels (configuration-labels compiled-config))
  (define display-ids
    (for/hasheq ([(source id) (in-hash source-ids)] #:when (member id used-labels))
      (values source id)))
  (define html-prog
    (add-guids display-ast 0 display-ids (normalize-source-mode source-mode)))
  (match-define `(∃ ,binders ,_ ,tag) compiled-goal)
  (values compiled-config html-prog
          (query-info (map (lambda (name) (unwrap-symbolish name 'query-info)) names)
                      (for/list ([index (in-range (length binders))])
                        (string->symbol (format "u:~a" index)))
                      tag
                      (and (exact-nonnegative-integer? limit) limit))))
