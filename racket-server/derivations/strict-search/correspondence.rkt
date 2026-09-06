#lang racket

(require racket/match
         (prefix-in direct: "../functional-search/direct-interpreter.rkt")
         (prefix-in source: "source.rkt")
         (prefix-in machine: "functional-machine.rkt"))

(provide decode-configuration decode-search decode-resumption)

;; Structural decoding of the defunctionalized machine into Rstrict. Pending
;; eager work stays in source evaluation contexts; an actual Delay resumption
;; stays beneath Delay until Force runs. No machine step or source reduction
;; is called by this map.
;;
;; On the executable correspondence corpus, a machine transition either keeps
;; this decoded term unchanged (continuation administration), or contracts
;; exactly one Rstrict redex. Pure host kernel/Fresh callbacks are a parameter
;; boundary: independently replaying a callback that constructs new procedures
;; need not produce equal? host syntax even when those procedures are
;; extensionally equal. No decoder compares or identifies arbitrary closures.

(define (decode-search search)
  (match search
    [(machine:Empty next) `(Empty ,next)]
    [(machine:One state) `(One ,state)]
    [(machine:Yield state rest) `(Yield ,state ,(decode-search rest))]
    [(machine:Delay rest) `(Delay ,(decode-resumption rest))]
    [_ (raise-argument-error 'decode-search "defunctionalized Search" search)]))

(define (decode-resumption resumption)
  (match resumption
    [(machine:ResumeEval goal state) `(eval ,(source:encode-goal goal) ,state)]
    [(machine:ResumeMerge right rest)
     `(mplus ,(decode-search right) (force (Delay ,(decode-resumption rest))))]
    [(machine:ResumeBind rest (machine:Continue goal))
     `(bind (force (Delay ,(decode-resumption rest)))
            ,(source:encode-goal goal))]
    [_ (raise-argument-error 'decode-resumption "Delay resumption" resumption)]))

(define (decode-frontier frontier)
  (match frontier
    [(direct:Done next) `(Done ,next)]
    [(direct:Last (direct:Answer state)) `(Last ,state)]
    [(direct:Emit (direct:Answer state) tail)
     `(Emit ,state ,(decode-frontier tail))]
    [(direct:Forced tail) `(Forced ,(decode-frontier tail))]
    [_ (raise-argument-error 'decode-frontier "direct frontier" frontier)]))

(define (decode-return-value value)
  (match value
    [(or (machine:Empty _) (machine:One _) (machine:Yield _ _) (machine:Delay _))
     (decode-search value)]
    [_ (decode-frontier value)]))

(define (plug-continuation continuation computation)
  (match continuation
    [(machine:Halt) computation]
    [(machine:AfterConjLeft right k)
     (plug-continuation k `(bind ,computation ,(source:encode-goal right)))]
    [(machine:AfterDisjLeft right state k)
     (plug-continuation
      k `(mplus ,computation (eval ,(source:encode-goal right) ,state)))]
    [(machine:AfterDisjRight left k)
     (plug-continuation k `(mplus ,(decode-search left) ,computation))]
    [(machine:RebuildYield state k)
     (plug-continuation k `(Yield ,state ,computation))]
    [(machine:AfterBindHead rest (machine:Continue goal) k)
     (plug-continuation
      k `(mplus ,computation (bind ,(decode-search rest) ,(source:encode-goal goal))))]
    [(machine:AfterBindTail head k)
     (plug-continuation k `(mplus ,(decode-search head) ,computation))]
    [(machine:AfterForceMerge right k)
     (plug-continuation k `(mplus ,(decode-search right) ,computation))]
    [(machine:AfterForceBind (machine:Continue goal) k)
     (plug-continuation k `(bind ,computation ,(source:encode-goal goal)))]
    [(machine:AfterEvalRender k)
     (plug-continuation k `(render ,computation))]
    [(machine:AfterEmit state k)
     (plug-continuation k `(Emit ,state ,computation))]
    [(machine:AfterRenderForce k)
     (plug-continuation k `(Forced (render ,computation)))]
    [(machine:AfterForced k)
     (plug-continuation k `(Forced ,computation))]
    [_ (raise-argument-error 'plug-continuation "machine continuation" continuation)]))

(define (decode-configuration configuration)
  (match configuration
    [(machine:Eval goal state k)
     (plug-continuation k `(eval ,(source:encode-goal goal) ,state))]
    [(machine:Mplus left right k)
     (plug-continuation k `(mplus ,(decode-search left) ,(decode-search right)))]
    [(machine:Bind search (machine:Continue goal) k)
     (plug-continuation k `(bind ,(decode-search search) ,(source:encode-goal goal)))]
    [(machine:Force rest k)
     (plug-continuation k `(force (Delay ,(decode-resumption rest))))]
    [(machine:Render search k)
     (plug-continuation k `(render ,(decode-search search)))]
    [(machine:Return value k)
     (plug-continuation k (decode-return-value value))]
    [_ (raise-argument-error 'decode-configuration "machine configuration" configuration)]))
