#lang racket

(require racket/file
         racket/list
         racket/path
         racket/runtime-path
         rackunit
         rackunit/text-ui)

(provide intrinsic-dependency-tests)

(define-runtime-path pk-root "..")
(define-runtime-path tests-root ".")
(define-runtime-path corpus-root "../../../corpus")
(define-runtime-path export-traces-path "../export-traces.rkt")
(define-runtime-path mk-kernel-path "../mk/kernel.rkt")
(define-runtime-path approved-shared-kernel "../../../../shared/kernel.rkt")
(define-runtime-path approved-production-helper
  "../../../../../../src/search-lattice/wf/kernel-base.rkt")

;; These paths exercise the classifier itself.  The gate is whitelist-based,
;; so any future external semantic directory is rejected without first being
;; added to this list.
(define-runtime-path concrete-root "../../../../whole-tree-redex-column")
(define-runtime-path pilot-root "../../../../whole-tree-pipeline-pilot")
(define-runtime-path spike-root "../../../../whole-tree-spike")
(define-runtime-path premachine-root "../../../../premachine")
(define-runtime-path zipper-root "../../../../zipper")
(define-runtime-path cfree-root "../../../../cfree")
(define-runtime-path bridge-root "../../../../bridge")
(define-runtime-path production-root "../../../../../../src/search-lattice")

(define retired-semantics-roots
  (list concrete-root
        pilot-root
        spike-root
        premachine-root
        zipper-root
        cfree-root
        bridge-root))

(define intrinsic-module-paths
  (sort
   (for/list ([path (in-directory pk-root)]
              #:when (and (file-exists? path)
                          (equal? (path-get-extension path) #".rkt")))
     path)
   string<?
   #:key path->string))

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

(define (forbidden-reason importer resolved)
  (cond
    [(path-within? resolved tests-root)
     (and (not (path-within? importer tests-root))
          'test-module-from-nontest)]
    [(same-path? resolved export-traces-path)
     (and (not (path-within? importer tests-root))
          'trace-export-from-nontest)]
    [(path-within? resolved pk-root) #f]
    [(path-within? resolved corpus-root)
     (and (not (or (path-within? importer tests-root)
                   (same-path? importer export-traces-path)))
          'corpus-from-semantic-module)]
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

(define intrinsic-dependency-tests
  (test-suite
   "whole-tree P[K] intrinsic dependency boundary"
   (test-case
    "all marked modules exclude legacy semantics and unapproved production control"
    (check-equal?
     (append-map forbidden-imports intrinsic-module-paths)
     '()))
   (test-case
    "the dependency classifier recognizes every retired semantic root"
    (for ([root (in-list retired-semantics-roots)])
      (check-not-false
       (forbidden-reason
        export-traces-path
        (build-path root "sentinel.rkt"))))
    (check-equal?
     (forbidden-reason mk-kernel-path approved-shared-kernel)
     #f)
    (check-equal?
     (forbidden-reason mk-kernel-path approved-production-helper)
     #f)
    (check-equal?
     (forbidden-reason
      export-traces-path
      (build-path corpus-root "scenarios.rkt"))
     #f)
    (check-equal?
     (forbidden-reason
      (build-path pk-root "source-schema.rkt")
      (build-path corpus-root "scenarios.rkt"))
     'corpus-from-semantic-module)
    (check-equal?
     (forbidden-reason
      (build-path pk-root "source-schema.rkt")
      (build-path tests-root "observation-tests.rkt"))
     'test-module-from-nontest)
    (check-equal?
     (forbidden-reason
      (build-path pk-root "source-schema.rkt")
      export-traces-path)
     'trace-export-from-nontest)
    (check-equal?
     (forbidden-reason export-traces-path approved-production-helper)
     'production-helper-from-unapproved-module)
    (check-equal?
     (forbidden-reason
      export-traces-path
      (build-path production-root "languages" "core-lang.rkt"))
     'external-relative-module))))

(module+ test
  (run-tests intrinsic-dependency-tests))
