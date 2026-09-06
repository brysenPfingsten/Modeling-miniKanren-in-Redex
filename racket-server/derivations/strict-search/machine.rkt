#lang racket

(require (prefix-in source: "source.rkt")
         (prefix-in z: "refocused.rkt")
         (prefix-in direct: "../functional-search/direct-interpreter.rkt"))

(provide (struct-out Machine)
         encode-ZM decode-MZ readback-M initial-machine
         machine-final? machine-admin? machine-step/tagged machine-step
         trace run-machine run-search run)

;; Mtree specializes Z's list of one-hole frames to a first-order
;; continuation tree. Its direct rules are independent of Z and Rstrict
;; transitions. The representation maps are structural inverses, not
;; evaluators. This follows the old column's reification/direct-rule split.
(struct Machine (control continuation) #:transparent)

(define (encode-frames frames)
  (match frames
    ['() 'halt]
    [(cons frame rest)
     (define k (encode-frames rest))
     (match frame
       [(z:MergeLeft right) `(merge-left ,right ,k)]
       [(z:MergeRight left) `(merge-right ,left ,k)]
       [(z:BindFrame goal) `(bind ,goal ,k)]
       [(z:YieldFrame state) `(yield ,state ,k)]
       [(z:ForceFrame) `(force ,k)]
       [(z:RenderFrame) `(render ,k)]
       [(z:EmitFrame state) `(emit ,state ,k)]
       [(z:ForcedFrame) `(forced ,k)])]))

(define (decode-frames continuation)
  (match continuation
    ['halt '()]
    [`(merge-left ,right ,k) (cons (z:MergeLeft right) (decode-frames k))]
    [`(merge-right ,left ,k) (cons (z:MergeRight left) (decode-frames k))]
    [`(bind ,goal ,k) (cons (z:BindFrame goal) (decode-frames k))]
    [`(yield ,state ,k) (cons (z:YieldFrame state) (decode-frames k))]
    [`(force ,k) (cons (z:ForceFrame) (decode-frames k))]
    [`(render ,k) (cons (z:RenderFrame) (decode-frames k))]
    [`(emit ,state ,k) (cons (z:EmitFrame state) (decode-frames k))]
    [`(forced ,k) (cons (z:ForcedFrame) (decode-frames k))]))

(define (encode-ZM configuration)
  (match-define (z:Focus control frames) configuration)
  (Machine control (encode-frames frames)))

(define (decode-MZ configuration)
  (match-define (Machine control k) configuration)
  (z:Focus control (decode-frames k)))

(define (readback/control control k)
  (match k
    ['halt control]
    [`(merge-left ,right ,rest) (readback/control `(mplus ,control ,right) rest)]
    [`(merge-right ,left ,rest) (readback/control `(mplus ,left ,control) rest)]
    [`(bind ,goal ,rest) (readback/control `(bind ,control ,goal) rest)]
    [`(yield ,state ,rest) (readback/control `(Yield ,state ,control) rest)]
    [`(force ,rest) (readback/control `(force ,control) rest)]
    [`(render ,rest) (readback/control `(render ,control) rest)]
    [`(emit ,state ,rest) (readback/control `(Emit ,state ,control) rest)]
    [`(forced ,rest) (readback/control `(Forced ,control) rest)]))

(define (readback-M configuration)
  (match-define (Machine control k) configuration)
  (readback/control control k))

(define (initial-machine goal #:state [state (direct:empty-state)]
                         #:observe? [observe? #t])
  (Machine (source:initial goal #:state state)
           (if observe? '(render halt) 'halt)))

(define (value? control)
  (or (source:search-value? control) (source:observation-value? control)))

(define (machine-final? configuration)
  (match configuration
    [(Machine control 'halt) (value? control)]
    [_ #f]))

;; This is a syntactic classifier. It never calls an atomic/Fresh callback.
(define (machine-admin? configuration)
  (match-define (Machine control k) configuration)
  (cond
    [(value? control) (not (eq? k 'halt))]
    [else
     (match control
       [`(mplus ,left ,right)
        (not (and (source:search-value? left) (source:search-value? right)))]
       [`(bind ,search ,_) (not (source:search-value? search))]
       [`(force ,search) (not (source:search-value? search))]
       [`(render ,search) (not (source:search-value? search))]
       [(or `(Yield ,_ ,_) `(Emit ,_ ,_) `(Forced ,_)) #t]
       [_ #f])]))

(define (machine-step/tagged configuration #:kernel [K direct:basic-kernel])
  (match-define (Machine control k) configuration)
  (define (edge label next [continuation k])
    (list label (Machine next continuation)))
  (cond
    [(value? control)
     (match k
       ['halt #f]
       [`(merge-left ,right ,rest)
        (edge "admin" right `(merge-right ,control ,rest))]
       [`(merge-right ,left ,rest) (edge "admin" `(mplus ,left ,control) rest)]
       [`(bind ,goal ,rest) (edge "admin" `(bind ,control ,goal) rest)]
       [`(yield ,state ,rest) (edge "admin" `(Yield ,state ,control) rest)]
       [`(force ,rest) (edge "admin" `(force ,control) rest)]
       [`(render ,rest) (edge "admin" `(render ,control) rest)]
       [`(emit ,state ,rest) (edge "admin" `(Emit ,state ,control) rest)]
       [`(forced ,rest) (edge "admin" `(Forced ,control) rest)])]
    [else
     (match control
       [`(eval ,(and goal (or `(succeed ,_) `(fail ,_) `(atom ,_ ,_))) ,state)
        (edge "eval-atom"
              ((K (source:decode-goal goal) state)
               (lambda () `(Empty ,(direct:State-next state)))
               (lambda (next) `(One ,next))))]
       [`(eval (fresh ,n ,body ,_) ,state)
        (define next (direct:State-next state))
        (define vars (for/list ([i (in-range n)]) (direct:LVar (+ next i))))
        (edge "eval-fresh"
              `(eval ,(source:encode-goal (apply body vars))
                     ,(struct-copy direct:State state [next (+ next n)])))]
       [`(eval (disj ,left ,right ,_) ,state)
        (edge "eval-disj" `(mplus (eval ,left ,state) (eval ,right ,state)))]
       [`(eval (conj ,left ,right ,_) ,state)
        (edge "eval-conj" `(bind (eval ,left ,state) ,right))]
       [`(eval (suspend ,goal ,_) ,state)
        (edge "eval-suspend" `(Delay (eval ,goal ,state)))]
       [`(mplus ,left ,right)
        #:when (and (source:search-value? left) (source:search-value? right))
        (match left
          [`(Empty ,_) (edge "mplus-empty" right)]
          [`(One ,state) (edge "mplus-one" `(Yield ,state ,right))]
          [`(Yield ,state ,tail) (edge "mplus-yield" `(Yield ,state (mplus ,tail ,right)))]
          [`(Delay ,body) (edge "mplus-delay" `(Delay (mplus ,right (force (Delay ,body)))))])]
       [`(bind ,search ,goal)
        #:when (source:search-value? search)
        (match search
          [`(Empty ,n) (edge "bind-empty" `(Empty ,n))]
          [`(One ,state) (edge "bind-one" `(eval ,goal ,state))]
          [`(Yield ,state ,tail)
           (edge "bind-yield" `(mplus (eval ,goal ,state) (bind ,tail ,goal)))]
          [`(Delay ,body) (edge "bind-delay" `(Delay (bind (force (Delay ,body)) ,goal)))])]
       [`(force (Delay ,body)) (edge "force-delay" body)]
       [`(render ,search)
        #:when (source:search-value? search)
        (match search
          [`(Empty ,n) (edge "render-empty" `(Done ,n))]
          [`(One ,state) (edge "render-one" `(Last ,state))]
          [`(Yield ,state ,tail) (edge "render-yield" `(Emit ,state (render ,tail)))]
          [`(Delay ,body) (edge "render-delay" `(Forced (render (force (Delay ,body)))))])]
       [`(mplus ,left ,right) (edge "admin" left `(merge-left ,right ,k))]
       [`(bind ,search ,goal) (edge "admin" search `(bind ,goal ,k))]
       [`(Yield ,state ,tail) (edge "admin" tail `(yield ,state ,k))]
       [`(force ,search)
        #:when (not (source:search-value? search))
        (edge "admin" search `(force ,k))]
       [`(render ,search) (edge "admin" search `(render ,k))]
       [`(Emit ,state ,tail) (edge "admin" tail `(emit ,state ,k))]
       [`(Forced ,tail) (edge "admin" tail `(forced ,k))]
       [_ (error 'machine-step/tagged "stuck strict machine: ~e" configuration)])]))

(define (machine-step configuration #:kernel [K direct:basic-kernel])
  (match (machine-step/tagged configuration #:kernel K)
    [#f #f]
    [(list _ next) next]))

(define (trace configuration #:kernel [K direct:basic-kernel] #:fuel [fuel 100000])
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error 'trace "exact-nonnegative-integer?" fuel))
  (define (visit current remaining [reversed '()])
    (cond
      [(machine-final? current) (reverse reversed)]
      [(zero? remaining) (error 'trace "strict machine fuel exhausted")]
      [else
       (match-define (and edge (list _ next)) (machine-step/tagged current #:kernel K))
       (visit next (sub1 remaining) (cons edge reversed))]))
  (visit configuration fuel))

(define (run-machine configuration #:kernel [K direct:basic-kernel] #:fuel [fuel 100000])
  (define edges (trace configuration #:kernel K #:fuel fuel))
  (Machine-control (if (null? edges) configuration (second (last edges)))))

(define (run-search goal #:kernel [K direct:basic-kernel]
                    #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (run-machine (initial-machine goal #:state state #:observe? #f) #:kernel K #:fuel fuel))

(define (run goal #:kernel [K direct:basic-kernel]
             #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (source:observation->frontier
   (run-machine (initial-machine goal #:state state) #:kernel K #:fuel fuel)))
