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

  (test-case "the structural generator contains no core semantic labels"
    (define contents (file->string framework-file))
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
                      contents))))

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

  (test-case "the seed has no redex/parameter dependency"
    (define implementation-files
      (for/list ([path (in-list (racket-files seed-root))]
                 #:unless (equal? (simplify-path path)
                                  (simplify-path this-test-file)))
        path))
    (check-true (positive? (length implementation-files)))
    (check-equal?
     (files-containing implementation-files #rx"redex/parameter")
     '())))

(module+ test
  (run-tests DEPENDENCY-BOUNDARY))
