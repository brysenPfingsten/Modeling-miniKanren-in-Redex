#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in source-s: "source/s.rkt")
         (prefix-in source-e: "source/e.rkt")
         (prefix-in source-n: "source/n.rkt")
         (prefix-in stage-s: "stages/s.rkt")
         (prefix-in stage-e: "stages/e.rkt")
         (prefix-in stage-n: "stages/n.rkt")
         "corpus.rkt")

(provide GENERATED-DELAY-HORIZONTAL-TESTS)

(define EXPECTED-DELAY-TRACE-NAMES
  '(suspend-success
    bubble-success
    suspend-failure
    nested-suspend
    fresh-inside-suspend
    unused-fresh-outside-delayed-failure))

(define (canonical-top-level-proof-multiset proofs)
  (sort
   (for/list ([proof (in-list proofs)])
     (match (derivation-term proof)
       [(cons _judgment arguments) (cons 'judgment arguments)]))
   string<?
   #:key ~s))

(define (proof-observations proofs output-count)
  (for/list ([proof (in-list proofs)])
    (define outputs (take-right (derivation-term proof) output-count))
    (if (= output-count 1) (first outputs) outputs)))

(define (only who values)
  (match values
    [(list value) value]
    [_ (error who "expected exactly one raw proof, received ~e" values)]))

(define (trace-step raw source expected-label)
  (match (raw source)
    [(list (list label target))
     (check-equal? label expected-label)
     target]
    [other
     (error 'trace-step "expected one source step, received ~e" other)]))

(define (advance-source raw source labels)
  (for/fold ([current source]) ([label (in-list labels)])
    (trace-step raw current label)))

(struct stage-row
  (name
   corpus
   source-raw
   source-member?
   decompose-proofs
   d-step-proofs
   refocus
   z-step-proofs
   machineize
   m-step-proofs
   compress
   span-labels
   singleton-proofs
   b-step-proofs
   big-dispatch-one-proofs
   big-control-one-proofs
   big-evaluate-proofs
   big-promote-proofs
   D?
   Z?
   M?
   B?
   Big?)
  #:transparent)

(define-syntax-rule
  (define-stage-row
    row-id row-name corpus-id source-raw-id source-language-id
    D-language-id D-decompose-id D-step-id
    Z-language-id Z-refocus-id Z-step-id
    M-language-id M-machineize-id M-step-id
    B-language-id B-compress-id B-span-labels-id B-singleton-id B-step-id
    Big-language-id Big-dispatch-one-id Big-control-one-id
    Big-evaluate-id Big-promote-id)
  (define row-id
    (stage-row
     row-name
     corpus-id
     source-raw-id
     (lambda (source) (redex-match? source-language-id F source))
     (lambda (source) (build-derivations (D-decompose-id ,source D)))
     (lambda (D) (build-derivations (D-step-id ,D RuleName D_next)))
     (lambda (D) (term (Z-refocus-id ,D)))
     (lambda (Z) (build-derivations (Z-step-id ,Z RuleName Z_next)))
     (lambda (Z) (term (M-machineize-id ,Z)))
     (lambda (M) (build-derivations (M-step-id ,M RuleName M_next)))
     (lambda (M) (term (B-compress-id ,M)))
     (lambda (span) (term (B-span-labels-id ,span)))
     (lambda (B)
       (build-derivations (B-singleton-id ,B TransitionSpan B_next)))
     (lambda (B) (build-derivations (B-step-id ,B TransitionSpan B_next)))
     (lambda (work focus)
       (build-derivations
        (Big-dispatch-one-id ,work ,focus BigNext)))
     (lambda (control)
       (build-derivations (Big-control-one-id ,control ControlNext)))
     (lambda (source)
       (build-derivations (Big-evaluate-id ,source Big)))
     (lambda (B) (build-derivations (Big-promote-id ,B Big)))
     (lambda (D) (redex-match? D-language-id D D))
     (lambda (Z) (redex-match? Z-language-id Z Z))
     (lambda (M) (redex-match? M-language-id M M))
     (lambda (B) (redex-match? B-language-id B B))
     (lambda (Big) (redex-match? Big-language-id Big Big)))))

(define-stage-row
  ROW/S 'S DELAY-CORPUS/S
  source-s:raw-successors/generated/delay/s source-s:generated-delay-s-lang
  stage-s:delay/stage-extension/S/D-language
  stage-s:delay/stage-extension/S/D-decompose
  stage-s:delay/stage-extension/S/D-step
  stage-s:delay/stage-extension/S/Z-language
  stage-s:delay/stage-extension/S/Z-refocus-phase
  stage-s:delay/stage-extension/S/Z-step
  stage-s:delay/stage-extension/S/M-language
  stage-s:delay/stage-extension/S/M-machineize
  stage-s:delay/stage-extension/S/M-step
  stage-s:delay/stage-extension/S/B-language
  stage-s:delay/stage-extension/S/B-compress
  stage-s:delay/stage-extension/S/B-span-labels
  stage-s:delay/stage-extension/S/B-singleton
  stage-s:delay/stage-extension/S/B-step
  stage-s:delay/stage-extension/S/Big-language
  stage-s:delay/stage-extension/S/Big-dispatch-one
  stage-s:delay/stage-extension/S/Big-control-one
  stage-s:delay/stage-extension/S/Big-evaluate
  stage-s:delay/stage-extension/S/Big-promote)

(define-stage-row
  ROW/E 'E DELAY-CORPUS/E
  source-e:raw-successors/generated/delay/e source-e:generated-delay-e-lang
  stage-e:delay/stage-extension/E/D-language
  stage-e:delay/stage-extension/E/D-decompose
  stage-e:delay/stage-extension/E/D-step
  stage-e:delay/stage-extension/E/Z-language
  stage-e:delay/stage-extension/E/Z-refocus-phase
  stage-e:delay/stage-extension/E/Z-step
  stage-e:delay/stage-extension/E/M-language
  stage-e:delay/stage-extension/E/M-machineize
  stage-e:delay/stage-extension/E/M-step
  stage-e:delay/stage-extension/E/B-language
  stage-e:delay/stage-extension/E/B-compress
  stage-e:delay/stage-extension/E/B-span-labels
  stage-e:delay/stage-extension/E/B-singleton
  stage-e:delay/stage-extension/E/B-step
  stage-e:delay/stage-extension/E/Big-language
  stage-e:delay/stage-extension/E/Big-dispatch-one
  stage-e:delay/stage-extension/E/Big-control-one
  stage-e:delay/stage-extension/E/Big-evaluate
  stage-e:delay/stage-extension/E/Big-promote)

(define-stage-row
  ROW/N 'N DELAY-CORPUS/N
  source-n:raw-successors/generated/delay/n source-n:generated-delay-n-lang
  stage-n:delay/stage-extension/N/D-language
  stage-n:delay/stage-extension/N/D-decompose
  stage-n:delay/stage-extension/N/D-step
  stage-n:delay/stage-extension/N/Z-language
  stage-n:delay/stage-extension/N/Z-refocus-phase
  stage-n:delay/stage-extension/N/Z-step
  stage-n:delay/stage-extension/N/M-language
  stage-n:delay/stage-extension/N/M-machineize
  stage-n:delay/stage-extension/N/M-step
  stage-n:delay/stage-extension/N/B-language
  stage-n:delay/stage-extension/N/B-compress
  stage-n:delay/stage-extension/N/B-span-labels
  stage-n:delay/stage-extension/N/B-singleton
  stage-n:delay/stage-extension/N/B-step
  stage-n:delay/stage-extension/N/Big-language
  stage-n:delay/stage-extension/N/Big-dispatch-one
  stage-n:delay/stage-extension/N/Big-control-one
  stage-n:delay/stage-extension/N/Big-evaluate
  stage-n:delay/stage-extension/N/Big-promote)

(define ROWS (list ROW/S ROW/E ROW/N))

(define (source->D row source)
  (only 'source->D (proof-observations ((stage-row-decompose-proofs row) source) 1)))

(define (source->Z row source)
  ((stage-row-refocus row) (source->D row source)))

(define (source->M row source)
  ((stage-row-machineize row) (source->Z row source)))

(define (source->B row source)
  ((stage-row-compress row) (source->M row source)))

(define (check-step-proof who proofs input label output)
  (check-equal?
   (canonical-top-level-proof-multiset proofs)
   (list (list 'judgment input label output))
   (~a who)))

(define (check-rule-chain row rule-name)
  (define source
    (delay-row-source-ref (stage-row-corpus row) rule-name))
  (match-define (list (list source-label target))
    ((stage-row-source-raw row) source))
  (check-equal? source-label rule-name)

  (define D-proofs ((stage-row-decompose-proofs row) source))
  (define D (only 'rule-D (proof-observations D-proofs 1)))
  (check-equal? (canonical-top-level-proof-multiset D-proofs)
                (list (list 'judgment source D)))
  (define D-next (source->D row target))
  (check-step-proof 'D-step ((stage-row-d-step-proofs row) D)
                    D rule-name D-next)

  (define Z ((stage-row-refocus row) D))
  (define Z-next (source->Z row target))
  (check-step-proof 'Z-step ((stage-row-z-step-proofs row) Z)
                    Z rule-name Z-next)

  (define M ((stage-row-machineize row) Z))
  (define M-next (source->M row target))
  (check-step-proof 'M-step ((stage-row-m-step-proofs row) M)
                    M rule-name M-next)

  (define B ((stage-row-compress row) M))
  (define B-step-proofs ((stage-row-b-step-proofs row) B))
  (match-define (list (list span B-next))
    (proof-observations B-step-proofs 2))
  (define span-labels ((stage-row-span-labels row) span))
  (check-equal? (first span-labels) rule-name)
  (define source-after-span
    (advance-source (stage-row-source-raw row) source span-labels))
  (check-equal? B-next (source->B row source-after-span))
  (check-step-proof 'B-step B-step-proofs B span B-next)

  (when (member rule-name DELAY-OWNED-RULE-NAMES)
    (check-equal?
     (canonical-top-level-proof-multiset
      ((stage-row-singleton-proofs row) B))
     (canonical-top-level-proof-multiset B-step-proofs))
    (check-equal? span `(transition-span ,rule-name)))

  (define evaluated ((stage-row-big-evaluate-proofs row) source))
  (define promoted ((stage-row-big-promote-proofs row) B))
  (check-equal? (length evaluated) 1)
  (check-equal? (length promoted) 1)
  (check-equal? (proof-observations evaluated 1)
                (proof-observations promoted 1)))

(define (check-big-entry row B)
  (match B
    [`(BRun ,work ,focus)
     (check-equal?
      (length ((stage-row-big-dispatch-one-proofs row) work focus))
      1)]
    [`(BFrontier ,frontier ,spine)
     (check-equal?
      (length
       ((stage-row-big-control-one-proofs
         row)
        `(BigFrontierControl ,frontier ,spine)))
      1)]
    [_ (void)]))

(define (check-finite-trace row trace-case)
  (define source (delay-trace-case-source trace-case))
  (define labels (delay-trace-case-labels trace-case))
  (define spans (delay-trace-case-spans trace-case))
  (define terminal (delay-trace-case-terminal trace-case))
  (define expected-big `(BigFinal ,terminal))

  (define M0 (source->M row source))
  (define-values (M-final observed-labels)
    (for/fold ([M M0] [seen '()]) ([label (in-list labels)])
      (define proofs ((stage-row-m-step-proofs row) M))
      (match-define (list (list actual-label next))
        (proof-observations proofs 2))
      (check-equal? actual-label label)
      (check-step-proof 'trace-M-step proofs M label next)
      (values next (append seen (list actual-label)))))
  (check-equal? observed-labels labels)
  (check-equal? M-final (source->M row terminal))
  (check-equal? ((stage-row-m-step-proofs row) M-final) '())

  (define B0 (source->B row source))
  (check-big-entry row B0)
  (define-values (B-final observed-spans)
    (for/fold ([B B0] [seen '()])
              ([span (in-list spans)] [suffix-index (in-naturals)])
      (check-equal?
       (proof-observations ((stage-row-big-promote-proofs row) B) 1)
       (list expected-big))
      (define proofs ((stage-row-b-step-proofs row) B))
      (match-define (list (list actual-span next))
        (proof-observations proofs 2))
      (check-equal? actual-span span)
      (check-step-proof 'trace-B-step proofs B span next)
      (values next (append seen (list actual-span)))))
  (check-equal? observed-spans spans)
  (check-equal? B-final (source->B row terminal))
  (check-equal? ((stage-row-b-step-proofs row) B-final) '())
  (check-equal?
   (proof-observations ((stage-row-big-promote-proofs row) B-final) 1)
   (list expected-big))
  (check-equal?
   (proof-observations ((stage-row-big-evaluate-proofs row) source) 1)
   (list expected-big)))

(define (make-row-suite row)
  (test-suite
   (~a "generated Delay horizontal row " (stage-row-name row))

   (test-case "all sixteen rules cross direct R-D-Z-M-B-Big arrows"
     (for ([rule-name (in-list DELAY-RULE-NAMES)])
       (check-rule-chain row rule-name)))

   (test-case "six finite traces preserve every label span and B suffix"
     (define trace-cases
       (delay-row-corpus-finite-traces (stage-row-corpus row)))
     (check-equal? (map delay-trace-case-name trace-cases)
                   EXPECTED-DELAY-TRACE-NAMES)
     (for ([trace-case (in-list trace-cases)])
       (check-finite-trace row trace-case)))

   (test-case "all selected carriers expose their phase-specific grammar"
     (for ([source-pair
            (in-list
             (delay-row-corpus-rule-sources (stage-row-corpus row)))])
       (define source (second source-pair))
       (define D (source->D row source))
       (define Z ((stage-row-refocus row) D))
       (define M ((stage-row-machineize row) Z))
       (define B ((stage-row-compress row) M))
       (define Big
         (only 'grammar-Big
               (proof-observations
                ((stage-row-big-evaluate-proofs row) source)
                1)))
       (check-true ((stage-row-source-member? row) source))
       (check-true ((stage-row-D? row) D))
       (check-true ((stage-row-Z? row) Z))
       (check-true ((stage-row-M? row) M))
       (check-true ((stage-row-B? row) B))
       (check-true ((stage-row-Big? row) Big)))
     (check-false ((stage-row-source-member? row) 'malformed-source))
     (check-false ((stage-row-D? row) 'malformed-D))
     (check-false ((stage-row-Z? row) 'malformed-Z))
     (check-false ((stage-row-M? row) 'malformed-M))
     (check-false ((stage-row-B? row) 'malformed-B))
     (check-false ((stage-row-Big? row) 'malformed-Big)))

   (test-case "duplicate binders inhabit no source or derived carrier"
     (define source
       (delay-row-corpus-duplicate-binder-source (stage-row-corpus row)))
     (match-define `(More ,work) source)
     (define focus (term (More hole)))
     (check-false ((stage-row-source-member? row) source))
     (check-false ((stage-row-D? row) `(DecWork ,work ,focus)))
     (check-false ((stage-row-Z? row) `(ZWork ,work ,focus)))
     (check-false ((stage-row-M? row) `(MWork ,work ,focus)))
     (check-false ((stage-row-B? row) `(BRun ,work ,focus))))))

(define GENERATED-DELAY-HORIZONTAL-TESTS
  (test-suite
   "generated Delay direct horizontal stages"
   (make-row-suite ROW/S)
   (make-row-suite ROW/E)
   (make-row-suite ROW/N)))

(module+ test
  (run-tests GENERATED-DELAY-HORIZONTAL-TESTS))
