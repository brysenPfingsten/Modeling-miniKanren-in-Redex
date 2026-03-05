#lang racket

(require rackunit
         rackunit/text-ui
         racket/match
         racket/string
         json
         web-server/http/response-structs
         web-server/http/request-structs
         net/url-structs
         "../src/app.rkt"
         "../src/zipper.rkt"
         "../src/transpiler.rkt"
         "../src/model-registry.rkt"
         "./example-compat-tests.rkt")

(provide CONFIDENCE-GATES)

(define TRACE-STEP-CAP 30)

(define (read-all port)
  (let ([expr (read port)])
    (if (eof-object? expr)
        '()
        (cons expr (read-all port)))))

(define (example-src label)
  (for/first ([pr (in-list (frontend-example-programs))]
              #:when (equal? (car pr) label))
    (cdr pr)))

(define (final-config? cfg)
  (match cfg
    [`(,_ ,_ (empty-tree)) #t]
    [_ #f]))

(define (trace-steps model-id label)
  (define src (example-src label))
  (unless src
    (error 'trace-steps (format "missing example label: ~a" label)))
  (define-values (cfg0 _html)
    (parse-prog/canonical (read-all (open-input-string src))))
  (define step-once (lookup-model-step-once model-id))
  (unless step-once
    (error 'trace-steps (format "unknown model id: ~a" model-id)))
  (let loop ([cfg cfg0] [i 0] [acc '()])
    (define next* (step-once cfg))
    (cond
      [(null? next*)
       (values (reverse acc) (if (final-config? cfg) 'value 'stuck))]
      [(>= i TRACE-STEP-CAP)
       (values (reverse acc) 'cap)]
      [else
       (match-define (list nm cfg1) (first next*))
       (loop cfg1 (add1 i) (cons nm acc))])))

(define (named-step? nm)
  (and (string? nm)
       (> (string-length (string-trim nm)) 0)))

(define GOLDEN-PREFIXES
  (list
   (list "mk-l0-core"
         "core/fresh+conj+unify"
         '("Substitute Fresh Variables"
           "Substitute Fresh Variables"
           "Distribute State Over Conjunction"
           "Distribute State Over Conjunction"
           "Distribute State Over Conjunction"
           "Unification Succeeds"
           "Bring Success State To Second Conjunct"
           "Unification Succeeds"))
   (list "mk-l4-rail-lazy"
         "appendoh 1"
         '("core/fresh-substitute"
           "call/lazy-suspend-call"
           "call/lazy-invoke-delay"
           "call/lazy-expand-on-resume"
           "disj/goal-to-tree"
           "core/conj-distribute-state"
           "core/unify-fail"
           "core/conj-prune-fail"
           "disj/skip-left-fail"
           "core/fresh-substitute"))
   (list "mk-l4-rail-lazy"
         "fives/fours"
         '("core/fresh-substitute"
           "disj/goal-to-tree"
           "call/lazy-suspend-call"
           "rail/enter-right"
           "rail/invoke-delay"
           "call/lazy-suspend-call"
           "rail/return-left"
           "rail/invoke-delay"
           "call/lazy-expand-on-resume"
           "disj/goal-to-tree"))
   (list "mk-l3-flip-lazy"
         "fives/fours"
         '("core/fresh-substitute"
           "disj/goal-to-tree"
           "call/lazy-suspend-call"
           "flip/delay-swap-left"
           "flip/invoke-delay"
           "call/lazy-suspend-call"
           "flip/delay-swap-left"
           "flip/invoke-delay"
           "call/lazy-expand-on-resume"
           "disj/goal-to-tree"))
   (list "mk-l3-dfs-lazy"
         "same"
         '("core/fresh-substitute"
           "disj/goal-to-tree"
           "disj/goal-to-tree"
           "call/lazy-suspend-call"
           "dfs/delay-through-left"
           "dfs/delay-through-left"
           "dfs/invoke-delay"
           "call/lazy-expand-on-resume"
           "core/unify-success"
           "disj/collect-left-answer"))))

(define (get-response-body resp)
  (define out (open-output-string))
  ((response-output resp) out)
  (get-output-string out))

(define (make-post-model-request model-id)
  (make-request
   #"POST"
   (make-url #f #f #f #f #t
             (list (make-path/param "post" empty)
                   (make-path/param "model" empty))
             empty
             #f)
   (list (make-header #"content-type" #"application/json"))
   (delay '())
   (string->bytes/utf-8 (jsexpr->string (hasheq 'model model-id)))
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

(define (assert-step-payload-shape payload where)
  (check-true (hash? payload) (format "~a: payload must be json object" where))
  (check-true (exact-nonnegative-integer? (hash-ref payload 'step -1))
              (format "~a: missing/non-integer step" where))
  (check-true (named-step? (hash-ref payload 'stepName #f))
              (format "~a: missing/non-string stepName" where))
  (define program-json (hash-ref payload 'program #f))
  (check-true (string? program-json)
              (format "~a: missing/non-string program field" where))
  (define tree (string->jsexpr program-json))
  (check-true (hash? tree)
              (format "~a: program is not a json object" where))
  (check-true (named-step? (hash-ref tree 'name #f))
              (format "~a: tree root missing name" where)))

(define/provide-test-suite CONFIDENCE-GATES
  (test-case "golden trace prefixes stay stable and step names are always named"
    (for ([entry (in-list GOLDEN-PREFIXES)])
      (match-define (list model-id label expected-prefix) entry)
      (define-values (steps status) (trace-steps model-id label))
      (check-true (or (eq? status 'value) (eq? status 'cap))
                  (format "~a / ~a unexpectedly stuck" model-id label))
      (check-true (>= (length steps) (length expected-prefix))
                  (format "~a / ~a produced too few steps: got ~a, expected >= ~a"
                          model-id label (length steps) (length expected-prefix)))
      (for ([nm (in-list steps)]
            [idx (in-naturals 1)])
        (check-true (named-step? nm)
                    (format "~a / ~a has unnamed step at position ~a: ~v"
                            model-id label idx nm)))
      (check-equal? (take steps (length expected-prefix))
                    expected-prefix
                    (format "~a / ~a prefix drifted" model-id label))))

  (test-case "init/step payloads satisfy UI contract for canonical programs"
    (define pairs
      (list (list "mk-l4-rail-lazy" "appendoh 1")
            (list "mk-l3-flip-lazy" "fives/fours")
            (list "mk-l0-core" "core/fresh+conj+unify")))
    (for ([pr (in-list pairs)])
      (match-define (list model-id label) pr)
      (define src (example-src label))
      (define ses
        (session (zipper '() #f '() 0)
                 (make-stepper (lookup-model-step-once default-model-id))
                 1))
      (check-equal? (response-code (switch-model! ses (make-post-model-request model-id) 'shape-id))
                    200
                    (format "switch model failed for ~a" model-id))
      (define init-resp (init! ses (make-post-init-request src) 'shape-id))
      (check-equal? (response-code init-resp) 200
                    (format "init failed for ~a / ~a" model-id label))
      (assert-step-payload-shape (string->jsexpr (get-response-body init-resp))
                                 (format "~a / ~a init" model-id label))
      (define seen 0)
      (for ([i (in-range 25)])
        (define step-resp (step! ses))
        (define body (get-response-body step-resp))
        (unless (string=? body "null")
          (set! seen (add1 seen))
          (assert-step-payload-shape (string->jsexpr body)
                                     (format "~a / ~a step ~a" model-id label i))))
      (check-true (> seen 0)
                  (format "~a / ~a produced no non-null steps" model-id label)))))

(module+ test
  (run-tests CONFIDENCE-GATES))
