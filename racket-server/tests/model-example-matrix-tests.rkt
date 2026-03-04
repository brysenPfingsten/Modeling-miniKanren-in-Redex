#lang racket

(require rackunit
         rackunit/text-ui
         racket/match
         racket/string
         "../src/model-registry.rkt"
         "../src/transpiler.rkt"
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

(define (final-config? cfg)
  (match cfg
    [`(,_ ,_ (empty-tree)) #t]
    [_ #f]))

(define (step1-name+cfg succ)
  (match succ
    [(list name cfg) (values name cfg)]
    [_ (values "<unknown>" succ)]))

(define (domain-error? e)
  (and (exn:fail? e)
       (regexp-match? #px"not in domain" (exn-message e))))

(define (classify-pair model-id src)
  (define maybe-step-once (lookup-model-step-once model-id))
  (unless maybe-step-once
    (error 'classify-pair (format "unknown model: ~a" model-id)))

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
         (hasheq 'status (if (final-config? cfg) 'value 'stuck)
                 'steps steps
                 'last-rule last-rule)]
        [(> (length next*) 1)
         (hasheq 'status 'nondeterministic
                 'steps steps
                 'last-rule last-rule)]
        [(>= steps MATRIX-STEP-CAP)
         (hasheq 'status 'cap
                 'steps steps
                 'last-rule last-rule)]
        [else
         (define-values (nm cfg1) (step1-name+cfg (first next*)))
         (loop cfg1 (add1 steps) nm)]))))

(define (summarize rows)
  (for/fold ([h (hash)])
            ([r (in-list rows)])
    (define k (list (hash-ref r 'model) (hash-ref r 'status)))
    (hash-set h k (add1 (hash-ref h k 0)))))

(define/provide-test-suite MODEL-EXAMPLE-MATRIX
  (test-case "model/example step matrix (25-step) stays deterministic and avoids known stuck regressions"
    (define examples (frontend-example-programs))
    (define rows
      (for*/list ([spec (in-list all-model-specs)]
                  [ex (in-list examples)])
        (match-define (cons label src) ex)
        (define result (classify-pair (model-spec-id spec) src))
        (hasheq 'model (model-spec-id spec)
                'label label
                'status (hash-ref result 'status)
                'steps (hash-ref result 'steps)
                'last-rule (hash-ref result 'last-rule))))

    ;; Determinism guard.
    (for ([r (in-list rows)])
      (check-false (eq? (hash-ref r 'status) 'nondeterministic)
                   (format "unexpected nondeterminism for ~a / ~a"
                           (hash-ref r 'model)
                           (hash-ref r 'label))))

    ;; Compatibility guard: visible models should accept visible examples.
    (for ([r (in-list rows)])
      (check-false (eq? (hash-ref r 'status) 'incompatible)
                   (format "unexpected incompatible pair ~a / ~a"
                           (hash-ref r 'model)
                           (hash-ref r 'label))))

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

    ;; Bounded run query should always complete quickly in compatible models.
    (for ([r (in-list rows)]
          #:when (equal? (hash-ref r 'label) "call timing"))
      (check-equal? (hash-ref r 'status) 'value
                    (format "call timing should finish for ~a (got ~a)"
                            (hash-ref r 'model)
                            (hash-ref r 'status))))

    ;; Debug summary in test output.
    (displayln (format "[matrix-tests] 25-step summary: ~s" (summarize rows)))))

(module+ test
  (run-tests MODEL-EXAMPLE-MATRIX))
