#lang racket

(require rackunit
         (prefix-in direct: "../functional-search/direct-interpreter.rkt")
         (prefix-in source: "source.rkt")
         (prefix-in b: "compressed.rkt")
         (prefix-in big: "big-step.rkt")
         (prefix-in spec: "big-step-spec.rkt")
         (only-in "tests.rkt" finite-goals))

(define (query-observe goal [state (direct:empty-state)])
  `(observe (render ,(source:initial goal #:state state))))

(define (check-finite-goal goal state)
  (define query (query-observe goal state))
  (define proof (spec:prove query))
  (check-true (spec:BigProof? proof))
  (check-true (spec:valid-proof? proof))
  (check-true (spec:judgment-agrees? proof))
  (check-equal? (length (spec:raw-derivations query)) 1)
  (check-equal? (spec:promote query) proof)
  (define initial (source:initial goal #:state state))
  (check-equal? (spec:proof-source-trace proof) (source:trace `(render ,initial)))
  (define b-initial (b:initial-compressed goal #:state state))
  (check-equal? (spec:proof-compressed-trace proof b-initial) (b:trace b-initial))
  (check-equal? (source:observation->frontier (spec:BigProof-value proof))
                (direct:run goal #:state state))
  (define search-proof (spec:prove `(search ,initial)))
  (check-true (spec:judgment-agrees? search-proof))
  (check-equal? (length (spec:raw-derivations `(search ,initial))) 1)
  (check-equal? (spec:BigProof-value search-proof) (source:run-search goal #:state state)))

(define (identity-atom tag) (direct:Atom direct:success-outcome tag))

(define eager-sibling
  (direct:Disj
   (direct:put 'A)
   (direct:Conj
    (identity-atom 'p)
    (direct:Conj (identity-atom 'q)
                 (direct:Suspend (identity-atom 'h) 'delay) 'q-then-delay)
    'p-then-rest)
   'choice))

(define eager-bind
  (direct:Conj
   (direct:Disj (direct:put 'A) (direct:put 'B) 'choice)
   (direct:Conj (identity-atom 'continuation)
                (direct:Suspend (identity-atom 'resumed) 'delay)
                'continue-then-delay)
   'bind))

(define (logging-kernel events)
  (lambda (goal state)
    (match goal
      [(direct:Atom _ tag)
       (set-box! events (cons (list tag (direct:State-tag state)) (unbox events)))]
      [_ (void)])
    (direct:basic-kernel goal state)))

(module+ test
  ;; Final-state equality checks every field, including state held inside
  ;; mature chunks and allocation counters in terminal failures.
  (define rich-state
    (direct:State 7
                  (list (list (direct:LVar 2) 'old-binding))
                  '(old-disequality)
                  '(old-trail)
                  'initial))
  (for ([goal (in-list (append finite-goals
                               (list direct:nested-rail-witness eager-sibling eager-bind)))]
        [index (in-naturals)])
    (test-case (format "strict Big / fixed point / finite R-M-B witness ~a" index)
      (check-finite-goal goal rich-state)))

  (test-case "exact nested rail, and independent public Big driver"
    (check-equal?
     (direct:frontier-shape (big:run direct:nested-rail-witness))
     '(Forced (Forced (Forced (Forced (Emit A (Emit B (Last C)))))))))

  (test-case "Big proof cannot erase or reorder work and observer contractions"
    (define proof (spec:promote (query-observe eager-sibling)))
    (check-equal?
     (spec:BigProof-trace proof)
     '("eval-disj" "eval-atom" "eval-conj" "eval-atom" "bind-one"
       "eval-conj" "eval-atom" "bind-one" "eval-suspend" "mplus-one"
       "render-yield" "render-delay" "force-delay" "eval-atom" "render-one"))
    (check-false
     (spec:valid-proof?
      (struct-copy spec:BigProof proof [trace (reverse (spec:BigProof-trace proof))])))
    (check-false
     (spec:valid-proof? (struct-copy spec:BigProof proof [value '(Done 0)])))
    (check-false
     (spec:valid-proof? (struct-copy spec:BigProof proof [rule 'value])))
    (check-false
     (spec:valid-proof? (struct-copy spec:BigProof proof [premises '()]))))

  (test-case "Search proof search performs strict disjunction and bind work"
    (for ([goal (in-list (list eager-sibling eager-bind))]
          [expected (in-list '(((put initial) (p initial) (q initial))
                              ((put initial) (put initial)
                               (continuation A) (continuation B))))])
      (define events (box '()))
      (define proof
        (spec:prove `(search ,(source:initial goal)) #:kernel (logging-kernel events)))
      (check-true (spec:BigProof? proof))
      (check-equal? (reverse (unbox events)) expected)))

  (test-case "public inductive Big evaluates eager operands in premise order"
    (define events (box '()))
    (void (big:run-search eager-bind #:kernel (logging-kernel events)))
    (check-equal? (reverse (unbox events))
                  '((put initial) (put initial) (continuation A) (continuation B))))

  (test-case "mature Yield, explicit eager Yield and Delay barrier"
    (define pending (source:initial (identity-atom 'p) #:state rich-state))
    (define events (box '()))
    (define proof
      (spec:prove `(search (Yield ,rich-state ,pending))
                  #:kernel (logging-kernel events)))
    (check-equal? (spec:BigProof-value proof) `(Yield ,rich-state (One ,rich-state)))
    (check-equal? (reverse (unbox events)) '((p initial)))
    (check-true (spec:judgment-agrees? proof))
    (set-box! events '())
    (define delay `(Delay ,pending))
    (check-equal? (big:evaluate delay #:kernel (logging-kernel events)) delay)
    (check-equal? (unbox events) '())
    (define delayed-proof (spec:prove `(search ,delay) #:depth 1))
    (check-equal? (spec:BigProof-trace delayed-proof) '())
    (check-equal? (spec:BigProof-premises delayed-proof) '()))

  (test-case "all merge/bind constructors and explicit observer contexts"
    (define success `(succeed k))
    (define values
      (list '(Empty 11) `(One ,rich-state)
            `(Yield ,rich-state (One ,rich-state))
            `(Delay (eval ,success ,rich-state))))
    (for* ([left (in-list values)] [right (in-list values)])
      (define proof (spec:promote `(merge ,left ,right)))
      (check-true (spec:judgment-agrees? proof))
      (check-equal? (spec:proof-source-trace proof)
                    (source:trace `(mplus ,left ,right))))
    (for ([value (in-list values)])
      (define proof (spec:promote `(bind ,value ,success)))
      (check-true (spec:judgment-agrees? proof))
      (check-equal? (spec:proof-source-trace proof)
                    (source:trace `(bind ,value ,success))))
    (for ([computation
           (in-list
            (list `(force (eval (suspend ,success delay) ,rich-state))
                  `(Emit ,rich-state (Forced (render (eval ,success ,rich-state))))
                  `(Forced (Done 11)) `(Emit ,rich-state (Last ,rich-state))))])
      (define query
        `(,(if (match computation [`(force ,_) #t] [_ #f]) 'search 'observe)
          ,computation))
      (define proof (spec:promote query))
      (check-true (spec:judgment-agrees? proof))
      (check-equal? (length (spec:raw-derivations query)) 1)
      (check-equal? (spec:proof-source-trace proof) (source:trace computation))))

  ;; Fresh body factories may allocate host closures on each invocation.
  ;; Compare their full semantic results and ordered labels, not Racket eq?
  ;; identity of newly created procedures inside intermediate terms.
  (test-case "fresh body factory retains full state and allocation identity"
    (define goal
      (direct:Fresh
       2
       (lambda (x y)
         (direct:Fresh
          1
          (lambda (z)
            (direct:Atom
             (lambda (state)
               (direct:success-outcome
                (struct-copy direct:State state
                             [substitution (list (list x z) (list y 'payload))]
                             [trail (list x y z)])))
             'remember))
          'inner))
       'outer))
    (define proof (spec:promote (query-observe goal rich-state)))
    (check-true (spec:judgment-agrees? proof))
    (check-equal? (big:run goal #:state rich-state) (direct:run goal #:state rich-state))
    (match (spec:BigProof-value proof)
      [`(Last ,state)
       (check-equal? (direct:State-next state) 10)
       (check-equal? (direct:State-trail state)
                     (list (direct:LVar 7) (direct:LVar 8) (direct:LVar 9)))
       (check-equal? (direct:State-disequalities state) '(old-disequality))]
      [_ (fail-check "expected exact fresh answer")]))

  (test-case "proof-search exhaustion never manufactures a Big answer"
    (define (omega) (direct:Fresh 0 omega 'unguarded))
    (define unguarded (direct:Disj (direct:put 'A) (omega) 'unguarded-right))
    (define guarded
      (direct:Disj (direct:put 'A) (direct:Suspend (omega) 'guard) 'guarded-right))
    (for ([depth (in-list '(0 1 8 64 128))])
      (check-true
       (spec:ProofSearchExhausted?
        (spec:prove `(search ,(source:initial unguarded)) #:depth depth)))
      (check-true
       (spec:ProofSearchExhausted?
        (spec:prove (query-observe guarded) #:depth depth))))
    (define finite (spec:prove `(search ,(source:initial guarded)) #:depth 8))
    (check-true (spec:BigProof? finite))
    (check-true (spec:judgment-agrees? finite))
    (check-equal? (spec:BigProof-trace finite)
                  '("eval-disj" "eval-atom" "eval-suspend" "mplus-one"))
    (check-false (member "render-yield" (spec:BigProof-trace finite))))

  (test-case "relcalls are excluded at Big source entry"
    (check-exn #rx"relcalls" (lambda () (big:run (direct:Call 'p '() 'call))))))
