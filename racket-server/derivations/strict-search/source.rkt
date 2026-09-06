#lang racket

(require redex/reduction-semantics
         (prefix-in direct: "../functional-search/direct-interpreter.rkt"))

(provide Strict encode-goal decode-goal initial
         make-strict-raw make-strict-red strict-red
         search-value? observation-value? contract
         normalize trace run-search run observation->frontier)

;; Rstrict: strict Search computations, independent of the online WorkPath
;; calculus. State and atomic/fresh procedures are shared kernel parameters;
;; search control is explicit syntax. Relcalls are deliberately not admitted.
;; K returns a native Outcome function after performing its eager work. Each
;; atomic contraction eliminates that outcome with failure/success handlers.
(define-language Strict
  [σ any]
  [tag any]
  [p any]
  [n natural]
  [a (succeed tag) (fail tag) (atom p tag)]
  [g a (fresh n p tag) (conj g g tag) (disj g g tag) (suspend g tag)]
  [S (Empty n) (One σ) (Yield σ S) (Delay c)]
  [c S (eval g σ) (mplus c c) (bind c g) (Yield σ c) (force c)]
  ;; E does not descend beneath Delay. Both mplus arguments, and Yield's
  ;; recursive tail, must be mature before their surrounding call returns.
  [E hole (mplus E c) (mplus S E) (bind E g) (Yield σ E) (force E)]
  [O (Done n) (Last σ) (Emit σ O) (Forced O)]
  [o O (render c) (Emit σ o) (Forced o)]
  [t c o]
  ;; Readback is a separate observer; an internal force is not itself an
  ;; outward Forced event. Only render of a mature Delay emits that event.
  [C E (render E) (Emit σ C) (Forced C)])

(define (encode-goal goal)
  (match goal
    [(direct:Succeed tag) `(succeed ,tag)]
    [(direct:FailGoal tag) `(fail ,tag)]
    [(direct:Atom p tag) `(atom ,p ,tag)]
    [(direct:Fresh n body tag)
     (unless (exact-nonnegative-integer? n)
       (raise-argument-error 'encode-goal "exact-nonnegative-integer?" n))
     `(fresh ,n ,body ,tag)]
    [(direct:Conj left right tag)
     `(conj ,(encode-goal left) ,(encode-goal right) ,tag)]
    [(direct:Disj left right tag)
     `(disj ,(encode-goal left) ,(encode-goal right) ,tag)]
    [(direct:Suspend goal tag) `(suspend ,(encode-goal goal) ,tag)]
    [(direct:Call _ _ _)
     (error 'encode-goal "relcalls are outside the strict Search checkpoint")]
    [_ (raise-argument-error 'encode-goal "direct goal (without Call)" goal)]))

(define (decode-goal goal)
  (match goal
    [`(succeed ,tag) (direct:Succeed tag)]
    [`(fail ,tag) (direct:FailGoal tag)]
    [`(atom ,p ,tag) (direct:Atom p tag)]
    [`(fresh ,n ,body ,tag) (direct:Fresh n body tag)]
    [`(conj ,left ,right ,tag)
     (direct:Conj (decode-goal left) (decode-goal right) tag)]
    [`(disj ,left ,right ,tag)
     (direct:Disj (decode-goal left) (decode-goal right) tag)]
    [`(suspend ,goal ,tag) (direct:Suspend (decode-goal goal) tag)]
    [_ (raise-argument-error 'decode-goal "Strict goal" goal)]))

(define (initial goal #:state [state (direct:empty-state)])
  `(eval ,(encode-goal goal) ,state))

(define (atomic-result K goal state)
  ((K (decode-goal goal) state)
   (lambda () `(Empty ,(direct:State-next state)))
   (lambda (next) `(One ,next))))

(define (fresh-result n body state)
  (define next (direct:State-next state))
  (define variables
    (for/list ([offset (in-range n)]) (direct:LVar (+ next offset))))
  `(eval ,(encode-goal (apply body variables))
         ,(struct-copy direct:State state [next (+ next n)])))

(define (make-strict-raw [K direct:basic-kernel])
  (reduction-relation
   Strict
   #:domain t
   [--> (eval a σ) ,(atomic-result K (term a) (term σ)) eval-atom]
   [--> (eval (fresh n p tag) σ)
        ,(fresh-result (term n) (term p) (term σ)) eval-fresh]
   [--> (eval (disj g_1 g_2 tag) σ)
        (mplus (eval g_1 σ) (eval g_2 σ)) eval-disj]
   [--> (eval (conj g_1 g_2 tag) σ)
        (bind (eval g_1 σ) g_2) eval-conj]
   [--> (eval (suspend g tag) σ) (Delay (eval g σ)) eval-suspend]
   [--> (mplus (Empty n) S) S mplus-empty]
   [--> (mplus (One σ) S) (Yield σ S) mplus-one]
   [--> (mplus (Yield σ S_1) S_2)
        (Yield σ (mplus S_1 S_2)) mplus-yield]
   [--> (mplus (Delay c) S)
        (Delay (mplus S (force (Delay c)))) mplus-delay]
   [--> (bind (Empty n) g) (Empty n) bind-empty]
   [--> (bind (One σ) g) (eval g σ) bind-one]
   [--> (bind (Yield σ S) g)
        (mplus (eval g σ) (bind S g)) bind-yield]
   [--> (bind (Delay c) g)
        (Delay (bind (force (Delay c)) g)) bind-delay]
   [--> (force (Delay c)) c force-delay]
   [--> (render (Empty n)) (Done n) render-empty]
   [--> (render (One σ)) (Last σ) render-one]
   [--> (render (Yield σ S)) (Emit σ (render S)) render-yield]
   [--> (render (Delay c))
        (Forced (render (force (Delay c)))) render-delay]))

(define (make-strict-red [K direct:basic-kernel])
  (context-closure (make-strict-raw K) Strict C))

(define strict-red (make-strict-red))

(define (search-value? value) (redex-match? Strict S value))
(define (observation-value? value) (redex-match? Strict O value))

(define (unique-step who successors)
  (match successors
    ['() #f]
    [(list next) next]
    [_ (error who "expected one raw proof, got ~e" successors)]))

(define (contract computation #:kernel [K direct:basic-kernel])
  (unique-step 'contract
               (apply-reduction-relation/tag-with-names
                (make-strict-raw K) computation)))

(define (normalize/with relation computation fuel)
  (cond
    [(or (search-value? computation) (observation-value? computation)) computation]
    [(zero? fuel) (error 'normalize "strict reduction fuel exhausted")]
    [else
     (match (unique-step 'normalize
                         (apply-reduction-relation/tag-with-names
                          relation computation))
       [(list _ next) (normalize/with relation next (sub1 fuel))]
       [#f (error 'normalize "stuck computation: ~e" computation)])]))

(define (normalize computation #:kernel [K direct:basic-kernel] #:fuel [fuel 100000])
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error 'normalize "exact-nonnegative-integer?" fuel))
  (normalize/with (make-strict-red K) computation fuel))

(define (trace/with relation computation fuel [reversed '()])
  (cond
    [(or (search-value? computation) (observation-value? computation))
     (reverse reversed)]
    [(zero? fuel) (error 'trace "strict reduction fuel exhausted")]
    [else
     (match (unique-step 'trace
                         (apply-reduction-relation/tag-with-names relation computation))
       [(and step (list _ next))
        (trace/with relation next (sub1 fuel) (cons step reversed))]
       [#f (error 'trace "stuck computation: ~e" computation)])]))

(define (trace computation #:kernel [K direct:basic-kernel] #:fuel [fuel 100000])
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error 'trace "exact-nonnegative-integer?" fuel))
  (trace/with (make-strict-red K) computation fuel))

(define (observation->frontier observation)
  (match observation
    [`(Done ,n) (direct:Done n)]
    [`(Last ,state) (direct:Last (direct:Answer state))]
    [`(Emit ,state ,tail)
     (direct:Emit (direct:Answer state) (observation->frontier tail))]
    [`(Forced ,tail) (direct:Forced (observation->frontier tail))]
    [_ (raise-argument-error 'observation->frontier "Strict observation" observation)]))

(define (run-search goal #:kernel [K direct:basic-kernel]
                    #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (normalize (initial goal #:state state) #:kernel K #:fuel fuel))

(define (run goal #:kernel [K direct:basic-kernel]
             #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (observation->frontier
   (normalize `(render ,(initial goal #:state state)) #:kernel K #:fuel fuel)))
