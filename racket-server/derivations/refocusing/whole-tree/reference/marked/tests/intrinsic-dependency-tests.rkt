#lang racket

(require racket/list
         racket/path
         racket/runtime-path
         rackunit
         rackunit/text-ui)

(provide intrinsic-dependency-tests)

(define-runtime-path tests-root ".")
(define-runtime-path pk-root "..")
(define-runtime-path concrete-root "../../../../whole-tree-redex-column")
(define-runtime-path pilot-root "../../../../whole-tree-pipeline-pilot")
(define-runtime-path production-root "../../../../../../src/search-lattice")

(define intrinsic-test-paths
  (for/list ([name (in-list '("front-half-tests.rkt"
                              "grammar-litmus-tests.rkt"
                              "middle-tests.rkt"
                              "back-half-tests.rkt"
                              "intrinsic-dependency-tests.rkt"
                              "run.rkt"))])
    (build-path tests-root name)))

(define (module-datum path)
  (call-with-input-file
   path
   (lambda (input)
     (parameterize ([read-accept-reader #t])
       (syntax->datum (read-syntax path input))))))

(define (require-path-strings datum)
  (match datum
    [`(require . ,specifications)
     (filter (lambda (value)
               (and (string? value)
                    (regexp-match? #rx"[.]rkt$" value)))
             (flatten specifications))]
    [(? pair?)
     (append-map require-path-strings datum)]
    [_ '()]))

(define (path-within? child parent)
  (define child-parts (explode-path (simple-form-path child)))
  (define parent-parts (explode-path (simple-form-path parent)))
  (and (<= (length parent-parts) (length child-parts))
       (equal? parent-parts
               (take child-parts (length parent-parts)))))

(define (forbidden-reason resolved)
  (cond
    [(and (path-within? resolved concrete-root)
          (not (path-within? resolved pk-root)))
     'concrete-column]
    [(path-within? resolved pilot-root)
     'pipeline-pilot]
    [(path-within? resolved production-root)
     'production-control]
    [else #f]))

(define (forbidden-imports path)
  (for*/list
      ([import (in-list (require-path-strings (module-datum path)))]
       [resolved
        (in-value
         (simple-form-path
          (build-path (path-only path) import)))]
       [reason (in-value (forbidden-reason resolved))]
       #:when reason)
    (list (path->string (file-name-from-path path))
          import
          reason)))

(define intrinsic-dependency-tests
  (test-suite
   "whole-tree P[K] intrinsic dependency boundary"
   (test-case
    "intrinsic tests do not import concrete, pilot, or production control modules"
    (check-equal?
     (append-map forbidden-imports intrinsic-test-paths)
     '()))))

(module+ test
  (run-tests intrinsic-dependency-tests))
