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
         "../src/capability-analysis.rkt"
         "../src/model-registry.rkt"
         "../src/transpiler.rkt"
         "../src/zipper.rkt"
         "./variant-test-support.rkt"
         "./example-compat-tests.rkt")

(provide MODEL-EXAMPLE-MATRIX)

(define MATRIX-STEP-CAP 25)

(define PRIMARY-RAIL-MODELS
  '("mk-l4-rail-lazy" "mk-l4-rail-eager" "mk-l3-dfs-lazy"))

(define (read-all port)
  (let ([expr (read port)])
    (if (eof-object? expr)
        '()
        (cons expr (read-all port)))))

(define (step1-name+cfg succ)
  (match succ
    [(list name cfg) (values name cfg)]
    [_ (values "<unknown>" succ)]))

(define (domain-error? e)
  (and (exn:fail? e)
       (regexp-match? #px"not in domain" (exn-message e))))

(define (classify-pair model-id src should-compat?)
  (define maybe-step-once (lookup-model-step-once model-id))
  (unless maybe-step-once
    (error 'classify-pair (format "unknown model: ~a" model-id)))

  (if (not should-compat?)
      (hasheq 'status 'incompatible
              'steps 0
              'last-rule "")
      (let ()
        (define sexprs (read-all (open-input-string src)))
        (define-values (cfg0 _html) (parse-prog/canonical sexprs))
        (with-handlers ([domain-error?
                         (lambda (_e)
                           (hasheq 'status 'incompatible
                                   'steps 0
                                   'last-rule ""))])
          (let loop ([cfg cfg0] [steps 0] [last-rule ""])
            (define next* (maybe-step-once cfg))
            (cond
              [(null? next*)
               (hasheq 'status (if (trace-stop-config? cfg) 'value 'stuck)
                       'steps steps
                       'last-rule last-rule)]
              [(> (length next*) 1)
               (define rule-names
                 (for/list ([succ (in-list next*)])
                   (match succ
                     [(list name _cfg) (format "~a" name)]
                     [_ "<unknown>"])))
               (hasheq 'status 'nondeterministic
                       'steps steps
                       'last-rule (string-join rule-names " | "))]
              [(>= steps MATRIX-STEP-CAP)
               (hasheq 'status 'cap
                       'steps steps
                       'last-rule last-rule)]
              [else
               (define-values (nm cfg1) (step1-name+cfg (first next*)))
               (loop cfg1 (add1 steps) nm)]))))))

(define (summarize rows)
  (for/fold ([h (hash)])
            ([r (in-list rows)])
    (define k (list (hash-ref r 'model) (hash-ref r 'status)))
    (hash-set h k (add1 (hash-ref h k 0)))))

(define (response-body->string response)
  (define out (open-output-string))
  ((response-output response) out)
  (get-output-string out))

(define (make-post-request endpoint payload)
  (make-request
   #"POST"
   (make-url #f #f #f #f #t
             (list (make-path/param "post" empty)
                   (make-path/param endpoint empty))
             empty
             #f)
   (list (make-header #"content-type" #"application/json"))
   (delay '())
   (string->bytes/utf-8 (jsexpr->string payload))
   "127.0.0.1"
   5000
   "127.0.0.1"))

(define (make-post-analyze-request src)
  (make-post-request "analyze" (hasheq 'text src)))

(define (make-post-model-request model-id)
  (make-post-request "model" (hasheq 'model model-id)))

(define (make-post-init-request src)
  (make-post-request "init" (hasheq 'text src)))

(define (nonempty-string? v)
  (and (string? v)
       (positive? (string-length (string-trim v)))))

(define (assert-step-payload-shape payload where)
  (check-true (hash? payload) (format "~a: payload must be json object" where))
  (check-true (exact-nonnegative-integer? (hash-ref payload 'step -1))
              (format "~a: missing/non-integer step" where))
  (check-true (nonempty-string? (hash-ref payload 'stepName #f))
              (format "~a: missing/non-string stepName" where))
  (define program-json (hash-ref payload 'program #f))
  (check-true (string? program-json)
              (format "~a: missing/non-string program field" where))
  (define tree (string->jsexpr program-json))
  (check-true (hash? tree)
              (format "~a: program is not a json object" where))
  (define root-name (hash-ref tree 'name #f))
  (check-true (nonempty-string? root-name)
              (format "~a: tree root missing name" where))
  (check-false (equal? root-name "Unknown")
               (format "~a: tree root should not be Unknown" where)))

(define (run-api-steps! ses model-id label)
  (let loop ([i 0] [last-rule ""])
    (if (>= i MATRIX-STEP-CAP)
        (hasheq 'status 'cap
                'steps i
                'last-rule last-rule)
        (let* ([step-resp (step! ses)]
               [step-body (response-body->string step-resp)])
          (if (string=? step-body "null")
              (hasheq 'status 'done
                      'steps i
                      'last-rule last-rule)
              (let ([payload (string->jsexpr step-body)])
                (assert-step-payload-shape payload
                                           (format "~a / ~a step ~a"
                                                   model-id label i))
                (loop (add1 i) (hash-ref payload 'stepName ""))))))))

(define/provide-test-suite MODEL-EXAMPLE-MATRIX
  (test-case "model/example step matrix (25-step) stays deterministic and avoids known stuck regressions"
    (define examples (frontend-example-programs))
    (define rows
      (for*/list ([spec (in-list all-model-specs)]
                  [ex (in-list examples)])
        (match-define (cons label src) ex)
        (define reqs (hash-ref (analyze-source-capabilities src) 'requirements))
        (define should-compat?
          (member (model-spec-id spec)
                  (compatible-model-ids reqs all-model-specs)))
        (define result
          (classify-pair (model-spec-id spec) src should-compat?))
        (hasheq 'model (model-spec-id spec)
                'label label
                'should-compat? should-compat?
                'status (hash-ref result 'status)
                'steps (hash-ref result 'steps)
                'last-rule (hash-ref result 'last-rule))))

    ;; Determinism guard.
    (for ([r (in-list rows)])
      (check-false (eq? (hash-ref r 'status) 'nondeterministic)
                   (format "unexpected nondeterminism for ~a / ~a (choices=~a)"
                           (hash-ref r 'model)
                           (hash-ref r 'label)
                           (hash-ref r 'last-rule))))

    ;; Compatibility guard: compatible pairs should not be marked incompatible.
    (for ([r (in-list rows)])
      (when (hash-ref r 'should-compat? #f)
        (check-false (eq? (hash-ref r 'status) 'incompatible)
                     (format "unexpected incompatible pair ~a / ~a"
                             (hash-ref r 'model)
                             (hash-ref r 'label)))))

    ;; Incompatibility guard: incompatible pairs should be rejected early.
    (for ([r (in-list rows)])
      (when (not (hash-ref r 'should-compat? #t))
        (check-equal? (hash-ref r 'status) 'incompatible
                      (format "expected incompatible pair for ~a / ~a, got ~a"
                              (hash-ref r 'model)
                              (hash-ref r 'label)
                              (hash-ref r 'status)))))

    ;; Regression guard: fives/fours should not get stuck in rail-family semantics.
    (for ([mid (in-list PRIMARY-RAIL-MODELS)])
      (define row
        (for/first ([r (in-list rows)]
                    #:when (and (equal? (hash-ref r 'model) mid)
                                (equal? (hash-ref r 'label) "fives/fours")))
          r))
      (check-not-false row (format "missing matrix row for ~a / fives/fours" mid))
      (check-false (eq? (hash-ref row 'status) 'stuck)
                   (format "stuck regression for ~a / fives/fours (last-rule=~a, steps=~a)"
                           mid
                           (hash-ref row 'last-rule)
                           (hash-ref row 'steps))))

    ;; Core L0-safe baseline should always complete quickly in compatible models.
    (for ([r (in-list rows)]
          #:when (equal? (hash-ref r 'label) "core/fresh+conj+unify"))
      (check-equal? (hash-ref r 'status) 'value
                    (format "core/fresh+conj+unify should finish for ~a (got ~a)"
                            (hash-ref r 'model)
                            (hash-ref r 'status))))

    ;; Debug summary in test output.
    (displayln (format "[matrix-tests] 25-step summary: ~s" (summarize rows))))

  (test-case "api flow matrix (analyze->switch->init->step) validates compatibility and payload shape"
    (define examples (frontend-example-programs))
    (define rows
      (for*/list ([spec (in-list all-model-specs)]
                  [ex (in-list examples)])
        (match-define (cons label src) ex)
        (define model-id (model-spec-id spec))

        (define analyze-resp (analyze! #f (make-post-analyze-request src)))
        (check-equal? (response-code analyze-resp) 200
                      (format "analyze failed for ~a" label))
        (define analyze-body (string->jsexpr (response-body->string analyze-resp)))
        (check-true (hash-ref analyze-body 'validSyntax #f)
                    (format "analyze returned invalid syntax for ~a" label))

        (define compatible-ids (hash-ref analyze-body 'compatibleModelIds '()))
        (define should-compat? (member model-id compatible-ids))

        (define default-step-once (lookup-model-step-once default-model-id))
        (unless default-step-once
          (error 'MODEL-EXAMPLE-MATRIX
                 (format "default model missing stepper: ~a" default-model-id)))
        (define ses
          (session (zipper '() #f '() 0)
                   (make-stepper default-step-once)
                   1))

        (define model-resp (switch-model! ses (make-post-model-request model-id) 'matrix-id))
        (check-equal? (response-code model-resp) 200
                      (format "switch-model failed for ~a" model-id))

        (define row
          (if should-compat?
              (with-handlers ([exn:fail?
                               (lambda (e)
                                 (hasheq 'status 'init-error
                                         'steps 0
                                         'last-rule (exn-message e)))])
                (define init-resp (init! ses (make-post-init-request src) 'matrix-id))
                (check-equal? (response-code init-resp) 200
                              (format "init failed for compatible pair ~a / ~a"
                                      model-id
                                      label))
                (assert-step-payload-shape (string->jsexpr (response-body->string init-resp))
                                           (format "~a / ~a init" model-id label))
                (run-api-steps! ses model-id label))
              (let ([failed?
                     (with-handlers ([exn:fail? (lambda (_e) #t)])
                       (init! ses (make-post-init-request src) 'matrix-id)
                       #f)])
                (when (not failed?)
                  (fail-check
                   (format "expected incompatible init rejection for ~a / ~a"
                           model-id
                           label)))
                (hasheq 'status 'incompatible
                        'steps 0
                        'last-rule ""))))

        (hasheq 'model model-id
                'label label
                'should-compat? should-compat?
                'status (hash-ref row 'status)
                'steps (hash-ref row 'steps)
                'last-rule (hash-ref row 'last-rule))))

    (for ([r (in-list rows)])
      (when (hash-ref r 'should-compat? #f)
        (check-false (member (hash-ref r 'status) '(incompatible init-error))
                     (format "compatible pair failed API flow: ~a / ~a (status=~a last-rule=~a)"
                             (hash-ref r 'model)
                             (hash-ref r 'label)
                             (hash-ref r 'status)
                             (hash-ref r 'last-rule)))))

    (for ([r (in-list rows)])
      (when (not (hash-ref r 'should-compat? #t))
        (check-equal? (hash-ref r 'status) 'incompatible
                      (format "incompatible pair should reject init: ~a / ~a (status=~a)"
                              (hash-ref r 'model)
                              (hash-ref r 'label)
                              (hash-ref r 'status)))))

    (displayln (format "[matrix-tests] api-flow summary: ~s" (summarize rows)))))

(module+ test
  (run-tests MODEL-EXAMPLE-MATRIX))
