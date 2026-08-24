#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in source: "source/n.rkt")
         (prefix-in canonical: "stages/n.rkt")
         (prefix-in reverse: "stages/feature-order/n.rkt")
         "corpus.rkt")

(provide GENERATED-SEARCH-STAGE-FEATURE-ORDER-TESTS)

;; N is the smallest permanent stage-order fixture.  The source order suite
;; separately covers S/E/N; this fixture holds representation fixed and varies
;; only whether Delay or Disjunction is staged first.
(define REPRESENTATIVE-INHERITED-LABELS
  '(succeed force-delay commit-choice-answer))

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

(define (check-proof-multisets
         who canonical-proofs reverse-proofs [expected-count #f])
  (check-equal? (length canonical-proofs) (length reverse-proofs)
                (~a who " route multiplicity"))
  (when expected-count
    (check-equal? (length canonical-proofs) expected-count
                  (~a who " exact multiplicity")))
  (check-equal?
   (canonical-top-level-proof-multiset canonical-proofs)
   (canonical-top-level-proof-multiset reverse-proofs)
   (~a who " proof multiset")))

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

(struct order-stage
  (name
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
   big-evaluate-proofs
   big-promote-proofs)
  #:transparent)

(define-syntax-rule
  (define-order-stage
    stage-id stage-name
    D-decompose-id D-step-id
    Z-refocus-id Z-step-id
    M-machineize-id M-step-id
    B-compress-id B-span-labels-id B-singleton-id B-step-id
    Big-evaluate-id Big-promote-id)
  (define stage-id
    (order-stage
     stage-name
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
     (lambda (source)
       (build-derivations (Big-evaluate-id ,source Big)))
     (lambda (B)
       (build-derivations (Big-promote-id ,B Big))))))

(define-order-stage
  CANONICAL 'canonical
  canonical:search/delay-stage-extension/N/D-decompose
  canonical:search/delay-stage-extension/N/D-step
  canonical:search/delay-stage-extension/N/Z-refocus-phase
  canonical:search/delay-stage-extension/N/Z-step
  canonical:search/delay-stage-extension/N/M-machineize
  canonical:search/delay-stage-extension/N/M-step
  canonical:search/delay-stage-extension/N/B-compress
  canonical:search/delay-stage-extension/N/B-span-labels
  canonical:search/delay-stage-extension/N/B-singleton
  canonical:search/delay-stage-extension/N/B-step
  canonical:search/delay-stage-extension/N/Big-evaluate
  canonical:search/delay-stage-extension/N/Big-promote)

(define-order-stage
  REVERSE 'reverse
  reverse:search/reverse-disjunction-stage-extension/N/D-decompose
  reverse:search/reverse-disjunction-stage-extension/N/D-step
  reverse:search/reverse-disjunction-stage-extension/N/Z-refocus-phase
  reverse:search/reverse-disjunction-stage-extension/N/Z-step
  reverse:search/reverse-disjunction-stage-extension/N/M-machineize
  reverse:search/reverse-disjunction-stage-extension/N/M-step
  reverse:search/reverse-disjunction-stage-extension/N/B-compress
  reverse:search/reverse-disjunction-stage-extension/N/B-span-labels
  reverse:search/reverse-disjunction-stage-extension/N/B-singleton
  reverse:search/reverse-disjunction-stage-extension/N/B-step
  reverse:search/reverse-disjunction-stage-extension/N/Big-evaluate
  reverse:search/reverse-disjunction-stage-extension/N/Big-promote)

(define (stage->D stage source)
  (only
   'stage->D
   (proof-observations ((order-stage-decompose-proofs stage) source) 1)))

(define (stage->Z stage source)
  ((order-stage-refocus stage) (stage->D stage source)))

(define (stage->M stage source)
  ((order-stage-machineize stage) (stage->Z stage source)))

(define (stage->B stage source)
  ((order-stage-compress stage) (stage->M stage source)))

(define (check-order-case label source target)
  (define canonical-D-proofs
    ((order-stage-decompose-proofs CANONICAL) source))
  (define reverse-D-proofs
    ((order-stage-decompose-proofs REVERSE) source))
  (check-proof-multisets
   'D-decompose canonical-D-proofs reverse-D-proofs 1)
  (define canonical-D
    (only 'canonical-D (proof-observations canonical-D-proofs 1)))
  (define reverse-D
    (only 'reverse-D (proof-observations reverse-D-proofs 1)))
  (check-equal? canonical-D reverse-D)

  (define canonical-D-step
    ((order-stage-d-step-proofs CANONICAL) canonical-D))
  (define reverse-D-step
    ((order-stage-d-step-proofs REVERSE) reverse-D))
  (check-proof-multisets 'D-step canonical-D-step reverse-D-step 1)
  (check-equal? (proof-observations canonical-D-step 2)
                (list (list label (stage->D CANONICAL target))))

  (define canonical-Z ((order-stage-refocus CANONICAL) canonical-D))
  (define reverse-Z ((order-stage-refocus REVERSE) reverse-D))
  (check-equal? canonical-Z reverse-Z)
  (define canonical-Z-step
    ((order-stage-z-step-proofs CANONICAL) canonical-Z))
  (define reverse-Z-step
    ((order-stage-z-step-proofs REVERSE) reverse-Z))
  (check-proof-multisets 'Z-step canonical-Z-step reverse-Z-step 1)
  (check-equal? (proof-observations canonical-Z-step 2)
                (list (list label (stage->Z CANONICAL target))))

  (define canonical-M ((order-stage-machineize CANONICAL) canonical-Z))
  (define reverse-M ((order-stage-machineize REVERSE) reverse-Z))
  (check-equal? canonical-M reverse-M)
  (define canonical-M-step
    ((order-stage-m-step-proofs CANONICAL) canonical-M))
  (define reverse-M-step
    ((order-stage-m-step-proofs REVERSE) reverse-M))
  (check-proof-multisets 'M-step canonical-M-step reverse-M-step 1)
  (check-equal? (proof-observations canonical-M-step 2)
                (list (list label (stage->M CANONICAL target))))

  (define canonical-B ((order-stage-compress CANONICAL) canonical-M))
  (define reverse-B ((order-stage-compress REVERSE) reverse-M))
  (check-equal? canonical-B reverse-B)
  (define canonical-B-step
    ((order-stage-b-step-proofs CANONICAL) canonical-B))
  (define reverse-B-step
    ((order-stage-b-step-proofs REVERSE) reverse-B))
  (check-proof-multisets 'B-step canonical-B-step reverse-B-step 1)
  (match-define (list (list canonical-span canonical-B-next))
    (proof-observations canonical-B-step 2))
  (match-define (list (list reverse-span reverse-B-next))
    (proof-observations reverse-B-step 2))
  (check-equal? canonical-span reverse-span)
  (check-equal? canonical-B-next reverse-B-next)
  (define span-labels
    ((order-stage-span-labels CANONICAL) canonical-span))
  (check-equal? (first span-labels) label)
  (check-equal?
   canonical-B-next
   (stage->B
    CANONICAL
    (advance-source
     source:raw-successors/generated/search/n source span-labels)))

  (define canonical-evaluated
    ((order-stage-big-evaluate-proofs CANONICAL) source))
  (define reverse-evaluated
    ((order-stage-big-evaluate-proofs REVERSE) source))
  (check-proof-multisets
   'Big-evaluate canonical-evaluated reverse-evaluated 1)
  (define canonical-promoted
    ((order-stage-big-promote-proofs CANONICAL) canonical-B))
  (define reverse-promoted
    ((order-stage-big-promote-proofs REVERSE) reverse-B))
  (check-proof-multisets
   'Big-promote canonical-promoted reverse-promoted 1)
  (check-equal? (proof-observations canonical-evaluated 1)
                (proof-observations canonical-promoted 1)))

(define GENERATED-SEARCH-STAGE-FEATURE-ORDER-TESTS
  (test-suite
   "generated Search N stage feature-order independence"

   (test-case "all mixed witnesses and inherited representatives agree"
     (define mixed
       (search-row-corpus-mixed-feature-cases SEARCH-CORPUS/N))
     (check-equal? (map search-mixed-case-name mixed)
                   EXPECTED-SEARCH-MIXED-CASE-NAMES)
     (for ([case (in-list mixed)])
       (check-order-case
        (search-mixed-case-label case)
        (search-mixed-case-source case)
        (search-mixed-case-target case)))
     (for ([label (in-list REPRESENTATIVE-INHERITED-LABELS)])
       (define source (search-row-source-ref SEARCH-CORPUS/N label))
       (match-define (list (list actual-label target))
         (source:raw-successors/generated/search/n source))
       (check-equal? actual-label label)
       (check-order-case label source target)))

   (test-case "all eight feature labels remain singleton spans"
     (define cases (search-row-corpus-feature-rule-cases SEARCH-CORPUS/N))
     (check-equal? (map search-rule-case-label cases)
                   SEARCH-B-SINGLETON-RULE-NAMES)
     (for ([case (in-list cases)])
       (define label (search-rule-case-label case))
       (define source (search-rule-case-source case))
       (define canonical-B (stage->B CANONICAL source))
       (define reverse-B (stage->B REVERSE source))
       (check-equal? canonical-B reverse-B)
       (define canonical-proofs
         ((order-stage-singleton-proofs CANONICAL) canonical-B))
       (define reverse-proofs
         ((order-stage-singleton-proofs REVERSE) reverse-B))
       (check-proof-multisets
        'B-singleton canonical-proofs reverse-proofs 1)
       (check-equal? (map first (proof-observations canonical-proofs 2))
                     (list `(transition-span ,label)))))

   (test-case "the scheduler barrier enters neither ordered stage row"
     (define source (search-row-corpus-scheduler-barrier SEARCH-CORPUS/N))
     (check-equal? (source:raw-successors/generated/search/n source) '())
     (check-proof-multisets
      'barrier-D-decompose
      ((order-stage-decompose-proofs CANONICAL) source)
      ((order-stage-decompose-proofs REVERSE) source)
      0)
     (check-proof-multisets
      'barrier-Big-evaluate
      ((order-stage-big-evaluate-proofs CANONICAL) source)
      ((order-stage-big-evaluate-proofs REVERSE) source)
      0))

   (test-case "finite Big traces preserve every compressed suffix"
     (define traces (search-row-corpus-finite-traces SEARCH-CORPUS/N))
     (check-equal? (map search-trace-case-name traces)
                   EXPECTED-SEARCH-TRACE-NAMES)
     (for ([trace-case (in-list traces)])
       (define source (search-trace-case-source trace-case))
       (define terminal (search-trace-case-terminal trace-case))
       (define expected-big `(BigFinal ,terminal))
       (define canonical-evaluated
         ((order-stage-big-evaluate-proofs CANONICAL) source))
       (define reverse-evaluated
         ((order-stage-big-evaluate-proofs REVERSE) source))
       (check-proof-multisets
        'trace-Big-evaluate canonical-evaluated reverse-evaluated 1)
       (check-equal? (proof-observations canonical-evaluated 1)
                     (list expected-big))

       (define-values (canonical-final reverse-final observed-spans)
         (for/fold ([canonical-B (stage->B CANONICAL source)]
                    [reverse-B (stage->B REVERSE source)]
                    [seen '()])
                   ([expected-span
                     (in-list (search-trace-case-spans trace-case))])
           (check-equal? canonical-B reverse-B)
           (define canonical-promoted
             ((order-stage-big-promote-proofs CANONICAL) canonical-B))
           (define reverse-promoted
             ((order-stage-big-promote-proofs REVERSE) reverse-B))
           (check-proof-multisets
            'trace-Big-promote
            canonical-promoted reverse-promoted 1)
           (check-equal? (proof-observations canonical-promoted 1)
                         (list expected-big))
           (define canonical-step
             ((order-stage-b-step-proofs CANONICAL) canonical-B))
           (define reverse-step
             ((order-stage-b-step-proofs REVERSE) reverse-B))
           (check-proof-multisets
            'trace-B-step canonical-step reverse-step 1)
           (match-define (list (list canonical-span canonical-next))
             (proof-observations canonical-step 2))
           (match-define (list (list reverse-span reverse-next))
             (proof-observations reverse-step 2))
           (check-equal? canonical-span expected-span)
           (check-equal? reverse-span expected-span)
           (values canonical-next reverse-next
                   (append seen (list canonical-span)))))
       (check-equal? observed-spans (search-trace-case-spans trace-case))
       (check-equal? canonical-final (stage->B CANONICAL terminal))
       (check-equal? reverse-final (stage->B REVERSE terminal))
       (check-proof-multisets
        'trace-final-B
        ((order-stage-b-step-proofs CANONICAL) canonical-final)
        ((order-stage-b-step-proofs REVERSE) reverse-final)
        0)))))

(module+ test
  (run-tests GENERATED-SEARCH-STAGE-FEATURE-ORDER-TESTS))
