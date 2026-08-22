#lang racket

(require racket/file
         racket/runtime-path
         rackunit
         rackunit/text-ui)

(provide DEPENDENCY-BOUNDARY)

(define-runtime-path seed-root "..")
(define-runtime-path production-root "../../../src")
(define-runtime-path framework-file
  "../framework/decomposition-instance.rkt")
(define-runtime-path stage-framework-file
  "../framework/stage-generators.rkt")
(define-runtime-path selected-stage-renderer-file
  "../framework/core-stage-renderers.rkt")
(define-runtime-path selected-stage-extension-base-fixture-file
  "../framework/core-stage-extension-base-fixture.rkt")
(define-runtime-path selected-stage-extension-query-fixture-file
  "../framework/core-stage-extension-query-fixture.rkt")
(define-runtime-path stage-framework-test-file
  "../framework/stage-generators-tests.rkt")
(define-runtime-path stage-parameter-base-fixture-file
  "../framework/stage-generators-parameter-base-fixture.rkt")
(define-runtime-path stage-parameter-derived-fixture-file
  "../framework/stage-generators-parameter-derived-fixture.rkt")
(define-runtime-path generated-s-column
  "../generated/core/s/column.rkt")
(define-runtime-path generated-e-column
  "../generated/core/e/column.rkt")
(define-runtime-path e-source-file "../core/e/source.rkt")
(define-runtime-path e-decomposition-file "../core/e/decomposition.rkt")
(define-runtime-path s-decomposition-file "../core/s/decomposition.rkt")
(define-runtime-path s-refocused-file "../core/s/refocused.rkt")
(define-runtime-path s-machine-file "../core/s/machine.rkt")
(define-runtime-path s-compressed-file "../core/s/compressed.rkt")
(define-runtime-path s-fixed-point-file "../core/s/fixed-point.rkt")
(define-runtime-path this-test-file "./dependency-boundary-tests.rkt")

(define (racket-files root)
  (for/list ([path (in-directory root)]
             #:when (and (file-exists? path)
                         (regexp-match? #rx"[.]rkt$" (path->string path))))
    path))

(define (files-containing paths pattern)
  (for/list ([path (in-list paths)]
             #:when (regexp-match? pattern (file->string path)))
    path))

(define (source-slice path start-marker end-marker)
  (define contents (file->string path))
  (define (marker-start marker)
    (match
      (regexp-match-positions
       (regexp (regexp-quote marker))
       contents)
      [(list (cons start _end)) start]
      [#f #f]))
  (define start (marker-start start-marker))
  (define end (marker-start end-marker))
  (unless (and start end (< start end))
    (error 'source-slice
           "could not find ordered markers in ~a: ~e then ~e"
           path
           start-marker
           end-marker))
  (substring contents start end))

(define (source-from path marker)
  (define contents (file->string path))
  (match
    (regexp-match-positions
     (regexp (regexp-quote marker))
     contents)
    [(list (cons start _end)) (substring contents start)]
    [#f
     (error 'source-from
            "could not find marker in ~a: ~e"
            path
            marker)]))

(define (match-count pattern contents)
  (length (regexp-match* pattern contents)))

(define (sorted-path-strings paths)
  (sort
   (for/list ([path (in-list paths)])
     (path->string (simplify-path path)))
   string<?))

(define/provide-test-suite DEPENDENCY-BOUNDARY
  (test-case "production never imports the derivation seed"
    (check-equal?
     (files-containing
      (racket-files production-root)
      #rx"derivations/search-lattice")
     '()))

  (test-case "the independent E source and D semantics do not call R[S]"
    (for ([path (in-list (list e-source-file e-decomposition-file))])
      (define contents (file->string path))
      (check-false (regexp-match? #rx"core-red[.]rkt" contents))
      (check-false (regexp-match? #rx"[.]?/s/decomposition[.]rkt" contents))
      (check-false (regexp-match? #rx"Q-SE" contents))))

  (test-case "the direct D[S] module does not import the source relation"
    (check-false
     (regexp-match? #rx"core-red[.]rkt"
                    (file->string s-decomposition-file))))

  (test-case "the generators contain no core semantic labels or constructors"
    (for ([contents
           (in-list
            (map file->string
                 (list framework-file stage-framework-file)))])
      (for ([label (in-list
                    '(allocate-fresh
                      conj-fail
                      conj-return
                      disequality-fail
                      disequality-success
                      expand-conjunction
                      fail
                      finish-failure
                      finish-success
                      succeed
                      unify-fail
                      unify-success
                      unify-violates-disequality))])
        (check-false
         (regexp-match? (regexp (regexp-quote (symbol->string label)))
                        contents)))
      (for ([constructor (in-list '(Answer Conj Done Last More Owners Returned
                                           Work))])
        (check-false
         (regexp-match?
          (pregexp
           (format "[(]~a(?:[[:space:]]|[)])" constructor))
          contents)))))

  (test-case "each generated coordinate states semantics and each arrow once"
    (for ([path (in-list (list generated-s-column generated-e-column))])
      (define contents (file->string path))
      (check-equal?
       (match-count #px"[(]define-derivation-instance\\s" contents)
       1)
      (check-equal? (match-count #px"#:site\\s" contents) 13)
      (for ([form (in-list
                   '(define-decomposition-stage
                     define-refocused-stage
                     define-machine-isomorphism-stage
                     define-compressed-stage
                     define-fixed-point-stage))])
        (check-equal?
         (match-count
          (pregexp (format "[(]~a\\s" form))
          contents)
         1))
      (check-equal?
       (match-count #px"[(]define-compression-policy\\s" contents)
       1)
      (check-equal?
       (match-count #rx"[(]define-judgment-form" contents)
       0)))

  (test-case "stage renderers do not assume the core carrier nonterminal names"
    (define contents (file->string stage-framework-file))
    (for ([name (in-list '(W F S WorkFocus SpineContext))])
      (check-false
       (regexp-match?
        (pregexp
         (format "(?<![A-Za-z0-9_-])~a(?![A-Za-z0-9_-])" name))
        contents))))

  (test-case "generated coordinates do not import their semantic oracles"
    (for ([path (in-list (list generated-s-column generated-e-column))])
      (define contents (file->string path))
      (for ([forbidden
             (in-list
              '("core-red.rkt"
                "source-spec.rkt"
                "core/s/decomposition.rkt"
                "core/s/refocused.rkt"
                "core/s/machine.rkt"
                "core/s/compressed.rkt"
                "core/s/fixed-point.rkt"
                "s-to-e.rkt"
                "Q-SE"
                "redex/parameter"))])
        (check-false
         (regexp-match? (regexp (regexp-quote forbidden)) contents))))
    (check-false
     (regexp-match? #rx"Owners"
                    (file->string generated-e-column))))

  (test-case "direct S paths do not call the plug-and-scan specifications"
    (define direct-contract
      (source-slice
       s-decomposition-file
       "(define-judgment-form\n  core-s-decomposition-lang\n  #:contract (contract/s"
       "(define-judgment-form\n  core-s-decomposition-lang\n  #:contract (decomposed-step/direct/s"))
    (define direct-refocus
      (source-slice
       s-refocused-file
       "(define-judgment-form\n  core-s-refocused-lang\n  #:contract (refocus-work/direct/s"
       "(define-judgment-form\n  core-s-refocused-lang\n  #:contract (refocused-step/spec/s"))

    (check-false
     (regexp-match? #rx"[(]whole-frontier-support/s" direct-contract))
    (check-false (regexp-match? #rx"[(]plug-[CD]/s" direct-refocus))
    (check-false (regexp-match? #rx"[(]decompose/s" direct-refocus)))

  (test-case "the direct M[S] machine does not call Z or transported steppers"
    (define contents (file->string s-machine-file))
    (for ([forbidden (in-list
                      '("(refocus-work/direct/s"
                        "(refocus/direct/s"
                        "(refocused-step/direct/s"
                        "(machine-step/spec/s"
                        "(ZM-step-square/s"))])
      (check-false
       (regexp-match? (regexp (regexp-quote forbidden)) contents))))

  (test-case "the direct B[S] compressor does not call an earlier stepper or its specification"
    (define contents (file->string s-compressed-file))
    (for ([forbidden (in-list
                      '("core-red.rkt"
                        "(decompose/s"
                        "(refocus/direct/s"
                        "(refocused-step/direct/s"
                        "(machine-step/direct/s"
                        "(compressed-step/spec/s"
                        "(replay-transition-span/M/s"
                        "(MB-step-square/s"
                        "(plug-D/s"
                        "(plug-C/s"))])
      (check-false
       (regexp-match? (regexp (regexp-quote forbidden)) contents))))

  (test-case "the direct Big[S] fixed point has no earlier-stage imports, calls, or constructors"
    (define contents (file->string s-fixed-point-file))
    (for ([forbidden (in-list
                      '("core-red.rkt"
                        "source-spec.rkt"
                        "decomposition.rkt"
                        "refocused.rkt"
                        "machine.rkt"
                        "compressed.rkt"
                        "(decompose/s"
                        "(refocus/spec/s"
                        "(refocus/direct/s"
                        "(refocused-step/spec/s"
                        "(refocused-step/direct/s"
                        "(machine-step/spec/s"
                        "(machine-step/direct/s"
                        "(compressed-step/spec/s"
                        "(compressed-step/direct/s"
                        "DecWork"
                        "DecFrontier"
                        "DecAllocate"
                        "ZWork"
                        "ZFrontier"
                        "ZAllocate"
                        "MWork"
                        "MFrontier"
                        "MAllocate"
                        "BRun"
                        "BSettled"
                        "BDead"
                        "BFinal"
                        "TransitionSpan"
                        "ContractWork"
                        "ContractFrontier"))])
      (check-false
       (regexp-match? (regexp (regexp-quote forbidden)) contents))))

  (test-case "generated direct B does not call M or its replay specification"
    (define direct-B
      (source-slice
       stage-framework-file
       "#:mode (step-direct I O O)\n             #:contract (step-direct B TransitionSpan B)"
       "(define-judgment-form\n             compressed-language\n             #:contract (corresponds M B)"))
    (for ([forbidden
           (in-list
            '("machine-step-direct"
              "(replay"
              "(step-spec"
              "apply-reduction-relation"
              "remove-duplicates"))])
      (check-false
       (regexp-match? (regexp (regexp-quote forbidden)) direct-B))))

  (test-case "generated direct Big contains no prior-stage artifact or stepper"
    (define direct-Big
      (source-slice
       stage-framework-file
       ";; This direct artifact extends the source language, not B."
       ";; The specification deliberately retains B and its exact span"))
    (for ([forbidden
           (in-list
            '("B-step-direct"
              "machine-step-direct"
              "apply-reduction-relation"
              "remove-duplicates"
              "DecWork"
              "DecFrontier"
              "DecAllocate"
              "ZWork"
              "ZFrontier"
              "ZAllocate"
              "MWork"
              "MFrontier"
              "MAllocate"
              "BRun"
              "BSettled"
              "BDead"
              "BFinal"
              "TransitionSpan"))])
      (check-false
       (regexp-match? (regexp (regexp-quote forbidden)) direct-Big))))

  (test-case "generated runtime has no host dispatcher, proof deduplication, or aliases"
    (define stage-renderers
      (source-from
       stage-framework-file
       "(define-syntax (define-decomposition-stage"))
    (for ([forbidden
           (in-list
            '("apply-reduction-relation"
              "remove-duplicates"
              "trace-deterministic"
              "(parameterize"
              "rename-in"
              "rename-out"
              "compatibility"
              "deprecated"))])
      (check-false
       (regexp-match? (regexp (regexp-quote forbidden)) stage-renderers))))

  (test-case "redex/parameter imports are confined to lifting frameworks and fixtures"
    (define implementation-files
      (for/list ([path (in-list (racket-files seed-root))]
                 #:unless (equal? (simplify-path path)
                                  (simplify-path this-test-file)))
        path))
    (check-true (positive? (length implementation-files)))
    (check-equal?
     (sorted-path-strings
     (files-containing implementation-files #rx"redex/parameter"))
     (sorted-path-strings
      (list stage-framework-file
            selected-stage-renderer-file
            selected-stage-extension-base-fixture-file
            selected-stage-extension-query-fixture-file
            stage-framework-test-file
            stage-parameter-base-fixture-file
            stage-parameter-derived-fixture-file))))

  (test-case "the seven semantic-premise sites are liftable and both fixtures are nonvacuous"
    (define framework-contents (file->string stage-framework-file))
    (define fixture-contents (file->string stage-framework-test-file))
    (define base-fixture-contents
      (file->string stage-parameter-base-fixture-file))
    (define derived-fixture-contents
      (file->string stage-parameter-derived-fixture-file))
    (define fixture-declarations
      (source-slice
       stage-framework-test-file
       "#lang racket"
       "(define/provide-test-suite STAGE-GENERATOR-SMOKE"))

    (check-equal?
     (match-count
      #rx"redex-parameter:define-judgment-form[*]"
      framework-contents)
     7)
    (check-equal? (match-count #rx"#:parameters" framework-contents) 7)
    (for ([surface-form
           (in-list
            '("#:redex-parameters"
              "#:redex-parameters-add"
              "#:redex-parameter-overrides"))])
      (check-true
       (regexp-match?
        (regexp (regexp-quote surface-form))
        framework-contents)))

    (check-equal?
     (match-count
      #rx"redex-parameter:define-judgment-form[*]"
      fixture-declarations)
     1)
    (check-equal?
     (match-count
      #rx"redex-parameter:define-extended-judgment-form[*]"
      fixture-declarations)
     1)
    (check-equal?
     (match-count #rx"#:redex-parameter-overrides" fixture-declarations)
     1)
    (for ([witness
           (in-list
            '("a lifted Redex dependency preserves raw proofs through D, B, and Big"
              "foreign-echo-evidence/extended"
              "(Echo \"lifted\")"
              "(Pulse 7)"
              "(BigFinal (Shell (Halted 8)))"))])
      (check-true
       (regexp-match?
        (regexp (regexp-quote witness))
        fixture-contents)))

    (check-equal?
     (match-count
      #rx"redex-parameter:define-judgment-form[*]"
      base-fixture-contents)
     1)
    (check-equal?
     (match-count
      #rx"redex-parameter:define-extended-judgment-form[*]"
      derived-fixture-contents)
     1)
    (for ([witness
           (in-list
            '("#:redex-parameters ([evidence hygiene-evidence])"
              "(provide hygiene-base-lang"
              "hygiene/base"))])
      (check-true
       (regexp-match?
        (regexp (regexp-quote witness))
        base-fixture-contents)))
    (for ([witness
           (in-list
            '("stage-generators-parameter-base-fixture.rkt"
              "#:from hygiene/base"
              "#:redex-parameter-overrides"
              "([evidence hygiene-evidence/extended])"
              "#:rules-add"
              "(evidence Input N)"))])
      (check-true
       (regexp-match?
        (regexp (regexp-quote witness))
        derived-fixture-contents)))
    (for ([witness
           (in-list
            '("a delta-added rule resolves an inherited Redex slot across modules"
              "cross-module:hygiene-contract"
              "cross-module:hygiene-B-step/direct"
              "cross-module:hygiene-B-step/spec"
              "cross-module:hygiene-big-evaluate/direct"
              "cross-module:hygiene-big-evaluate/spec"
              "(BigFinal (Halted 8))"))])
      (check-true
       (regexp-match?
        (regexp (regexp-quote witness))
        fixture-contents))))

  (test-case "semantic selection never uses ordinary Racket parameterize"
    (define implementation-files
      (for/list ([path (in-list (racket-files seed-root))]
                 #:unless (equal? (simplify-path path)
                                  (simplify-path this-test-file)))
        path))
    (check-equal?
     (files-containing implementation-files #px"[(]parameterize(?=[[:space:]])")
     '())))

(module+ test
  (run-tests DEPENDENCY-BOUNDARY))
