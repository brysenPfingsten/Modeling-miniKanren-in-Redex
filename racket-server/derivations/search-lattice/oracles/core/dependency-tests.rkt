#lang racket

(require racket/runtime-path
         rackunit
         rackunit/text-ui)

(provide CORE-ORACLE-DEPENDENCY-TESTS)

(define-runtime-path oracle-root ".")

(define source-directories '("s" "e" "n"))
(define source-files '("language.rkt" "source.rkt" "wf.rkt"))

(define (source-text representation filename)
  (file->string (build-path oracle-root representation filename)))

(define-test-suite CORE-ORACLE-DEPENDENCY-TESTS
  (test-case
   "each source oracle is independent of production, generation, and peers"
   (for* ([representation (in-list source-directories)]
          [filename (in-list source-files)])
     (define text (source-text representation filename))
     (check-false
      (regexp-match? #rx"src/search-lattice|generated/|stage-generators" text)
      (format "forbidden implementation dependency in ~a/~a"
              representation
              filename))
     (for ([peer (in-list (remove representation source-directories))])
       (check-false
        (regexp-match?
         (regexp (format "[\"/]~a[/\"]" (regexp-quote peer)))
         text)
        (format "cross-oracle dependency from ~a/~a to ~a"
                representation
                filename
                peer)))))

  (test-case
   "the source languages contain no generated or event carrier"
   (for ([representation (in-list source-directories)])
     (define text (source-text representation "language.rkt"))
     (check-false (regexp-match? #rx"AllocateEvent" text))
     (check-false (regexp-match? #rx"define-derivation-instance" text))))

  (test-case
   "vertical maps are theorem-side and do not import staged artifacts"
   (define text (file->string (build-path oracle-root "vertical.rkt")))
   (check-false
    (regexp-match?
     #rx"generated/|decomposition|refocused|machine|compressed|fixed-point"
     text))
   (check-false (regexp-match? #rx"AllocateEvent|parameterize" text)))

  (test-case
   "failed supply is intrinsic and obsolete history recovery stays removed"
   (define vertical-text
     (file->string (build-path oracle-root "vertical.rkt")))
   (check-false
    (regexp-match?
     #rx"support-witness|resolve-E-support|predecessor-derived|supportless"
     vertical-text))
   (for ([representation (in-list '("e" "n"))])
     (define wf-text (source-text representation "wf.rkt"))
     (check-false
      (regexp-match? #rx"wf-unreachable|dead-left" wf-text)
      (format "obsolete failed-continuation escape in ~a WF"
              representation)))))

(module+ test
  (run-tests CORE-ORACLE-DEPENDENCY-TESTS))
