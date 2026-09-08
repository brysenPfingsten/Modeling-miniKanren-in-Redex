#lang racket

(require racket/runtime-path
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (only-in "../derivations/matrix/full-source.rkt" StrictSRel)
         (only-in "../derivations/shared/wf.rkt" wf-s-rel?)
         "../src/sexpr-read.rkt"
         "../src/transpiler.rkt")

(provide EXAMPLE-COMPAT
         frontend-example-programs)

;; Source of truth lives in frontend; tests consume it directly.
(define-runtime-path FRONTEND-EXAMPLES-PATH
  "../../frontend/src/utils/example_programs.js")

(define TEMPLATE-DEF-RX
  #px"const\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*=\\s*`((?:\\\\`|[^`])*)`\\s*;?")

(define ARRAY-ENTRY-RX
  #px"\\{\\s*id:\\s*\"([^\"]+)\"\\s*,\\s*label:\\s*\"([^\"]+)\"\\s*,\\s*miniSource:\\s*([A-Za-z_][A-Za-z0-9_]*)")

(define (decode-template-literal s)
  ;; Frontend examples currently use escaped backticks inside template literals.
  (regexp-replace* #px"\\\\`" s "`"))

(define (extract-template-map js-src)
  (for/hash ([m (in-list (regexp-match* TEMPLATE-DEF-RX
                                        js-src
                                        #:match-select values))])
    (define var-name (second m))
    (define template-body (third m))
    (values var-name (decode-template-literal template-body))))

(define (extract-example-refs js-src)
  (for/list ([m (in-list (regexp-match* ARRAY-ENTRY-RX
                                        js-src
                                        #:match-select values))])
    (list (second m) (third m) (fourth m))))

(define (frontend-example-programs)
  (define js-src (file->string FRONTEND-EXAMPLES-PATH))
  (define templates (extract-template-map js-src))
  (for/list ([entry (in-list (extract-example-refs js-src))])
    (match-define (list _id label value-var) entry)
    (define maybe-src (hash-ref templates value-var #f))
    (unless maybe-src
      (error 'frontend-example-programs
             (format "example value ~a (label ~a) has no matching template definition"
                     value-var
                     label)))
    (cons label maybe-src)))

(define (render-src/micro src)
  (render-micro-source (read-all-sexprs (open-input-string src))))

(define (assert-example-compat! name src [mode "mini"])
  (define-values (compiled-config html query)
    (parse-prog/canonical (read-all-sexprs (open-input-string src))
                          #:source-mode mode))
  (check-true (string? html) (format "~a should produce html-guid source" name))
  (check-true (redex-match? StrictSRel p compiled-config)
              (format "~a (~a) should compile into full strict S syntax" name mode))
  (check-true (wf-s-rel? compiled-config)
              (format "~a (~a) should satisfy full strict S well-formedness" name mode))
  (check-true (query-info? query))
  (check-equal? (query-info-variables query)
                (for/list ([index (in-range (length (query-info-names query)))])
                  (string->symbol (format "u:~a" index))))
  (match-define `(program ,_ (commit (eval (Owners) (∃ ,binders ,_ ,tag) ,_)))
    compiled-config)
  (check-equal? (length binders) (length (query-info-names query)))
  (check-equal? tag (query-info-tag query))
  (check-true (or (not (query-info-limit query))
                  (exact-nonnegative-integer? (query-info-limit query)))))

(define/provide-test-suite EXAMPLE-COMPAT
  (test-case "frontend examples compile to full strict S with explicit query metadata"
    (define examples (frontend-example-programs))
    (check-true (pair? examples)
                "frontend/src/utils/example_programs.js did not yield runnable examples")
    (for ([pr (in-list examples)])
      (match-define (cons label src) pr)
      (assert-example-compat! label src)))

  (test-case "frontend examples render to micro and compile to full strict S"
    (for ([pr (in-list (frontend-example-programs))])
      (match-define (cons label src) pr)
      (define micro-src (render-src/micro src))
      (assert-example-compat! label micro-src "micro"))))

(module+ test
  (run-tests EXAMPLE-COMPAT))
