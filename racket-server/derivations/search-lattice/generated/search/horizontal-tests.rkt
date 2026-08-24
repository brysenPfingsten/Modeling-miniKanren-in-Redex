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

(provide GENERATED-SEARCH-HORIZONTAL-TESTS)

;; Proof observations are sorted as multisets.  Length checks happen before
;; every comparison, so equal duplicate derivations remain duplicate evidence.
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
   big-promote-proofs)
  #:transparent)

(define-syntax-rule
  (define-stage-row
    row-id row-name corpus-id source-raw-id
    D-decompose-id D-step-id
    Z-refocus-id Z-step-id
    M-machineize-id M-step-id
    B-compress-id B-span-labels-id B-singleton-id B-step-id
    Big-dispatch-one-id Big-control-one-id
    Big-evaluate-id Big-promote-id)
  (define row-id
    (stage-row
     row-name
     corpus-id
     source-raw-id
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
     (lambda (B)
       (build-derivations (B-step-id ,B TransitionSpan B_next)))
     (lambda (work focus)
       (build-derivations
        (Big-dispatch-one-id ,work ,focus BigNext)))
     (lambda (control)
       (build-derivations (Big-control-one-id ,control ControlNext)))
     (lambda (source)
       (build-derivations (Big-evaluate-id ,source Big)))
     (lambda (B)
       (build-derivations (Big-promote-id ,B Big))))))

(define-stage-row
  ROW/S 'S SEARCH-CORPUS/S source-s:raw-successors/generated/search/s
  stage-s:search/delay-stage-extension/S/D-decompose
  stage-s:search/delay-stage-extension/S/D-step
  stage-s:search/delay-stage-extension/S/Z-refocus-phase
  stage-s:search/delay-stage-extension/S/Z-step
  stage-s:search/delay-stage-extension/S/M-machineize
  stage-s:search/delay-stage-extension/S/M-step
  stage-s:search/delay-stage-extension/S/B-compress
  stage-s:search/delay-stage-extension/S/B-span-labels
  stage-s:search/delay-stage-extension/S/B-singleton
  stage-s:search/delay-stage-extension/S/B-step
  stage-s:search/delay-stage-extension/S/Big-dispatch-one
  stage-s:search/delay-stage-extension/S/Big-control-one
  stage-s:search/delay-stage-extension/S/Big-evaluate
  stage-s:search/delay-stage-extension/S/Big-promote)

(define-stage-row
  ROW/E 'E SEARCH-CORPUS/E source-e:raw-successors/generated/search/e
  stage-e:search/delay-stage-extension/E/D-decompose
  stage-e:search/delay-stage-extension/E/D-step
  stage-e:search/delay-stage-extension/E/Z-refocus-phase
  stage-e:search/delay-stage-extension/E/Z-step
  stage-e:search/delay-stage-extension/E/M-machineize
  stage-e:search/delay-stage-extension/E/M-step
  stage-e:search/delay-stage-extension/E/B-compress
  stage-e:search/delay-stage-extension/E/B-span-labels
  stage-e:search/delay-stage-extension/E/B-singleton
  stage-e:search/delay-stage-extension/E/B-step
  stage-e:search/delay-stage-extension/E/Big-dispatch-one
  stage-e:search/delay-stage-extension/E/Big-control-one
  stage-e:search/delay-stage-extension/E/Big-evaluate
  stage-e:search/delay-stage-extension/E/Big-promote)

(define-stage-row
  ROW/N 'N SEARCH-CORPUS/N source-n:raw-successors/generated/search/n
  stage-n:search/delay-stage-extension/N/D-decompose
  stage-n:search/delay-stage-extension/N/D-step
  stage-n:search/delay-stage-extension/N/Z-refocus-phase
  stage-n:search/delay-stage-extension/N/Z-step
  stage-n:search/delay-stage-extension/N/M-machineize
  stage-n:search/delay-stage-extension/N/M-step
  stage-n:search/delay-stage-extension/N/B-compress
  stage-n:search/delay-stage-extension/N/B-span-labels
  stage-n:search/delay-stage-extension/N/B-singleton
  stage-n:search/delay-stage-extension/N/B-step
  stage-n:search/delay-stage-extension/N/Big-dispatch-one
  stage-n:search/delay-stage-extension/N/Big-control-one
  stage-n:search/delay-stage-extension/N/Big-evaluate
  stage-n:search/delay-stage-extension/N/Big-promote)

(define ROWS (list ROW/S ROW/E ROW/N))

(define (source->D row source)
  (only 'source->D
        (proof-observations ((stage-row-decompose-proofs row) source) 1)))

(define (source->Z row source)
  ((stage-row-refocus row) (source->D row source)))

(define (source->M row source)
  ((stage-row-machineize row) (source->Z row source)))

(define (source->B row source)
  ((stage-row-compress row) (source->M row source)))

(define (check-step-proof who proofs input label output)
  (check-equal? (length proofs) 1 (~a who " multiplicity"))
  (check-equal?
   (canonical-top-level-proof-multiset proofs)
   (list (list 'judgment input label output))
   (~a who)))

(define (check-case-chain row label source target)
  (check-equal? ((stage-row-source-raw row) source)
                (list (list label target)))

  (define D-proofs ((stage-row-decompose-proofs row) source))
  (define D (only 'case-D (proof-observations D-proofs 1)))
  (check-equal? (canonical-top-level-proof-multiset D-proofs)
                (list (list 'judgment source D)))
  (define D-next (source->D row target))
  (check-step-proof 'D-step ((stage-row-d-step-proofs row) D)
                    D label D-next)

  (define Z ((stage-row-refocus row) D))
  (define Z-next (source->Z row target))
  (check-step-proof 'Z-step ((stage-row-z-step-proofs row) Z)
                    Z label Z-next)

  (define M ((stage-row-machineize row) Z))
  (define M-next (source->M row target))
  (check-step-proof 'M-step ((stage-row-m-step-proofs row) M)
                    M label M-next)

  (define B ((stage-row-compress row) M))
  (define B-step-proofs ((stage-row-b-step-proofs row) B))
  (match-define (list (list span B-next))
    (proof-observations B-step-proofs 2))
  (define span-labels ((stage-row-span-labels row) span))
  (check-equal? (first span-labels) label)
  (check-equal?
   B-next
   (source->B
    row
    (advance-source (stage-row-source-raw row) source span-labels)))
  (check-step-proof 'B-step B-step-proofs B span B-next)

  (when (member label SEARCH-B-SINGLETON-RULE-NAMES)
    (check-equal? span `(transition-span ,label))
    (define singleton-proofs ((stage-row-singleton-proofs row) B))
    (check-equal? (length singleton-proofs) 1)
    (check-equal? (canonical-top-level-proof-multiset singleton-proofs)
                  (canonical-top-level-proof-multiset B-step-proofs)))

  (define evaluated ((stage-row-big-evaluate-proofs row) source))
  (define promoted ((stage-row-big-promote-proofs row) B))
  (check-equal? (length evaluated) 1)
  (check-equal? (length promoted) 1)
  (check-equal? (proof-observations evaluated 1)
                (proof-observations promoted 1)))

(define (check-big-entry row B expected-count)
  (match B
    [`(BRun ,work ,focus)
     (check-equal?
      (length ((stage-row-big-dispatch-one-proofs row) work focus))
      expected-count)]
    [`(BFrontier ,frontier ,spine)
     (check-equal?
      (length
       ((stage-row-big-control-one-proofs row)
        `(BigFrontierControl ,frontier ,spine)))
      expected-count)]
    [_ (void)]))

(define (check-finite-trace row trace-case)
  (define source (search-trace-case-source trace-case))
  (define labels (search-trace-case-labels trace-case))
  (define spans (search-trace-case-spans trace-case))
  (define terminal (search-trace-case-terminal trace-case))
  (define expected-big `(BigFinal ,terminal))

  (define-values (M-final observed-labels)
    (for/fold ([M (source->M row source)] [seen '()])
              ([label (in-list labels)])
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
  (check-big-entry row B0 1)
  (define-values (B-final observed-spans)
    (for/fold ([B B0] [seen '()]) ([expected-span (in-list spans)])
      (check-equal?
       (proof-observations ((stage-row-big-promote-proofs row) B) 1)
       (list expected-big))
      (define proofs ((stage-row-b-step-proofs row) B))
      (match-define (list (list actual-span next))
        (proof-observations proofs 2))
      (check-equal? actual-span expected-span)
      (check-step-proof 'trace-B-step proofs B actual-span next)
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
   (~a "generated Search horizontal row " (stage-row-name row))

   (test-case "all twenty-one inherited labels cross D Z M B and Big"
     (for ([representative
            (in-list
             (search-row-corpus-rule-sources (stage-row-corpus row)))])
       (match-define (list label source) representative)
       (match-define (list (list actual-label target))
         ((stage-row-source-raw row) source))
       (check-equal? actual-label label)
       (check-case-chain row label source target)))

   (test-case "all eight mixed witnesses retain exact horizontal proofs"
     (define mixed
       (search-row-corpus-mixed-feature-cases (stage-row-corpus row)))
     (check-equal? (map search-mixed-case-name mixed)
                   EXPECTED-SEARCH-MIXED-CASE-NAMES)
     (for ([case (in-list mixed)])
       (check-case-chain
        row
        (search-mixed-case-label case)
        (search-mixed-case-source case)
        (search-mixed-case-target case))))

   (test-case "the scheduler barrier enters no horizontal stage or Big"
     (define source
       (search-row-corpus-scheduler-barrier (stage-row-corpus row)))
     (check-equal? ((stage-row-source-raw row) source) '())
     (check-equal? ((stage-row-decompose-proofs row) source) '())
     (check-equal? ((stage-row-big-evaluate-proofs row) source) '()))

   (test-case "three finite traces preserve spans and unique Big finals"
     (define traces
       (search-row-corpus-finite-traces (stage-row-corpus row)))
     (check-equal? (map search-trace-case-name traces)
                   EXPECTED-SEARCH-TRACE-NAMES)
     (for ([trace-case (in-list traces)])
       (check-finite-trace row trace-case)))))

(define GENERATED-SEARCH-HORIZONTAL-TESTS
  (test-suite
   "generated Search direct horizontal stages"
   (make-row-suite ROW/S)
   (make-row-suite ROW/E)
   (make-row-suite ROW/N)))

(module+ test
  (run-tests GENERATED-SEARCH-HORIZONTAL-TESTS))
