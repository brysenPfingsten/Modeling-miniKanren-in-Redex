#lang racket

(require racket/file
         racket/list
         racket/runtime-path
         rackunit
         "../framework/decomposition-instance-tests.rkt"
         "../framework/stage-generators-tests.rkt"
         "../framework/core-source-schema-tests.rkt"
         "../framework/core-stage-schema-tests.rkt"
         "../framework/core-stage-extension-tests.rkt"
         "../framework/core-stage-functor-tests.rkt"
         "../framework/delay-schema-tests.rkt"
         "../framework/delay-stage-extension-tests.rkt"
         "../framework/delay-stage-asymmetric-tests.rkt"
         "../framework/disjunction-schema-tests.rkt"
         "../framework/disjunction-stage-extension-tests.rkt"
         "../framework/search-join-schema-tests.rkt"
         "../framework/stage-extension-dependencies-tests.rkt"
         "../generated/core/source/comparison-tests.rkt"
         "../generated/core/source/dependency-tests.rkt"
         "../generated/core/stages/dependency-tests.rkt"
         "../generated/core/stages/horizontal-tests.rkt"
         "../generated/core/stages/vertical-transformation-tests.rkt"
         "../generated/core/stages/vertical-transport-diagnostics-tests.rkt"
         "../generated/delay/source-tests.rkt"
         "../generated/delay/horizontal-tests.rkt"
         "../generated/delay/embedding-tests.rkt"
         "../generated/delay/cube-tests.rkt"
         "../generated/delay/transport-diagnostics-tests.rkt"
         "../generated/delay/dependency-tests.rkt"
         "../generated/disjunction/source-tests.rkt"
         "../generated/disjunction/horizontal-tests.rkt"
         "../generated/disjunction/embedding-tests.rkt"
         "../generated/disjunction/cube-tests.rkt"
         "../generated/disjunction/transport-diagnostics-tests.rkt"
         "../generated/disjunction/dependency-tests.rkt"
         "../generated/search/source-tests.rkt"
         "../generated/search/horizontal-tests.rkt"
         "../generated/search/embedding-tests.rkt"
         "../generated/search/feature-order-tests.rkt"
         "../generated/search/stage-feature-order-tests.rkt"
         "../generated/search/cube-tests.rkt"
         "../generated/search/transport-diagnostics-tests.rkt"
         "../generated/search/dependency-tests.rkt"
         "../oracles/core/s/tests.rkt"
         "../oracles/core/e/tests.rkt"
         "../oracles/core/n/tests.rkt"
         "../oracles/core/vertical-tests.rkt"
         "../oracles/core/dependency-tests.rkt"
         "../oracles/delay/tests.rkt"
         "../oracles/disjunction/tests.rkt"
         "../oracles/search/tests.rkt"
         "./core-matrix-tests.rkt"
         "./core-s-horizontal-tests.rkt"
         "./dependency-boundary-tests.rkt")

(provide
 (struct-out test-suite-registration)
 SEARCH-LATTICE-TEST-INVENTORY
 SEARCH-LATTICE-FOCUSED-AGGREGATE-MODULES
 SEARCH-LATTICE-INTRINSIC-TEST-MODULES
 SEARCH-LATTICE-TEST-INVENTORY-CHECKS
 require-search-lattice-intrinsic-tests
 registered-test-suite)

(struct test-suite-registration (module-path suite-id suite-provider)
  #:transparent)

(define-syntax-rule (register-test-suite module-path suite-id)
  (test-suite-registration module-path
                           'suite-id
                           (lambda () suite-id)))

(define-runtime-path SEARCH-LATTICE-ROOT-PATH "..")
(define SEARCH-LATTICE-ROOT
  (simplify-path SEARCH-LATTICE-ROOT-PATH))

(define-syntax (define-intrinsic-test-inventory stx)
  (syntax-case stx ()
    [(_ inventory-id require-id [module-path require-path] ...)
     #'(begin
         (define inventory-id
           (list module-path ...))
         (define-syntax-rule (require-id)
           (require (submod require-path test) ...)))]))

;; Direct checks in implementation module+ bodies are semantic tests too.
;; This single declaration supplies both their inspectable root-relative
;; inventory and the static require form used by tests/all.rkt.
(define-intrinsic-test-inventory
  SEARCH-LATTICE-INTRINSIC-TEST-MODULES
  require-search-lattice-intrinsic-tests
  ["core/e/language.rkt" "../core/e/language.rkt"]
  ["core/e/source.rkt" "../core/e/source.rkt"]
  ["core/s-to-e.rkt" "../core/s-to-e.rkt"]
  ["core/s/fixed-point-spec.rkt" "../core/s/fixed-point-spec.rkt"]
  ["core/s/fixed-point.rkt" "../core/s/fixed-point.rkt"]
  ["core/s/machine-spec.rkt" "../core/s/machine-spec.rkt"]
  ["core/s/machine.rkt" "../core/s/machine.rkt"]
  ["core/s/private/support-kernel.rkt"
   "../core/s/private/support-kernel.rkt"]
  ["core/s/refocused.rkt" "../core/s/refocused.rkt"]
  ["demo.rkt" "../demo.rkt"]
  ["oracles/core/n/language.rkt" "../oracles/core/n/language.rkt"]
  ["oracles/core/n/source.rkt" "../oracles/core/n/source.rkt"]
  ["oracles/core/n/wf.rkt" "../oracles/core/n/wf.rkt"])

;; This is the complete, flat registry of suites run by tests/all.rkt.  Keep
;; leaf suites here rather than their focused aggregate wrappers so that no
;; suite can enter the canonical aggregate more than once transitively.
(define SEARCH-LATTICE-TEST-INVENTORY
  (list
   (register-test-suite
    "framework/decomposition-instance-tests.rkt"
    DECOMPOSITION-FRAMEWORK-TESTS)
   (register-test-suite
    "framework/stage-generators-tests.rkt"
    STAGE-GENERATOR-SMOKE)
   (register-test-suite
    "framework/core-source-schema-tests.rkt"
    CORE-SOURCE-SCHEMA-TESTS)
   (register-test-suite
    "framework/core-stage-schema-tests.rkt"
    CORE-STAGE-SCHEMA-TESTS)
   (register-test-suite
    "framework/core-stage-extension-tests.rkt"
    CORE-STAGE-EXTENSION-TESTS)
   (register-test-suite
    "framework/core-stage-functor-tests.rkt"
    CORE-STAGE-FUNCTOR-TESTS)
   (register-test-suite
    "framework/delay-schema-tests.rkt"
    DELAY-SCHEMA-TESTS)
   (register-test-suite
    "framework/delay-stage-extension-tests.rkt"
    DELAY-STAGE-EXTENSION-TESTS)
   (register-test-suite
    "framework/delay-stage-asymmetric-tests.rkt"
    DELAY-STAGE-ASYMMETRIC-TESTS)
   (register-test-suite
    "framework/disjunction-schema-tests.rkt"
    DISJUNCTION-SCHEMA-TESTS)
   (register-test-suite
    "framework/disjunction-stage-extension-tests.rkt"
    DISJUNCTION-STAGE-EXTENSION-TESTS)
   (register-test-suite
    "framework/search-join-schema-tests.rkt"
    SEARCH-JOIN-SCHEMA)
   (register-test-suite
    "framework/stage-extension-dependencies-tests.rkt"
    STAGE-EXTENSION-DEPENDENCIES-TESTS)
   (register-test-suite
    "generated/core/source/comparison-tests.rkt"
    GENERATED-CORE-SOURCE-COMPARISONS)
   (register-test-suite
    "generated/core/source/dependency-tests.rkt"
    GENERATED-CORE-SOURCE-DEPENDENCIES)
   (register-test-suite
    "generated/core/stages/dependency-tests.rkt"
    GENERATED-CORE-STAGE-DEPENDENCIES)
   (register-test-suite
    "generated/core/stages/horizontal-tests.rkt"
    GENERATED-CORE-STAGES-HORIZONTAL)
   (register-test-suite
    "generated/core/stages/vertical-transformation-tests.rkt"
    GENERATED-CORE-STAGES-VERTICAL-TRANSFORMATIONS)
   (register-test-suite
    "generated/core/stages/vertical-transport-diagnostics-tests.rkt"
    GENERATED-CORE-STAGES-VERTICAL-TRANSPORT-DIAGNOSTICS)
   (register-test-suite
    "generated/delay/source-tests.rkt"
    GENERATED-DELAY-SOURCE-TESTS)
   (register-test-suite
    "generated/delay/horizontal-tests.rkt"
    GENERATED-DELAY-HORIZONTAL-TESTS)
   (register-test-suite
    "generated/delay/embedding-tests.rkt"
    GENERATED-DELAY-EMBEDDING-TESTS)
   (register-test-suite
    "generated/delay/cube-tests.rkt"
    GENERATED-DELAY-CUBE-TESTS)
   (register-test-suite
    "generated/delay/transport-diagnostics-tests.rkt"
    GENERATED-DELAY-TRANSPORT-DIAGNOSTICS-TESTS)
   (register-test-suite
    "generated/delay/dependency-tests.rkt"
    GENERATED-DELAY-DEPENDENCY-TESTS)
   (register-test-suite
    "generated/disjunction/source-tests.rkt"
    GENERATED-DISJUNCTION-SOURCE-TESTS)
   (register-test-suite
    "generated/disjunction/horizontal-tests.rkt"
    GENERATED-DISJUNCTION-HORIZONTAL-TESTS)
   (register-test-suite
    "generated/disjunction/embedding-tests.rkt"
    GENERATED-DISJUNCTION-EMBEDDING-TESTS)
   (register-test-suite
    "generated/disjunction/cube-tests.rkt"
    GENERATED-DISJUNCTION-CUBE-TESTS)
   (register-test-suite
    "generated/disjunction/transport-diagnostics-tests.rkt"
    GENERATED-DISJUNCTION-TRANSPORT-DIAGNOSTICS-TESTS)
   (register-test-suite
    "generated/disjunction/dependency-tests.rkt"
    GENERATED-DISJUNCTION-DEPENDENCY-TESTS)
   (register-test-suite
    "generated/search/source-tests.rkt"
    GENERATED-SEARCH-SOURCE-TESTS)
   (register-test-suite
    "generated/search/horizontal-tests.rkt"
    GENERATED-SEARCH-HORIZONTAL-TESTS)
   (register-test-suite
    "generated/search/embedding-tests.rkt"
    GENERATED-SEARCH-EMBEDDING-TESTS)
   (register-test-suite
    "generated/search/feature-order-tests.rkt"
    GENERATED-SEARCH-FEATURE-ORDER-TESTS)
   (register-test-suite
    "generated/search/stage-feature-order-tests.rkt"
    GENERATED-SEARCH-STAGE-FEATURE-ORDER-TESTS)
   (register-test-suite
    "generated/search/cube-tests.rkt"
    GENERATED-SEARCH-CUBE-TESTS)
   (register-test-suite
    "generated/search/transport-diagnostics-tests.rkt"
    GENERATED-SEARCH-TRANSPORT-DIAGNOSTICS-TESTS)
   (register-test-suite
    "generated/search/dependency-tests.rkt"
    GENERATED-SEARCH-DEPENDENCY-TESTS)
   (register-test-suite
    "oracles/core/s/tests.rkt"
    CORE-S-ORACLE-TESTS)
   (register-test-suite
    "oracles/core/e/tests.rkt"
    CORE-E-ORACLE-TESTS)
   (register-test-suite
    "oracles/core/n/tests.rkt"
    CORE-N-ORACLE-TESTS)
   (register-test-suite
    "oracles/core/vertical-tests.rkt"
    CORE-R-VERTICAL-TESTS)
   (register-test-suite
    "oracles/core/dependency-tests.rkt"
    CORE-ORACLE-DEPENDENCY-TESTS)
   (register-test-suite
    "oracles/delay/tests.rkt"
    DELAY-ORACLE-TESTS)
   (register-test-suite
    "oracles/disjunction/tests.rkt"
    DISJUNCTION-ORACLE-TESTS)
   (register-test-suite
    "oracles/search/tests.rkt"
    SEARCH-ORACLE-TESTS)
   (register-test-suite
    "tests/core-matrix-tests.rkt"
    CORE-MATRIX-SEED)
   (register-test-suite
    "tests/core-s-horizontal-tests.rkt"
    CORE-S-HORIZONTAL)
   (register-test-suite
    "tests/dependency-boundary-tests.rkt"
    DEPENDENCY-BOUNDARY)
   (register-test-suite
    "tests/test-inventory.rkt"
    SEARCH-LATTICE-TEST-INVENTORY-CHECKS)))

;; These remain useful focused entry points, but tests/all.rkt registers their
;; leaves directly.  Listing them here distinguishes an intentional wrapper
;; from an unregistered semantic test module.
(define SEARCH-LATTICE-FOCUSED-AGGREGATE-MODULES
  (list "generated/core/source/tests.rkt"
        "generated/core/stages/tests.rkt"
        "generated/delay/tests.rkt"
        "generated/disjunction/tests.rkt"
        "generated/search/tests.rkt"
        "oracles/core/tests.rkt"
        "oracles/core/s/all.rkt"
        "oracles/core/e/all.rkt"
        "oracles/core/n/all.rkt"))

(define EXPECTED-CANONICAL-SUITE-COUNT 51)
(define EXPECTED-SEMANTIC-TEST-MODULE-COUNT 56)
(define EXPECTED-FOCUSED-AGGREGATE-COUNT 9)
(define EXPECTED-INTRINSIC-TEST-MODULE-COUNT 13)
(define EXPECTED-TEST-SUBMODULE-COUNT 74)

(define (registration-module-file registration)
  (build-path SEARCH-LATTICE-ROOT
              (test-suite-registration-module-path registration)))

(define (registered-test-suite registration)
  ((test-suite-registration-suite-provider registration)))

(define (semantic-test-module? path)
  (define filename-path
    (file-name-from-path path))
  (and filename-path
       (let ([filename (path->string filename-path)])
         (or (regexp-match? #rx"-tests\\.rkt$" filename)
             (string=? filename "tests.rkt")))))

(define (relative-module-path path)
  (path->string
   (find-relative-path SEARCH-LATTICE-ROOT path)))

(define (discovered-semantic-test-modules)
  ;; Scan the whole subtree rather than only Git-visible files.  This stricter
  ;; check prevents an ignored scratch test module from silently escaping the
  ;; canonical registry; compiled artifacts cannot match the .rkt predicates.
  (sort
   (for/list ([path (in-list (find-files semantic-test-module?
                                         SEARCH-LATTICE-ROOT))])
     (relative-module-path path))
   string<?))

(define (defines-test-submodule? path)
  (and (file-exists? path)
       (call-with-input-file path
         (lambda (input)
           (for/or ([line (in-lines input)])
             (regexp-match?
              #px"^\\s*\\(module\\+\\s+test(?:\\s|\\)|$)"
              line))))))

(define (discovered-test-submodules)
  (sort
   (for/list ([path (in-list (find-files defines-test-submodule?
                                         SEARCH-LATTICE-ROOT))])
     (relative-module-path path))
   string<?))

(define (duplicate-values values [same? equal?])
  (remove-duplicates
   (for*/list ([value (in-list values)]
               [later (in-list (cdr (member value values same?)))]
               #:when (same? value later))
     value)
   same?))

(define (suite-closure suites)
  (for/fold ([seen '()])
            ([suite (in-list suites)])
    (foldts-test-suite
     (lambda (nested-suite _name _before _after nested-seen)
       (cons nested-suite nested-seen))
     (lambda (_suite _name _before _after _seen nested-seen)
       nested-seen)
     (lambda (_test-case _name _action nested-seen)
       nested-seen)
     seen
     suite)))

(define-test-suite SEARCH-LATTICE-TEST-INVENTORY-CHECKS
  (test-case
   "the canonical registry has stable cardinality and unique coordinates"
   (define module-paths
     (map test-suite-registration-module-path
          SEARCH-LATTICE-TEST-INVENTORY))
   (define suite-ids
     (map test-suite-registration-suite-id
          SEARCH-LATTICE-TEST-INVENTORY))
   (check-equal? (length SEARCH-LATTICE-TEST-INVENTORY)
                 EXPECTED-CANONICAL-SUITE-COUNT)
   (check-equal? (duplicate-values module-paths)
                 '()
                 "duplicate canonical module registration")
   (check-equal? (duplicate-values suite-ids)
                 '()
                 "duplicate canonical suite-id registration"))

  (test-case
   "the canonical registry contains no duplicate suite at any depth"
   (define suites
     (map registered-test-suite SEARCH-LATTICE-TEST-INVENTORY))
   (check-true (andmap rackunit-test-suite? suites))
   (check-equal? (duplicate-values (suite-closure suites) eq?)
                 '()
                 "the same suite is registered more than once transitively"))

  (test-case
   "every registered suite and intrinsic test module still exists"
   (for ([registration (in-list SEARCH-LATTICE-TEST-INVENTORY)])
     (check-true
      (file-exists? (registration-module-file registration))
      (format "missing registered module: ~a"
              (test-suite-registration-module-path registration))))
   (check-equal? (length SEARCH-LATTICE-INTRINSIC-TEST-MODULES)
                 EXPECTED-INTRINSIC-TEST-MODULE-COUNT)
   (for ([path (in-list SEARCH-LATTICE-INTRINSIC-TEST-MODULES)])
     (check-true
      (file-exists? (build-path SEARCH-LATTICE-ROOT path))
      (format "missing intrinsic test module: ~a" path))))

  (test-case
   "the focused aggregate allowlist is exact and disjoint"
   (define registered-paths
     (map test-suite-registration-module-path
          SEARCH-LATTICE-TEST-INVENTORY))
   (check-equal? (length SEARCH-LATTICE-FOCUSED-AGGREGATE-MODULES)
                 EXPECTED-FOCUSED-AGGREGATE-COUNT)
   (check-equal? (duplicate-values SEARCH-LATTICE-FOCUSED-AGGREGATE-MODULES)
                 '()
                 "duplicate focused aggregate allowlist entry")
   (for ([path (in-list SEARCH-LATTICE-FOCUSED-AGGREGATE-MODULES)])
     (check-true
      (file-exists? (build-path SEARCH-LATTICE-ROOT path))
      (format "missing focused aggregate allowlist module: ~a" path)))
   (check-equal?
    (filter (lambda (path) (member path registered-paths))
            SEARCH-LATTICE-FOCUSED-AGGREGATE-MODULES)
    '()
    "focused aggregate wrappers must not enter the canonical registry"))

  (test-case
   "all semantic tests and test submodules have an explicit disposition"
   (define discovered
     (discovered-semantic-test-modules))
   (define expected
     (sort
      (append
       (filter semantic-test-module?
               (map test-suite-registration-module-path
                    SEARCH-LATTICE-TEST-INVENTORY))
       (filter semantic-test-module?
               SEARCH-LATTICE-FOCUSED-AGGREGATE-MODULES))
      string<?))
   (check-equal? (length discovered)
                 EXPECTED-SEMANTIC-TEST-MODULE-COUNT)
   (check-equal? discovered expected)
   (define discovered-submodules
     (discovered-test-submodules))
   (define expected-submodules
     (sort
      (append
       (map test-suite-registration-module-path
            SEARCH-LATTICE-TEST-INVENTORY)
       SEARCH-LATTICE-FOCUSED-AGGREGATE-MODULES
       SEARCH-LATTICE-INTRINSIC-TEST-MODULES
       (list "tests/all.rkt"))
      string<?))
   (check-equal? (length discovered-submodules)
                 EXPECTED-TEST-SUBMODULE-COUNT)
   (check-equal? discovered-submodules expected-submodules)))

(module+ test
  (require rackunit/text-ui)
  (run-tests SEARCH-LATTICE-TEST-INVENTORY-CHECKS))
