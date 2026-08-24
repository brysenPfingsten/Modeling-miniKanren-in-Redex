#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in stage-s: "stages/s.rkt")
         (prefix-in stage-e: "stages/e.rkt")
         (prefix-in stage-n: "stages/n.rkt")
         (prefix-in q: "stages/vertical.rkt")
         "corpus.rkt")

(provide GENERATED-SEARCH-CUBE-TESTS)

(define (canonical-multiset values)
  (sort values string<? #:key ~s))

(define (normalized-proof-multiset proofs transform-arguments)
  (canonical-multiset
   (for/list ([proof (in-list proofs)])
     (match (derivation-term proof)
       [(cons _judgment arguments)
        (cons 'judgment (transform-arguments arguments))]))))

(define (check-complete-proof-square who source-proofs target-proofs lift)
  (check-equal? (length source-proofs) (length target-proofs)
                (~a who " raw proof multiplicity"))
  (check-equal?
   (normalized-proof-multiset source-proofs lift)
   (normalized-proof-multiset target-proofs values)
   (~a who " complete top-level proof multiset")))

(define (outputs proofs count)
  (for/list ([proof (in-list proofs)])
    (define values (take-right (derivation-term proof) count))
    (if (= count 1) (first values) values)))

(define (only who values)
  (match values
    [(list value) value]
    [_ (error who "expected one raw proof, received ~e" values)]))

(struct cube-row
  (name
   corpus
   decompose
   refocus
   machineize
   compress
   d-step
   z-step
   m-step
   b-step
   big)
  #:transparent)

(define-syntax-rule
  (define-cube-row
    row-id row-name corpus-id
    decompose-id refocus-id machineize-id compress-id
    d-step-id z-step-id m-step-id b-step-id big-id)
  (define row-id
    (cube-row
     row-name corpus-id
     (lambda (source) (build-derivations (decompose-id ,source D)))
     (lambda (D) (term (refocus-id ,D)))
     (lambda (Z) (term (machineize-id ,Z)))
     (lambda (M) (term (compress-id ,M)))
     (lambda (D) (build-derivations (d-step-id ,D RuleName D_next)))
     (lambda (Z) (build-derivations (z-step-id ,Z RuleName Z_next)))
     (lambda (M) (build-derivations (m-step-id ,M RuleName M_next)))
     (lambda (B) (build-derivations (b-step-id ,B TransitionSpan B_next)))
     (lambda (B) (build-derivations (big-id ,B Big))))))

(define-cube-row
  ROW/S 'S SEARCH-CORPUS/S
  stage-s:search/delay-stage-extension/S/D-decompose
  stage-s:search/delay-stage-extension/S/Z-refocus-phase
  stage-s:search/delay-stage-extension/S/M-machineize
  stage-s:search/delay-stage-extension/S/B-compress
  stage-s:search/delay-stage-extension/S/D-step
  stage-s:search/delay-stage-extension/S/Z-step
  stage-s:search/delay-stage-extension/S/M-step
  stage-s:search/delay-stage-extension/S/B-step
  stage-s:search/delay-stage-extension/S/Big-promote)

(define-cube-row
  ROW/E 'E SEARCH-CORPUS/E
  stage-e:search/delay-stage-extension/E/D-decompose
  stage-e:search/delay-stage-extension/E/Z-refocus-phase
  stage-e:search/delay-stage-extension/E/M-machineize
  stage-e:search/delay-stage-extension/E/B-compress
  stage-e:search/delay-stage-extension/E/D-step
  stage-e:search/delay-stage-extension/E/Z-step
  stage-e:search/delay-stage-extension/E/M-step
  stage-e:search/delay-stage-extension/E/B-step
  stage-e:search/delay-stage-extension/E/Big-promote)

(define-cube-row
  ROW/N 'N SEARCH-CORPUS/N
  stage-n:search/delay-stage-extension/N/D-decompose
  stage-n:search/delay-stage-extension/N/Z-refocus-phase
  stage-n:search/delay-stage-extension/N/M-machineize
  stage-n:search/delay-stage-extension/N/B-compress
  stage-n:search/delay-stage-extension/N/D-step
  stage-n:search/delay-stage-extension/N/Z-step
  stage-n:search/delay-stage-extension/N/M-step
  stage-n:search/delay-stage-extension/N/B-step
  stage-n:search/delay-stage-extension/N/Big-promote)

(struct cube-edge
  (name
   source
   target
   Q-R
   Q-D
   Q-Z
   Q-M
   Q-B
   Q-Big
   decompose-commutes?
   refocus-commutes?
   machineize-commutes?
   compress-commutes?
   big-commutes?
   D-composition?
   Z-composition?
   M-composition?
   B-composition?
   Big-composition?)
  #:transparent)

(define EDGE/SE
  (cube-edge
   'S->E ROW/S ROW/E
   q:Q-SE/R/stages/search q:Q-SE/D/stages/search
   q:Q-SE/Z/stages/search q:Q-SE/M/stages/search
   q:Q-SE/B/stages/search q:Q-SE/Big/stages/search
   q:Q-SE/decompose-commutes/stages/search?
   q:Q-SE/refocus-commutes/stages/search?
   q:Q-SE/machineize-commutes/stages/search?
   q:Q-SE/compress-commutes/stages/search?
   q:Q-SE/big-commutes/stages/search?
   #f #f #f #f #f))

(define EDGE/EN
  (cube-edge
   'E->N ROW/E ROW/N
   q:Q-EN/R/stages/search q:Q-EN/D/stages/search
   q:Q-EN/Z/stages/search q:Q-EN/M/stages/search
   q:Q-EN/B/stages/search q:Q-EN/Big/stages/search
   q:Q-EN/decompose-commutes/stages/search?
   q:Q-EN/refocus-commutes/stages/search?
   q:Q-EN/machineize-commutes/stages/search?
   q:Q-EN/compress-commutes/stages/search?
   q:Q-EN/big-commutes/stages/search?
   #f #f #f #f #f))

(define EDGE/SN
  (cube-edge
   'S->N ROW/S ROW/N
   q:Q-SN/R/stages/search q:Q-SN/D/stages/search
   q:Q-SN/Z/stages/search q:Q-SN/M/stages/search
   q:Q-SN/B/stages/search q:Q-SN/Big/stages/search
   q:Q-SN/decompose-commutes/stages/search?
   q:Q-SN/refocus-commutes/stages/search?
   q:Q-SN/machineize-commutes/stages/search?
   q:Q-SN/compress-commutes/stages/search?
   q:Q-SN/big-commutes/stages/search?
   q:Q-SN/D-composition/stages/search?
   q:Q-SN/Z-composition/stages/search?
   q:Q-SN/M-composition/stages/search?
   q:Q-SN/B-composition/stages/search?
   q:Q-SN/Big-composition/stages/search?))

(define EDGES (list EDGE/SE EDGE/EN EDGE/SN))

(define (source->D row source)
  (only 'source->D (outputs ((cube-row-decompose row) source) 1)))

(define (source->Z row source)
  ((cube-row-refocus row) (source->D row source)))

(define (source->M row source)
  ((cube-row-machineize row) (source->Z row source)))

(define (source->B row source)
  ((cube-row-compress row) (source->M row source)))

(define (lift-decompose edge arguments)
  (match-define (list source D) arguments)
  (list ((cube-edge-Q-R edge) source)
        ((cube-edge-Q-D edge) D)))

(define (lift-step Q arguments)
  (match-define (list carrier label next) arguments)
  (list (Q carrier) label (Q next)))

(define (lift-big edge arguments)
  (match-define (list B Big) arguments)
  (list ((cube-edge-Q-B edge) B)
        ((cube-edge-Q-Big edge) Big)))

(define (check-SN-composition edge D Z M B Bigs)
  (when (eq? (cube-edge-name edge) 'S->N)
    (check-true ((cube-edge-D-composition? edge) D))
    (check-true ((cube-edge-Z-composition? edge) Z))
    (check-true ((cube-edge-M-composition? edge) M))
    (check-true ((cube-edge-B-composition? edge) B))
    (for ([Big (in-list Bigs)])
      (check-true ((cube-edge-Big-composition? edge) Big)))))

(define (check-chain edge source expected-target)
  (define source-row (cube-edge-source edge))
  (define target-row (cube-edge-target edge))
  (check-equal? ((cube-edge-Q-R edge) source) expected-target)
  (when (eq? (cube-edge-name edge) 'S->N)
    (check-true (q:Q-SN/R-composition/stages/search? source)))

  (define source-D-proofs ((cube-row-decompose source-row) source))
  (define target-D-proofs ((cube-row-decompose target-row) expected-target))
  (check-complete-proof-square
   `(,(cube-edge-name edge) decompose)
   source-D-proofs target-D-proofs
   (lambda (arguments) (lift-decompose edge arguments)))
  (check-true ((cube-edge-decompose-commutes? edge) source))

  (for ([source-D (in-list (outputs source-D-proofs 1))])
    (define target-D ((cube-edge-Q-D edge) source-D))
    (define source-Z ((cube-row-refocus source-row) source-D))
    (define target-Z ((cube-row-refocus target-row) target-D))
    (check-equal? ((cube-edge-Q-Z edge) source-Z) target-Z)
    (check-true ((cube-edge-refocus-commutes? edge) source-D))

    (define source-M ((cube-row-machineize source-row) source-Z))
    (define target-M ((cube-row-machineize target-row) target-Z))
    (check-equal? ((cube-edge-Q-M edge) source-M) target-M)
    (check-true ((cube-edge-machineize-commutes? edge) source-Z))

    (define source-B ((cube-row-compress source-row) source-M))
    (define target-B ((cube-row-compress target-row) target-M))
    (check-equal? ((cube-edge-Q-B edge) source-B) target-B)
    (check-true ((cube-edge-compress-commutes? edge) source-M))

    (define source-Big-proofs ((cube-row-big source-row) source-B))
    (define target-Big-proofs ((cube-row-big target-row) target-B))
    (check-complete-proof-square
     `(,(cube-edge-name edge) Big)
     source-Big-proofs target-Big-proofs
     (lambda (arguments) (lift-big edge arguments)))
    (check-true ((cube-edge-big-commutes? edge) source-B))

    (for ([source-step (in-list
                        (list (cube-row-d-step source-row)
                              (cube-row-z-step source-row)
                              (cube-row-m-step source-row)
                              (cube-row-b-step source-row)))]
          [target-step (in-list
                        (list (cube-row-d-step target-row)
                              (cube-row-z-step target-row)
                              (cube-row-m-step target-row)
                              (cube-row-b-step target-row)))]
          [source-carrier (in-list (list source-D source-Z source-M source-B))]
          [target-carrier (in-list (list target-D target-Z target-M target-B))]
          [Q (in-list (list (cube-edge-Q-D edge)
                            (cube-edge-Q-Z edge)
                            (cube-edge-Q-M edge)
                            (cube-edge-Q-B edge)))]
          [phase (in-list '(D Z M B))])
      (check-complete-proof-square
       `(,(cube-edge-name edge) ,phase step)
       (source-step source-carrier)
       (target-step target-carrier)
       (lambda (arguments) (lift-step Q arguments))))

    (check-SN-composition
     edge source-D source-Z source-M source-B
     (outputs source-Big-proofs 1))))

(define (check-barrier edge source expected-target)
  (define source-row (cube-edge-source edge))
  (define target-row (cube-edge-target edge))
  (check-equal? ((cube-edge-Q-R edge) source) expected-target)
  (when (eq? (cube-edge-name edge) 'S->N)
    (check-true (q:Q-SN/R-composition/stages/search? source)))
  (define source-D-proofs ((cube-row-decompose source-row) source))
  (define target-D-proofs ((cube-row-decompose target-row) expected-target))
  (check-complete-proof-square
   `(,(cube-edge-name edge) barrier/decompose)
   source-D-proofs
   target-D-proofs
   (lambda (arguments) (lift-decompose edge arguments)))
  (check-equal? source-D-proofs '())
  (check-equal? target-D-proofs '())
  (check-true ((cube-edge-decompose-commutes? edge) source)))

(define (finite-B-suffixes row B [fuel 64])
  (when (zero? fuel)
    (error 'finite-B-suffixes "bounded Search B trace exceeded 64 steps"))
  (match (outputs ((cube-row-b-step row) B) 2)
    ['() (list B)]
    [(list (list _span next))
     (cons B (finite-B-suffixes row next (sub1 fuel)))]
    [other
     (error 'finite-B-suffixes
            "expected deterministic B step, received ~e"
            other)]))

(define (check-B-suffixes edge source)
  (define source-row (cube-edge-source edge))
  (define target-row (cube-edge-target edge))
  (for ([source-B (in-list (finite-B-suffixes
                            source-row
                            (source->B source-row source)))])
    (define target-B ((cube-edge-Q-B edge) source-B))
    (check-complete-proof-square
     `(,(cube-edge-name edge) B-suffix-step)
     ((cube-row-b-step source-row) source-B)
     ((cube-row-b-step target-row) target-B)
     (lambda (arguments)
       (lift-step (cube-edge-Q-B edge) arguments)))
    (check-complete-proof-square
     `(,(cube-edge-name edge) B-suffix-Big)
     ((cube-row-big source-row) source-B)
     ((cube-row-big target-row) target-B)
     (lambda (arguments) (lift-big edge arguments)))
    (check-true ((cube-edge-big-commutes? edge) source-B))))

(define GENERATED-SEARCH-CUBE-TESTS
  (test-suite
   "generated Search representation and stage commuting cube"

   (test-case "all twenty-one inherited witnesses satisfy five direct phase laws"
     (for ([edge (in-list EDGES)])
       (define source-corpus (cube-row-corpus (cube-edge-source edge)))
       (define target-corpus (cube-row-corpus (cube-edge-target edge)))
       (define source-pairs (search-row-corpus-rule-sources source-corpus))
       (define target-pairs (search-row-corpus-rule-sources target-corpus))
       (check-equal? (length source-pairs) (length SEARCH-RULE-NAMES))
       (check-equal? (length target-pairs) (length SEARCH-RULE-NAMES))
       (check-equal? (sort (map first source-pairs) symbol<?)
                     SEARCH-RULE-NAMES)
       (check-equal? (sort (map first target-pairs) symbol<?)
                     SEARCH-RULE-NAMES)
       (for ([source-pair (in-list source-pairs)]
             [target-pair (in-list target-pairs)])
         (check-equal? (first source-pair) (first target-pair))
         (check-chain edge (second source-pair) (second target-pair)))))

   (test-case "all eight mixed-feature witnesses satisfy direct maps"
     (for ([edge (in-list EDGES)])
       (define source-cases
         (search-row-corpus-mixed-feature-cases
          (cube-row-corpus (cube-edge-source edge))))
       (define target-cases
         (search-row-corpus-mixed-feature-cases
          (cube-row-corpus (cube-edge-target edge))))
       (check-equal? (map search-mixed-case-name source-cases)
                     EXPECTED-SEARCH-MIXED-CASE-NAMES)
       (check-equal? (map search-mixed-case-name target-cases)
                     EXPECTED-SEARCH-MIXED-CASE-NAMES)
       (for ([source-case (in-list source-cases)]
             [target-case (in-list target-cases)])
         (check-equal? (search-mixed-case-name source-case)
                       (search-mixed-case-name target-case))
         (check-chain edge
                      (search-mixed-case-source source-case)
                      (search-mixed-case-source target-case)))))

   (test-case "the scheduler barrier remains a mapped zero-proof boundary"
     (for ([edge (in-list EDGES)])
       (define source
         (search-row-corpus-scheduler-barrier
          (cube-row-corpus (cube-edge-source edge))))
       (define target
         (search-row-corpus-scheduler-barrier
          (cube-row-corpus (cube-edge-target edge))))
       (check-barrier edge source target)))

   (test-case "all three bounded mixed traces commute at every B suffix"
     (for ([edge (in-list EDGES)])
       (define source-traces
         (search-row-corpus-finite-traces
          (cube-row-corpus (cube-edge-source edge))))
       (define target-traces
         (search-row-corpus-finite-traces
          (cube-row-corpus (cube-edge-target edge))))
       (check-equal? (map search-trace-case-name source-traces)
                     EXPECTED-SEARCH-TRACE-NAMES)
       (check-equal? (map search-trace-case-name target-traces)
                     EXPECTED-SEARCH-TRACE-NAMES)
       (for ([source-trace (in-list source-traces)]
             [target-trace (in-list target-traces)])
         (check-equal? (search-trace-case-name source-trace)
                       (search-trace-case-name target-trace))
         (define source (search-trace-case-source source-trace))
         (define target (search-trace-case-source target-trace))
         (check-chain edge source target)
         (check-B-suffixes edge source))))))

(module+ test
  (run-tests GENERATED-SEARCH-CUBE-TESTS))
