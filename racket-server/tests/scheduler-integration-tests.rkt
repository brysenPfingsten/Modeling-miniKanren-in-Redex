#lang racket

(require rackunit rackunit/text-ui json redex/reduction-semantics
         "../src/app.rkt" "../src/program-runner.rkt"
         "../src/search-runtime.rkt" "../src/sexpr-read.rkt"
         (only-in "../src/transpiler.rkt" parse-prog/canonical query-info)
         (prefix-in dfs: "../src/search-lattice/reduction-relations/search-dfs-relcall-red.rkt")
         (prefix-in flip: "../src/search-lattice/reduction-relations/search-flip-relcall-red.rkt")
         (prefix-in rail: "../src/search-lattice/reduction-relations/rail-relcall-red.rkt")
         (prefix-in lang: "../src/search-lattice/languages/rail-relcall-lang.rkt")
         (prefix-in wf: "../src/search-lattice/wf/all.rkt")
         (prefix-in strict: "../derivations/strict-search/matrix/full-source.rkt")
         (only-in "../derivations/strict-search/shared/wf.rkt" wf-s-rel?)
         "../derivations/strict-search/test-support/witnesses.rkt"
         "test-http-helpers.rkt")

(provide SCHEDULER-INTEGRATION)

(struct edge (name before after) #:transparent)

(define (native-relation strategy)
  (match strategy
    [(strict-search) strict:strict-s-rel-red]
    [(search-strategy "dfs") dfs:search-dfs-relcall-red]
    [(search-strategy "flip") flip:search-flip-relcall-red]
    [(search-strategy "rail") rail:rail-relcall-red]))

(define (native-wf? strategy configuration)
  (match strategy
    [(strict-search) (wf-s-rel? configuration)]
    [(search-strategy "rail")
     (judgment-holds (wf:wf-config/rail-relcall? ,configuration))]
    [(search-strategy (or "dfs" "flip"))
     (judgment-holds (wf:wf-config/search-relcall? ,configuration))]))

(define (contains-constructor? datum constructor)
  (match datum
    [(cons head tail)
     (or (eq? head constructor)
         (contains-constructor? head constructor)
         (contains-constructor? tail constructor))]
    [_ #f]))

(define (picture-nodes picture)
  (cons picture (append-map picture-nodes (hash-ref picture 'children '()))))

(define (configuration-body configuration)
  (match configuration
    [`(program ,_ ,body) body]
    [`(,_ ,body) body]))

;; Count only the public spine, independently of the runtime's extraction.
(define (answer-states term)
  (match term
    [`(Emit ,_ (Answer ,_ ,state) ,rest) (cons state (answer-states rest))]
    [`(Last ,_ (Answer ,_ ,state)) (list state)]
    [`(Forced ,_ ,rest) (answer-states rest)]
    [`(,(or 'advance 'collect) ,rest) (answer-states rest)]
    [_ '()]))

(define (check-payload response session)
  (define payload (string->jsexpr (response-body->string response)))
  (check-equal? (hash-ref payload 'executionStatus)
                (symbol->string (model-session-status session)))
  (check-equal? (hash-ref payload 'stepKind)
                (symbol->string (model-session-current-step-kind session)))
  (check-equal? (hash-ref payload 'answerCount)
                (length (model-session-current-answer-nodes session)))
  (check-equal? (string->jsexpr (hash-ref payload 'program))
                (model-session-current-picture session)))

;; Each session edge is checked against exactly one native named contraction.
;; Strict public invocation is the one separate, explicitly prescribed step.
(define (check-trace api library [fuel 300] [reversed '()])
  (define configuration (model-session-current-config api))
  (define strategy (model-session-search-strategy api))
  (check-equal? configuration (model-session-current-config library))
  (check-true (native-wf? strategy configuration))
  (when (member strategy (list (search-strategy "dfs") (search-strategy "flip")))
    (check-false (contains-constructor? configuration 'DisjR)))
  (define answer-count (length (answer-states (configuration-body configuration))))
  (check-equal? (length (model-session-current-answer-nodes api)) answer-count)
  (check-equal? (count (lambda (node) (equal? (hash-ref node 'renderRole #f) "answer-node"))
                       (picture-nodes (model-session-current-picture api)))
                answer-count)
  (match (model-session-status api)
    ['complete
     (check-equal? (apply-reduction-relation (native-relation strategy) configuration) '())
     (values api (reverse reversed))]
    [(and status (or 'running 'paused))
     (when (zero? fuel) (error 'check-trace "finite witness exceeded its bound"))
     (define expected
       (match* (strategy status)
         [((strict-search) 'paused)
          (match-define `(program ,definitions ,frontier) configuration)
          (check-equal? (apply-reduction-relation strict:strict-s-rel-red configuration) '())
          (list "advance" `(program ,definitions (advance ,frontier)))]
         [(_ _)
          (match-define (list successor)
            (apply-reduction-relation/tag-with-names (native-relation strategy) configuration))
          successor]))
     (define-values (response next-api) (step! api))
     (define next-library (model-session-step library))
     (check-equal? (list (model-session-current-step-name next-api)
                         (model-session-current-config next-api)) expected)
     (check-equal? (model-session-current-step-kind next-api)
                   (if (eq? status 'paused) 'public-operation 'reduction))
     (when (and (search-strategy? strategy) (eq? status 'paused))
       (check-equal? (first expected) "force-delay"))
     (check-payload response next-api)
     (check-trace next-api next-library (sub1 fuel)
                  (cons (edge (first expected) configuration (second expected)) reversed))]
    [other (error 'check-trace "unexpected status ~e" other)]))

(define empty-state '(state () () () (label "initial")))
(define empty-query (query-info '() '() '(label "query") #f))
(define (open-goal strategy goal [owners '(Owners)] [state empty-state])
  (open-compiled
   (match strategy
     [(strict-search) `(program () (commit (eval ,owners ,goal ,state)))]
     [(search-strategy _) `(() (More (Work ,owners ,goal ,state)))])
   empty-query strategy))

(define old-active
  (term-match/single lang:rail-relcall-lang
    [(Γ (in-hole WorkFocus (Work owners g σ))) (term g)]))
(define strict-active
  (term-match/single strict:StrictSRel
    [(in-hole C (eval owners a σ)) (term a)]))
(define (state-label state)
  (match state [`(state ,_ ,_ (,equation ,_ ...) ,_) (second (last equation))]))
(define (meaningful-events strategy edges)
  (append-map
   (lambda (transition)
     (match-define (edge name before after) transition)
     (append
      (match name
        ["advance" '(public-advance)]
        ["force-delay" (list (if (strict-search? strategy) 'internal-force 'public-force))]
        [(or "eval-atom" "unify-success")
         (list (list 'work (second (last ((if (strict-search? strategy) strict-active old-active) before)))))]
        [_ '()])
      (for/list ([state (in-list (drop (answer-states (configuration-body after))
                                      (length (answer-states (configuration-body before)))))])
        (list 'commit (state-label state)))))
   edges))

(define (frontier-shape frontier)
  (match frontier
    [`(Forced ,_ ,rest) `(Forced ,(frontier-shape rest))]
    [`(Emit ,_ (Answer ,_ ,state) ,rest) `(Emit ,(state-label state) ,(frontier-shape rest))]
    [`(Last ,_ (Answer ,_ ,state)) `(Last ,(state-label state))]
    [`(More ,_) 'More]
    [`(Done ,_) 'Done]))

(define/provide-test-suite SCHEDULER-INTEGRATION
  (test-case "all twelve profiles initialize and step all three native scheduler carriers"
    (define source
      "(defrel (same x y) (== x y))
       (defrel (choose q) (conde [(same q 'a)] [(same q 'b)] [(same q 'c)]))
       (run* (q) (same 'ready 'ready) (choose q) (=/= q 'a))")
    (check-equal? all-surfaced-search-strategies
                  (map search-strategy '("dfs" "flip" "rail")))
    (for* ([conjunction '("left" "right")]
           [disjunction '("left" "right")]
           [placement '("relbody" "relcall" "disj")]
           [strategy (in-list all-surfaced-search-strategies)])
      (define profile (hasheq 'conjAssoc conjunction 'disjAssoc disjunction 'delayPlacement placement))
      (with-check-info (['profile profile] ['strategy strategy])
        (define-values (compiled _html query)
          (parse-prog/canonical (read-all-sexprs (open-input-string source))
                                #:compile-profile profile #:search-strategy strategy))
        (define-values (response api)
          (init! #f (make-post-init-request source
                     (hasheq 'text source 'sourceMode "mini" 'compileProfile profile)
                     #:strategy strategy) 'scheduler-profile))
        (define library (open-source source #:compile-profile profile #:search-strategy strategy))
        (check-match compiled `(,_ (More (Work (Owners) ,_ ,_))))
        (check-equal? compiled (model-session-current-config api))
        (check-equal? query (model-session-query api))
        (check-payload response api)
        (define-values (final edges) (check-trace api library))
        (check-not-false (member "force-delay" (map edge-name edges)))
        (check-false (member "advance" (map edge-name edges)))
        (check-equal? (sort (model-session-current-host-answers final) symbol<?) '(b c)))))

  (test-case "nested rails preserve their own work order and public force boundaries"
    (define (atom name) `((sym ,name) =? (sym ,name) (label ,name)))
    (define goal
      `((suspend ,(atom "A") (label "delay-A"))
        ∨ (,(atom "B") ∨ (suspend ,(atom "C") (label "delay-C")) (label "inner"))
        (label "outer")))
    (for ([strategy (in-list (cons default-search-strategy all-surfaced-search-strategies))])
      (define initial (open-goal strategy goal))
      (define-values (final edges) (check-trace initial initial 80))
      (check-equal?
       (meaningful-events strategy edges)
       (match strategy
         [(strict-search)
          '((work "B") public-advance internal-force (work "A") (commit "B")
            public-advance internal-force (work "C") (commit "A") (commit "C"))]
         [(search-strategy "dfs")
          '(public-force (work "A") (commit "A") (work "B") (commit "B")
            public-force (work "C") (commit "C"))]
         [(search-strategy (or "flip" "rail"))
          '(public-force (work "B") (commit "B") public-force (work "A")
            (commit "A") (work "C") (commit "C"))]))
      (check-equal?
       (frontier-shape (configuration-body (model-session-current-config final)))
       (match strategy
         [(search-strategy "dfs") '(Forced (Emit "A" (Emit "B" (Forced (Last "C")))))]
         [_ '(Forced (Emit "B" (Forced (Emit "A" (Last "C")))))]))
      (when (equal? strategy (search-strategy "rail"))
        (check-true (ormap (lambda (transition) (contains-constructor? (edge-after transition) 'DisjR)) edges)))
      (check-equal?
       (for/list ([transition (in-list edges)]
                  #:when (equal? (edge-name transition)
                                  (if (strict-search? strategy) "advance" "force-delay")))
         (frontier-shape (configuration-body (edge-before transition))))
       (match strategy
         [(search-strategy "dfs") '(More (Forced (Emit "A" (Emit "B" More))))]
         [_ '(More (Forced (Emit "B" More)))]))
      ;; Equal final observations do not equate intermediate pending work.
      (define first-emission
        (edge-after (findf (lambda (transition)
                            (= 1 (length (answer-states (configuration-body (edge-after transition)))))) edges)))
      (match strategy
        [(strict-search) (check-true (contains-constructor? first-emission 'One))]
        [(search-strategy _) (check-true (contains-constructor? first-emission 'Work))])))

  (test-case "existing allocation witnesses retain native scope across scheduler forcing"
    (for* ([name '(unused-binder allocation-across-delay sparse-inherited-ancestry
                                answer-local-continuation delayed-sibling-capture)]
           [strategy (in-list all-surfaced-search-strategies)])
      (define example (findf (lambda (item) (eq? (witness-name item) name)) witnesses))
      (with-check-info (['witness name] ['strategy strategy])
        (define initial (open-goal strategy (witness-goal example)
                                   (witness-owners example) (witness-state example)))
        (define-values (final edges) (check-trace initial initial 120))
        (define scopes (map (lambda (node) (hash-ref node 'scope)) (model-session-current-answer-nodes final)))
        (check-equal? (sort (map length scopes) <)
                      (match name
                        [(or 'unused-binder 'allocation-across-delay) '(2)]
                        ['sparse-inherited-ancestry '(4)]
                        [(or 'answer-local-continuation 'delayed-sibling-capture) '(2 3)]))
        (when (eq? name 'sparse-inherited-ancestry)
          (check-equal? scopes '((9 2 7 0))))
        (when (eq? name 'allocation-across-delay)
          (define labels (map edge-name edges))
          (check-true (< (index-of labels "force-delay")
                         (last (indexes-of labels "allocate-fresh"))))))))

  (test-case "pending conjunction candidates never enter the committed answer spine"
    (define goal
      '((((nat 0) =? (nat 0) (label "left")) ∨ ((nat 1) =? (nat 1) (label "right")) (label "choice"))
        ∧ (fail (label "pending")) (label "bind")))
    (for ([strategy (in-list all-surfaced-search-strategies)])
      (define initial (open-goal strategy goal))
      (define-values (final edges) (check-trace initial initial 80))
      (check-equal? (model-session-current-answer-nodes final) '())
      (for ([transition (in-list edges)])
        (check-equal? (answer-states (configuration-body (edge-after transition))) '()))
      (check-true (ormap (lambda (transition) (contains-constructor? (edge-after transition) 'Returned)) edges)))))

(module+ test
  (define failures (run-tests SCHEDULER-INTEGRATION))
  (unless (zero? failures)
    (error 'SCHEDULER-INTEGRATION "~a test case(s) failed" failures)))
