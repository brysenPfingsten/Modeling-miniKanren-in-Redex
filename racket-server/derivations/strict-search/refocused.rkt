#lang racket

(require redex/reduction-semantics
         (prefix-in source: "source.rkt")
         (prefix-in direct: "../functional-search/direct-interpreter.rkt"))

(provide (struct-out Focus)
         (struct-out MergeLeft) (struct-out MergeRight)
         (struct-out BindFrame) (struct-out YieldFrame) (struct-out ForceFrame)
         (struct-out RenderFrame) (struct-out EmitFrame) (struct-out ForcedFrame)
         decompose plug initial-machine machine-step machine-step/tagged
         run-machine run-search run)

;; The frames are exactly the one-hole constructors of E and the observer C.
;; No frame enters Delay. MergeRight retains the already-mature left Search
;; while the machine computes the right operand.
(struct Focus (control frames) #:transparent)
(struct MergeLeft (right) #:transparent)
(struct MergeRight (left) #:transparent)
(struct BindFrame (goal) #:transparent)
(struct YieldFrame (state) #:transparent)
(struct ForceFrame () #:transparent)
(struct RenderFrame () #:transparent)
(struct EmitFrame (state) #:transparent)
(struct ForcedFrame () #:transparent)

(define (plug control frames)
  (match frames
    ['() control]
    [(cons frame rest)
     (plug
      (match frame
        [(MergeLeft right) `(mplus ,control ,right)]
        [(MergeRight left) `(mplus ,left ,control)]
        [(BindFrame goal) `(bind ,control ,goal)]
        [(YieldFrame state) `(Yield ,state ,control)]
        [(ForceFrame) `(force ,control)]
        [(RenderFrame) `(render ,control)]
        [(EmitFrame state) `(Emit ,state ,control)]
        [(ForcedFrame) `(Forced ,control)])
      rest)]))

;; Independent decomposition of a whole term, for reconstruction and
;; reduction/decomposition checks. The machine below retains the frames
;; instead of plugging and decomposing the entire term after every contraction.
(define (decompose computation [frames '()])
  (match computation
    [`(mplus ,left ,right)
     (cond
       [(not (source:search-value? left))
        (decompose left (cons (MergeLeft right) frames))]
       [(not (source:search-value? right))
        (decompose right (cons (MergeRight left) frames))]
       [else (Focus computation frames)])]
    [`(bind ,search ,goal)
     (if (source:search-value? search)
         (Focus computation frames)
         (decompose search (cons (BindFrame goal) frames)))]
    [`(Yield ,state ,tail)
     (if (source:search-value? tail)
         (Focus computation frames)
         (decompose tail (cons (YieldFrame state) frames)))]
    [`(force ,search)
     (if (source:search-value? search)
         (Focus computation frames)
         (decompose search (cons (ForceFrame) frames)))]
    [`(render ,search)
     (if (source:search-value? search)
         (Focus computation frames)
         (decompose search (cons (RenderFrame) frames)))]
    [`(Emit ,state ,tail)
     (if (source:observation-value? tail)
         (Focus computation frames)
         (decompose tail (cons (EmitFrame state) frames)))]
    [`(Forced ,tail)
     (if (source:observation-value? tail)
         (Focus computation frames)
         (decompose tail (cons (ForcedFrame) frames)))]
    [_ (Focus computation frames)]))

(define (initial-machine goal #:state [state (direct:empty-state)]
                         #:observe? [observe? #t])
  (Focus (source:initial goal #:state state)
         (if observe? (list (RenderFrame)) '())))

(define (step/with raw configuration)
  (match-define (Focus control frames) configuration)
  (cond
    [(or (source:search-value? control) (source:observation-value? control))
     (match frames
       ['() #f]
       [(cons (MergeLeft right) rest)
        (list "admin" (Focus right (cons (MergeRight control) rest)))]
       [(cons frame rest)
        (list "admin" (Focus (plug control (list frame)) rest))])]
    [else
     (match (apply-reduction-relation/tag-with-names raw control)
       [(list (list label next)) (list label (Focus next frames))]
       ['()
        (list
         "admin"
         (match control
           [`(mplus ,left ,right) (Focus left (cons (MergeLeft right) frames))]
           [`(bind ,search ,goal) (Focus search (cons (BindFrame goal) frames))]
           [`(Yield ,state ,tail) (Focus tail (cons (YieldFrame state) frames))]
           [`(force ,search)
            #:when (not (source:search-value? search))
            (Focus search (cons (ForceFrame) frames))]
           [`(render ,search) (Focus search (cons (RenderFrame) frames))]
           [`(Emit ,state ,tail) (Focus tail (cons (EmitFrame state) frames))]
           [`(Forced ,tail) (Focus tail (cons (ForcedFrame) frames))]
           [_ (error 'machine-step "stuck control: ~e" control)]))]
       [successors (error 'machine-step "nonunique raw contraction: ~e" successors)])]))

(define (machine-step/tagged configuration #:kernel [K direct:basic-kernel])
  (step/with (source:make-strict-raw K) configuration))

(define (machine-step configuration #:kernel [K direct:basic-kernel])
  (match (machine-step/tagged configuration #:kernel K)
    [#f #f]
    [(list _ next) next]))

(define (run/with raw configuration fuel)
  (match-define (Focus control frames) configuration)
  (cond
    [(and (null? frames)
          (or (source:search-value? control) (source:observation-value? control)))
     control]
    [else
     (when (zero? fuel) (error 'run-machine "strict machine fuel exhausted"))
     (match (step/with raw configuration)
       [(list _ next) (run/with raw next (sub1 fuel))]
       [#f (error 'run-machine "unexpected stuck machine: ~e" configuration)])]))

(define (run-machine configuration #:kernel [K direct:basic-kernel]
                     #:fuel [fuel 100000])
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error 'run-machine "exact-nonnegative-integer?" fuel))
  (run/with (source:make-strict-raw K) configuration fuel))

(define (run-search goal #:kernel [K direct:basic-kernel]
                    #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (run-machine (initial-machine goal #:state state #:observe? #f)
               #:kernel K #:fuel fuel))

(define (run goal #:kernel [K direct:basic-kernel]
             #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (source:observation->frontier
   (run-machine (initial-machine goal #:state state) #:kernel K #:fuel fuel)))
