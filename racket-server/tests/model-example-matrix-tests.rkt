#lang racket

(require rackunit rackunit/text-ui redex/reduction-semantics json
         "../src/app.rkt" "../src/program-runner.rkt"
         (only-in "../src/transpiler.rkt" render-micro-source)
         "../src/sexpr-read.rkt"
         "../src/search-runtime.rkt"
         "../derivations/strict-search/matrix/full-source.rkt"
         "../derivations/strict-search/shared/wf.rkt"
         "test-http-helpers.rkt")

;; Three conjuncts and three alternatives make both association choices real.
;; Calls occur in both relation bodies and the query.
(define source
  "(defrel (same x y) (== x y))
   (defrel (choose q)
     (conde [(same q 'a)] [(same q 'b)] [(same q 'c)]))
   (run* (q)
     (same 'ready 'ready)
     (choose q)
     (=/= q 'a))")

(define (response-payload response)
  (string->jsexpr (response-body->string response)))

(define (check-payload response session)
  (define payload (response-payload response))
  (assert-step-payload-shape payload 'matrix-integration)
  (check-equal? (hash-ref payload 'executionStatus)
                (symbol->string (model-session-status session)))
  (check-equal? (hash-ref payload 'stepKind)
                (symbol->string (model-session-current-step-kind session)))
  (check-equal? (hash-ref payload 'answerCount)
                (length (model-session-current-answer-nodes session)))
  (check-equal? (string->jsexpr (hash-ref payload 'program))
                (model-session-current-picture session)))

(define (check-connected-trace api-session direct-session [fuel 300] [labels '()])
  (define configuration (model-session-current-config api-session))
  (check-equal? configuration (model-session-current-config direct-session))
  (check-true (wf-s-rel? configuration))
  (cond
    [(model-session-done? api-session) (values api-session (reverse labels))]
    [(zero? fuel) (error 'check-connected-trace "finite witness exhausted its step bound")]
    [else
     (define expected
       (match (model-session-status api-session)
         ['paused
          (match-define (list 'program definitions frontier) configuration)
          (list "advance" (list 'program definitions (list 'advance frontier)))]
         ['running
          (match-define (list successor)
            (apply-reduction-relation/tag-with-names strict-s-rel-red configuration))
          successor]
         [other (error 'check-connected-trace "unexpected status ~e" other)]))
     (define-values (response next-api) (step! api-session))
     (define next-direct (model-session-step direct-session))
     (check-payload response next-api)
     (check-equal? (list (model-session-current-step-name next-api)
                         (model-session-current-config next-api))
                   expected)
     (check-connected-trace next-api next-direct (sub1 fuel)
                            (cons (first expected) labels))]))

(define/provide-test-suite MODEL-EXAMPLE-MATRIX
  (test-case "all twelve profiles connect GUI and library to exact named matrix reductions"
    (for* ([conjunction '("left" "right")]
           [disjunction '("left" "right")]
           [placement '("relbody" "relcall" "disj")])
      (define profile
        (hasheq 'conjAssoc conjunction 'disjAssoc disjunction 'delayPlacement placement))
      (with-check-info (['profile profile])
        (define-values (response api-session)
          (init! #f (make-post-init-request source
                    (hasheq 'text source 'sourceMode "mini" 'compileProfile profile))
                 'matrix-profile))
        (define direct-session (open-source source #:compile-profile profile))
        (check-payload response api-session)
        (define-values (final labels) (check-connected-trace api-session direct-session))
        (check-not-false (member "eval-call" labels))
        (check-not-false (member "eval-suspend" labels))
        (check-not-false (member "advance" labels))
        (check-not-false (member "advance-delay" labels))
        (check-not-false (member "commit-one" labels))
        ;; Expected for this symmetric finite witness only; profiles are not
        ;; asserted to agree on arbitrary work order, answers, or delay rounds.
        (check-equal? (sort (model-session-current-host-answers final) symbol<?) '(b c))
        (define micro (render-micro-source (read-all-sexprs (open-input-string source))
                                           #:compile-profile profile))
        (define-values (micro-response micro-session)
          (init! #f (make-post-init-request micro
                     (hasheq 'text micro 'sourceMode "micro")) 'matrix-micro))
        (check-payload micro-response micro-session)
        (define-values (micro-final _micro-labels)
          (check-connected-trace micro-session (open-source micro #:source-mode "micro")))
        (check-equal? (model-session-current-host-answers micro-final)
                      (model-session-current-host-answers final))))))

(module+ test (run-tests MODEL-EXAMPLE-MATRIX))
