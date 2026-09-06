#lang racket

(require (prefix-in direct: "../functional-search/direct-interpreter.rkt")
         (prefix-in functional: "functional-machine.rkt"))

(provide (struct-out Registers) (struct-out exn:fail:register-fuel)
         make-registers registers-from-machine decode-machine
         register-final? register-step! drive! run-search run)

;; Registerization of the strict functional machine, with one bank per run.
;; x/y hold the current command's operands; k retains all pending strict
;; work, including mature chunks. PC dispatch is administrative host control,
;; never an object-language Delay. Search/resumption/continuation data are the
;; already-defunctionalized data definitions, not new scheduler jobs.
;;
;; PC       x                   y
;; eval     goal                State
;; mplus    mature left Search  mature right Search
;; bind     mature Search       Continue
;; force    Delay resumption    #f
;; render   mature Search       #f
;; return   Search or frontier  #f
(struct Registers (pc x y k kernel steps) #:mutable #:transparent)
;; The kernel returns a native Outcome, eliminated within the eval dispatch.
;; Its eager work remains inside this primitive boundary at every stage.
(struct exn:fail:register-fuel exn:fail (configuration) #:transparent)

(define (make-registers goal #:kernel [K direct:basic-kernel]
                        #:state [state (direct:empty-state)] #:observe? [observe? #t])
  (Registers 'eval goal state
             (if observe?
                 (functional:AfterEvalRender (functional:Halt))
                 (functional:Halt))
             K 0))

;; These are structural representation maps. Operational dispatch below does
;; not decode a machine configuration or call the functional machine stepper.
(define (registers-from-machine configuration #:kernel [K direct:basic-kernel])
  (match configuration
    [(functional:Eval goal state k) (Registers 'eval goal state k K 0)]
    [(functional:Mplus left right k) (Registers 'mplus left right k K 0)]
    [(functional:Bind search continue k) (Registers 'bind search continue k K 0)]
    [(functional:Force rest k) (Registers 'force rest #f k K 0)]
    [(functional:Render search k) (Registers 'render search #f k K 0)]
    [(functional:Return value k) (Registers 'return value #f k K 0)]
    [_ (raise-argument-error 'registers-from-machine "strict functional configuration"
                             configuration)]))

(define (decode-machine registers)
  (match-define (Registers pc x y k _ _) registers)
  (match pc
    ['eval (functional:Eval x y k)]
    ['mplus (functional:Mplus x y k)]
    ['bind (functional:Bind x y k)]
    ['force (functional:Force x k)]
    ['render (functional:Render x k)]
    ['return (functional:Return x k)]
    [_ (error 'decode-machine "invalid program counter: ~e" pc)]))

(define (register-final? registers)
  (and (eq? (Registers-pc registers) 'return)
       (functional:Halt? (Registers-k registers))))

;; Every jump assigns the live operands and clears the dead second operand.
;; All right-hand sides are computed from the old bank before this update.
(define (jump! registers pc x y k)
  (set-Registers-x! registers x)
  (set-Registers-y! registers y)
  (set-Registers-k! registers k)
  (set-Registers-pc! registers pc))

(define (eval! registers)
  (match-define (Registers _ goal state k K _) registers)
  (match goal
    [(direct:Fresh arity body _)
     (unless (exact-nonnegative-integer? arity)
       (raise-argument-error 'register-step! "exact-nonnegative-integer?" arity))
     (define next (direct:State-next state))
     (define variables
       (for/list ([offset (in-range arity)]) (direct:LVar (+ next offset))))
     (jump! registers 'eval (apply body variables)
            (struct-copy direct:State state [next (+ next arity)]) k)]
    [(direct:Conj left right _)
     (jump! registers 'eval left state (functional:AfterConjLeft right k))]
    [(direct:Disj left right _)
     (jump! registers 'eval left state (functional:AfterDisjLeft right state k))]
    [(direct:Suspend goal _)
     (jump! registers 'return (functional:Delay (functional:ResumeEval goal state)) #f k)]
    [(direct:Call _ _ _)
     (error 'register-step! "relcalls are outside the strict register coordinate")]
    [atomic
     ((K atomic state)
      (lambda ()
        (jump! registers 'return (functional:Empty (direct:State-next state)) #f k))
      (lambda (result)
        (jump! registers 'return (functional:One result) #f k)))]))

(define (mplus! registers)
  (match-define (Registers _ left right k _ _) registers)
  (match left
    [(functional:Empty _) (jump! registers 'return right #f k)]
    [(functional:One state)
     (jump! registers 'return (functional:Yield state right) #f k)]
    [(functional:Yield state rest)
     (jump! registers 'mplus rest right (functional:RebuildYield state k))]
    [(functional:Delay rest)
     (jump! registers 'return (functional:Delay (functional:ResumeMerge right rest)) #f k)]))

(define (bind! registers)
  (match-define (Registers _ search continue k _ _) registers)
  (match* (search continue)
    [((functional:Empty next) _) (jump! registers 'return (functional:Empty next) #f k)]
    [((functional:One state) (functional:Continue goal))
     (jump! registers 'eval goal state k)]
    [((functional:Yield state rest) (functional:Continue goal))
     (jump! registers 'eval goal state (functional:AfterBindHead rest continue k))]
    [((functional:Delay rest) _)
     (jump! registers 'return (functional:Delay (functional:ResumeBind rest continue)) #f k)]))

(define (force! registers)
  (match-define (Registers _ resumption _ k _ _) registers)
  (match resumption
    [(functional:ResumeEval goal state) (jump! registers 'eval goal state k)]
    [(functional:ResumeMerge right rest)
     (jump! registers 'force rest #f (functional:AfterForceMerge right k))]
    [(functional:ResumeBind rest continue)
     (jump! registers 'force rest #f (functional:AfterForceBind continue k))]))

(define (render! registers)
  (match-define (Registers _ search _ k _ _) registers)
  (match search
    [(functional:Empty next) (jump! registers 'return (direct:Done next) #f k)]
    [(functional:One state)
     (jump! registers 'return (direct:Last (direct:Answer state)) #f k)]
    [(functional:Yield state rest)
     (jump! registers 'render rest #f (functional:AfterEmit state k))]
    [(functional:Delay rest)
     (jump! registers 'force rest #f (functional:AfterRenderForce k))]))

(define (return! registers)
  (match-define (Registers _ value _ continuation _ _) registers)
  (match continuation
    [(functional:Halt) (void)]
    [(functional:AfterConjLeft right k)
     (jump! registers 'bind value (functional:Continue right) k)]
    [(functional:AfterDisjLeft right state k)
     (jump! registers 'eval right state (functional:AfterDisjRight value k))]
    [(functional:AfterDisjRight left k) (jump! registers 'mplus left value k)]
    [(functional:RebuildYield state k)
     (jump! registers 'return (functional:Yield state value) #f k)]
    [(functional:AfterBindHead rest continue k)
     (jump! registers 'bind rest continue (functional:AfterBindTail value k))]
    [(functional:AfterBindTail head k) (jump! registers 'mplus head value k)]
    [(functional:AfterForceMerge right k) (jump! registers 'mplus right value k)]
    [(functional:AfterForceBind continue k) (jump! registers 'bind value continue k)]
    [(functional:AfterEvalRender k) (jump! registers 'render value #f k)]
    [(functional:AfterEmit state k)
     (jump! registers 'return (direct:Emit (direct:Answer state) value) #f k)]
    [(functional:AfterRenderForce k)
     (jump! registers 'render value #f (functional:AfterForced k))]
    [(functional:AfterForced k) (jump! registers 'return (direct:Forced value) #f k)]))

(define (register-step! registers)
  (cond
    [(register-final? registers) #f]
    [else
     (match (Registers-pc registers)
       ['eval (eval! registers)]
       ['mplus (mplus! registers)]
       ['bind (bind! registers)]
       ['force (force! registers)]
       ['render (render! registers)]
       ['return (return! registers)]
       [other (error 'register-step! "invalid program counter: ~e" other)])
     (set-Registers-steps! registers (add1 (Registers-steps registers)))
     #t]))

(define (drive/remaining! registers fuel)
  (cond
    [(register-final? registers) (Registers-x registers)]
    [(zero? fuel)
     (raise (exn:fail:register-fuel
             "strict register machine exhausted its step budget"
             (current-continuation-marks)
             (decode-machine registers)))]
    [else
     (register-step! registers)
     (drive/remaining! registers (sub1 fuel))]))

(define (drive! registers #:fuel [fuel 100000])
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error 'drive! "exact-nonnegative-integer?" fuel))
  (drive/remaining! registers fuel))

(define (run-search goal #:kernel [K direct:basic-kernel]
                    #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (drive! (make-registers goal #:kernel K #:state state #:observe? #f) #:fuel fuel))

(define (run goal #:kernel [K direct:basic-kernel]
             #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (drive! (make-registers goal #:kernel K #:state state) #:fuel fuel))
