#lang racket

(require redex/reduction-semantics
         (prefix-in big: "big-step.rkt")
         (prefix-in compressed: "compressed.rkt")
         (prefix-in source: "source.rkt")
         (prefix-in direct: "../functional-search/direct-interpreter.rkt"))

(provide (struct-out BigProof) (struct-out ProofSearchExhausted)
         proof-functional promote prove valid-proof? judgment-agrees?
         raw-derivations proof-source-trace proof-compressed-trace)

;; Queries name the mutually recursive functions whose least fixed point is
;; presented by the judgments in big-step.rkt:
;;   (search c), (merge S S), (bind S g), (render S), (observe o).
;; A proof is a finite tree.  Its trace records contractions in premise order;
;; premises are genuine subderivations, not a list of small-step successors.
(struct BigProof (rule query value trace premises) #:transparent)
(struct ProofSearchExhausted (query depth) #:transparent)

(define (conclude rule query value . pieces)
  (BigProof rule query value
            (append-map
             (lambda (piece)
               (match piece
                 [(BigProof _ _ _ trace _) trace]
                 [(? string? label) (list label)]))
             pieces)
            (filter BigProof? pieces)))

;; One unfolding of the fixed-point functional.  Every recursive edge goes
;; through recur; no source/machine step is consulted.  Ordered local bindings
;; retain the already-mature first chunk during strict second-operand work.
(define (proof-functional recur query #:kernel [K direct:basic-kernel])
  (match query
    [`(search ,(? source:search-value? value))
     (conclude 'value query value)]
    [`(search (eval ,(and goal (or `(succeed ,_) `(fail ,_) `(atom ,_ ,_))) ,state))
     (conclude 'eval-atom query (big:atomic-result K goal state) "eval-atom")]
    [`(search (eval (fresh ,n ,body ,_) ,state))
     (define child (recur `(search ,(big:fresh-computation n body state))))
     (conclude 'eval-fresh query (BigProof-value child) "eval-fresh" child)]
    [`(search (eval (disj ,left ,right ,_) ,state))
     (define p-left (recur `(search (eval ,left ,state))))
     (define p-right (recur `(search (eval ,right ,state))))
     (define p-merge (recur `(merge ,(BigProof-value p-left) ,(BigProof-value p-right))))
     (conclude 'eval-disj query (BigProof-value p-merge)
               "eval-disj" p-left p-right p-merge)]
    [`(search (eval (conj ,left ,right ,_) ,state))
     (define p-left (recur `(search (eval ,left ,state))))
     (define p-bind (recur `(bind ,(BigProof-value p-left) ,right)))
     (conclude 'eval-conj query (BigProof-value p-bind) "eval-conj" p-left p-bind)]
    [`(search (eval (suspend ,goal ,_) ,state))
     (conclude 'eval-suspend query `(Delay (eval ,goal ,state)) "eval-suspend")]
    [`(search (mplus ,left ,right))
     (define p-left (recur `(search ,left)))
     (define p-right (recur `(search ,right)))
     (define p-merge (recur `(merge ,(BigProof-value p-left) ,(BigProof-value p-right))))
     (conclude 'mplus query (BigProof-value p-merge) p-left p-right p-merge)]
    [`(search (bind ,search ,goal))
     (define p-search (recur `(search ,search)))
     (define p-bind (recur `(bind ,(BigProof-value p-search) ,goal)))
     (conclude 'bind query (BigProof-value p-bind) p-search p-bind)]
    [`(search (Yield ,state ,tail))
     (define p-tail (recur `(search ,tail)))
     (conclude 'Yield query `(Yield ,state ,(BigProof-value p-tail)) p-tail)]
    [`(search (force ,search))
     (define p-search (recur `(search ,search)))
     (match-define `(Delay ,body) (BigProof-value p-search))
     (define p-body (recur `(search ,body)))
     (conclude 'force query (BigProof-value p-body) p-search "force-delay" p-body)]

    [`(merge (Empty ,_) ,right)
     (conclude 'mplus-empty query right "mplus-empty")]
    [`(merge (One ,state) ,right)
     (conclude 'mplus-one query `(Yield ,state ,right) "mplus-one")]
    [`(merge (Yield ,state ,tail) ,right)
     (define p-merge (recur `(merge ,tail ,right)))
     (conclude 'mplus-yield query `(Yield ,state ,(BigProof-value p-merge))
               "mplus-yield" p-merge)]
    [`(merge (Delay ,body) ,right)
     (conclude 'mplus-delay query `(Delay (mplus ,right (force (Delay ,body))))
               "mplus-delay")]

    [`(bind (Empty ,n) ,_)
     (conclude 'bind-empty query `(Empty ,n) "bind-empty")]
    [`(bind (One ,state) ,goal)
     (define child (recur `(search (eval ,goal ,state))))
     (conclude 'bind-one query (BigProof-value child) "bind-one" child)]
    [`(bind (Yield ,state ,tail) ,goal)
     (define p-head (recur `(search (eval ,goal ,state))))
     (define p-tail (recur `(bind ,tail ,goal)))
     (define p-merge (recur `(merge ,(BigProof-value p-head) ,(BigProof-value p-tail))))
     (conclude 'bind-yield query (BigProof-value p-merge)
               "bind-yield" p-head p-tail p-merge)]
    [`(bind (Delay ,body) ,goal)
     (conclude 'bind-delay query `(Delay (bind (force (Delay ,body)) ,goal))
               "bind-delay")]

    [`(render (Empty ,n))
     (conclude 'render-empty query `(Done ,n) "render-empty")]
    [`(render (One ,state))
     (conclude 'render-one query `(Last ,state) "render-one")]
    [`(render (Yield ,state ,tail))
     (define child (recur `(render ,tail)))
     (conclude 'render-yield query `(Emit ,state ,(BigProof-value child))
               "render-yield" child)]
    [`(render (Delay ,body))
     (define p-search (recur `(search (force (Delay ,body)))))
     (define p-render (recur `(render ,(BigProof-value p-search))))
     (conclude 'render-delay query `(Forced ,(BigProof-value p-render))
               "render-delay" p-search p-render)]

    [`(observe ,(? source:observation-value? value))
     (conclude 'observation-value query value)]
    [`(observe (render ,computation))
     (define p-search (recur `(search ,computation)))
     (define p-render (recur `(render ,(BigProof-value p-search))))
     (conclude 'render query (BigProof-value p-render) p-search p-render)]
    [`(observe (Emit ,state ,tail))
     (define p-tail (recur `(observe ,tail)))
     (conclude 'Emit query `(Emit ,state ,(BigProof-value p-tail)) p-tail)]
    [`(observe (Forced ,tail))
     (define p-tail (recur `(observe ,tail)))
     (conclude 'Forced query `(Forced ,(BigProof-value p-tail)) p-tail)]
    [_ (raise-argument-error 'proof-functional "well-sorted Big query" query)]))

;; Fixed-point promotion: erase the control-transfer constructors and tie the
;; recursive equations directly.  This evaluator has no bound; like judgment
;; search, it may diverge when there is no finite derivation.
(define (promote query #:kernel [K direct:basic-kernel])
  (proof-functional (lambda (next) (promote next #:kernel K)) query #:kernel K))

;; Depth is a bound on attempted proof construction, not part of the relation.
;; Exhaustion never constructs a BigProof and is never translated to Empty,
;; Done, a partial answer, or a theorem that no derivation exists.
(define (prove query #:kernel [K direct:basic-kernel] #:depth [depth 10000])
  (unless (exact-nonnegative-integer? depth)
    (raise-argument-error 'prove "exact-nonnegative-integer?" depth))
  (let/ec exhausted
    (local [(define (visit query remaining)
              (when (zero? remaining)
                (exhausted (ProofSearchExhausted query depth)))
              (proof-functional
               (lambda (next) (visit next (sub1 remaining))) query #:kernel K))]
      (visit query depth))))

;; Check a finite certificate by one rule unfolding at each node, consuming
;; exactly its stated premises.  A forged result, trace, rule, query, reordered
;; premise, missing premise, or extra premise is rejected.
(define (valid-proof? proof #:kernel [K direct:basic-kernel])
  (and
   (BigProof? proof)
   (with-handlers ([exn:fail? (lambda (_) #f)])
     (define remaining (BigProof-premises proof))
     (define expected
       (proof-functional
        (lambda (query)
          (match remaining
            [(cons child rest)
             (unless (and (equal? query (BigProof-query child))
                          (valid-proof? child #:kernel K))
               (error 'valid-proof? "invalid premise"))
             (set! remaining rest)
             child]
            ['() (error 'valid-proof? "missing premise")]))
        (BigProof-query proof) #:kernel K))
     (and (null? remaining) (equal? expected proof)))))

;; Independent Redex presentation agrees with this proof's conclusion.
;; Call only on a finite certificate/query, not as a divergence decision.
(define (judgment-agrees? proof #:kernel [K direct:basic-kernel])
  (match-define (BigProof _ query value trace _) proof)
  (equal?
   (list (list value trace))
   (match query
     [`(search ,computation)
      (judgment-holds (big:search-big ,K ,computation any_value any_trace)
                     (any_value any_trace))]
     [`(merge ,left ,right)
      (judgment-holds (big:merge-big ,K ,left ,right any_value any_trace)
                     (any_value any_trace))]
     [`(bind ,search ,goal)
      (judgment-holds (big:bind-big ,K ,search ,goal any_value any_trace)
                     (any_value any_trace))]
     [`(render ,search)
      (judgment-holds (big:render-big ,K ,search any_value any_trace)
                     (any_value any_trace))]
     [`(observe ,computation)
      (judgment-holds (big:observe-big ,K ,computation any_value any_trace)
                     (any_value any_trace))])))

;; Unlike judgment-holds result collection, build-derivations retains proof
;; multiplicity even when two proofs have the same conclusion.
(define (raw-derivations query #:kernel [K direct:basic-kernel])
  (match query
    [`(search ,computation)
     (build-derivations (big:search-big ,K ,computation any_value any_trace))]
    [`(merge ,left ,right)
     (build-derivations (big:merge-big ,K ,left ,right any_value any_trace))]
    [`(bind ,search ,goal)
     (build-derivations (big:bind-big ,K ,search ,goal any_value any_trace))]
    [`(render ,search)
     (build-derivations (big:render-big ,K ,search any_value any_trace))]
    [`(observe ,computation)
     (build-derivations (big:observe-big ,K ,computation any_value any_trace))]))

(define (query->computation query)
  (match query
    [`(search ,computation) computation]
    [`(merge ,left ,right) `(mplus ,left ,right)]
    [`(bind ,search ,goal) `(bind ,search ,goal)]
    [`(render ,search) `(render ,search)]
    [`(observe ,computation) computation]))

;; Finite-run certificate: replay precisely the proof's source contractions.
;; The induction behind this checker is by Big derivation: operand premises
;; lift under the strict E/C contexts, the named root rule contracts, and the
;; result premises lift under Yield/Emit/Forced.  Delay has no such lift.
;; Conversely a finite R run splits uniquely at those context boundaries.
;; Together with the downstream stage's span replay, this supplies a concrete
;; finite B/Big witness, not a coinductive stream or guarded-fusion claim.
(define (proof-source-trace proof #:kernel [K direct:basic-kernel])
  (unless (valid-proof? proof #:kernel K)
    (raise-argument-error 'proof-source-trace "valid BigProof" proof))
  (define relation (source:make-strict-red K))
  (define (replay computation labels [reversed '()])
    (match labels
      ['()
       (unless (equal? computation (BigProof-value proof))
         (error 'proof-source-trace "proof did not reach its claimed result"))
       (reverse reversed)]
      [(cons label rest)
       (match (apply-reduction-relation/tag-with-names relation computation)
         [(list (and step (list actual next)))
          (unless (equal? label actual)
            (error 'proof-source-trace "expected contraction ~e, found ~e" label actual))
          (replay next rest (cons step reversed))]
         [other (error 'proof-source-trace "nonunique or missing contraction: ~e" other)])]))
  (replay (query->computation (BigProof-query proof)) (BigProof-trace proof)))

;; This finite B/Big certificate also checks every B edge's exact M span.
;; Its recursion consumes the existing finite Big trace, so it cannot
;; accidentally certify a divergent B run by exhausting a numeric budget.
(define (proof-compressed-trace proof initial #:kernel [K direct:basic-kernel])
  (unless (and (valid-proof? proof #:kernel K)
               (equal? (compressed:readback-B initial)
                       (query->computation (BigProof-query proof))))
    (raise-arguments-error 'proof-compressed-trace
                           "proof and compressed entry must have the same source query"
                           "proof" proof "initial" initial))
  (define (replay configuration labels [reversed '()])
    (match labels
      ['()
       (unless (and (compressed:compressed-final? configuration)
                    (equal? (compressed:readback-B configuration)
                            (BigProof-value proof)))
         (error 'proof-compressed-trace "B endpoint is not the Big conclusion"))
       (reverse reversed)]
      [(cons label rest)
       (match (compressed:compressed-step/tagged configuration #:kernel K)
         [(and edge (list span next))
          (unless (and (equal? (compressed:semantic-labels span) (list label))
                       (equal? (compressed:replay-span
                                (compressed:decode-BM configuration) span #:kernel K)
                               (compressed:decode-BM next)))
            (error 'proof-compressed-trace "B/M span does not match Big contraction"))
          (replay next rest (cons edge reversed))]
         [#f (error 'proof-compressed-trace "B ended before the Big trace")])]))
  (replay initial (BigProof-trace proof)))
