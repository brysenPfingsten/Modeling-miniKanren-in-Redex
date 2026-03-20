#lang racket
(require rackunit
         rackunit/text-ui
         web-server/http/response-structs
         web-server/http/request-structs
         json
         "../src/app.rkt"
         "../src/search-strategy.rkt"
         "../src/zipper.rkt"
         "../src/transpiler.rkt"
         "./test-http-helpers.rkt")

(define sample-tree
  '(() ((∃
          (x:q)
          ((sym "tree1") =? (sym "horse") (label "u5"))
          (label "f0"))
        (state () () () () (label "s")))))

(define step/const-tree-output
  (make-stepper (lambda (_) (list (list "foo" sample-tree)))))

(define streamed-answer-tree
  '(() ((succeed (label "ok")) (state () () () () (label "tail")))
       (⊤ (state () () () () (label "answer")))))

(define step/streamed-answer-output
  (make-stepper (lambda (_) (list (list "stream-step" streamed-answer-tree)))))

(define sample-program-jsexpr
  (hasheq 'children
          (list (hasheq 'id "u5"
                        'left (hasheq 'sym "tree1")
                        'name "Unify"
                        'right (hasheq 'sym "horse")))
          'disequalities '()
          'id "f0"
          'name "Fresh"
          'reified "_.0"
          'stateId "s"
          'sub '()
          'trail '()
          'vars (list (hasheq 'var "q"))))

(define (check-sample-program-response response expected-step expected-step-name)
  (define payload (string->jsexpr (response-body->string response)))
  (check-equal? (hash-ref payload 'step #f) expected-step)
  (check-equal? (hash-ref payload 'stepName #f) expected-step-name)
  (check-equal? (string->jsexpr (hash-ref payload 'program #f))
                sample-program-jsexpr))

(define (json-contains-name? node target)
  (match node
    [(? hash? h)
     (or (equal? (hash-ref h 'name #f) target)
         (json-contains-name? (hash-ref h 'children '()) target))]
    [(list xs ...) (ormap (lambda (x) (json-contains-name? x target)) xs)]
    [_ #f]))

(define disj-delay-program
  "(defrel (same x y)
     (== x y))

   (run 2 (q)
     (conde
       [(same q 'cat)]
       [(same q 'dog)]))")

(define same-program
  "(defrel (same x y)
     (== x y))

   (run* (q)
     (conde
       [(conde
          [(same q 'turtle)]
          [(same q 'cat)]
          [(== q 'dog)])]
       [(same q 'fish)]))")

(define (collect-step-names ses limit [i 0] [acc '()])
  (cond
    [(>= i limit) (reverse acc)]
    [else
     (define response (step! ses))
     (define out (response-body->string response))
     (if (string=? out "null")
         (reverse acc)
         (collect-step-names ses
                             limit
                             (add1 i)
                             (cons (hash-ref (string->jsexpr out) 'stepName #f)
                                   acc)))]))

(define-test-suite STEP!
  #:before (thunk (displayln "Running tests for step!..."))
  #:after  (thunk (displayln "Finished running tests for step!"))

  (test-case "step! sends null reponse with header if no more reductions and does not affect zipper"
              (define zip (zipper '() (step "foo" '(() ())) '() 1))
              (define stepper (make-stepper (λ (_) '())))
              (define ses (session zip stepper 1))
              (define response (step! ses))
              (check-equal? (response-code response) 200)
              (check-equal? (response-message response) #"OK")
              (check-equal? (response-mime response) APPLICATION/JSON-MIME-TYPE)
              (check-equal? (response-headers response)
                            (list (make-header #"X-Done" #"true")))
              (check-equal? (response-body->string response) "null")
              (define new-zipper (session-zipper ses))
              (check-equal? zip new-zipper))

  (test-case "step! advances via stepper when no future cache and updates state"
              (define zip (zipper '() (step "foo" sample-tree) '() 1))
              (define stepper step/const-tree-output)
              (define ses (session zip stepper 1))
              (define response (step! ses))
              (check-equal? (response-code response) 200)
              (check-equal? (response-message response) #"OK")
              (check-equal? (response-mime response) APPLICATION/JSON-MIME-TYPE)
              (check-equal? (response-headers response) '())
              (check-sample-program-response response 2 "foo")
              (define new-zipper (session-zipper ses))
              (check-equal? (zipper-prev new-zipper) (list (step "foo" sample-tree)))
              (check-equal? (step-name (zipper-curr new-zipper)) "foo")
              (check-equal? (zipper-next new-zipper) '())
              (check-equal? (zipper-idx   new-zipper) 2))

  (test-case "step! gets next tree in the state if it is cached and updates state"
              (define zip (zipper '() (step "foo" sample-tree) (list (step "bar" sample-tree)) 1))
              (define stepper step/const-tree-output)
              (define ses (session zip stepper 1))
              (define response (step! ses))
              (check-equal? (response-code response) 200)
              (check-equal? (response-message response) #"OK")
              (check-equal? (response-mime response) APPLICATION/JSON-MIME-TYPE)
              (check-equal? (response-headers response) '())
              (check-sample-program-response response 2 "bar")
              (define new-zipper (session-zipper ses))
              (check-equal? (zipper-prev new-zipper) (list (step "foo" sample-tree)))
              (check-equal? (zipper-curr new-zipper) (step "bar" sample-tree))
              (check-equal? (zipper-next new-zipper) '())
              (check-equal? (zipper-idx   new-zipper) 2)
              )

  (test-case "step! serializes top-level answer stream ahead of remaining work"
              (define zip (zipper '() (step "foo" sample-tree) '() 1))
              (define ses (session zip step/streamed-answer-output 1))
              (define response (step! ses))
              (check-equal? (response-code response) 200)
              (define payload (string->jsexpr (response-body->string response)))
              (define program-json (string->jsexpr (hash-ref payload 'program #f)))
              (check-equal? (hash-ref program-json 'name #f) "Answer")
              (check-false (json-contains-name? program-json "Emit")))
)

(define-test-suite INIT!
  #:before (thunk (displayln "Running tests for init!..."))
  #:after (thunk (displayln "Finished running tests for init!."))

  (test-case "init! parses, updates state, and sends response with json and string prog"
              (define sample-req (make-post-init-request "(run* (q) (== 'a 'a))"))
              (define zip (zipper '() #f '() 0))
              (define stepper identity)
              (define ses (session zip stepper 1))
              (define response (init! ses sample-req 'testid))
              (check-equal? (response-code response) 200)
              (check-equal? (response-message response) #"OK")
              (check-equal? (response-mime response) 
                            APPLICATION/JSON-MIME-TYPE)
              (check-equal? (response-headers response) 
                            (list (header #"Set-Cookie" #"session-id=testid; Path=/; SameSite=Lax")))
              (define json-response (string->jsexpr (response-body->string response)))
              (check-equal? (hash-ref json-response 'stepName #f) "Initialize Program")
              (check-equal? (hash-ref json-response 'step #f) 0)
              (check-not-false (hash-ref json-response 'program #f))
              (check-not-false (hash-ref json-response 'htmlGuids #f)))

  (test-case "init! defaults missing source options to canonical mini profile"
              (define sample-req
                (make-post-init-request
                 "(run* (q) (== 'a 'a))"
                 (hasheq 'text "(run* (q) (== 'a 'a))")))
              (define zip (zipper '() #f '() 0))
              (define stepper identity)
              (define ses (session zip stepper 1))
              (define response (init! ses sample-req 'defaultid))
              (check-equal? (response-code response) 200)
              (define json-response (string->jsexpr (response-body->string response)))
              (check-equal? (hash-ref json-response 'stepName #f) "Initialize Program")
              (check-equal? (hash-ref json-response 'step #f) 0)
              (check-not-false (hash-ref json-response 'program #f))
              (check-not-false (hash-ref json-response 'htmlGuids #f)))

  (test-case "init! serializes direct micro Zzz as goal delay"
              (define sample-req
                (make-post-init-request
                 "(run* (q) (Zzz (== q 'cat)))"
                 (hasheq 'text "(run* (q) (Zzz (== q 'cat)))"
                         'sourceMode "micro")))
              (define zip (zipper '() #f '() 0))
              (define stepper identity)
              (define ses (session zip stepper 1))
              (define response (init! ses sample-req 'goal-delay-id))
              (check-equal? (response-code response) 200)
              (define payload (string->jsexpr (response-body->string response)))
              (define program-json (string->jsexpr (hash-ref payload 'program #f)))
              (check-true (json-contains-name? program-json "Goal-Delay"))
              (check-false (equal? (hash-ref program-json 'name #f) "Delay")))

  (test-case "init! throws error if program is not syntactically correct"
              (define sample-req (make-post-init-request "(run* (== 'a 'a))"))
              (define zip (zipper '() #f '() 0))
              (define stepper identity)
              (define ses (session zip stepper 1))
              (check-exn exn:fail:syntax? (thunk (init! ses sample-req 'testid))))

  (test-case "init! defaults missing searchStrategy in payload"
              (define sample-req
                (make-post-request "init"
                                   (hasheq 'text "(run* (q) (== q 'ok))"
                                           'sourceMode "mini"
                                           'compileProfile (hash-ref default-source-options 'compileProfile))))
              (define zip (zipper '() #f '() 0))
              (define stepper identity)
              (define ses (session zip stepper 1))
              (define response (init! ses sample-req 'default-strategy-id))
              (check-equal? (response-code response) 200)
              (check-equal? (session-search-strategy ses) default-search-strategy))

  (test-case "init! rejects invalid searchStrategy hoist in payload"
              (define sample-req
                (make-post-init-request
                 "(run* (q) (== q 'ok))"
                 (hasheq 'text "(run* (q) (== q 'ok))"
                         'sourceMode "mini"
                         'compileProfile (hash-ref default-source-options 'compileProfile)
                         'searchStrategy (hasheq 'hoist "sideways"
                                                 'scheduler "rail"))))
              (define zip (zipper '() #f '() 0))
              (define stepper identity)
              (define ses (session zip stepper 1))
              (check-exn exn:fail?
                         (thunk (init! ses sample-req 'invalid-hoist-id))))

  (test-case "init! rejects invalid searchStrategy scheduler in payload"
              (define sample-req
                (make-post-init-request
                 disj-delay-program
                 (hasheq 'text disj-delay-program
                         'sourceMode "mini"
                         'compileProfile (hash-ref default-source-options 'compileProfile)
                         'searchStrategy (hasheq 'hoist "late"
                                                 'scheduler "zigzag"))))
              (define zip (zipper '() #f '() 0))
              (define stepper identity)
              (define ses (session zip stepper 1))
              (check-exn exn:fail?
                         (thunk (init! ses sample-req 'invalid-scheduler-id))))

  (test-case "init! accepts searchStrategy payload and updates session state"
              (define zip (zipper '() #f '() 0))
              (define ses (session zip step/const-tree-output 1))
              (define response
                (init!
                 ses
                 (make-post-init-request
                  disj-delay-program
                  #:strategy (search-strategy "late" "flip"))
                 'init-search-strategy-id))
              (check-equal? (response-code response) 200)
              (check-equal? (session-search-strategy ses)
                            (search-strategy "late" "flip"))
              (define names (collect-step-names ses 24))
              (check-not-false (member "search-flip-fused-calls/delay-swap-left" names))
              (check-false (member "rail-fused-calls/enter-right" names)))
  )

(define-test-suite RESET!
  #:before (thunk (displayln "Running tests for reset!..."))
  #:after (thunk (displayln "Finished running tests for reset."))

  (test-case "reset! empties state and sends initial state when it has a prev cache"
             (define zip (zipper (list 'a 'b 'c (step "Initialize Program" sample-tree))
                                   'd '() 5))
             (define stepper identity)
             (define ses (session zip stepper 1))
             (define ses-table (make-hash))
             (hash-set! ses-table 'testid ses)
             (define response (reset! ses ses-table 'testid))
             (check-equal? (response-code response) 200)
             (check-equal? (response-message response) #"OK")
             (check-equal? (response-mime response) 
                           APPLICATION/JSON-MIME-TYPE)
             (check-equal? (response-headers response) 
                           (list (header #"X-Is-Last" #"true")))
             (check-sample-program-response response 0 "Initialize Program")
             (check-false (hash-ref ses-table 'testid false)))


  (test-case "reset! empties state and sends current state with header when it doesn't have a prev cache"
             (define zip (zipper '() (step "Initialize Program" sample-tree) '() 0))
             (define stepper identity)
             (define ses (session zip stepper 1))
             (define ses-table (make-hash))
             (hash-set! ses-table 'testid ses)
             (define response (reset! ses ses-table 'testid))
             (check-equal? (response-code response) 200)
             (check-equal? (response-message response) #"OK")
             (check-equal? (response-mime response) APPLICATION/JSON-MIME-TYPE)
             (check-equal? (response-headers response)
                           (list (make-header #"X-Is-Last" #"true")))
             (check-sample-program-response response 0 "Initialize Program")
             (check-false (hash-ref ses-table 'testid false)))
  )

(define-test-suite BACK!
  #:before (thunk (displayln "Running tests for back!..."))
  #:after (thunk (displayln "Finished running tests for back!."))

  (test-case "back! sends initial state with header when only one thing in prev cache and updates state"
             (define zip (zipper (list (step "Initialize Program" sample-tree)) 'test '() 1))
             (define stepper identity)
             (define ses (session zip stepper 1))
             (define response (back! ses))
             (check-equal? (response-code response) 200)
             (check-equal? (response-message response) #"OK")
             (check-equal? (response-mime response) APPLICATION/JSON-MIME-TYPE)
             (check-equal? (response-headers response)
                           (list (header #"X-Is-Last" #"true")))
             (check-sample-program-response response 0 "Initialize Program")
             (define new-zipper (session-zipper ses))
             (check-equal? (zipper-prev new-zipper) '())
             (check-equal? (zipper-curr new-zipper) (step "Initialize Program" sample-tree))
             (check-equal? (zipper-next new-zipper) '(test))
             (check-equal? (zipper-idx new-zipper) 0))

  (test-case "back! sends initial state when multiple things in prev cache and updates state"
              (define zip (zipper (list (step "Initialize Program" sample-tree) 'test1) 'test2 '() 2))
              (define stepper identity)
              (define ses (session zip stepper 1))
              (define response (back! ses))
              (check-equal? (response-code response) 200)
              (check-equal? (response-message response) #"OK")
              (check-equal? (response-mime response) APPLICATION/JSON-MIME-TYPE)
              (check-equal? (response-headers response) '())
              (check-sample-program-response response 1 "Initialize Program")
              (define new-zipper (session-zipper ses))
              (check-equal? (zipper-prev new-zipper) '(test1))
              (check-equal? (zipper-curr new-zipper) (step "Initialize Program" sample-tree))
              (check-equal? (zipper-next new-zipper) '(test2))
              (check-equal? (zipper-idx new-zipper) 1))
  )

(define-test-suite INIT-SEARCH-STRATEGY!
  #:before (thunk (displayln "Running tests for init search strategy binding!..."))
  #:after (thunk (displayln "Finished running tests for init search strategy binding!."))

  (test-case "late flip strategy emits flip rules and no rail rules"
             (define ses (session (zipper '() #f '() 0) step/const-tree-output 1))
             (check-equal? (response-code (init! ses (make-post-init-request disj-delay-program #:strategy (search-strategy "late" "flip")) 'testid)) 200)
             (check-equal? (session-search-strategy ses) (search-strategy "late" "flip"))
             (define names (collect-step-names ses 24))
             (check-not-false (member "search-flip-fused-calls/delay-swap-left" names))
             (check-not-false (member "delay/invoke-delay" names))
             (check-false (member "rail-fused-calls/enter-right" names))
             (check-false (member "rail-fused-calls/return-left" names)))

  (test-case "early rail strategy emits railroad rules and no flip rule"
             (define ses (session (zipper '() #f '() 0) step/const-tree-output 1))
             (check-equal? (response-code (init! ses (make-post-init-request disj-delay-program #:strategy (search-strategy "early" "rail")) 'testid)) 200)
             (check-equal? (session-search-strategy ses) (search-strategy "early" "rail"))
             (define names (collect-step-names ses 24))
             (check-not-false (member "rail-seq-calls/enter-right" names))
             (check-not-false (member "rail-seq-calls/return-left" names))
             (check-not-false (member "delay/invoke-delay" names))
             (check-false (member "search-flip-seq-calls/delay-swap-left" names)))

  (test-case "late dfs relcall-delay profile expands calls without eager/lazy resume rules"
             (define ses (session (zipper '() #f '() 0) step/const-tree-output 1))
             (check-equal?
              (response-code
               (init!
                ses
                (make-post-init-request
                 disj-delay-program
                 (hasheq 'text disj-delay-program
                         'sourceMode "mini"
                         'compileProfile (hasheq 'conjAssoc "left"
                                                 'disjAssoc "right"
                                                 'delayPlacement "relcall"))
                 #:strategy (search-strategy "late" "dfs"))
                'testid))
              200)
             (check-equal? (session-search-strategy ses) (search-strategy "late" "dfs"))
             (define names (collect-step-names ses 24))
             (check-not-false (member "search-base-fused-calls/expand" names))
             (check-false (ormap (lambda (nm)
                                   (regexp-match? #rx"eager|lazy|proceed" nm))
                                 names)))

  (test-case "disj delay placement does not also suspend plain relcalls"
             (define ses (session (zipper '() #f '() 0) step/const-tree-output 1))
             (define response
               (init!
                ses
                (make-post-init-request
                 same-program
                 (hasheq 'text same-program
                         'sourceMode "mini"
                         'compileProfile (hasheq 'conjAssoc "right"
                                                 'disjAssoc "left"
                                                 'delayPlacement "disj"))
                 #:strategy (search-strategy "early" "rail"))
                'testid))
             (check-equal? (response-code response) 200)
             (check-equal? (session-search-strategy ses) (search-strategy "early" "rail"))
             (define names (collect-step-names ses 16))
             (check-not-false (member "delay/suspend-goal" names))
             (check-not-false (member "search-base-seq-calls/expand" names))
             (check-false (ormap (lambda (nm)
                                   (regexp-match? #rx"eager|lazy|proceed" nm))
                                 names))))

(define-test-suite SOURCE-CONVERT!
  (test-case "source-convert! lowers mini source to direct micro source with Zzz"
             (define req
               (make-post-source-convert-request
                "(defrel (same x y) (== x y))
                 (run* (q)
                   (conde
                     [(same q 'cat)]
                     [(same q 'dog)]))"))
             (define response (source-convert! req))
             (check-equal? (response-code response) 200)
             (define body (string->jsexpr (response-body->string response)))
             (define rendered (hash-ref body 'source #f))
             (check-true (string? rendered))
             (check-not-false (regexp-match? #rx"Zzz" rendered)))

  (test-case "source-convert! rejects unsupported target source modes"
             (define req
               (make-post-source-convert-request
                "(run* (q) (== q 'cat))"
                (hasheq 'text "(run* (q) (== q 'cat))"
                        'sourceMode "mini"
                        'compileProfile (hash-ref default-source-options 'compileProfile)
                        'targetSourceMode "mini")))
             (check-exn exn:fail?
                        (lambda () (source-convert! req)))))

(define/provide-test-suite APP
  #:before (thunk (displayln "Running tests for app.rkt..."))
  #:after (thunk (displayln "Finished running tests for app.rkt"))
  STEP!
  INIT!
  RESET!
  BACK!
  INIT-SEARCH-STRATEGY!
  SOURCE-CONVERT!
)

(run-tests APP)
