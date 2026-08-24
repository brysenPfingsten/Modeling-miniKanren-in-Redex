#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in stage-s: "stages/s.rkt")
         (prefix-in stage-e: "stages/e.rkt")
         (prefix-in stage-n: "stages/n.rkt")
         (prefix-in q: "stages/vertical.rkt")
         "corpus.rkt")

(provide GENERATED-DELAY-CUBE-TESTS)

(define EXPECTED-DELAY-TRACE-NAMES
  '(suspend-success
    bubble-success
    suspend-failure
    nested-suspend
    fresh-inside-suspend
    unused-fresh-outside-delayed-failure))

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
  ROW/S 'S DELAY-CORPUS/S
  stage-s:delay/stage-extension/S/D-decompose
  stage-s:delay/stage-extension/S/Z-refocus-phase
  stage-s:delay/stage-extension/S/M-machineize
  stage-s:delay/stage-extension/S/B-compress
  stage-s:delay/stage-extension/S/D-step
  stage-s:delay/stage-extension/S/Z-step
  stage-s:delay/stage-extension/S/M-step
  stage-s:delay/stage-extension/S/B-step
  stage-s:delay/stage-extension/S/Big-promote)

(define-cube-row
  ROW/E 'E DELAY-CORPUS/E
  stage-e:delay/stage-extension/E/D-decompose
  stage-e:delay/stage-extension/E/Z-refocus-phase
  stage-e:delay/stage-extension/E/M-machineize
  stage-e:delay/stage-extension/E/B-compress
  stage-e:delay/stage-extension/E/D-step
  stage-e:delay/stage-extension/E/Z-step
  stage-e:delay/stage-extension/E/M-step
  stage-e:delay/stage-extension/E/B-step
  stage-e:delay/stage-extension/E/Big-promote)

(define-cube-row
  ROW/N 'N DELAY-CORPUS/N
  stage-n:delay/stage-extension/N/D-decompose
  stage-n:delay/stage-extension/N/Z-refocus-phase
  stage-n:delay/stage-extension/N/M-machineize
  stage-n:delay/stage-extension/N/B-compress
  stage-n:delay/stage-extension/N/D-step
  stage-n:delay/stage-extension/N/Z-step
  stage-n:delay/stage-extension/N/M-step
  stage-n:delay/stage-extension/N/B-step
  stage-n:delay/stage-extension/N/Big-promote)

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
   q:Q-SE/R/stages/delay q:Q-SE/D/stages/delay
   q:Q-SE/Z/stages/delay q:Q-SE/M/stages/delay
   q:Q-SE/B/stages/delay q:Q-SE/Big/stages/delay
   q:Q-SE/decompose-commutes/stages/delay?
   q:Q-SE/refocus-commutes/stages/delay?
   q:Q-SE/machineize-commutes/stages/delay?
   q:Q-SE/compress-commutes/stages/delay?
   q:Q-SE/big-commutes/stages/delay?
   #f #f #f #f #f))

(define EDGE/EN
  (cube-edge
   'E->N ROW/E ROW/N
   q:Q-EN/R/stages/delay q:Q-EN/D/stages/delay
   q:Q-EN/Z/stages/delay q:Q-EN/M/stages/delay
   q:Q-EN/B/stages/delay q:Q-EN/Big/stages/delay
   q:Q-EN/decompose-commutes/stages/delay?
   q:Q-EN/refocus-commutes/stages/delay?
   q:Q-EN/machineize-commutes/stages/delay?
   q:Q-EN/compress-commutes/stages/delay?
   q:Q-EN/big-commutes/stages/delay?
   #f #f #f #f #f))

(define EDGE/SN
  (cube-edge
   'S->N ROW/S ROW/N
   q:Q-SN/R/stages/delay q:Q-SN/D/stages/delay
   q:Q-SN/Z/stages/delay q:Q-SN/M/stages/delay
   q:Q-SN/B/stages/delay q:Q-SN/Big/stages/delay
   q:Q-SN/decompose-commutes/stages/delay?
   q:Q-SN/refocus-commutes/stages/delay?
   q:Q-SN/machineize-commutes/stages/delay?
   q:Q-SN/compress-commutes/stages/delay?
   q:Q-SN/big-commutes/stages/delay?
   q:Q-SN/D-composition/stages/delay?
   q:Q-SN/Z-composition/stages/delay?
   q:Q-SN/M-composition/stages/delay?
   q:Q-SN/B-composition/stages/delay?
   q:Q-SN/Big-composition/stages/delay?))

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
    (check-true (q:Q-SN/R-composition/stages/delay? source)))

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

(define (finite-B-suffixes row B [fuel 64])
  (when (zero? fuel)
    (error 'finite-B-suffixes "bounded Delay B trace exceeded 64 steps"))
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

(define GENERATED-DELAY-CUBE-TESTS
  (test-suite
   "generated Delay representation and stage commuting cube"

   (test-case "all sixteen witnesses satisfy five direct phase laws"
     (for ([edge (in-list EDGES)])
       (define source-corpus (cube-row-corpus (cube-edge-source edge)))
       (define target-corpus (cube-row-corpus (cube-edge-target edge)))
       (define source-pairs (delay-row-corpus-rule-sources source-corpus))
       (define target-pairs (delay-row-corpus-rule-sources target-corpus))
       (check-equal? (length source-pairs) (length DELAY-RULE-NAMES))
       (check-equal? (length target-pairs) (length DELAY-RULE-NAMES))
       (check-equal? (sort (map first source-pairs) symbol<?)
                     DELAY-RULE-NAMES)
       (check-equal? (sort (map first target-pairs) symbol<?)
                     DELAY-RULE-NAMES)
       (for ([source-pair (in-list source-pairs)]
             [target-pair (in-list target-pairs)])
         (check-equal? (first source-pair) (first target-pair))
         (check-chain edge (second source-pair) (second target-pair)))))

   (test-case "sparse wrappers satisfy direct maps and composition"
     (for ([edge (in-list EDGES)])
       (define source
         (delay-row-corpus-sparse-witness
          (cube-row-corpus (cube-edge-source edge))))
       (define target
         (delay-row-corpus-sparse-witness
          (cube-row-corpus (cube-edge-target edge))))
       (check-chain edge source target)))

   (test-case "all six finite traces commute at every B suffix"
     (for ([edge (in-list EDGES)])
       (define source-traces
         (delay-row-corpus-finite-traces
          (cube-row-corpus (cube-edge-source edge))))
       (define target-traces
         (delay-row-corpus-finite-traces
          (cube-row-corpus (cube-edge-target edge))))
       (check-equal? (map delay-trace-case-name source-traces)
                     EXPECTED-DELAY-TRACE-NAMES)
       (check-equal? (map delay-trace-case-name target-traces)
                     EXPECTED-DELAY-TRACE-NAMES)
       (for ([source-trace (in-list source-traces)]
             [target-trace (in-list target-traces)])
         (check-equal? (delay-trace-case-name source-trace)
                       (delay-trace-case-name target-trace))
         (define source (delay-trace-case-source source-trace))
         (define target (delay-trace-case-source target-trace))
         (check-chain edge source target)
         (check-B-suffixes edge source))))))

(module+ test
  (run-tests GENERATED-DELAY-CUBE-TESTS))
