#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in stage-s: "stages/s.rkt")
         (prefix-in diag-s: (submod "stages/s.rkt" diagnostics))
         (prefix-in stage-e: "stages/e.rkt")
         (prefix-in diag-e: (submod "stages/e.rkt" diagnostics))
         (prefix-in stage-n: "stages/n.rkt")
         (prefix-in diag-n: (submod "stages/n.rkt" diagnostics))
         (prefix-in q: "stages/vertical.rkt")
         "corpus.rkt")

(provide GENERATED-DISJUNCTION-TRANSPORT-DIAGNOSTICS-TESTS)

;; This module is intentionally secondary.  Every selected coordinate is
;; first built by its primary direct arrow; codecs and readbacks only compare
;; against that existing coordinate.

(define (outputs proofs count)
  (for/list ([proof (in-list proofs)])
    (define values (take-right (derivation-term proof) count))
    (if (= count 1) (first values) values)))

(define (canonical values)
  (sort values string<? #:key ~s))

(define (canonical-top-level-proof-multiset proofs)
  (canonical
   (for/list ([proof (in-list proofs)])
     (match (derivation-term proof)
       [(cons _judgment arguments) (cons 'judgment arguments)]))))

(define (check-proof-arguments proofs expected-arguments)
  (check-equal? (length proofs) (length expected-arguments))
  (check-equal?
   (canonical-top-level-proof-multiset proofs)
   (canonical
    (for/list ([arguments (in-list expected-arguments)])
      (cons 'judgment arguments)))))

(define (only who values)
  (match values
    [(list value) value]
    [_ (error who "expected one diagnostic proof, received ~e" values)]))

(struct diagnostic-row
  (name
   corpus
   decompose
   plug-D
   refocus
   D->Z
   Z->D
   readback-Z
   Z-step
   Z-step-spec
   machineize
   encode-ZM
   decode-MZ
   readback-M
   ZM-corresponds-proofs
   M-step
   M-step-spec
   ZM-square-proofs
   compress
   encode-MB
   decode-BM
   readback-B
   MB-corresponds-proofs
   replay-proofs
   B-step
   B-step-spec
   MB-square-proofs
   span-labels
   big-evaluate
   initialize-B
   promote
   big-spec
   close-B
   flatten
   readback-Big
   unfold-square-proofs
   closure-square-proofs
   root-square-proofs)
  #:transparent)

(define-syntax-rule
  (define-diagnostic-row
    row-id row-name corpus-id
    decompose-id plug-D-id refocus-id D->Z-id Z->D-id readback-Z-id
    Z-step-id Z-step-spec-id
    machineize-id encode-ZM-id decode-MZ-id readback-M-id
    ZM-corresponds-id M-step-id M-step-spec-id ZM-square-id
    compress-id encode-MB-id decode-BM-id readback-B-id
    MB-corresponds-id replay-id B-step-id B-step-spec-id MB-square-id
    span-labels-id
    big-evaluate-id initialize-B-id promote-id big-spec-id
    close-B-id flatten-id readback-Big-id
    unfold-square-id closure-square-id root-square-id)
  (define row-id
    (diagnostic-row
     row-name corpus-id
     (lambda (source) (build-derivations (decompose-id ,source D)))
     (lambda (D) (term (plug-D-id ,D)))
     (lambda (D) (term (refocus-id ,D)))
     (lambda (D) (term (D->Z-id ,D)))
     (lambda (Z) (term (Z->D-id ,Z)))
     (lambda (Z) (term (readback-Z-id ,Z)))
     (lambda (Z) (build-derivations (Z-step-id ,Z RuleName Z_next)))
     (lambda (Z) (build-derivations (Z-step-spec-id ,Z RuleName Z_next)))
     (lambda (Z) (term (machineize-id ,Z)))
     (lambda (Z) (term (encode-ZM-id ,Z)))
     (lambda (M) (term (decode-MZ-id ,M)))
     (lambda (M) (term (readback-M-id ,M)))
     (lambda (Z) (build-derivations (ZM-corresponds-id ,Z M_0)))
     (lambda (M) (build-derivations (M-step-id ,M RuleName M_next)))
     (lambda (M) (build-derivations (M-step-spec-id ,M RuleName M_next)))
     (lambda (Z)
       (build-derivations
        (ZM-square-id ,Z RuleName_0 Z_next M_0 M_1)))
     (lambda (M) (term (compress-id ,M)))
     (lambda (M) (term (encode-MB-id ,M)))
     (lambda (B) (term (decode-BM-id ,B)))
     (lambda (B) (term (readback-B-id ,B)))
     (lambda (M) (build-derivations (MB-corresponds-id ,M B_0)))
     (lambda (M)
       (build-derivations (replay-id ,M TransitionSpan_0 M_next)))
     (lambda (B) (build-derivations (B-step-id ,B TransitionSpan B_next)))
     (lambda (B)
       (build-derivations (B-step-spec-id ,B TransitionSpan B_next)))
     (lambda (B)
       (build-derivations
        (MB-square-id ,B TransitionSpan_0 B_next M_0 M_1)))
     (lambda (span) (term (span-labels-id ,span)))
     (lambda (source) (build-derivations (big-evaluate-id ,source Big)))
     (lambda (source) (build-derivations (initialize-B-id ,source B)))
     (lambda (B) (build-derivations (promote-id ,B Big)))
     (lambda (source)
       (build-derivations (big-spec-id ,source BTrace Big)))
     (lambda (B) (build-derivations (close-B-id ,B BTrace T)))
     (lambda (trace) (term (flatten-id ,trace)))
     (lambda (Big) (term (readback-Big-id ,Big)))
     (lambda (B)
       (build-derivations
        (unfold-square-id ,B TransitionSpan_0 B_next Big_0)))
     (lambda (B)
       (build-derivations (closure-square-id ,B BTrace_0 Big_0)))
     (lambda (source)
       (build-derivations (root-square-id ,source BTrace_0 Big_0))))))

(define-diagnostic-row
  ROW/S 'S DISJUNCTION-CORPUS/S
  stage-s:disjunction/stage-extension/S/D-decompose
  stage-s:disjunction/stage-extension/S/D-plug-D
  stage-s:disjunction/stage-extension/S/Z-refocus-phase
  diag-s:disjunction/stage-extension/S/diagnostic-D->Z
  diag-s:disjunction/stage-extension/S/diagnostic-Z->D
  diag-s:disjunction/stage-extension/S/diagnostic-readback-Z
  stage-s:disjunction/stage-extension/S/Z-step
  diag-s:disjunction/stage-extension/S/diagnostic-Z-step
  stage-s:disjunction/stage-extension/S/M-machineize
  diag-s:disjunction/stage-extension/S/diagnostic-encode-ZM
  diag-s:disjunction/stage-extension/S/diagnostic-decode-MZ
  diag-s:disjunction/stage-extension/S/diagnostic-readback-M
  diag-s:disjunction/stage-extension/S/diagnostic-ZM-corresponds
  stage-s:disjunction/stage-extension/S/M-step
  diag-s:disjunction/stage-extension/S/diagnostic-M-step
  diag-s:disjunction/stage-extension/S/diagnostic-ZM-square
  stage-s:disjunction/stage-extension/S/B-compress
  diag-s:disjunction/stage-extension/S/diagnostic-encode-MB
  diag-s:disjunction/stage-extension/S/diagnostic-decode-BM
  diag-s:disjunction/stage-extension/S/diagnostic-readback-B
  diag-s:disjunction/stage-extension/S/diagnostic-MB-corresponds
  diag-s:disjunction/stage-extension/S/diagnostic-replay-M
  stage-s:disjunction/stage-extension/S/B-step
  diag-s:disjunction/stage-extension/S/diagnostic-B-step
  diag-s:disjunction/stage-extension/S/diagnostic-MB-square
  stage-s:disjunction/stage-extension/S/B-span-labels
  stage-s:disjunction/stage-extension/S/Big-evaluate
  diag-s:disjunction/stage-extension/S/diagnostic-initialize-B
  stage-s:disjunction/stage-extension/S/Big-promote
  diag-s:disjunction/stage-extension/S/diagnostic-Big-evaluate
  diag-s:disjunction/stage-extension/S/diagnostic-close-B
  diag-s:disjunction/stage-extension/S/diagnostic-flatten-BTrace
  diag-s:disjunction/stage-extension/S/diagnostic-readback-Big
  diag-s:disjunction/stage-extension/S/diagnostic-B-Big-unfold
  diag-s:disjunction/stage-extension/S/diagnostic-B-Big-closure
  diag-s:disjunction/stage-extension/S/diagnostic-B-Big-root)

(define-diagnostic-row
  ROW/E 'E DISJUNCTION-CORPUS/E
  stage-e:disjunction/stage-extension/E/D-decompose
  stage-e:disjunction/stage-extension/E/D-plug-D
  stage-e:disjunction/stage-extension/E/Z-refocus-phase
  diag-e:disjunction/stage-extension/E/diagnostic-D->Z
  diag-e:disjunction/stage-extension/E/diagnostic-Z->D
  diag-e:disjunction/stage-extension/E/diagnostic-readback-Z
  stage-e:disjunction/stage-extension/E/Z-step
  diag-e:disjunction/stage-extension/E/diagnostic-Z-step
  stage-e:disjunction/stage-extension/E/M-machineize
  diag-e:disjunction/stage-extension/E/diagnostic-encode-ZM
  diag-e:disjunction/stage-extension/E/diagnostic-decode-MZ
  diag-e:disjunction/stage-extension/E/diagnostic-readback-M
  diag-e:disjunction/stage-extension/E/diagnostic-ZM-corresponds
  stage-e:disjunction/stage-extension/E/M-step
  diag-e:disjunction/stage-extension/E/diagnostic-M-step
  diag-e:disjunction/stage-extension/E/diagnostic-ZM-square
  stage-e:disjunction/stage-extension/E/B-compress
  diag-e:disjunction/stage-extension/E/diagnostic-encode-MB
  diag-e:disjunction/stage-extension/E/diagnostic-decode-BM
  diag-e:disjunction/stage-extension/E/diagnostic-readback-B
  diag-e:disjunction/stage-extension/E/diagnostic-MB-corresponds
  diag-e:disjunction/stage-extension/E/diagnostic-replay-M
  stage-e:disjunction/stage-extension/E/B-step
  diag-e:disjunction/stage-extension/E/diagnostic-B-step
  diag-e:disjunction/stage-extension/E/diagnostic-MB-square
  stage-e:disjunction/stage-extension/E/B-span-labels
  stage-e:disjunction/stage-extension/E/Big-evaluate
  diag-e:disjunction/stage-extension/E/diagnostic-initialize-B
  stage-e:disjunction/stage-extension/E/Big-promote
  diag-e:disjunction/stage-extension/E/diagnostic-Big-evaluate
  diag-e:disjunction/stage-extension/E/diagnostic-close-B
  diag-e:disjunction/stage-extension/E/diagnostic-flatten-BTrace
  diag-e:disjunction/stage-extension/E/diagnostic-readback-Big
  diag-e:disjunction/stage-extension/E/diagnostic-B-Big-unfold
  diag-e:disjunction/stage-extension/E/diagnostic-B-Big-closure
  diag-e:disjunction/stage-extension/E/diagnostic-B-Big-root)

(define-diagnostic-row
  ROW/N 'N DISJUNCTION-CORPUS/N
  stage-n:disjunction/stage-extension/N/D-decompose
  stage-n:disjunction/stage-extension/N/D-plug-D
  stage-n:disjunction/stage-extension/N/Z-refocus-phase
  diag-n:disjunction/stage-extension/N/diagnostic-D->Z
  diag-n:disjunction/stage-extension/N/diagnostic-Z->D
  diag-n:disjunction/stage-extension/N/diagnostic-readback-Z
  stage-n:disjunction/stage-extension/N/Z-step
  diag-n:disjunction/stage-extension/N/diagnostic-Z-step
  stage-n:disjunction/stage-extension/N/M-machineize
  diag-n:disjunction/stage-extension/N/diagnostic-encode-ZM
  diag-n:disjunction/stage-extension/N/diagnostic-decode-MZ
  diag-n:disjunction/stage-extension/N/diagnostic-readback-M
  diag-n:disjunction/stage-extension/N/diagnostic-ZM-corresponds
  stage-n:disjunction/stage-extension/N/M-step
  diag-n:disjunction/stage-extension/N/diagnostic-M-step
  diag-n:disjunction/stage-extension/N/diagnostic-ZM-square
  stage-n:disjunction/stage-extension/N/B-compress
  diag-n:disjunction/stage-extension/N/diagnostic-encode-MB
  diag-n:disjunction/stage-extension/N/diagnostic-decode-BM
  diag-n:disjunction/stage-extension/N/diagnostic-readback-B
  diag-n:disjunction/stage-extension/N/diagnostic-MB-corresponds
  diag-n:disjunction/stage-extension/N/diagnostic-replay-M
  stage-n:disjunction/stage-extension/N/B-step
  diag-n:disjunction/stage-extension/N/diagnostic-B-step
  diag-n:disjunction/stage-extension/N/diagnostic-MB-square
  stage-n:disjunction/stage-extension/N/B-span-labels
  stage-n:disjunction/stage-extension/N/Big-evaluate
  diag-n:disjunction/stage-extension/N/diagnostic-initialize-B
  stage-n:disjunction/stage-extension/N/Big-promote
  diag-n:disjunction/stage-extension/N/diagnostic-Big-evaluate
  diag-n:disjunction/stage-extension/N/diagnostic-close-B
  diag-n:disjunction/stage-extension/N/diagnostic-flatten-BTrace
  diag-n:disjunction/stage-extension/N/diagnostic-readback-Big
  diag-n:disjunction/stage-extension/N/diagnostic-B-Big-unfold
  diag-n:disjunction/stage-extension/N/diagnostic-B-Big-closure
  diag-n:disjunction/stage-extension/N/diagnostic-B-Big-root)

(define ROWS (list ROW/S ROW/E ROW/N))

(define (check-diagnostics row source)
  (define D
    (only 'diagnostic-D (outputs ((diagnostic-row-decompose row) source) 1)))
  (define Z ((diagnostic-row-refocus row) D))
  (define M ((diagnostic-row-machineize row) Z))
  (define B ((diagnostic-row-compress row) M))
  (define Bigs (outputs ((diagnostic-row-big-evaluate row) source) 1))
  (define Big (only 'diagnostic-Big Bigs))

  (define Z-step-proofs ((diagnostic-row-Z-step row) Z))
  (match-define (list (list rule-name Z-next))
    (outputs Z-step-proofs 2))
  (define M-step-proofs ((diagnostic-row-M-step row) M))
  (match-define (list (list M-rule-name M-next))
    (outputs M-step-proofs 2))
  (check-equal? M-rule-name rule-name)
  (check-equal? M-next ((diagnostic-row-encode-ZM row) Z-next))

  (define B-step-proofs ((diagnostic-row-B-step row) B))
  (match-define (list (list span B-next))
    (outputs B-step-proofs 2))
  (define replay-proofs ((diagnostic-row-replay-proofs row) M))
  (match-define (list (list replay-span replay-M-next))
    (outputs replay-proofs 2))
  (check-equal? replay-span span)
  (check-equal? replay-M-next ((diagnostic-row-decode-BM row) B-next))

  (check-equal? ((diagnostic-row-plug-D row) D) source)
  (check-equal? ((diagnostic-row-D->Z row) D) Z)
  (check-equal? ((diagnostic-row-Z->D row) Z) D)
  (check-equal? ((diagnostic-row-readback-Z row) Z) source)
  (check-equal? ((diagnostic-row-encode-ZM row) Z) M)
  (check-equal? ((diagnostic-row-decode-MZ row) M) Z)
  (check-equal? ((diagnostic-row-readback-M row) M) source)
  (check-proof-arguments
   ((diagnostic-row-ZM-corresponds-proofs row) Z)
   (list (list Z M)))
  (check-proof-arguments
   ((diagnostic-row-ZM-square-proofs row) Z)
   (list (list Z rule-name Z-next M M-next)))
  (check-equal? ((diagnostic-row-encode-MB row) M) B)
  (check-equal? ((diagnostic-row-decode-BM row) B) M)
  (check-equal? ((diagnostic-row-readback-B row) B) source)
  (check-proof-arguments
   ((diagnostic-row-MB-corresponds-proofs row) M)
   (list (list M B)))
  (check-proof-arguments
   replay-proofs
   (list (list M span replay-M-next)))
  (check-proof-arguments
   ((diagnostic-row-MB-square-proofs row) B)
   (list (list B span B-next M replay-M-next)))
  (check-equal? (outputs ((diagnostic-row-initialize-B row) source) 1)
                (list B))
  (check-equal? (outputs ((diagnostic-row-promote row) B) 1) Bigs)
  (for ([Big (in-list Bigs)])
    (check-equal? ((diagnostic-row-readback-Big row) Big)
                  (match Big [`(BigFinal ,terminal) terminal])))
  (check-proof-arguments
   ((diagnostic-row-unfold-square-proofs row) B)
   (list (list B span B-next Big)))

  (check-equal?
   (canonical (outputs Z-step-proofs 2))
   (canonical (outputs ((diagnostic-row-Z-step-spec row) Z) 2)))
  (check-equal?
   (canonical (outputs M-step-proofs 2))
   (canonical (outputs ((diagnostic-row-M-step-spec row) M) 2)))
  (check-equal?
   (canonical (outputs B-step-proofs 2))
   (canonical (outputs ((diagnostic-row-B-step-spec row) B) 2))))

(define (check-B-diagnostic-suffixes row B spans expected-big)
  (check-proof-arguments
   ((diagnostic-row-closure-square-proofs row) B)
   (list (list B spans expected-big)))
  (match spans
    ['()
     (check-equal? ((diagnostic-row-B-step row) B) '())]
    [(cons expected-span remaining-spans)
     (define B-step-proofs ((diagnostic-row-B-step row) B))
     (match-define (list (list actual-span B-next))
       (outputs B-step-proofs 2))
     (check-equal? actual-span expected-span)
     (define M ((diagnostic-row-decode-BM row) B))
     (define M-next ((diagnostic-row-decode-BM row) B-next))
     (check-proof-arguments
      ((diagnostic-row-replay-proofs row) M)
      (list (list M actual-span M-next)))
     (check-proof-arguments
      ((diagnostic-row-MB-square-proofs row) B)
      (list (list B actual-span B-next M M-next)))
     (check-proof-arguments
      ((diagnostic-row-unfold-square-proofs row) B)
      (list (list B actual-span B-next expected-big)))
     (check-B-diagnostic-suffixes
      row B-next remaining-spans expected-big)]))

(define GENERATED-DISJUNCTION-TRANSPORT-DIAGNOSTICS-TESTS
  (test-suite
   "secondary generated Disjunction codec and readback diagnostics"

   (test-case "all eighteen representatives agree with secondary transports"
     (for ([row (in-list ROWS)])
       (for ([pair
              (in-list
               (disjunction-row-corpus-rule-sources
                (diagnostic-row-corpus row)))])
         (check-diagnostics row (second pair)))))

   (test-case "complete-state copying agrees with secondary transports"
     (for ([row (in-list ROWS)])
       (check-diagnostics
        row
        (disjunction-rule-case-source
         (disjunction-row-corpus-complete-state-copy
          (diagnostic-row-corpus row))))))

   (test-case "five finite diagnostics retain exact BTrace evidence"
     (for ([row (in-list ROWS)])
       (for ([trace-case
              (in-list
               (disjunction-row-corpus-finite-traces
                (diagnostic-row-corpus row)))])
         (define source (disjunction-trace-case-source trace-case))
         (define terminal (disjunction-trace-case-terminal trace-case))
         (define expected-spans (disjunction-trace-case-spans trace-case))
         (define expected-big `(BigFinal ,terminal))
         (check-diagnostics row source)
         (define spec
           (outputs ((diagnostic-row-big-spec row) source) 2))
         (check-equal? spec
                       (list (list expected-spans expected-big)))
         (check-proof-arguments
          ((diagnostic-row-root-square-proofs row) source)
          (list (list source expected-spans expected-big)))
         (check-equal?
          ((diagnostic-row-flatten row) expected-spans)
          (disjunction-trace-case-labels trace-case))
         (define B
           (only 'trace-initial-B
                 (outputs
                  ((diagnostic-row-initialize-B row) source)
                  1)))
         (check-B-diagnostic-suffixes row B expected-spans expected-big)
         (check-equal?
          (outputs ((diagnostic-row-close-B row) B) 2)
          (list (list expected-spans terminal))))))))

(module+ test
  (run-tests GENERATED-DISJUNCTION-TRANSPORT-DIAGNOSTICS-TESTS))
