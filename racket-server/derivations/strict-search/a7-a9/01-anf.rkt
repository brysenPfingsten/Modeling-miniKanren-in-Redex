#lang racket

(require (prefix-in d: "../../functional-search/direct-interpreter.rkt"))
(provide eval/a merge/a bind/a force/a render/a run-search run)

;; The direct strict interpreter with evaluation order named explicitly.
;; Kernel and Fresh callbacks are primitive host boundaries in this experiment.
;; Search and goal data are the oracle's data; no oracle evaluator is called.
(define (eval/a goal state K)
  (match goal
    [(d:Fresh arity body _)
     (unless (exact-nonnegative-integer? arity)
       (raise-argument-error 'eval/a "exact-nonnegative-integer?" arity))
     (define next (d:State-next state))
     (define variables (for/list ([i (in-range arity)]) (d:LVar (+ next i))))
     (define state* (struct-copy d:State state [next (+ next arity)]))
     (define body* (apply body variables))
     (eval/a body* state* K)]
    [(d:Conj left right _)
     (define search (eval/a left state K))
     (define continue (lambda (state*) (eval/a right state* K)))
     (bind/a search continue K)]
    [(d:Disj left right _)
     (define left-search (eval/a left state K))
     (define right-search (eval/a right state K))
     (merge/a left-search right-search K)]
    [(d:Suspend body _)
     (d:Delay (lambda () (eval/a body state K)))]
    [(d:Call _ _ _) (error 'eval/a "relcalls are outside this derivation")]
    [atomic
     (define outcome (K atomic state))
     (define search (outcome (lambda () (d:Empty (d:State-next state))) d:One))
     search]))

(define (merge/a left right K)
  (match left
    [(d:Empty _) right]
    [(d:One state) (d:Yield state right)]
    [(d:Yield state rest)
     (define tail (merge/a rest right K))
     (d:Yield state tail)]
    [(d:Delay rest)
     (d:Delay
      (lambda ()
        (define forced (force/a rest K))
        (merge/a right forced K)))]))

(define (bind/a search continue K)
  (match search
    [(d:Empty next) (d:Empty next)]
    [(d:One state) (continue state)]
    [(d:Yield state rest)
     (define head (continue state))
     (define tail (bind/a rest continue K))
     (merge/a head tail K)]
    [(d:Delay rest)
     (d:Delay
      (lambda ()
        (define forced (force/a rest K))
        (bind/a forced continue K)))]))

(define (force/a resume K) (resume))

(define (render/a search K)
  (match search
    [(d:Empty next) (d:Done next)]
    [(d:One state) (d:Last (d:Answer state))]
    [(d:Yield state rest)
     (define tail (render/a rest K))
     (d:Emit (d:Answer state) tail)]
    [(d:Delay rest)
     (define forced (force/a rest K))
     (define tail (render/a forced K))
     (d:Forced tail)]))

(define (run-search goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)])
  (eval/a goal state K))
(define (run goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)])
  (define search (eval/a goal state K))
  (render/a search K))
