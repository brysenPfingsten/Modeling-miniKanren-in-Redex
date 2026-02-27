#lang racket

(require redex
         redex/reduction-semantics
         rackunit)
(check-redundancy #t)

(require "../src/definitions.rkt"
         "../src/judgment-forms.rkt"
         "../src/transpiler.rkt")

(define (read-all port)
  (let ([expr (read port)])
    (if (eof-object? expr)
        '()
        (cons expr (read-all port)))))

(define (parse-src src)
  (parse-prog (read-all (open-input-string src))))

(module+ test
  (define-values (model-1 html-1)
    (parse-src "(run* (q) (== 'a 'a))"))

  (test-true "run*-only translation matches program non-terminal"
             (redex-match? L p model-1))
  (test-true "run*-only translation is closed"
             (judgment-holds (closed-program? ,model-1)))
  (test-true "translator returns tagged HTML payload" (string? html-1))

  (define-values (model-2 html-2)
    (parse-src
     "(defrel (same x y) (== x y))
(run* (q) (same q 'cat))"))

  (test-true "defrel+run* translation matches program non-terminal"
             (redex-match? L p model-2))
  (test-true "defrel+run* translation is closed"
             (judgment-holds (closed-program? ,model-2)))
  (test-true "defrel+run* returns tagged HTML payload" (string? html-2))

  (test-results))
