#lang racket

(require racket/file
         racket/list
         racket/path
         racket/runtime-path
         rackunit
         rackunit/text-ui)

(provide lean-intrinsic-dependency-tests)

(define-runtime-path lean-root "..")
(define-runtime-path tests-root ".")
(define-runtime-path mk-kernel-path "../mk/kernel.rkt")
(define-runtime-path approved-shared-kernel "../../../../shared/kernel.rkt")
(define-runtime-path approved-production-helper
  "../../../../../../src/search-lattice/wf/kernel-base.rkt")

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
    [(cons first rest)
     (append (require-path-strings first)
             (require-path-strings rest))]
    [_ '()]))

(define (path-within? child parent)
  (define child-parts (explode-path (simple-form-path child)))
  (define parent-parts (explode-path (simple-form-path parent)))
  (and (<= (length parent-parts) (length child-parts))
       (equal? parent-parts
               (take child-parts (length parent-parts)))))

(define (same-path? left right)
  (equal? (simple-form-path left) (simple-form-path right)))

(define semantic-module-paths
  (sort
   (for/list ([path (in-directory lean-root)]
              #:when (and (file-exists? path)
                          (equal? (path-get-extension path) #".rkt")
                          (not (path-within? path tests-root))))
     path)
   string<?
   #:key path->string))

(define (forbidden-reason importer resolved)
  (cond
    [(path-within? resolved tests-root)
     'test-module-from-semantics]
    [(path-within? resolved lean-root) #f]
    [(same-path? resolved approved-shared-kernel)
     (and (not (same-path? importer mk-kernel-path))
          'shared-kernel-from-unapproved-module)]
    [(same-path? resolved approved-production-helper)
     (and (not (same-path? importer mk-kernel-path))
          'production-helper-from-unapproved-module)]
    [else 'external-relative-module]))

(define (forbidden-imports path)
  (for*/list
      ([import (in-list (require-path-strings (module-datum path)))]
       [resolved
        (in-value
         (simple-form-path
          (build-path (path-only path) import)))]
       [reason (in-value (forbidden-reason path resolved))]
       #:when reason)
    (list (path->string (file-name-from-path path))
          import
          reason)))

(define (semantic-source path)
  (file->string path))

(define lean-intrinsic-dependency-tests
  (test-suite
   "lean source intrinsic dependency boundary"

   (test-case
    "semantic modules import only lean and approved atomic helpers"
    (check-equal?
     (append-map forbidden-imports semantic-module-paths)
     '()))

   (test-case
    "semantic sources contain no marked, Q, corpus, or retired imports"
    (for ([path (in-list semantic-module-paths)])
      (define source (semantic-source path))
      (for ([forbidden
             (in-list
              '("reference/marked"
                "../marked"
                "q/reference"
                "../q"
                "corpus/"
                "whole-tree-spike"
                "whole-tree-pipeline-pilot"
                "whole-tree-redex-column"
                "premachine"
                "zipper"
                "cfree"
                "bridge"))])
        (check-false
         (regexp-match? (regexp (regexp-quote forbidden)) source)
         (format "~a contains ~a" path forbidden)))))

   (test-case
    "only the Kmk adapter reaches the two approved external helpers"
    (check-equal?
     (forbidden-reason mk-kernel-path approved-shared-kernel)
     #f)
    (check-equal?
     (forbidden-reason mk-kernel-path approved-production-helper)
     #f)
    (check-not-false
     (forbidden-reason
      (build-path lean-root "source-schema.rkt")
      approved-shared-kernel)))))

(module+ test
  (run-tests lean-intrinsic-dependency-tests))
