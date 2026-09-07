#lang racket

(require rackunit racket/runtime-path syntax/modcode syntax/modresolve)

(define-runtime-path directory ".")
(define-runtime-path repository "../../..")
(define retained (build-path directory "retained-scope"))
(define shared (build-path directory "shared"))
(define support (build-path directory "test-support"))
(define matrix (build-path directory "matrix"))

(define (inside? path directory)
  (define path-parts (explode-path (simplify-path path)))
  (define directory-parts (explode-path (simplify-path directory)))
  (and (<= (length directory-parts) (length path-parts))
       (equal? directory-parts (take path-parts (length directory-parts)))))

(define (source-files root)
  (for/list ([path (in-directory root)]
             #:when (and (file-exists? path) (equal? (path-get-extension path) #".rkt")))
    (simplify-path path)))

(define (suite? path)
  (define name (path->string (file-name-from-path path)))
  (or (equal? name "all.rkt") (regexp-match? #rx"(^|-)tests[.]rkt$" name)))

(define (demonstration? path)
  (regexp-match? #rx"^show" (path->string (file-name-from-path path))))

;; Compile source, rather than matching require strings or trusting stale zo
;; files. Inspect expanded imports at every phase, including imports introduced
;; by macros and nested module/module+ bodies. Compilation does not run the
;; inspected modules' runtime bodies or test submodules.
(define inspection-namespace (make-base-namespace))
(define dependency-cache (make-hash))

(define (resolved-file resolved)
  (match resolved
    [(? path? path) (simplify-path path)]
    [`(submod ,(? path? path) ,_ ...) (simplify-path path)]
    [_ #f]))

(define (compiled-imports code origin)
  (append
   (for*/list ([phase-imports (in-list (module-compiled-imports code))]
               [index (in-list (cdr phase-imports))]
               [path (in-value (resolved-file (resolve-module-path-index index origin)))]
               #:when (and path (inside? path repository)))
     path)
   (append-map (lambda (submodule) (compiled-imports submodule origin))
               (append (module-compiled-submodules code #t)
                       (module-compiled-submodules code #f)))))

(define (local-imports origin)
  (hash-ref! dependency-cache origin
             (lambda ()
               (parameterize ([current-namespace inspection-namespace])
                 (remove-duplicates
                  (compiled-imports
                   (get-module-code origin #:choose (lambda (_source _zo _so) 'src))
                   origin))))))

(define (check-closure roots allowed?)
  (define visited (make-hash))
  (define (visit origin chain)
    (unless (hash-ref visited origin #f)
      (hash-set! visited origin #t)
      (for ([dependency (in-list (local-imports origin))])
        ;; A submodule may import its enclosing module; this adds no file edge.
        (unless (equal? origin dependency)
          (define allowed (allowed? dependency))
          (check-true allowed
                      (format "forbidden local dependency: ~a"
                              (map (lambda (path)
                                     (path->string (find-relative-path (simplify-path directory) path)))
                                   (reverse (cons dependency (cons origin chain))))))
          (when allowed (visit dependency (cons origin chain)))))))
  (for ([root (in-list roots)]) (visit root '())))

(module+ test
  (test-case "preferred runtime and derivation depend only on the current route and shared code"
    (define (runtime? path)
      (and (or (inside? path retained) (inside? path shared))
           (not (suite? path)) (not (demonstration? path))))
    (check-closure (filter runtime? (source-files retained)) runtime?))

  (test-case "shared code does not depend on routes, fixtures, or test suites"
    (check-closure (source-files shared)
                   (lambda (path) (and (inside? path shared) (not (suite? path))))))

  (test-case "test support does not load historical implementations or test suites"
    (check-closure (source-files support)
                   (lambda (path)
                     (and (or (inside? path shared) (inside? path support))
                          (not (suite? path))))))

  (test-case "retained checks may compare native matrix providers without importing other suites"
    (check-closure (filter (lambda (path)
                             (and (or (suite? path) (demonstration? path))
                                  (not (equal? (file-name-from-path path) (string->path "all.rkt")))))
                           (source-files retained))
                   (lambda (path)
                     (and (or (inside? path retained) (inside? path shared)
                              (inside? path support) (inside? path matrix))
                          (not (suite? path))))))

  (test-case "matrix execution depends only on its concrete sources and shared machinery"
    (define (runtime? path)
      (and (or (inside? path matrix) (inside? path shared))
           (not (suite? path))))
    (check-closure (filter runtime? (source-files matrix)) runtime?))

  (test-case "matrix checks use native rows and the independent retained checkpoint"
    (check-closure (source-files matrix)
                   (lambda (path)
                     (or (inside? path matrix) (inside? path shared)
                         (inside? path support)
                         (and (inside? path retained) (not (suite? path)))))))

  (test-case "the strict aggregate includes both maintained derivation accounts"
    ;; Parse the actual direct require, without loading the broad aggregate
    ;; recursively from its own layout test.
    (define module-datum
      (call-with-input-file (build-path directory "all.rkt")
        (lambda (input)
          (parameterize ([read-accept-reader #t])
            (syntax->datum (read-syntax "all.rkt" input))))))
    (match-define `(module ,_ ,_ (#%module-begin ,forms ...)) module-datum)
    (for ([aggregate (in-list '("retained-scope/all.rkt" "matrix/all.rkt"))])
      (check-not-false
       (for/or ([form (in-list forms)])
         (match form
           [`(require ,specifications ...) (member aggregate specifications)]
           [_ #f]))))))
