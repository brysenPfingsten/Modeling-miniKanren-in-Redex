#lang racket
;; Generated from 03-defunc.rkt by derive.rkt. Regenerate; do not edit.
(require (prefix-in d: "../../functional-search/direct-interpreter.rkt")
         "03-data.rkt"
         "runtime.rkt")

(require (prefix-in m: "04-machine.rkt"))

(provide (all-defined-out))

(define signatures
  '((eval/d goal state K k)
    (merge/d left right K k)
    (bind/d search continue K k)
    (continue/d continue state K k)
    (force/d resume K k)
    (render/d search K k)
    (return/d value K k)))

(struct Registers (pc r0 r1 r2 r3 steps) #:mutable #:transparent)

(define (jump! bank pc r0 (r1 #f) (r2 #f) (r3 #f))
  (set-Registers-r0! bank r0)
  (set-Registers-r1! bank r1)
  (set-Registers-r2! bank r2)
  (set-Registers-r3! bank r3)
  (set-Registers-pc! bank pc))

(define (halt! bank value) (jump! bank 'halt value))

(define (initial
         goal
         #:kernel
         (K d:basic-kernel)
         #:state
         (state (d:empty-state))
         #:observe?
         (observe? #t))
  (Registers 'eval/d goal state K (if observe? (KRun (KDone)) (KDone)) 0))

(define (decode bank)
  (match
   (Registers-pc bank)
   ('halt (m:Halted (Registers-r0 bank)))
   (pc
    (match
     (assq pc signatures)
     ((cons _ parameters)
      (m:Call
       pc
       (take
        (list (Registers-r0 bank) (Registers-r1 bank) (Registers-r2 bank) (Registers-r3 bank))
        (length parameters))))
     (#f (error 'decode "unknown PC: ~e" pc))))))

(define (from-machine current)
  (match
   current
   ((m:Halted value) (Registers 'halt value #f #f #f 0))
   ((m:Call pc operands)
    (define bank (Registers 'halt #f #f #f #f 0))
    (apply jump! bank pc operands)
    bank)))

(define (step! bank)
  (match
   (Registers-pc bank)
   ('halt #f)
   (_ (dispatch! bank) (set-Registers-steps! bank (add1 (Registers-steps bank))) #t)))

(define (drive/steps! bank fuel)
  (match
   (Registers-pc bank)
   ('halt (Registers-r0 bank))
   (_
    (when (zero? fuel) (exhausted 'registers (decode bank)))
    (step! bank)
    (drive/steps! bank (sub1 fuel)))))

(define (drive! bank #:fuel (fuel 100000)) (check-fuel fuel) (drive/steps! bank fuel))

(define (run-search
         goal
         #:kernel
         (K d:basic-kernel)
         #:state
         (state (d:empty-state))
         #:fuel
         (fuel 100000))
  (drive! (initial goal #:kernel K #:state state #:observe? #f) #:fuel fuel))

(define (run
         goal
         #:kernel
         (K d:basic-kernel)
         #:state
         (state (d:empty-state))
         #:fuel
         (fuel 100000))
  (drive! (initial goal #:kernel K #:state state) #:fuel fuel))

(define (dispatch! bank)
  (match
   (Registers-pc bank)
   ('eval/d
    (define goal (Registers-r0 bank))
    (define state (Registers-r1 bank))
    (define K (Registers-r2 bank))
    (define k (Registers-r3 bank))
    (match
     goal
     ((d:Fresh arity body _)
      (unless (exact-nonnegative-integer? arity)
        (raise-argument-error 'eval/d "exact-nonnegative-integer?" arity))
      (define next (d:State-next state))
      (define variables (for/list ((i (in-range arity))) (d:LVar (+ next i))))
      (define state* (struct-copy d:State state (next (+ next arity))))
      (define body* (apply body variables))
      (jump! bank 'eval/d body* state* K k))
     ((d:Conj left right _) (jump! bank 'eval/d left state K (KConj right k)))
     ((d:Disj left right _) (jump! bank 'eval/d left state K (KDisjLeft right state k)))
     ((d:Suspend body _) (jump! bank 'return/d (d:Delay (REval body state)) K k))
     ((d:Call _ _ _) (halt! bank (error 'eval/d "relcalls are outside this derivation")))
     (atomic
      (define outcome (K atomic state))
      (define search (outcome (lambda () (d:Empty (d:State-next state))) d:One))
      (jump! bank 'return/d search K k))))
   ('merge/d
    (define left (Registers-r0 bank))
    (define right (Registers-r1 bank))
    (define K (Registers-r2 bank))
    (define k (Registers-r3 bank))
    (match
     left
     ((d:Empty _) (jump! bank 'return/d right K k))
     ((d:One state) (jump! bank 'return/d (d:Yield state right) K k))
     ((d:Yield state rest) (jump! bank 'merge/d rest right K (KYield state k)))
     ((d:Delay rest) (jump! bank 'return/d (d:Delay (RMerge right rest)) K k))))
   ('bind/d
    (define search (Registers-r0 bank))
    (define continue (Registers-r1 bank))
    (define K (Registers-r2 bank))
    (define k (Registers-r3 bank))
    (match
     search
     ((d:Empty next) (jump! bank 'return/d (d:Empty next) K k))
     ((d:One state) (jump! bank 'continue/d continue state K k))
     ((d:Yield state rest)
      (jump! bank 'continue/d continue state K (KBindHead rest continue k)))
     ((d:Delay rest) (jump! bank 'return/d (d:Delay (RBind rest continue)) K k))))
   ('continue/d
    (define continue (Registers-r0 bank))
    (define state (Registers-r1 bank))
    (define K (Registers-r2 bank))
    (define k (Registers-r3 bank))
    (match continue ((GRight goal) (jump! bank 'eval/d goal state K k))))
   ('force/d
    (define resume (Registers-r0 bank))
    (define K (Registers-r1 bank))
    (define k (Registers-r2 bank))
    (match
     resume
     ((REval goal state) (jump! bank 'eval/d goal state K k))
     ((RMerge right rest) (jump! bank 'force/d rest K (KMergeForced right k)))
     ((RBind rest continue) (jump! bank 'force/d rest K (KBindForced continue k)))))
   ('render/d
    (define search (Registers-r0 bank))
    (define K (Registers-r1 bank))
    (define k (Registers-r2 bank))
    (match
     search
     ((d:Empty next) (jump! bank 'return/d (d:Done next) K k))
     ((d:One state) (jump! bank 'return/d (d:Last (d:Answer state)) K k))
     ((d:Yield state rest) (jump! bank 'render/d rest K (KEmit state k)))
     ((d:Delay rest) (jump! bank 'force/d rest K (KRenderForced k)))))
   ('return/d
    (define value (Registers-r0 bank))
    (define K (Registers-r1 bank))
    (define k (Registers-r2 bank))
    (match
     k
     ((KDone) (halt! bank value))
     ((KConj right next) (jump! bank 'bind/d value (GRight right) K next))
     ((KDisjLeft right state next) (jump! bank 'eval/d right state K (KDisjRight value next)))
     ((KDisjRight left next) (jump! bank 'merge/d left value K next))
     ((KYield state next) (jump! bank 'return/d (d:Yield state value) K next))
     ((KBindHead rest continue next)
      (jump! bank 'bind/d rest continue K (KBindTail value next)))
     ((KBindTail head next) (jump! bank 'merge/d head value K next))
     ((KMergeForced right next) (jump! bank 'merge/d right value K next))
     ((KBindForced continue next) (jump! bank 'bind/d value continue K next))
     ((KRun next) (jump! bank 'render/d value K next))
     ((KEmit state next) (jump! bank 'return/d (d:Emit (d:Answer state) value) K next))
     ((KRenderForced next) (jump! bank 'render/d value K (KForced next)))
     ((KForced next) (jump! bank 'return/d (d:Forced value) K next))))
   (other (error 'dispatch! "unknown PC: ~e" other))))

