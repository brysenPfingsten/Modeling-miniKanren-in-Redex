#lang racket

(require (prefix-in d: "../../functional-search/direct-interpreter.rkt")
         "03-data.rkt")
(provide eval/d merge/d bind/d force/d continue/d render/d return/d run-search run)

;; Replace each labeled CPS lambda with its closure record, and each call
;; to such a lambda with the corresponding apply function. These are still
;; ordinary, mutually tail-recursive Racket functions: no PC or machine loop.
;; derive.rkt mechanically reifies their tail calls in 04 and registerizes 05.
(define (eval/d goal state K k)
  (match goal
    [(d:Fresh arity body _)
     (unless (exact-nonnegative-integer? arity)
       (raise-argument-error 'eval/d "exact-nonnegative-integer?" arity))
     (define next (d:State-next state))
     (define variables (for/list ([i (in-range arity)]) (d:LVar (+ next i))))
     (define state* (struct-copy d:State state [next (+ next arity)]))
     (define body* (apply body variables))
     (eval/d body* state* K k)]
    [(d:Conj left right _) (eval/d left state K (KConj right k))]
    [(d:Disj left right _) (eval/d left state K (KDisjLeft right state k))]
    [(d:Suspend body _) (return/d (d:Delay (REval body state)) K k)]
    [(d:Call _ _ _) (error 'eval/d "relcalls are outside this derivation")]
    [atomic
     ;; K stays a native functional primitive, including its Outcome result.
     ;; No outcome record or conversion precedes this direct elimination.
     (define outcome (K atomic state))
     (define search (outcome (lambda () (d:Empty (d:State-next state))) d:One))
     (return/d search K k)]))

(define (merge/d left right K k)
  (match left
    [(d:Empty _) (return/d right K k)]
    [(d:One state) (return/d (d:Yield state right) K k)]
    [(d:Yield state rest) (merge/d rest right K (KYield state k))]
    [(d:Delay rest) (return/d (d:Delay (RMerge right rest)) K k)]))

(define (bind/d search continue K k)
  (match search
    [(d:Empty next) (return/d (d:Empty next) K k)]
    [(d:One state) (continue/d continue state K k)]
    [(d:Yield state rest) (continue/d continue state K (KBindHead rest continue k))]
    [(d:Delay rest) (return/d (d:Delay (RBind rest continue)) K k)]))

(define (continue/d continue state K k)
  (match continue [(GRight goal) (eval/d goal state K k)]))

(define (force/d resume K k)
  (match resume
    [(REval goal state) (eval/d goal state K k)]
    [(RMerge right rest) (force/d rest K (KMergeForced right k))]
    [(RBind rest continue) (force/d rest K (KBindForced continue k))]))

(define (render/d search K k)
  (match search
    [(d:Empty next) (return/d (d:Done next) K k)]
    [(d:One state) (return/d (d:Last (d:Answer state)) K k)]
    [(d:Yield state rest) (render/d rest K (KEmit state k))]
    [(d:Delay rest) (force/d rest K (KRenderForced k))]))

(define (return/d value K k)
  (match k
    [(KDone) value]
    [(KConj right next) (bind/d value (GRight right) K next)]
    [(KDisjLeft right state next) (eval/d right state K (KDisjRight value next))]
    [(KDisjRight left next) (merge/d left value K next)]
    [(KYield state next) (return/d (d:Yield state value) K next)]
    [(KBindHead rest continue next) (bind/d rest continue K (KBindTail value next))]
    [(KBindTail head next) (merge/d head value K next)]
    [(KMergeForced right next) (merge/d right value K next)]
    [(KBindForced continue next) (bind/d value continue K next)]
    [(KRun next) (render/d value K next)]
    [(KEmit state next) (return/d (d:Emit (d:Answer state) value) K next)]
    [(KRenderForced next) (render/d value K (KForced next))]
    [(KForced next) (return/d (d:Forced value) K next)]))

(define (run-search goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)])
  (eval/d goal state K (KDone)))
(define (run goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)])
  (eval/d goal state K (KRun (KDone))))
