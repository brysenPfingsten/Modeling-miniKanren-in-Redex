#lang racket

(require rackunit
         rackunit/text-ui
         racket/match
         racket/string
         json
         web-server/http/response-structs
         "../src/app.rkt"
         "../src/model-registry.rkt"
         "../src/model-surface-policy.rkt"
         "../src/sexpr-read.rkt"
         "../src/transpiler.rkt"
         "../src/zipper.rkt"
         "./test-http-helpers.rkt"
         "./variant-test-support.rkt"
         "./example-compat-tests.rkt")

(provide MODEL-EXAMPLE-MATRIX)

(define MATRIX-STEP-CAP 25)

(define PRIMARY-RAIL-MODELS
  '("l4-rail-lazy" "l4-rail-eager" "l3-dfs-lazy"))

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
        (define sexprs (read-all-sexprs (open-input-string src)))
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
               (hasheq 'status (if (final-config? cfg) 'value 'stuck)
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

(define (make-default-session)
  (define default-step-once (lookup-model-step-once default-model-id))
  (unless default-step-once
    (error 'MODEL-EXAMPLE-MATRIX
           (format "default model missing stepper: ~a" default-model-id)))
  (session (zipper '() #f '() 0)
           (make-stepper default-step-once)
           1))

(define (make-heavy-row model-id label result)
  (hasheq 'model model-id
          'label label
          'status (hash-ref result 'status)
          'steps (hash-ref result 'steps)
          'last-rule (hash-ref result 'last-rule)))

(define (collect-heavy-rows specs examples runner)
  (for*/list ([spec (in-list specs)]
              [(label src) (in-dict examples)])
    (define model-id (model-spec-id spec))
    (define result (runner model-id label src))
    (make-heavy-row model-id label result)))

(define (assert-heavy-rows rows
                           disallowed-statuses
                           #:forbid-nondeterministic? [forbid-nondeterministic? #f]
                           #:check-primary-rail? [check-primary-rail? #f]
                           #:context [context "heavy"])
  (when forbid-nondeterministic?
    (for ([r (in-list rows)])
      (check-false (eq? (hash-ref r 'status) 'nondeterministic)
                   (format "~a: unexpected nondeterminism for ~a / ~a (choices=~a)"
                           context
                           (hash-ref r 'model)
                           (hash-ref r 'label)
                           (hash-ref r 'last-rule)))))
  (for ([r (in-list rows)])
    (check-false (member (hash-ref r 'status) disallowed-statuses)
                 (format "~a: surfaced pair failed for ~a / ~a (status=~a last-rule=~a)"
                         context
                         (hash-ref r 'model)
                         (hash-ref r 'label)
                         (hash-ref r 'status)
                         (hash-ref r 'last-rule))))
  (when check-primary-rail?
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
                           (hash-ref row 'steps))))))

(define (run-heavy-row/api model-id label src)
  (define ses (make-default-session))
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (hasheq 'status 'init-error
                             'steps 0
                             'last-rule (exn-message e)))])
    (define init-resp (init! ses (make-post-init-request src #:model model-id) 'matrix-id))
    (check-equal? (response-code init-resp) 200
                  (format "init failed for ~a / ~a" model-id label))
    (check-equal? (session-model-id ses) model-id
                  (format "session model binding drifted for ~a / ~a"
                          model-id
                          label))
    (assert-step-payload-shape (string->jsexpr (response-body->string init-resp))
                               (format "~a / ~a init" model-id label))
    (run-api-steps! ses model-id label)))

(define/provide-test-suite MODEL-EXAMPLE-MATRIX
  (test-case "matrix lane: surfaced L3/L4 full coverage"
    (define examples (frontend-example-programs))
    (define heavy-rows
      (collect-heavy-rows surfaced-model-specs
                          examples
                          (lambda (model-id _label src)
                            (classify-pair model-id src #t))))
    (assert-heavy-rows heavy-rows '(incompatible)
                       #:forbid-nondeterministic? #t
                       #:check-primary-rail? #t
                       #:context "direct matrix")
    (displayln (format "[matrix-tests] heavy summary: ~s" (summarize heavy-rows))))

  (test-case "api-flow lane: surfaced L3/L4 full matrix"
    (define examples (frontend-example-programs))
    (define heavy-rows (collect-heavy-rows surfaced-model-specs examples run-heavy-row/api))
    (assert-heavy-rows heavy-rows '(incompatible init-error)
                       #:context "api matrix")
    (displayln (format "[matrix-tests] heavy api-flow summary: ~s" (summarize heavy-rows)))))

(module+ test
  (run-tests MODEL-EXAMPLE-MATRIX))
