#lang racket
;; Generated from 03-defunc.rkt by derive.rkt. Regenerate; do not edit.
(require (prefix-in d: "../../functional-search/direct-interpreter.rkt")
         "03-data.rkt"
         "runtime.rkt")

(provide (all-defined-out))

(define signatures
  '((eval/d goal state K k)
    (merge/d left right K k)
    (bind/d search continue K k)
    (continue/d continue state K k)
    (force/d resume K k)
    (render/d search K k)
    (return/d value K k)))

(struct Call (pc operands) #:transparent)

(struct Halted (value) #:transparent)

(define (initial
         goal
         #:kernel
         (K d:basic-kernel)
         #:state
         (state (d:empty-state))
         #:observe?
         (observe? #t))
  (Call 'eval/d (list goal state K (if observe? (KRun (KDone)) (KDone)))))

(define (drive/steps current fuel)
  (match
   current
   ((Halted value) value)
   (_
    (when (zero? fuel) (exhausted 'machine current))
    (drive/steps (step current) (sub1 fuel)))))

(define (drive current #:fuel (fuel 100000)) (check-fuel fuel) (drive/steps current fuel))

(define (run-search
         goal
         #:kernel
         (K d:basic-kernel)
         #:state
         (state (d:empty-state))
         #:fuel
         (fuel 100000))
  (drive (initial goal #:kernel K #:state state #:observe? #f) #:fuel fuel))

(define (run
         goal
         #:kernel
         (K d:basic-kernel)
         #:state
         (state (d:empty-state))
         #:fuel
         (fuel 100000))
  (drive (initial goal #:kernel K #:state state) #:fuel fuel))

(define (step current)
  (match
   current
   ((Call 'eval/d (list goal state K k))
    (match
     goal
     ((d:Fresh arity body _)
      (unless (exact-nonnegative-integer? arity)
        (raise-argument-error 'eval/d "exact-nonnegative-integer?" arity))
      (define next (d:State-next state))
      (define variables (for/list ((i (in-range arity))) (d:LVar (+ next i))))
      (define state* (struct-copy d:State state (next (+ next arity))))
      (define body* (apply body variables))
      (Call 'eval/d (list body* state* K k)))
     ((d:Conj left right _) (Call 'eval/d (list left state K (KConj right k))))
     ((d:Disj left right _) (Call 'eval/d (list left state K (KDisjLeft right state k))))
     ((d:Suspend body _) (Call 'return/d (list (d:Delay (REval body state)) K k)))
     ((d:Call _ _ _) (Halted (error 'eval/d "relcalls are outside this derivation")))
     (atomic
      (define outcome (K atomic state))
      (define search (outcome (lambda () (d:Empty (d:State-next state))) d:One))
      (Call 'return/d (list search K k)))))
   ((Call 'merge/d (list left right K k))
    (match
     left
     ((d:Empty _) (Call 'return/d (list right K k)))
     ((d:One state) (Call 'return/d (list (d:Yield state right) K k)))
     ((d:Yield state rest) (Call 'merge/d (list rest right K (KYield state k))))
     ((d:Delay rest) (Call 'return/d (list (d:Delay (RMerge right rest)) K k)))))
   ((Call 'bind/d (list search continue K k))
    (match
     search
     ((d:Empty next) (Call 'return/d (list (d:Empty next) K k)))
     ((d:One state) (Call 'continue/d (list continue state K k)))
     ((d:Yield state rest)
      (Call 'continue/d (list continue state K (KBindHead rest continue k))))
     ((d:Delay rest) (Call 'return/d (list (d:Delay (RBind rest continue)) K k)))))
   ((Call 'continue/d (list continue state K k))
    (match continue ((GRight goal) (Call 'eval/d (list goal state K k)))))
   ((Call 'force/d (list resume K k))
    (match
     resume
     ((REval goal state) (Call 'eval/d (list goal state K k)))
     ((RMerge right rest) (Call 'force/d (list rest K (KMergeForced right k))))
     ((RBind rest continue) (Call 'force/d (list rest K (KBindForced continue k))))))
   ((Call 'render/d (list search K k))
    (match
     search
     ((d:Empty next) (Call 'return/d (list (d:Done next) K k)))
     ((d:One state) (Call 'return/d (list (d:Last (d:Answer state)) K k)))
     ((d:Yield state rest) (Call 'render/d (list rest K (KEmit state k))))
     ((d:Delay rest) (Call 'force/d (list rest K (KRenderForced k))))))
   ((Call 'return/d (list value K k))
    (match
     k
     ((KDone) (Halted value))
     ((KConj right next) (Call 'bind/d (list value (GRight right) K next)))
     ((KDisjLeft right state next) (Call 'eval/d (list right state K (KDisjRight value next))))
     ((KDisjRight left next) (Call 'merge/d (list left value K next)))
     ((KYield state next) (Call 'return/d (list (d:Yield state value) K next)))
     ((KBindHead rest continue next)
      (Call 'bind/d (list rest continue K (KBindTail value next))))
     ((KBindTail head next) (Call 'merge/d (list head value K next)))
     ((KMergeForced right next) (Call 'merge/d (list right value K next)))
     ((KBindForced continue next) (Call 'bind/d (list value continue K next)))
     ((KRun next) (Call 'render/d (list value K next)))
     ((KEmit state next) (Call 'return/d (list (d:Emit (d:Answer state) value) K next)))
     ((KRenderForced next) (Call 'render/d (list value K (KForced next))))
     ((KForced next) (Call 'return/d (list (d:Forced value) K next)))))
   ((Halted _) #f)
   (_ (raise-argument-error 'step "derived machine configuration" current))))

