#lang racket

(require redex/reduction-semantics
         (prefix-in source: "source.rkt")
         (prefix-in direct: "../functional-search/direct-interpreter.rkt"))

(provide StrictBig search-big merge-big bind-big render-big observe-big
         atomic-result fresh-computation
         evaluate run-search run)

;; These mutually inductive judgments are the least fixed point of the
;; displayed rules.  They contain no machine states, transition relation,
;; normalization call, or fuel.  Premises expose strict operand evaluation
;; rather than hiding it in a host call to the direct interpreter.
;;
;; A judgment records the ordered *source contraction* labels as well as its
;; result.  In particular, the first operand's entire eager chunk precedes
;; the second operand, both precede merge, and render starts only afterward.
;; Kernel and fresh-body procedures are assumed pure, deterministic, and
;; terminating.  Recursion through a fresh body is allowed; a divergent
;; computation has no finite derivation.  Relcalls are not in this language.
(define-extended-language StrictBig source:Strict
  [K any]
  [label string]
  [trace (label ...)])

(define-metafunction StrictBig
  traces : trace ... -> trace
  [(traces (label ...) ...) (label ... ...)])

(define (atomic-result K goal state)
  ((K (source:decode-goal goal) state)
   (lambda () `(Empty ,(direct:State-next state)))
   (lambda (next) `(One ,next))))

(define (fresh-computation n body state)
  (define next (direct:State-next state))
  (define variables
    (for/list ([offset (in-range n)]) (direct:LVar (+ next offset))))
  `(eval ,(source:encode-goal (apply body variables))
         ,(struct-copy direct:State state [next (+ next n)])))

(define-judgment-form StrictBig
  #:mode (search-big I I O O)
  #:contract (search-big K c S trace)

  [----------------------------------------------- "value"
   (search-big K S S ())]

  [(where S ,(atomic-result (term K) (term a) (term σ)))
   ----------------------------------------------- "eval atom"
   (search-big K (eval a σ) S ("eval-atom"))]

  [(where c ,(fresh-computation (term n) (term p) (term σ)))
   (search-big K c S trace)
   ----------------------------------------------- "eval fresh"
   (search-big K (eval (fresh n p tag) σ) S
               (traces ("eval-fresh") trace))]

  [(search-big K (eval g_1 σ) S_1 trace_1)
   (search-big K (eval g_2 σ) S_2 trace_2)
   (merge-big K S_1 S_2 S trace_merge)
   ----------------------------------------------- "eval disjunction"
   (search-big K (eval (disj g_1 g_2 tag) σ) S
               (traces ("eval-disj") trace_1 trace_2 trace_merge))]

  [(search-big K (eval g_1 σ) S_1 trace_1)
   (bind-big K S_1 g_2 S trace_bind)
   ----------------------------------------------- "eval conjunction"
   (search-big K (eval (conj g_1 g_2 tag) σ) S
               (traces ("eval-conj") trace_1 trace_bind))]

  [----------------------------------------------- "eval suspension"
   (search-big K (eval (suspend g tag) σ) (Delay (eval g σ))
               ("eval-suspend"))]

  [(search-big K c_1 S_1 trace_1)
   (search-big K c_2 S_2 trace_2)
   (merge-big K S_1 S_2 S trace_merge)
   ----------------------------------------------- "strict merge operands"
   (search-big K (mplus c_1 c_2) S
               (traces trace_1 trace_2 trace_merge))]

  [(search-big K c S_1 trace_1)
   (bind-big K S_1 g S trace_bind)
   ----------------------------------------------- "strict bind operand"
   (search-big K (bind c g) S (traces trace_1 trace_bind))]

  [(side-condition ,(not (source:search-value? (term c))))
   (search-big K c S trace)
   ----------------------------------------------- "eager Yield tail"
   (search-big K (Yield σ c) (Yield σ S) trace)]

  [(search-big K c_1 (Delay c_2) trace_1)
   (search-big K c_2 S trace_2)
   ----------------------------------------------- "force suspension"
   (search-big K (force c_1) S
               (traces trace_1 ("force-delay") trace_2))])

(define-judgment-form StrictBig
  #:mode (merge-big I I I O O)
  #:contract (merge-big K S S S trace)

  [----------------------------------------------- "merge empty"
   (merge-big K (Empty n) S S ("mplus-empty"))]

  [----------------------------------------------- "merge one"
   (merge-big K (One σ) S (Yield σ S) ("mplus-one"))]

  [(merge-big K S_1 S_2 S trace)
   ----------------------------------------------- "merge eager tail"
   (merge-big K (Yield σ S_1) S_2 (Yield σ S)
              (traces ("mplus-yield") trace))]

  [----------------------------------------------- "merge suspension"
   (merge-big K (Delay c) S
              (Delay (mplus S (force (Delay c))))
              ("mplus-delay"))])

(define-judgment-form StrictBig
  #:mode (bind-big I I I O O)
  #:contract (bind-big K S g S trace)

  [----------------------------------------------- "bind empty"
   (bind-big K (Empty n) g (Empty n) ("bind-empty"))]

  [(search-big K (eval g σ) S trace)
   ----------------------------------------------- "bind one"
   (bind-big K (One σ) g S (traces ("bind-one") trace))]

  [(search-big K (eval g σ) S_1 trace_1)
   (bind-big K S_tail g S_2 trace_2)
   (merge-big K S_1 S_2 S trace_merge)
   ----------------------------------------------- "bind eager residual"
   (bind-big K (Yield σ S_tail) g S
             (traces ("bind-yield") trace_1 trace_2 trace_merge))]

  [----------------------------------------------- "bind suspension"
   (bind-big K (Delay c) g
             (Delay (bind (force (Delay c)) g))
             ("bind-delay"))])

(define-judgment-form StrictBig
  #:mode (render-big I I O O)
  #:contract (render-big K S O trace)

  [----------------------------------------------- "render empty"
   (render-big K (Empty n) (Done n) ("render-empty"))]

  [----------------------------------------------- "render one"
   (render-big K (One σ) (Last σ) ("render-one"))]

  [(render-big K S O trace)
   ----------------------------------------------- "render Yield"
   (render-big K (Yield σ S) (Emit σ O)
               (traces ("render-yield") trace))]

  [(search-big K (force (Delay c)) S trace_search)
   (render-big K S O trace_render)
   ----------------------------------------------- "render suspension"
   (render-big K (Delay c) (Forced O)
               (traces ("render-delay") trace_search trace_render))])

(define-judgment-form StrictBig
  #:mode (observe-big I I O O)
  #:contract (observe-big K o O trace)

  [----------------------------------------------- "observation value"
   (observe-big K O O ())]

  [(search-big K c S trace_search)
   (render-big K S O trace_render)
   ----------------------------------------------- "strict render operand"
   (observe-big K (render c) O (traces trace_search trace_render))]

  [(side-condition ,(not (source:observation-value? (term o))))
   (observe-big K o O trace)
   ----------------------------------------------- "observation Emit tail"
   (observe-big K (Emit σ o) (Emit σ O) trace)]

  [(side-condition ,(not (source:observation-value? (term o))))
   (observe-big K o O trace)
   ----------------------------------------------- "observation Forced tail"
   (observe-big K (Forced o) (Forced O) trace)])

;; These unbounded entries search for an inductive derivation.  A divergent
;; query need not return.  Use big-step-spec.rkt's bounded proof-search harness
;; when testing divergence; exhausting that harness is not a Big result.
(define (evaluate computation #:kernel [K direct:basic-kernel])
  (define answers
    (cond
      [(redex-match? source:Strict c computation)
       (judgment-holds (search-big ,K ,computation S trace) (S trace))]
      [(redex-match? source:Strict o computation)
       (judgment-holds (observe-big ,K ,computation O trace) (O trace))]
      [else (raise-argument-error 'evaluate "Strict computation" computation)]))
  (match answers
    [(list (list value _trace)) value]
    ['() (error 'evaluate "no finite Big derivation for ~e" computation)]
    [_ (error 'evaluate "nonunique Big result: ~e" answers)]))

(define (run-search goal #:kernel [K direct:basic-kernel]
                    #:state [state (direct:empty-state)])
  (evaluate (source:initial goal #:state state) #:kernel K))

(define (run goal #:kernel [K direct:basic-kernel]
             #:state [state (direct:empty-state)])
  (source:observation->frontier
   (evaluate `(render ,(source:initial goal #:state state)) #:kernel K)))
