#lang racket

(require (prefix-in d: "../../functional-search/direct-interpreter.rkt"))
(provide eval/k merge/k bind/k force/k render/k run-search run)

;; Full CPS of the control layer, including calls into suspended computation.
;; Delay now holds (lambda (k) ...), never a nullary host-returning thunk.
;; Labels C0..C12, G0, R0..R2 identify the finite closure families in 03-data.
(define (eval/k goal state K k)
  (match goal
    [(d:Fresh arity body _)
     (unless (exact-nonnegative-integer? arity)
       (raise-argument-error 'eval/k "exact-nonnegative-integer?" arity))
     (define next (d:State-next state))
     (define variables (for/list ([i (in-range arity)]) (d:LVar (+ next i))))
     (define state* (struct-copy d:State state [next (+ next arity)]))
     (define body* (apply body variables))
     (eval/k body* state* K k)]
    [(d:Conj left right _)
     (eval/k left state K
             (lambda (search) ; C1
               (bind/k search
                       (lambda (state* k*) (eval/k right state* K k*)) ; G0
                       K k)))]
    [(d:Disj left right _)
     (eval/k left state K
             (lambda (left-search) ; C2
               (eval/k right state K
                       (lambda (right-search) ; C3
                         (merge/k left-search right-search K k)))))]
    [(d:Suspend body _)
     (k (d:Delay (lambda (k*) (eval/k body state K k*))))] ; R0
    [(d:Call _ _ _) (error 'eval/k "relcalls are outside this derivation")]
    [atomic
     ;; Outcome production and selection form the eager atomic primitive.
     ;; Its handlers construct Search values; they contain no control calls.
     (define outcome (K atomic state))
     (define search (outcome (lambda () (d:Empty (d:State-next state))) d:One))
     (k search)]))

(define (merge/k left right K k)
  (match left
    [(d:Empty _) (k right)]
    [(d:One state) (k (d:Yield state right))]
    [(d:Yield state rest)
     (merge/k rest right K (lambda (tail) (k (d:Yield state tail))))] ; C4
    [(d:Delay rest)
     (k (d:Delay
         (lambda (k*) ; R1
           (force/k rest K
                    (lambda (forced) (merge/k right forced K k*))))))])) ; C7

(define (bind/k search continue K k)
  (match search
    [(d:Empty next) (k (d:Empty next))]
    [(d:One state) (continue state k)]
    [(d:Yield state rest)
     (continue state
               (lambda (head) ; C5
                 (bind/k rest continue K
                         (lambda (tail) (merge/k head tail K k)))))] ; C6
    [(d:Delay rest)
     (k (d:Delay
         (lambda (k*) ; R2
           (force/k rest K
                    (lambda (forced) (bind/k forced continue K k*))))))])) ; C8

(define (force/k resume K k) (resume k))

(define (render/k search K k)
  (match search
    [(d:Empty next) (k (d:Done next))]
    [(d:One state) (k (d:Last (d:Answer state)))]
    [(d:Yield state rest)
     (render/k rest K (lambda (tail) (k (d:Emit (d:Answer state) tail))))] ; C10
    [(d:Delay rest)
     (force/k rest K
              (lambda (forced) ; C11
                (render/k forced K (lambda (tail) (k (d:Forced tail))))))])) ; C12

(define (run-search goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)])
  (eval/k goal state K (lambda (value) value))) ; C0
(define (run goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)])
  (define done (lambda (value) value)) ; C0, same closed code as run-search
  (eval/k goal state K (lambda (search) (render/k search K done)))) ; C9
