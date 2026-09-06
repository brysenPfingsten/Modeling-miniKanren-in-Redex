#lang racket

(require (prefix-in source: "source.rkt")
         (prefix-in m: "machine.rkt")
         (prefix-in direct: "../functional-search/direct-interpreter.rkt"))

(provide (struct-out BRun) (struct-out BFinal) (struct-out Span)
         initial-compressed decode-BM readback-B compressed-final?
         compressed-step/tagged compressed-step/spec compression-square?
         replay-span semantic-labels trace run-compressed run-search run)

;; Bstrict is an administrative compression of Mtree. Each residual dispatch
;; contracts ONE source redex and symbolically specializes the following
;; traversal. No bounded or unbounded loop of semantic machine transitions
;; implements B. In particular every force, delay producer and render event
;; remains a separate B edge. The old column's direct/spec/exact-span split is
;; reused, but its source-specific 1--3 edge corridor is not.
;;
;; A span contains one semantic label followed by zero or more admin labels.
;; Administrative normalization is structural traversal only: it invokes no
;; kernel, body callback, source contraction, or exact-machine transition.
;; Its length depends on the finite syntax/continuation at that point.
(struct BRun (control continuation) #:transparent)
(struct BFinal (value) #:transparent)
(struct Span (labels) #:transparent
  #:guard
  (lambda (labels name)
    (unless (and (pair? labels) (list? labels) (andmap string? labels)
                 (not (equal? (first labels) "admin"))
                 (andmap (lambda (label) (equal? label "admin")) (rest labels)))
      (raise-argument-error name "one source label followed by admin labels" labels))
    labels))

(define (decode-BM configuration)
  (match configuration
    [(BRun control k) (m:Machine control k)]
    [(BFinal value) (m:Machine value 'halt)]))

(define (readback-B configuration) (m:readback-M (decode-BM configuration)))
(define (compressed-final? configuration) (BFinal? configuration))

(define (initial-compressed goal #:state [state (direct:empty-state)]
                            #:observe? [observe? #t])
  (BRun (source:initial goal #:state state) (if observe? '(render halt) 'halt)))

(define (value? control)
  (or (source:search-value? control) (source:observation-value? control)))

;; Symbolic residual dispatcher. The reversed certificate is built alongside
;; traversal, never recovered by executing M. Every recursive call performs
;; the statically specified "admin" edge and retains its exact orientation.
(define (residual control k reversed)
  (define (continue next continuation)
    (residual next continuation (cons "admin" reversed)))
  (define (stop configuration) (list (Span (reverse reversed)) configuration))
  (cond
    [(value? control)
     (match k
       ['halt (stop (BFinal control))]
       [`(merge-left ,right ,rest) (continue right `(merge-right ,control ,rest))]
       [`(merge-right ,left ,rest) (continue `(mplus ,left ,control) rest)]
       [`(bind ,goal ,rest) (continue `(bind ,control ,goal) rest)]
       [`(yield ,state ,rest) (continue `(Yield ,state ,control) rest)]
       [`(force ,rest) (continue `(force ,control) rest)]
       [`(render ,rest) (continue `(render ,control) rest)]
       [`(emit ,state ,rest) (continue `(Emit ,state ,control) rest)]
       [`(forced ,rest) (continue `(Forced ,control) rest)])]
    [else
     (match control
       [`(mplus ,left ,right)
        (if (and (source:search-value? left) (source:search-value? right))
            (stop (BRun control k))
            (continue left `(merge-left ,right ,k)))]
       [`(bind ,search ,goal)
        (if (source:search-value? search)
            (stop (BRun control k))
            (continue search `(bind ,goal ,k)))]
       [`(Yield ,state ,tail) (continue tail `(yield ,state ,k))]
       [`(force ,search)
        (if (source:search-value? search)
            (stop (BRun control k))
            (continue search `(force ,k)))]
       [`(render ,search)
        (if (source:search-value? search)
            (stop (BRun control k))
            (continue search `(render ,k)))]
       [`(Emit ,state ,tail) (continue tail `(emit ,state ,k))]
       [`(Forced ,tail) (continue tail `(forced ,k))]
       [_ (stop (BRun control k))])]))

;; Direct residual equations: no calls to machine-step, source:contract or Z.
(define (compressed-step/tagged configuration #:kernel [K direct:basic-kernel])
  (match configuration
    [(BFinal _) #f]
    [(BRun control k)
     (define (finish label next) (residual next k (list label)))
     (match control
       [`(eval ,(and goal (or `(succeed ,_) `(fail ,_) `(atom ,_ ,_))) ,state)
        (finish "eval-atom"
                ((K (source:decode-goal goal) state)
                 (lambda () `(Empty ,(direct:State-next state)))
                 (lambda (next) `(One ,next))))]
       [`(eval (fresh ,n ,body ,_) ,state)
        (define next (direct:State-next state))
        (define vars (for/list ([i (in-range n)]) (direct:LVar (+ next i))))
        (finish "eval-fresh"
                `(eval ,(source:encode-goal (apply body vars))
                       ,(struct-copy direct:State state [next (+ next n)])))]
       [`(eval (disj ,left ,right ,_) ,state)
        (finish "eval-disj" `(mplus (eval ,left ,state) (eval ,right ,state)))]
       [`(eval (conj ,left ,right ,_) ,state)
        (finish "eval-conj" `(bind (eval ,left ,state) ,right))]
       [`(eval (suspend ,goal ,_) ,state)
        (finish "eval-suspend" `(Delay (eval ,goal ,state)))]
       [`(mplus ,left ,right)
        #:when (and (source:search-value? left) (source:search-value? right))
        (match left
          [`(Empty ,_) (finish "mplus-empty" right)]
          [`(One ,state) (finish "mplus-one" `(Yield ,state ,right))]
          [`(Yield ,state ,tail) (finish "mplus-yield" `(Yield ,state (mplus ,tail ,right)))]
          [`(Delay ,body) (finish "mplus-delay" `(Delay (mplus ,right (force (Delay ,body)))))])]
       [`(bind ,search ,goal)
        #:when (source:search-value? search)
        (match search
          [`(Empty ,n) (finish "bind-empty" `(Empty ,n))]
          [`(One ,state) (finish "bind-one" `(eval ,goal ,state))]
          [`(Yield ,state ,tail)
           (finish "bind-yield" `(mplus (eval ,goal ,state) (bind ,tail ,goal)))]
          [`(Delay ,body) (finish "bind-delay" `(Delay (bind (force (Delay ,body)) ,goal)))])]
       [`(force (Delay ,body)) (finish "force-delay" body)]
       [`(render ,search)
        #:when (source:search-value? search)
        (match search
          [`(Empty ,n) (finish "render-empty" `(Done ,n))]
          [`(One ,state) (finish "render-one" `(Last ,state))]
          [`(Yield ,state ,tail) (finish "render-yield" `(Emit ,state (render ,tail)))]
          [`(Delay ,body) (finish "render-delay" `(Forced (render (force (Delay ,body)))))])]
       [_ (error 'compressed-step/tagged "not a canonical strict residual: ~e" configuration)])]))

(define (semantic-labels span)
  (filter (lambda (label) (not (equal? label "admin"))) (Span-labels span)))

;; The independent specification composes exact M transitions. It must not be
;; called to produce a B successor. Replay is label sensitive and rejects a
;; missing, extra, reordered, or semantically different edge.
(define (replay-span configuration span #:kernel [K direct:basic-kernel])
  (define (replay current labels)
    (match labels
      ['() current]
      [(cons label rest)
       (match (m:machine-step/tagged current #:kernel K)
         [(list actual next) (and (equal? label actual) (replay next rest))]
         [#f #f])]))
  (replay configuration (Span-labels span)))

(define (compressed-step/spec configuration #:kernel [K direct:basic-kernel])
  (define initial (decode-BM configuration))
  (define (administration current reversed)
    (cond
      [(m:machine-admin? current)
       (match-define (list label next) (m:machine-step/tagged current #:kernel K))
       (unless (equal? label "admin") (error 'compressed-step/spec "classifier mismatch"))
       (administration next (cons label reversed))]
      [else (list (Span (reverse reversed)) current)]))
  (match (m:machine-step/tagged initial #:kernel K)
    [#f #f]
    [(list "admin" _) (error 'compressed-step/spec "noncanonical initial residual")]
    [(list label next) (administration next (list label))]))

(define (compression-square? configuration #:kernel [K direct:basic-kernel])
  (match* ((compressed-step/tagged configuration #:kernel K)
           (compressed-step/spec configuration #:kernel K))
    [(#f #f) #t]
    [((list span next) (list expected endpoint))
     (and (equal? span expected)
          (equal? (decode-BM next) endpoint)
          (equal? (replay-span (decode-BM configuration) span #:kernel K) endpoint))]
    [(_ _) #f]))

(define (trace configuration #:kernel [K direct:basic-kernel] #:fuel [fuel 100000])
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error 'trace "exact-nonnegative-integer?" fuel))
  (define (visit current remaining [reversed '()])
    (cond
      [(BFinal? current) (reverse reversed)]
      [(zero? remaining) (error 'trace "strict compression fuel exhausted")]
      [else
       (match-define (and edge (list _ next)) (compressed-step/tagged current #:kernel K))
       (visit next (sub1 remaining) (cons edge reversed))]))
  (visit configuration fuel))

(define (run-compressed configuration #:kernel [K direct:basic-kernel] #:fuel [fuel 100000])
  (define edges (trace configuration #:kernel K #:fuel fuel))
  (readback-B (if (null? edges) configuration (second (last edges)))))

(define (run-search goal #:kernel [K direct:basic-kernel]
                    #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (run-compressed (initial-compressed goal #:state state #:observe? #f) #:kernel K #:fuel fuel))

(define (run goal #:kernel [K direct:basic-kernel]
             #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (source:observation->frontier
   (run-compressed (initial-compressed goal #:state state) #:kernel K #:fuel fuel)))
