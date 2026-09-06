#lang racket

(require (prefix-in source: "source.rkt")
         (prefix-in direct: "../functional-search/direct-interpreter.rkt"))

(provide (struct-out Dec) (struct-out Final)
         decompose plug readback initial-decomposition decomposed-step/tagged
         trace run-decomposition run-search run)

;; Dstrict reconstructs the whole term after every contraction, unlike Z's
;; retained-context transitions. This is the strict instance of the old
;; whole-tree column's plug/contract/redecompose construction, not its
;; dormant-right decomposition policy. Contexts are innermost first.
(struct Dec (redex context) #:transparent)
(struct Final (value) #:transparent)

(define (plug control context)
  (match context
    ['() control]
    [(cons frame rest)
     (plug
      (match frame
        [`(merge-left ,right) `(mplus ,control ,right)]
        [`(merge-right ,left) `(mplus ,left ,control)]
        [`(bind ,goal) `(bind ,control ,goal)]
        [`(yield ,state) `(Yield ,state ,control)]
        ['force `(force ,control)]
        ['render `(render ,control)]
        [`(emit ,state) `(Emit ,state ,control)]
        ['forced `(Forced ,control)])
      rest)]))

(define (decompose computation [context '()])
  (cond
    [(and (null? context)
          (or (source:search-value? computation)
              (source:observation-value? computation)))
     (Final computation)]
    [else
     (match computation
       [`(mplus ,left ,right)
        (cond
          [(not (source:search-value? left))
           (decompose left (cons `(merge-left ,right) context))]
          [(not (source:search-value? right))
           (decompose right (cons `(merge-right ,left) context))]
          [else (Dec computation context)])]
       [`(bind ,search ,goal)
        (if (source:search-value? search)
            (Dec computation context)
            (decompose search (cons `(bind ,goal) context)))]
       [`(Yield ,state ,tail)
        (decompose tail (cons `(yield ,state) context))]
       [`(force ,search)
        (if (source:search-value? search)
            (Dec computation context)
            (decompose search (cons 'force context)))]
       [`(render ,search)
        (if (source:search-value? search)
            (Dec computation context)
            (decompose search (cons 'render context)))]
       [`(Emit ,state ,tail)
        (decompose tail (cons `(emit ,state) context))]
       [`(Forced ,tail) (decompose tail (cons 'forced context))]
       ;; Delay is a value: there is deliberately no descent clause for it.
       [_ (Dec computation context)])]))

(define (readback configuration)
  (match configuration
    [(Final value) value]
    [(Dec redex context) (plug redex context)]))

(define (initial-decomposition goal #:state [state (direct:empty-state)]
                               #:observe? [observe? #t])
  (define computation (source:initial goal #:state state))
  (decompose (if observe? `(render ,computation) computation)))

(define (decomposed-step/tagged configuration #:kernel [K direct:basic-kernel])
  (match configuration
    [(Final _) #f]
    [(Dec redex context)
     (match (source:contract redex #:kernel K)
       [(list label contractum)
        (list label (decompose (plug contractum context)))]
       [#f (error 'decomposed-step/tagged "stuck decomposition: ~e" configuration)])]))

(define (trace configuration #:kernel [K direct:basic-kernel]
               #:fuel [fuel 100000])
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error 'trace "exact-nonnegative-integer?" fuel))
  (define (visit current remaining [reversed '()])
    (cond
      [(Final? current) (reverse reversed)]
      [(zero? remaining) (error 'trace "strict decomposition fuel exhausted")]
      [else
       (match-define (and edge (list _ next))
         (decomposed-step/tagged current #:kernel K))
       (visit next (sub1 remaining) (cons edge reversed))]))
  (visit configuration fuel))

(define (run-decomposition configuration #:kernel [K direct:basic-kernel]
                           #:fuel [fuel 100000])
  (define edges (trace configuration #:kernel K #:fuel fuel))
  (readback (if (null? edges) configuration (second (last edges)))))

(define (run-search goal #:kernel [K direct:basic-kernel]
                    #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (run-decomposition (initial-decomposition goal #:state state #:observe? #f)
                     #:kernel K #:fuel fuel))

(define (run goal #:kernel [K direct:basic-kernel]
             #:state [state (direct:empty-state)] #:fuel [fuel 100000])
  (source:observation->frontier
   (run-decomposition (initial-decomposition goal #:state state)
                      #:kernel K #:fuel fuel)))
