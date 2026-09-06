#lang racket

(require racket/match
         (prefix-in direct: "../functional-search/direct-interpreter.rkt"))

(provide (all-defined-out))

#|
Functional derivation from the strict direct interpreter, before any online
fusion.  The first section makes evaluation order explicit in CPS; the second
replaces the continuation and Delay closures with first-order data.  Neither
section calls the direct interpreter's value-of, mplus, bind, or render.

Both disjunction operands are evaluated before merging.  A Yield tail is a
mature Search value.  bind on Yield computes the continuation result, then the
recursive residual, before mplus starts.  Only Suspend and the residuals of
mplus/bind on Delay introduce object-language suspensions.  In particular,
AfterDisjLeft is an eager evaluation frame, not a delayed scheduler job.

Goal syntax, states, kernels, and readback structures are shared with direct.
K computes a native Outcome eagerly; both stages apply that result to handlers
within the atomic operation. Kernel internals remain an opaque parameter.
The first-order machine carries K as its fixed execution environment.  If
run-search and render are called separately, pass the same #:kernel to both;
run maintains that environment throughout evaluation and forcing automatically.
Relation calls are deliberately excluded from this initial strict coordinate.
The step budget bounds interpreter transitions, not arbitrary host computation
inside an Atom procedure or Fresh body.  These executable equations and finite
checks support the derivation; they do not constitute a general adequacy or
guarded-fusion proof.
|#

;; One budget covers eager evaluation, all forced resumptions, and readback.
(define default-fuel 100000)

(struct exn:fail:fuel exn:fail (configuration) #:transparent)

(define (make-budget fuel)
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error 'make-budget "exact-nonnegative-integer?" fuel))
  (box fuel))

(define (consume! budget configuration)
  (when (zero? (unbox budget))
    (raise
     (exn:fail:fuel "strict functional machine exhausted its step budget"
                    (current-continuation-marks)
                    configuration)))
  (set-box! budget (sub1 (unbox budget))))

;; ---------------------------------------------------------------------------
;; CPS equations.  Delay retains the nullary-thunk interface of direct Search.
;; The optional final argument to /k procedures is their shared budget box.

(define (eval/k goal state K k [budget (make-budget default-fuel)])
  (consume! budget `(eval/k ,goal ,state))
  (match goal
    [(direct:Fresh arity body _)
     (unless (exact-nonnegative-integer? arity)
       (raise-argument-error 'eval/k "exact-nonnegative-integer?" arity))
     (define next (direct:State-next state))
     (define variables
       (for/list ([offset (in-range arity)])
         (direct:LVar (+ next offset))))
     (define state*
       (struct-copy direct:State state [next (+ next arity)]))
     (eval/k (apply body variables) state* K k budget)]
    [(direct:Conj left right _)
     (eval/k left state K
             (lambda (search)
               (bind/k search
                       (lambda (state* k*)
                         (eval/k right state* K k* budget))
                       k budget))
             budget)]
    [(direct:Disj left right _)
     (eval/k left state K
             (lambda (left-search)
               (eval/k right state K
                       (lambda (right-search)
                         (mplus/k left-search right-search k budget))
                       budget))
             budget)]
    [(direct:Suspend delayed-goal _)
     (k (direct:Delay
         (lambda ()
           (eval/k delayed-goal state K values budget))))]
    [(direct:Call _ _ _)
     (error 'eval/k "relation calls are outside the strict-search coordinate")]
    [atomic
     ((K atomic state)
      (lambda () (k (direct:Empty (direct:State-next state))))
      (lambda (state*) (k (direct:One state*))))]))

(define (mplus/k left right k [budget (make-budget default-fuel)])
  (consume! budget `(mplus/k ,left ,right))
  (match left
    [(direct:Empty _) (k right)]
    [(direct:One state) (k (direct:Yield state right))]
    [(direct:Yield state rest)
     (mplus/k rest right
              (lambda (tail) (k (direct:Yield state tail)))
              budget)]
    [(direct:Delay rest)
     (k (direct:Delay
         (lambda ()
           ;; right is already mature.  Force rest before entering mplus/k.
           (define forced (rest))
           (mplus/k right forced values budget))))]))

(define (bind/k search continue k [budget (make-budget default-fuel)])
  (consume! budget `(bind/k ,search))
  (match search
    [(direct:Empty next) (k (direct:Empty next))]
    [(direct:One state) (continue state k)]
    [(direct:Yield state rest)
     (continue state
               (lambda (head)
                 (bind/k rest continue
                         (lambda (tail) (mplus/k head tail k budget))
                         budget)))]
    [(direct:Delay rest)
     (k (direct:Delay
         (lambda ()
           (define forced (rest))
           (bind/k forced continue values budget))))]))

(define (render/k search k [budget (make-budget default-fuel)])
  (consume! budget `(render/k ,search))
  (match search
    [(direct:Empty next) (k (direct:Done next))]
    [(direct:One state) (k (direct:Last (direct:Answer state)))]
    [(direct:Yield state rest)
     (render/k rest
               (lambda (tail) (k (direct:Emit (direct:Answer state) tail)))
               budget)]
    [(direct:Delay rest)
     (define forced (rest))
     (render/k forced
               (lambda (tail) (k (direct:Forced tail)))
               budget)]))

(define (cps-run-search goal
                        #:kernel [K direct:basic-kernel]
                        #:state [state (direct:empty-state)]
                        #:fuel [fuel default-fuel])
  (eval/k goal state K values (make-budget fuel)))

(define (cps-run goal
                 #:kernel [K direct:basic-kernel]
                 #:state [state (direct:empty-state)]
                 #:fuel [fuel default-fuel])
  (define budget (make-budget fuel))
  (eval/k goal state K
          (lambda (search) (render/k search values budget))
          budget))

;; ---------------------------------------------------------------------------
;; Defunctionalized Search, continuations, commands, and Delay resumptions.

(struct Empty (next) #:transparent)
(struct One (state) #:transparent)
(struct Yield (state rest) #:transparent)
(struct Delay (rest) #:transparent)

;; Defunctionalization of State -> Search conjunction continuations.
(struct Continue (goal) #:transparent)

;; The only ways to form a Delay payload.  A merge retains nested orientation
;; through its mature right Search and its original left resumption.
(struct ResumeEval (goal state) #:transparent)
(struct ResumeMerge (right left-rest) #:transparent)
(struct ResumeBind (rest continue) #:transparent)

(struct Halt () #:transparent)
(struct AfterConjLeft (right k) #:transparent)
(struct AfterDisjLeft (right state k) #:transparent)
(struct AfterDisjRight (left k) #:transparent)
(struct RebuildYield (state k) #:transparent)
(struct AfterBindHead (rest continue k) #:transparent)
(struct AfterBindTail (head k) #:transparent)
(struct AfterForceMerge (right k) #:transparent)
(struct AfterForceBind (continue k) #:transparent)
(struct AfterEvalRender (k) #:transparent)
(struct AfterEmit (state k) #:transparent)
(struct AfterRenderForce (k) #:transparent)
(struct AfterForced (k) #:transparent)

;; Return carries a Search during evaluation, or a frontier during readback.
(struct Eval (goal state k) #:transparent)
(struct Mplus (left right k) #:transparent)
(struct Bind (search continue k) #:transparent)
(struct Force (resumption k) #:transparent)
(struct Render (search k) #:transparent)
(struct Return (value k) #:transparent)

(define (initial-machine goal
                         #:state [state (direct:empty-state)]
                         #:render? [render? #f])
  (Eval goal state (if render? (AfterEvalRender (Halt)) (Halt))))

(define (machine-final? configuration)
  (match configuration
    [(Return _ (Halt)) #t]
    [_ #f]))

(define (machine-step configuration #:kernel [K direct:basic-kernel])
  (match configuration
    [(Eval (direct:Fresh arity body _) state k)
     (unless (exact-nonnegative-integer? arity)
       (raise-argument-error 'machine-step "exact-nonnegative-integer?" arity))
     (define next (direct:State-next state))
     (define variables
       (for/list ([offset (in-range arity)])
         (direct:LVar (+ next offset))))
     (define state*
       (struct-copy direct:State state [next (+ next arity)]))
     (Eval (apply body variables) state* k)]
    [(Eval (direct:Conj left right _) state k)
     (Eval left state (AfterConjLeft right k))]
    [(Eval (direct:Disj left right _) state k)
     (Eval left state (AfterDisjLeft right state k))]
    [(Eval (direct:Suspend goal _) state k)
     (Return (Delay (ResumeEval goal state)) k)]
    [(Eval (direct:Call _ _ _) _ _)
     (error 'machine-step
            "relation calls are outside the strict-search coordinate")]
    [(Eval atomic state k)
     ((K atomic state)
      (lambda () (Return (Empty (direct:State-next state)) k))
      (lambda (state*) (Return (One state*) k)))]

    [(Mplus (Empty _) right k) (Return right k)]
    [(Mplus (One state) right k) (Return (Yield state right) k)]
    [(Mplus (Yield state rest) right k)
     (Mplus rest right (RebuildYield state k))]
    [(Mplus (Delay rest) right k)
     (Return (Delay (ResumeMerge right rest)) k)]

    [(Bind (Empty next) _ k) (Return (Empty next) k)]
    [(Bind (One state) (Continue goal) k) (Eval goal state k)]
    [(Bind (Yield state rest) (and continue (Continue goal)) k)
     (Eval goal state (AfterBindHead rest continue k))]
    [(Bind (Delay rest) continue k)
     (Return (Delay (ResumeBind rest continue)) k)]

    [(Force (ResumeEval goal state) k) (Eval goal state k)]
    [(Force (ResumeMerge right rest) k)
     (Force rest (AfterForceMerge right k))]
    [(Force (ResumeBind rest continue) k)
     (Force rest (AfterForceBind continue k))]

    [(Render (Empty next) k) (Return (direct:Done next) k)]
    [(Render (One state) k)
     (Return (direct:Last (direct:Answer state)) k)]
    [(Render (Yield state rest) k) (Render rest (AfterEmit state k))]
    [(Render (Delay rest) k) (Force rest (AfterRenderForce k))]

    [(Return value (Halt)) configuration]
    [(Return search (AfterConjLeft right k))
     (Bind search (Continue right) k)]
    [(Return left-search (AfterDisjLeft right state k))
     (Eval right state (AfterDisjRight left-search k))]
    [(Return right-search (AfterDisjRight left-search k))
     (Mplus left-search right-search k)]
    [(Return tail (RebuildYield state k))
     (Return (Yield state tail) k)]
    [(Return head (AfterBindHead rest continue k))
     (Bind rest continue (AfterBindTail head k))]
    [(Return tail (AfterBindTail head k)) (Mplus head tail k)]
    [(Return forced (AfterForceMerge right k)) (Mplus right forced k)]
    [(Return forced (AfterForceBind continue k)) (Bind forced continue k)]
    [(Return search (AfterEvalRender k)) (Render search k)]
    [(Return tail (AfterEmit state k))
     (Return (direct:Emit (direct:Answer state) tail) k)]
    [(Return search (AfterRenderForce k)) (Render search (AfterForced k))]
    [(Return tail (AfterForced k)) (Return (direct:Forced tail) k)]
    [_ (error 'machine-step "invalid machine configuration: ~e" configuration)]))

(define (run-machine/budget configuration K budget)
  (match configuration
    [(Return value (Halt)) value]
    [_
     (consume! budget configuration)
     (run-machine/budget (machine-step configuration #:kernel K) K budget)]))

(define (run-machine configuration
                     #:kernel [K direct:basic-kernel]
                     #:fuel [fuel default-fuel])
  (run-machine/budget configuration K (make-budget fuel)))

(define (run-search goal
                    #:kernel [K direct:basic-kernel]
                    #:state [state (direct:empty-state)]
                    #:fuel [fuel default-fuel])
  (run-machine (initial-machine goal #:state state)
               #:kernel K #:fuel fuel))

(define (render search
                #:kernel [K direct:basic-kernel]
                #:fuel [fuel default-fuel])
  (run-machine (Render search (Halt)) #:kernel K #:fuel fuel))

(define (run goal
             #:kernel [K direct:basic-kernel]
             #:state [state (direct:empty-state)]
             #:fuel [fuel default-fuel])
  (run-machine (initial-machine goal #:state state #:render? #t)
               #:kernel K #:fuel fuel))

(module+ test
  (require rackunit)

  (define finite-witnesses
    (list (direct:Succeed 'success)
          (direct:FailGoal 'failure)
          (direct:Disj (direct:put 'A) (direct:put 'B) 'eager)
          (direct:Conj
           (direct:Disj (direct:put 'A) (direct:put 'B) 'choice)
           (direct:Fresh 1 (lambda (x) (direct:Succeed x)) 'fresh)
           'bind)
          direct:nested-rail-witness))
  (for ([goal (in-list finite-witnesses)])
    (define expected (direct:run goal))
    (check-equal? (cps-run goal) expected)
    (check-equal? (run goal) expected))

  ;; A left mature answer must be retained while the right operand executes.
  (define strict-goal
    (direct:Disj (direct:put 'A) (direct:put 'B) 'strict))
  (match-define (Eval _ _ (AfterDisjRight left-search (Halt)))
    (machine-step
     (machine-step
      (machine-step (initial-machine strict-goal)))))
  (check-equal? left-search (One (struct-copy direct:State
                                            (direct:empty-state)
                                            [tag 'A])))

  ;; Fresh permits finite-fuel divergence witnesses without relation calls.
  (define (omega)
    (direct:Fresh 0 omega 'unguarded))
  (define delayed-omega (direct:Suspend (omega) 'guard))
  (check-true (Delay? (run-search delayed-omega #:fuel 10)))
  (check-true (direct:Delay? (cps-run-search delayed-omega #:fuel 10)))
  (check-exn exn:fail:fuel? (lambda () (run delayed-omega #:fuel 100)))
  (check-exn exn:fail:fuel? (lambda () (cps-run delayed-omega #:fuel 100)))
  (check-exn exn:fail:fuel? (lambda () (run-search (omega) #:fuel 100)))
  (check-exn exn:fail:fuel? (lambda () (cps-run-search (omega) #:fuel 100)))
  (check-exn #rx"relation calls are outside"
             (lambda () (run (direct:Call 'later '() 'relation)))))
