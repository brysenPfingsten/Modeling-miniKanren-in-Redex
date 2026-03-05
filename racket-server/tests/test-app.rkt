#lang racket
(require rackunit
         rackunit/text-ui
         web-server/http/response-structs
         web-server/http/request-structs
         net/url-structs
         json
         "../src/app.rkt"
         "../src/zipper.rkt"
         "../src/transpiler.rkt")

(define sample-tree
  '(() ()
       ((∃
          (x:q)
          ((sym "tree1") =? (sym "horse") (label "u5"))
          (label "f0"))
        (state () () () (label "s")))))

(define step/const-tree-output
  (make-stepper (lambda (_) (list (list "foo" sample-tree)))))

(define (get-response-out response)
  (let ([out (open-output-string)])
    ((response-output response) out)
    (get-output-string out)))

(define (make-post-model-request model)
  (make-request
   #"POST"
   (make-url #f #f #f #f #t
             (list (make-path/param "post" empty)
                   (make-path/param "model" empty))
             empty
             #f)
   (list (make-header #"content-type" #"application/json"))
   (delay '())
   (string->bytes/utf-8 (format "{\"model\":\"~a\"}" model))
   "127.0.0.1"
   5000
   "127.0.0.1"))

(define (make-post-init-request program-text)
  (make-request
   #"POST"
   (make-url #f #f #f #f #t
             (list (make-path/param "post" empty)
                   (make-path/param "init" empty))
             empty
             #f)
   (list (make-header #"content-type" #"application/json"))
   (delay '())
   (string->bytes/utf-8 (jsexpr->string (hasheq 'text program-text)))
   "127.0.0.1"
   5000
   "127.0.0.1"))

(define (make-post-analyze-request program-text)
  (make-request
   #"POST"
   (make-url #f #f #f #f #t
             (list (make-path/param "post" empty)
                   (make-path/param "analyze" empty))
             empty
             #f)
   (list (make-header #"content-type" #"application/json"))
   (delay '())
   (string->bytes/utf-8 (jsexpr->string (hasheq 'text program-text)))
   "127.0.0.1"
   5000
   "127.0.0.1"))

(define disj-delay-program
  "(defrel (same x y)
     (== x y))

   (run 2 (q)
     (conde
       [(same q 'cat)]
       [(same q 'dog)]))")

(define (collect-step-names ses limit)
  (let loop ([i 0] [acc '()])
    (if (>= i limit)
        (reverse acc)
        (let* ([response (step! ses)]
               [out (get-response-out response)])
          (if (string=? out "null")
              (reverse acc)
              (loop (add1 i)
                    (cons (hash-ref (string->jsexpr out) 'stepName #f) acc)))))))

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
              (check-equal? (get-response-out response) "null")
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
              (check-equal? (get-response-out response)
                            "{\"program\":\"{\\\"children\\\":[{\\\"id\\\":\\\"u5\\\",\\\"left\\\":{\\\"sym\\\":\\\"tree1\\\"},\\\"name\\\":\\\"Unify\\\",\\\"right\\\":{\\\"sym\\\":\\\"horse\\\"}}],\\\"id\\\":\\\"f0\\\",\\\"name\\\":\\\"Fresh\\\",\\\"reified\\\":[],\\\"stateId\\\":\\\"s\\\",\\\"sub\\\":[],\\\"trail\\\":[],\\\"vars\\\":[{\\\"var\\\":\\\"q\\\"}]}\",\"step\":2,\"stepName\":\"foo\"}")
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
              (check-equal? (get-response-out response)
                            "{\"program\":\"{\\\"children\\\":[{\\\"id\\\":\\\"u5\\\",\\\"left\\\":{\\\"sym\\\":\\\"tree1\\\"},\\\"name\\\":\\\"Unify\\\",\\\"right\\\":{\\\"sym\\\":\\\"horse\\\"}}],\\\"id\\\":\\\"f0\\\",\\\"name\\\":\\\"Fresh\\\",\\\"reified\\\":[],\\\"stateId\\\":\\\"s\\\",\\\"sub\\\":[],\\\"trail\\\":[],\\\"vars\\\":[{\\\"var\\\":\\\"q\\\"}]}\",\"step\":2,\"stepName\":\"bar\"}")
              (define new-zipper (session-zipper ses))
              (check-equal? (zipper-prev new-zipper) (list (step "foo" sample-tree)))
              (check-equal? (zipper-curr new-zipper) (step "bar" sample-tree))
              (check-equal? (zipper-next new-zipper) '())
              (check-equal? (zipper-idx   new-zipper) 2)
              )
)

(define-test-suite INIT!
  #:before (thunk (displayln "Running tests for init!..."))
  #:after (thunk (displayln "Finished running tests for init!."))

  (test-case "init! parses, updates state, and sends response with json and string prog"
              (define sample-req
              (make-request
              #"POST"
              (make-url #f #f #f #f #t
                        (list (make-path/param "post" empty)
                              (make-path/param "init" empty))
                        empty
                        #f)
              (list (make-header #"content-type" #"application/json"))
              (delay '())
              (string->bytes/utf-8 "{\"text\":\"(run* (q) (== 'a 'a))\"}")
              "127.0.0.1"
              5000
              "127.0.0.1"))
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
              (define json-response (string->jsexpr (get-response-out response)))
              (check-equal? (hash-ref json-response 'stepName #f) "Initialize Program")
              (check-equal? (hash-ref json-response 'step #f) 0)
              (check-not-false (hash-ref json-response 'program #f))
              (check-not-false (hash-ref json-response 'htmlGuids #f)))

  (test-case "init! throws error if program is not syntactically correct"
              (define sample-req
              (make-request
              #"POST"
              (make-url #f #f #f #f #t
                        (list (make-path/param "post" empty)
                              (make-path/param "init" empty))
                        empty
                        #f)
              (list (make-header #"content-type" #"application/json"))
              (delay '())
              (string->bytes/utf-8 "{\"text\":\"(run* (== 'a 'a))\"}")
              "127.0.0.1"
              5000
              "127.0.0.1"))
              (define zip (zipper '() #f '() 0))
              (define stepper identity)
              (define ses (session zip stepper 1))
              (check-exn exn:fail:syntax? (thunk (init! ses sample-req 'testid))))

  (test-case "init! rejects program incompatible with currently selected model"
              (define sample-req (make-post-init-request disj-delay-program))
              (define zip (zipper '() #f '() 0))
              (define stepper identity)
              (define ses (session zip stepper 1))
              (check-equal? (response-code (switch-model! ses (make-post-model-request "mk-l0-core") 'incompat-id))
                            200)
              (check-exn exn:fail?
                         (thunk (init! ses sample-req 'incompat-id))))
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
             (check-equal? (get-response-out response)
                           "{\"program\":\"{\\\"children\\\":[{\\\"id\\\":\\\"u5\\\",\\\"left\\\":{\\\"sym\\\":\\\"tree1\\\"},\\\"name\\\":\\\"Unify\\\",\\\"right\\\":{\\\"sym\\\":\\\"horse\\\"}}],\\\"id\\\":\\\"f0\\\",\\\"name\\\":\\\"Fresh\\\",\\\"reified\\\":[],\\\"stateId\\\":\\\"s\\\",\\\"sub\\\":[],\\\"trail\\\":[],\\\"vars\\\":[{\\\"var\\\":\\\"q\\\"}]}\",\"step\":0,\"stepName\":\"Initialize Program\"}")
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
             (check-equal? (get-response-out response)
                           "{\"program\":\"{\\\"children\\\":[{\\\"id\\\":\\\"u5\\\",\\\"left\\\":{\\\"sym\\\":\\\"tree1\\\"},\\\"name\\\":\\\"Unify\\\",\\\"right\\\":{\\\"sym\\\":\\\"horse\\\"}}],\\\"id\\\":\\\"f0\\\",\\\"name\\\":\\\"Fresh\\\",\\\"reified\\\":[],\\\"stateId\\\":\\\"s\\\",\\\"sub\\\":[],\\\"trail\\\":[],\\\"vars\\\":[{\\\"var\\\":\\\"q\\\"}]}\",\"step\":0,\"stepName\":\"Initialize Program\"}")
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
             (check-equal? (get-response-out response)
                           "{\"program\":\"{\\\"children\\\":[{\\\"id\\\":\\\"u5\\\",\\\"left\\\":{\\\"sym\\\":\\\"tree1\\\"},\\\"name\\\":\\\"Unify\\\",\\\"right\\\":{\\\"sym\\\":\\\"horse\\\"}}],\\\"id\\\":\\\"f0\\\",\\\"name\\\":\\\"Fresh\\\",\\\"reified\\\":[],\\\"stateId\\\":\\\"s\\\",\\\"sub\\\":[],\\\"trail\\\":[],\\\"vars\\\":[{\\\"var\\\":\\\"q\\\"}]}\",\"step\":0,\"stepName\":\"Initialize Program\"}")
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
              (check-equal? (get-response-out response)
                            "{\"program\":\"{\\\"children\\\":[{\\\"id\\\":\\\"u5\\\",\\\"left\\\":{\\\"sym\\\":\\\"tree1\\\"},\\\"name\\\":\\\"Unify\\\",\\\"right\\\":{\\\"sym\\\":\\\"horse\\\"}}],\\\"id\\\":\\\"f0\\\",\\\"name\\\":\\\"Fresh\\\",\\\"reified\\\":[],\\\"stateId\\\":\\\"s\\\",\\\"sub\\\":[],\\\"trail\\\":[],\\\"vars\\\":[{\\\"var\\\":\\\"q\\\"}]}\",\"step\":1,\"stepName\":\"Initialize Program\"}")
              (define new-zipper (session-zipper ses))
              (check-equal? (zipper-prev new-zipper) '(test1))
              (check-equal? (zipper-curr new-zipper) (step "Initialize Program" sample-tree))
              (check-equal? (zipper-next new-zipper) '(test2))
              (check-equal? (zipper-idx new-zipper) 1))
  )

(define-test-suite SWITCH-MODEL!
  #:before (thunk (displayln "Running tests for switch-model!..."))
  #:after (thunk (displayln "Finished running tests for switch-model!."))

  (test-case "switch-model! updates stepper for known model id"
             (define zip (zipper '() (step "foo" sample-tree) '() 1))
             (define old-stepper step/const-tree-output)
             (define ses (session zip old-stepper 1))
             (define req (make-post-model-request "mk-l3-dfs-lazy"))
             (define response (switch-model! ses req 'testid))
             (check-equal? (response-code response) 200)
             (check-true (procedure? (session-stepper ses)))
             (check-false (eq? (session-stepper ses) old-stepper))
             (check-equal? (response-headers response)
                           (list (header #"Set-Cookie" #"session-id=testid; Path=/; SameSite=Lax")))
             (check-equal? (string->jsexpr (get-response-out response))
                           (hasheq 'model "mk-l3-dfs-lazy")))

  (test-case "switch-model! supports core-only model id"
             (define zip (zipper '() (step "foo" sample-tree) '() 1))
             (define old-stepper step/const-tree-output)
             (define ses (session zip old-stepper 1))
             (define req (make-post-model-request "mk-l0-core"))
             (define response (switch-model! ses req 'testid))
             (check-equal? (response-code response) 200)
             (check-true (procedure? (session-stepper ses)))
             (check-false (eq? (session-stepper ses) old-stepper))
             (check-equal? (string->jsexpr (get-response-out response))
                           (hasheq 'model "mk-l0-core")))

  (test-case "switch-model! rejects unknown model id and keeps existing stepper"
             (define zip (zipper '() (step "foo" sample-tree) '() 1))
             (define old-stepper step/const-tree-output)
             (define ses (session zip old-stepper 1))
             (define req (make-post-model-request "nope"))
             (define response (switch-model! ses req 'testid))
             (check-equal? (response-code response) 400)
             (check-true (eq? (session-stepper ses) old-stepper))
             (check-true (hash-has-key? (string->jsexpr (get-response-out response)) 'error)))

  (test-case "flip model emits flip delay/disjunction rules (no railroad disjunction rules)"
             (define ses (session (zipper '() #f '() 0) step/const-tree-output 1))
             (check-equal? (response-code (switch-model! ses (make-post-model-request "mk-l3-flip-lazy") 'testid)) 200)
             (check-equal? (response-code (init! ses (make-post-init-request disj-delay-program) 'testid)) 200)
             (define names (collect-step-names ses 24))
             (check-not-false (member "flip/delay-swap-left" names))
             (check-not-false (member "flip/invoke-delay" names))
             (check-false (member "rail/enter-right" names))
             (check-false (member "rail/return-left" names)))

  (test-case "rail model emits railroad delay/disjunction rules (no flip disjunction rule)"
             (define ses (session (zipper '() #f '() 0) step/const-tree-output 1))
             (check-equal? (response-code (switch-model! ses (make-post-model-request "mk-l4-rail-lazy") 'testid)) 200)
             (check-equal? (response-code (init! ses (make-post-init-request disj-delay-program) 'testid)) 200)
             (define names (collect-step-names ses 24))
             (check-not-false (member "rail/enter-right" names))
             (check-not-false (member "rail/return-left" names))
             (check-not-false (member "rail/invoke-delay" names))
             (check-false (member "flip/delay-swap-left" names)))

  (test-case "rail eager model emits eager call rules after init"
             (define ses (session (zipper '() #f '() 0) step/const-tree-output 1))
             (check-equal? (response-code (switch-model! ses (make-post-model-request "mk-l4-rail-eager") 'testid)) 200)
             (check-equal? (response-code (init! ses (make-post-init-request disj-delay-program) 'testid)) 200)
             (define names (collect-step-names ses 24))
             (check-not-false (member "call/eager-suspend-expanded" names))
             (check-not-false (member "call/eager-resume-goal" names))
             (check-false (member "call/lazy-suspend-call" names))
             (check-false (member "call/lazy-expand-on-resume" names))))

(define-test-suite LIST-MODELS!
  #:before (thunk (displayln "Running tests for list-models!..."))
  #:after (thunk (displayln "Finished running tests for list-models!."))

  (test-case "list-models! returns known backend models with parser contract"
             (define response (list-models!))
             (check-equal? (response-code response) 200)
             (define models (string->jsexpr (get-response-out response)))
             (check-true (list? models))
             (check-true (>= (length models) 10))
             (define ids (for/list ([m (in-list models)])
                           (hash-ref m 'id #f)))
             (check-not-false (member "mk-l0-core" ids))
             (check-not-false (member "mk-l1-call-lazy" ids))
             (check-not-false (member "mk-l1-call-eager" ids))
             (check-not-false (member "mk-l2-disj-left" ids))
             (check-not-false (member "mk-l4-rail-lazy" ids))
             (check-not-false (member "mk-l3-dfs-lazy" ids))
             (check-not-false (member "mk-l4-rail-eager" ids))
             (check-not-false (member "mk-l3-dfs-eager" ids))
             (check-not-false (member "mk-l3-flip-lazy" ids))
             (check-not-false (member "mk-l3-flip-eager" ids))
             (check-true (for/and ([m (in-list models)])
                           (and (hash-has-key? m 'parserProfile)
                                (hash-has-key? m 'parserTarget)
                                (hash-has-key? m 'capabilities)
                                (equal? (hash-ref m 'parserTarget #f)
                                        canonical-parser-target-id))))))

(define-test-suite ANALYZE!
  #:before (thunk (displayln "Running tests for analyze!..."))
  #:after (thunk (displayln "Finished running tests for analyze!."))

  (test-case "analyze! returns capability payload for valid source"
             (define req (make-post-analyze-request "(run* (q) (fresh (x) (== q x)))"))
             (define response (analyze! #f req))
             (check-equal? (response-code response) 200)
             (define body (string->jsexpr (get-response-out response)))
             (check-true (hash-ref body 'validSyntax #f))
             (check-true (list? (hash-ref body 'requirements '())))
             (check-true (list? (hash-ref body 'compatibleModelIds '())))
             (check-true (list? (hash-ref body 'incompatibleModelIds '())))
             (check-true (hash? (hash-ref body 'incompatReasonsByModel #hash())))
             (check-true (string? (hash-ref body 'analysisVersion ""))))

  (test-case "analyze! returns 400 on syntax error"
             (define req (make-post-analyze-request "(run* (== 'a 'a))"))
             (define response (analyze! #f req))
             (check-equal? (response-code response) 400)
             (define body (string->jsexpr (get-response-out response)))
             (check-false (hash-ref body 'validSyntax #t))
             (check-true (hash-has-key? body 'error)))

  (test-case "analyze! compatibility ids are known model ids"
             (define req
               (make-post-analyze-request
                "(run* (q) (fresh (x) (== q x)))"))
             (define response (analyze! #f req))
             (check-equal? (response-code response) 200)
             (define body (string->jsexpr (get-response-out response)))
             (define models-res (string->jsexpr (get-response-out (list-models!))))
             (define known-ids
               (for/set ([m (in-list models-res)])
                 (hash-ref m 'id #f)))
             (for ([id (in-list (hash-ref body 'compatibleModelIds '()))])
               (check-true (set-member? known-ids id)))
             (for ([id (in-list (hash-ref body 'incompatibleModelIds '()))])
               (check-true (set-member? known-ids id))))

  (test-case "analyze! returns mixed compatible/incompatible payload for appendo"
             (define req
               (make-post-analyze-request
                "(defrel (appendo l s out)
                   (conde
                     [(== l '()) (== s out)]
                     [(fresh (a d res)
                        (== l (cons a d))
                        (== out (cons a res))
                        (appendo d s res))]))
                 (run* (q) (appendo (list 'mini) (list 'kanren) q))"))
             (define response (analyze! #f req))
             (check-equal? (response-code response) 200)
             (define body (string->jsexpr (get-response-out response)))
             (check-true (hash-ref body 'validSyntax #f))
             (check-not-false (member "mk-l3-dfs-lazy"
                                      (hash-ref body 'compatibleModelIds '())))
             (check-not-false (member "mk-l0-core"
                                      (hash-ref body 'incompatibleModelIds '())))
             (define reasons-by-model (hash-ref body 'incompatReasonsByModel #hash()))
             (define reasons-l0
               (or (hash-ref reasons-by-model "mk-l0-core" #f)
                   (hash-ref reasons-by-model 'mk-l0-core #f)
                   '()))
             (check-true (pair? reasons-l0))
             (check-not-false
              (member "missing cap/relcall (required by req/relcall)"
                      reasons-l0))))

(define/provide-test-suite APP
  #:before (thunk (displayln "Running tests for app.rkt..."))
  #:after (thunk (displayln "Finished running tests for app.rkt"))
  STEP!
  INIT!
  RESET!
  BACK!
  SWITCH-MODEL!
  LIST-MODELS!
  ANALYZE!
)

(run-tests APP)
