#lang racket

(require json rackunit rackunit/text-ui web-server/http/response-structs
         "../src/app.rkt" "../src/program-runner.rkt" "../src/search-runtime.rkt"
         "./example-compat-tests.rkt" "./test-http-helpers.rkt")

(provide CONFIDENCE-GATES)

(define (example-source label)
  (match (assoc label (frontend-example-programs))
    [(cons _ source) source]
    [_ (error 'example-source "missing frontend example: ~a" label)]))

(define (profile delay)
  (hasheq 'conjAssoc "left" 'disjAssoc "right" 'delayPlacement delay))

(define (trace session remaining [reversed '()])
  (check-not-equal? (model-session-status session) 'stuck)
  (define accumulated (cons session reversed))
  (cond
    [(or (zero? remaining) (model-session-done? session)) (reverse accumulated)]
    [else (trace (model-session-step session) (sub1 remaining) accumulated)]))

(define (check-payload response session context)
  (check-equal? (response-code response) 200 context)
  (define payload (string->jsexpr (response-body->string response)))
  (assert-step-payload-shape payload context)
  (check-equal? (hash-ref payload 'executionStatus) (symbol->string (model-session-status session)) context)
  (check-equal? (hash-ref payload 'stepKind) (symbol->string (model-session-current-step-kind session)) context)
  (check-equal? (hash-ref payload 'answerCount) (length (model-session-current-answer-nodes session)) context)
  (check-equal? (string->jsexpr (hash-ref payload 'program)) (model-session-current-picture session) context))

(define (check-payload-trace response session remaining context)
  (check-payload response session context)
  (unless (or (zero? remaining) (model-session-done? session))
    (define-values (next-response next) (step! session))
    (check-payload-trace next-response next (sub1 remaining) context)))

(define/provide-test-suite CONFIDENCE-GATES
  (test-case "representative compiler delay placements execute named full-matrix source operations"
    (for ([delay '("relbody" "relcall" "disj")])
      (define sessions (trace (open-source (example-source "same") #:compile-profile (profile delay)) 80))
      (define labels (map model-session-current-step-name (rest sessions)))
      (check-not-false (member "eval-call" labels) delay)
      (check-not-false (member "eval-suspend" labels) delay)
      (check-not-false (member "advance-delay" labels) delay)
      (for ([before (in-list sessions)] [after (in-list (rest sessions))])
        (define label (model-session-current-step-name after))
        (define before-config (model-session-current-config before))
        (define after-config (model-session-current-config after))
        (check-true (and (string? label) (not (string=? (string-trim label) ""))))
        (match (model-session-current-step-kind after)
          ['public-operation
           (check-equal? label "advance")
           (check-equal? (configuration-status before-config) 'paused)
           (check-equal? after-config (advance-configuration before-config))]
          ['reduction
           (check-equal? ((lookup-search-step-once default-search-strategy) before-config)
                         (list (list label after-config)))]))))

  (test-case "recursive examples remain responsive through a bounded manual trace"
    (for ([label '("fives/fours" "appendoh 1")])
      (define sessions (trace (open-source (example-source label)) 30))
      (check-true (> (length sessions) 1) label)
      (check-not-false (member "eval-call" (map model-session-current-step-name sessions)) label)))

  (test-case "init and step payloads agree with their actual strict sessions across profiles"
    (for* ([label '("appendoh 1" "fives/fours" "same")]
           [delay '("relbody" "relcall" "disj")])
      (define source (example-source label))
      (define-values (response session)
        (init! #f
               (make-post-init-request source
                 (hasheq 'text source 'sourceMode "mini" 'compileProfile (profile delay)))
               'shape-id))
      (check-equal? (model-session-search-strategy session) default-search-strategy)
      (check-payload-trace response session 25 (format "~a / ~a" label delay)))))

(module+ test (run-tests CONFIDENCE-GATES))
