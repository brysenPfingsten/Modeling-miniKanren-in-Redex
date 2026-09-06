#lang racket
(require redex/reduction-semantics "feature-schema.rkt"
         (only-in "../../shared/kernel.rkt" Failure Success)
         (for-syntax racket/base racket/syntax syntax/parse))
(provide define-ownerless-big)
;; Compile-time specialization: each row retains its own grammar, state,
;; kernel and allocator. No state or control is decoded into another row.
(define-syntax (define-ownerless-big stx)
 (syntax-parse stx
  [(_ coordinate:id language:id parent:id value?:id observation?:id atomic:id allocate:id feature:id)
   #:with search-big (format-id #'coordinate "search-big/~a" #'coordinate)
   #:with merge-big (format-id #'coordinate "merge-big/~a" #'coordinate)
   #:with bind-big (format-id #'coordinate "bind-big/~a" #'coordinate)
   #:with render-big (format-id #'coordinate "render-big/~a" #'coordinate)
   #:with commit-big (format-id #'coordinate "commit-big/~a" #'coordinate)
   #:with advance-big (format-id #'coordinate "advance-big/~a" #'coordinate)
   #:with collect-big (format-id #'coordinate "collect-big/~a" #'coordinate)
   #:with observe-big (format-id #'coordinate "observe-big/~a" #'coordinate)
   #:with evaluate (format-id #'coordinate "evaluate/~a" #'coordinate)
   #:with promote-search (format-id #'coordinate "promote-search/~a" #'coordinate)
   #:with promote-merge (format-id #'coordinate "promote-merge/~a" #'coordinate)
   #:with promote-bind (format-id #'coordinate "promote-bind/~a" #'coordinate)
   #:with promote-render (format-id #'coordinate "promote-render/~a" #'coordinate)
   #:with promote-commit (format-id #'coordinate "promote-commit/~a" #'coordinate)
   #:with promote-advance (format-id #'coordinate "promote-advance/~a" #'coordinate)
   #:with promote-collect (format-id #'coordinate "promote-collect/~a" #'coordinate)
   #:with promote-observe (format-id #'coordinate "promote-observe/~a" #'coordinate)
   #:with promote (format-id #'coordinate "promote/~a" #'coordinate)
   #:with raw-derivations (format-id #'coordinate "raw-derivations/~a" #'coordinate)
   #'(feature-specialize feature
    (provide language search-big merge-big bind-big render-big commit-big advance-big collect-big observe-big
             evaluate promote raw-derivations)
    (define-extended-language language parent [label string] [trace (label (... ...))])
    (define-metafunction language traces : trace (... ...) -> trace
      [(traces (label (... ...)) (... ...)) (label (... ...) (... ...))])
    (define (atomic-result goal state)
      (match (atomic goal state)
        [(Failure) `(Empty ,(second state))]
        [(Success next) `(One ,next)]))
(define-judgment-form language
  #:mode (search-big I O O)
  #:contract (search-big c SV trace)

  [----------------------------------------------- "value"
   (search-big SV SV ())]

  [(where SV ,(atomic-result (term a) (term σ)))
   ----------------------------------------------- "eval atom"
   (search-big (eval a σ) SV ("eval-atom"))]

  [(where c ,(allocate (term (x (... ...))) (term g) (term σ)))
   (search-big c SV trace)
   ----------------------------------------------- "eval fresh"
   (search-big (eval (∃ (x (... ...)) g tag) σ) SV
               (traces ("allocate-fresh") trace))]

  [(search-big (eval g_1 σ) SV_1 trace_1)
   (search-big (eval g_2 σ) SV_2 trace_2)
   (merge-big SV_1 SV_2 SV trace_merge)
   ----------------------------------------------- "eval disjunction"
   (search-big (eval (g_1 ∨ g_2 tag) σ) SV
               (traces ("eval-disj") trace_1 trace_2 trace_merge))]

  [(search-big (eval g_1 σ) SV_1 trace_1)
   (bind-big SV_1 g_2 SV trace_bind)
   ----------------------------------------------- "eval conjunction"
   (search-big (eval (g_1 ∧ g_2 tag) σ) SV
               (traces ("eval-conj") trace_1 trace_bind))]

  [----------------------------------------------- "eval suspension"
   (search-big (eval (suspend g tag) σ) (Delay (eval g σ))
               ("eval-suspend"))]

  [(search-big c_1 SV_1 trace_1)
   (search-big c_2 SV_2 trace_2)
   (merge-big SV_1 SV_2 SV trace_merge)
   ----------------------------------------------- "strict merge operands"
   (search-big (mplus c_1 c_2) SV
               (traces trace_1 trace_2 trace_merge))]

  [(search-big c SV_1 trace_1)
   (bind-big SV_1 g SV trace_bind)
   ----------------------------------------------- "strict bind operand"
   (search-big (bind c g) SV (traces trace_1 trace_bind))]

  [(side-condition ,(not (value? (term c))))
   (search-big c SV trace)
   ----------------------------------------------- "eager Yield tail"
   (search-big (Yield σ c) (Yield σ SV) trace)]

  [(search-big c_1 (Delay c_2) trace_1)
   (search-big (prefix c_2) SV trace_2)
   ----------------------------------------------- "force suspension"
   (search-big (force c_1) SV
               (traces trace_1 ("force-delay") trace_2))]

  [(search-big c SV trace)
   ----------------------------------------------- "prefix returned Search"
   (search-big (prefix c) SV (traces trace ("prefix-value")))])

(define-judgment-form language
  #:mode (merge-big I I O O)
  #:contract (merge-big SV SV SV trace)

  [----------------------------------------------- "merge empty"
   (merge-big (Empty supply) SV SV ("mplus-empty"))]

  [----------------------------------------------- "merge one"
   (merge-big (One σ) SV (Yield σ SV) ("mplus-one"))]

  [(merge-big SV_1 SV_2 SV trace)
   ----------------------------------------------- "merge eager tail"
   (merge-big (Yield σ SV_1) SV_2 (Yield σ SV)
              (traces ("mplus-yield") trace))]

  [----------------------------------------------- "merge suspension"
   (merge-big (Delay c) SV
              (Delay (mplus SV (force (Delay c))))
              ("mplus-delay"))])

(define-judgment-form language
  #:mode (bind-big I I O O)
  #:contract (bind-big SV g SV trace)

  [----------------------------------------------- "bind empty"
   (bind-big (Empty supply) g (Empty supply) ("bind-empty"))]

  [(search-big (eval g σ) SV trace)
   ----------------------------------------------- "bind one"
   (bind-big (One σ) g SV (traces ("bind-one") trace))]

  [(search-big (eval g σ) SV_1 trace_1)
   (bind-big SV_tail g SV_2 trace_2)
   (merge-big SV_1 SV_2 SV trace_merge)
   ----------------------------------------------- "bind eager residual"
   (bind-big (Yield σ SV_tail) g SV
             (traces ("bind-yield") trace_1 trace_2 trace_merge))]

  [----------------------------------------------- "bind suspension"
   (bind-big (Delay c) g
             (Delay (bind c g))
             ("bind-delay"))])

(define-judgment-form language
  #:mode (render-big I O O)
  #:contract (render-big SV O trace)

  [----------------------------------------------- "render empty"
   (render-big (Empty supply) (Done supply) ("render-empty"))]

  [----------------------------------------------- "render one"
   (render-big (One σ) (Last σ) ("render-one"))]

  [(render-big SV O trace)
   ----------------------------------------------- "render Yield"
   (render-big (Yield σ SV) (Emit σ O)
               (traces ("render-yield") trace))]

  [(search-big c SV trace_search)
   (render-big SV O trace_render)
   ----------------------------------------------- "render suspension"
   (render-big (Delay c) (Forced O)
               (traces ("render-delay") trace_search trace_render))])

(define-judgment-form language
  #:mode (commit-big I O O)
  #:contract (commit-big SV F trace)
  [----------------------------------------------- "commit empty"
   (commit-big (Empty supply) (Done supply) ("commit-empty"))]
  [----------------------------------------------- "commit one"
   (commit-big (One σ) (Last σ) ("commit-one"))]
  [(commit-big SV F trace)
   ----------------------------------------------- "commit eager tail"
   (commit-big (Yield σ SV) (Emit σ F) (traces ("commit-yield") trace))]
  [----------------------------------------------- "commit suspended tip"
   (commit-big (Delay c) (More (Delay c)) ("commit-delay"))])

(define-judgment-form language
  #:mode (advance-big I O O)
  #:contract (advance-big F F trace)
  [----------------------------------------------- "advance done"
   (advance-big (Done supply) (Done supply) ("advance-done"))]
  [----------------------------------------------- "advance last"
   (advance-big (Last σ) (Last σ) ("advance-last"))]
  [(advance-big F_1 F_2 trace)
   ----------------------------------------------- "advance Emit"
   (advance-big (Emit σ F_1) (Emit σ F_2) (traces ("advance-emit") trace))]
  [(advance-big F_1 F_2 trace)
   ----------------------------------------------- "advance existing history"
   (advance-big (Forced F_1) (Forced F_2) (traces ("advance-forced") trace))]
  [(search-big c SV trace_search)
   (commit-big SV F trace_commit)
   ----------------------------------------------- "advance one exposed suspension"
   (advance-big (More (Delay c)) (Forced F)
                (traces ("advance-delay") trace_search trace_commit))])

(define-judgment-form language
  #:mode (collect-big I O O)
  #:contract (collect-big F O trace)
  [----------------------------------------------- "collect done"
   (collect-big (Done supply) (Done supply) ("collect-done"))]
  [----------------------------------------------- "collect last"
   (collect-big (Last σ) (Last σ) ("collect-last"))]
  [(collect-big F O trace)
   ----------------------------------------------- "collect Emit"
   (collect-big (Emit σ F) (Emit σ O) (traces ("collect-emit") trace))]
  [(collect-big F O trace)
   ----------------------------------------------- "collect existing history"
   (collect-big (Forced F) (Forced O) (traces ("collect-forced") trace))]
  [(search-big c SV trace_search)
   (commit-big SV F trace_commit)
   (collect-big F O trace_collect)
   ----------------------------------------------- "collect suspended frontier"
   (collect-big (More (Delay c)) (Forced O)
                (traces ("collect-delay") trace_search trace_commit trace_collect))])

(define-judgment-form language
  #:mode (observe-big I O O)
  #:contract (observe-big o F trace)

  [----------------------------------------------- "observation value"
   (observe-big F F ())]

  [(search-big c SV trace_search)
   (render-big SV O trace_render)
   ----------------------------------------------- "strict render operand"
   (observe-big (render c) O (traces trace_search trace_render))]

  [(search-big c SV trace_search)
   (commit-big SV F trace_commit)
   ----------------------------------------------- "strict commit operand"
   (observe-big (commit c) F (traces trace_search trace_commit))]

  [(observe-big o F_1 trace_operand)
   (advance-big F_1 F_2 trace_advance)
   ----------------------------------------------- "strict advance operand"
   (observe-big (advance o) F_2 (traces trace_operand trace_advance))]

  [(observe-big o F trace_operand)
   (collect-big F O trace_collect)
   ----------------------------------------------- "strict collect operand"
   (observe-big (collect o) O (traces trace_operand trace_collect))]

  [(side-condition ,(not (redex-match? parent F (term o))))
   (observe-big o F trace)
   ----------------------------------------------- "observation Emit tail"
   (observe-big (Emit σ o) (Emit σ F) trace)]

  [(side-condition ,(not (redex-match? parent F (term o))))
   (observe-big o F trace)
   ----------------------------------------------- "observation Forced tail"
   (observe-big (Forced o) (Forced F) trace)])


    ;; Unbounded fixed-point promotion. No source or machine transitions.
    (define (promote-search computation)
      (match computation
        [(? value? value) value]
        [`(eval ,(and goal (or `(succeed ,_) `(fail ,_) `(,_ =? ,_ ,_) `(,_ != ,_ ,_))) ,state)
         (atomic-result goal state)]
        [`(eval (∃ ,binders ,body ,_) ,state) (promote-search (allocate binders body state))]
        [`(eval (,left ∨ ,right ,_) ,state)
         (promote-merge (promote-search `(eval ,left ,state)) (promote-search `(eval ,right ,state)))]
        [`(eval (,left ∧ ,right ,_) ,state) (promote-bind (promote-search `(eval ,left ,state)) right)]
        [`(eval (suspend ,goal ,_) ,state) `(Delay (eval ,goal ,state))]
        [`(mplus ,left ,right) (promote-merge (promote-search left) (promote-search right))]
        [`(bind ,search ,goal) (promote-bind (promote-search search) goal)]
        [`(Yield ,state ,tail) `(Yield ,state ,(promote-search tail))]
        [`(force ,search)
         (match-define `(Delay ,body) (promote-search search))
         (promote-search `(prefix ,body))]
        [`(prefix ,body) (promote-search body)]))
    (define (promote-merge left right)
      (match left
        [`(Empty ,_) right]
        [`(One ,state) `(Yield ,state ,right)]
        [`(Yield ,state ,tail) `(Yield ,state ,(promote-merge tail right))]
        [`(Delay ,body) `(Delay (mplus ,right (force (Delay ,body))))]))
    (define (promote-bind search goal)
      (match search
        [`(Empty ,supply) `(Empty ,supply)]
        [`(One ,state) (promote-search `(eval ,goal ,state))]
        [`(Yield ,state ,tail) (promote-merge (promote-search `(eval ,goal ,state)) (promote-bind tail goal))]
        [`(Delay ,body) `(Delay (bind ,body ,goal))]))
    (define (promote-render search)
      (match search
        [`(Empty ,supply) `(Done ,supply)]
        [`(One ,state) `(Last ,state)]
        [`(Yield ,state ,tail) `(Emit ,state ,(promote-render tail))]
        [`(Delay ,body) `(Forced ,(promote-render (promote-search body)))]))
    (define (promote-commit search)
      (match search
        [`(Empty ,supply) `(Done ,supply)]
        [`(One ,state) `(Last ,state)]
        [`(Yield ,state ,tail) `(Emit ,state ,(promote-commit tail))]
        [`(Delay ,body) `(More (Delay ,body))]))
    (define (promote-advance frontier)
      (match frontier
        [`(Done ,_) frontier]
        [`(Last ,_) frontier]
        [`(Emit ,state ,tail) `(Emit ,state ,(promote-advance tail))]
        [`(Forced ,tail) `(Forced ,(promote-advance tail))]
        [`(More (Delay ,body)) `(Forced ,(promote-commit (promote-search body)))]))
    (define (promote-collect frontier)
      (match frontier
        [`(Done ,_) frontier]
        [`(Last ,_) frontier]
        [`(Emit ,state ,tail) `(Emit ,state ,(promote-collect tail))]
        [`(Forced ,tail) `(Forced ,(promote-collect tail))]
        [`(More (Delay ,body))
         `(Forced ,(promote-collect (promote-commit (promote-search body))))]))
    (define (promote-observe computation)
      (match computation
        [(? (lambda (value) (redex-match? parent F value)) value) value]
        [`(render ,search) (promote-render (promote-search search))]
        [`(commit ,search) (promote-commit (promote-search search))]
        [`(advance ,frontier) (promote-advance (promote-observe frontier))]
        [`(collect ,frontier) (promote-collect (promote-observe frontier))]
        [`(Emit ,state ,tail) `(Emit ,state ,(promote-observe tail))]
        [`(Forced ,tail) `(Forced ,(promote-observe tail))]))
    (define (promote computation)
      (unless (redex-match? parent q computation) (raise-argument-error (quote promote) "feature computation" computation))
      (if (redex-match? parent c computation) (promote-search computation) (promote-observe computation)))
    (define (evaluate computation)
      (define answers
        (if (redex-match? parent c computation)
            (judgment-holds (search-big ,computation SV trace) (SV trace))
            (judgment-holds (observe-big ,computation F trace) (F trace))))
      (match answers
        [(list (list value labels)) (list value labels)]
        [_ (error 'evaluate "nonunique or missing finite Big derivation: ~e" answers)]))
    (define (raw-derivations computation)
      (if (redex-match? parent c computation)
          (build-derivations (search-big ,computation any_value any_trace))
          (build-derivations (observe-big ,computation any_value any_trace)))))]))
