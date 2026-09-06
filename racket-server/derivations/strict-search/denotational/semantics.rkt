#lang racket

;; Executable higher-order presentation of the domain in README.md.
;; Goal, kernel Outcome, Search, and Frontier are functions. Only primitive
;; interfaces are imported; no syntax evaluator or machine is used here.
(require (only-in "../../functional-search/direct-interpreter.rkt"
                  State State-next LVar Succeed FailGoal Atom empty-state)
         "kernel.rkt")

(provide failure-outcome success-outcome
         empty-search one-search yield-search delay-search case-search
         mplus bind
         done last-answer emit forced case-frontier render
         atomic succeed fail atom fresh conj disj suspend fix-goal
         run-search run)

;; Scott constructors. Yield receives an already-computed Search function.
;; Its four-argument eliminator must not be confused with a nullary resumption.
(define (empty-search next)
  (lambda (on-empty _one _yield _delay) (on-empty next))) ; S0
(define (one-search state)
  (lambda (_empty on-one _yield _delay) (on-one state))) ; S1
(define (yield-search state rest)
  (lambda (_empty _one on-yield _delay) (on-yield state rest))) ; S2
(define (delay-search resume)
  (lambda (_empty _one _yield on-delay) (on-delay resume))) ; S3
(define (case-search search on-empty on-one on-yield on-delay)
  (search on-empty on-one on-yield on-delay))

;; Racket evaluates BOTH arguments before mplus starts. The recursive Yield
;; tail below likewise finishes before yield-search constructs its lambda.
(define (mplus left right)
  (case-search
   left
   (lambda (_next) right)
   (lambda (state) (yield-search state right))
   (lambda (state rest) (yield-search state (mplus rest right)))
   (lambda (resume)
     (delay-search (lambda () (mplus right (resume))))))) ; R1

(define (bind search continue)
  (case-search
   search
   (lambda (next) (empty-search next))
   (lambda (state) (continue state))
   (lambda (state rest)
     (mplus (continue state) (bind rest continue)))
   (lambda (resume)
     (delay-search (lambda () (bind (resume) continue)))))) ; R2

;; Exact finite readbacks also use Scott constructors. Emit's tail is eager.
;; State serves as the opaque answer payload; reification adds Answer's wrapper.
(define (done next)
  (lambda (on-done _last _emit _forced) (on-done next))) ; O0
(define (last-answer state)
  (lambda (_done on-last _emit _forced) (on-last state))) ; O1
(define (emit state tail)
  (lambda (_done _last on-emit _forced) (on-emit state tail))) ; O2
(define (forced tail)
  (lambda (_done _last _emit on-forced) (on-forced tail))) ; O3
(define (case-frontier frontier on-done on-last on-emit on-forced)
  (frontier on-done on-last on-emit on-forced))

(define (render search)
  (case-search search
               done
               last-answer
               (lambda (state rest) (emit state (render rest)))
               (lambda (resume) (forced (render (resume))))))

;; With K fixed, a Goal is State -> Search. Construction of a goal does not
;; run it. Tags are kernel requests' metadata; composite syntax has no role.
(define (atomic request)
  (lambda (K state) ; G0
    ((K request state)
     (lambda () (empty-search (State-next state)))
     one-search)))
(define (succeed [tag 'succeed]) (atomic (Succeed tag)))
(define (fail [tag 'fail]) (atomic (FailGoal tag)))
(define (atom procedure [tag 'atom]) (atomic (Atom procedure tag)))

(define (fresh arity body)
  (lambda (K state) ; G1
    (unless (exact-nonnegative-integer? arity)
      (raise-argument-error 'fresh "exact-nonnegative-integer?" arity))
    (define next (State-next state))
    (define variables
      (for/list ([offset (in-range arity)]) (LVar (+ next offset))))
    (define state* (struct-copy State state [next (+ next arity)]))
    ((apply body variables) K state*)))

(define (conj left right)
  (lambda (K state) ; G2
    (bind (left K state) (lambda (state*) (right K state*)))))
(define (disj left right)
  (lambda (K state) ; G3
    (mplus (left K state) (right K state))))
(define (suspend goal)
  (lambda (K state) ; G4
    (delay-search (lambda () (goal K state))))) ; R0

;; Executable unfolding of the least fixed point in the domain of Goals.
;; Eta expansion makes self available as a FUNCTION in a strict metalanguage.
;; It does not add Delay, a finite-unfolding limit, or a failure result.
(define (fix-goal functional)
  (local [(define (self K state) ((functional self) K state))]
    self))

(define (run-search goal #:kernel [K basic-kernel] #:state [state (empty-state)])
  (goal K state))
(define (run goal #:kernel [K basic-kernel] #:state [state (empty-state)])
  (render (run-search goal #:kernel K #:state state)))
