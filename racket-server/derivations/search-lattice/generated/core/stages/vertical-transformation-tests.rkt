#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in source-s: "../source/s.rkt")
         (prefix-in source-e: "../source/e.rkt")
         (prefix-in source-n: "../source/n.rkt")
         (prefix-in stage-s: "./s.rkt")
         (prefix-in stage-e: "./e.rkt")
         (prefix-in stage-n: "./n.rkt")
         (prefix-in stage-q: "./vertical.rkt")
         "./corpus.rkt")

(provide GENERATED-CORE-STAGES-VERTICAL-TRANSFORMATIONS)

;; One observation is extracted from every raw Redex derivation.  Equal
;; conclusions reached by distinct proofs therefore remain distinct entries.
(define (raw-observations derivations output-count)
  (for/list ([proof (in-list derivations)])
    (define outputs
      (take-right (derivation-term proof) output-count))
    (if (= output-count 1) (first outputs) outputs)))

(define (canonical-raw-multiset observations)
  (sort observations string<? #:key ~s))

(define (check-raw-square who source-observations target-observations lift)
  (check-equal?
   (length source-observations)
   (length target-observations)
   (format "~a raw proof multiplicity" who))
  (check-equal?
   (canonical-raw-multiset (map lift source-observations))
   (canonical-raw-multiset target-observations)
   (format "~a raw proof observations" who)))

(define (lift-labeled Q)
  (lambda (observation)
    (match-define (list label target) observation)
    (list label (Q target))))

(define (lift-observed-big Q-Big)
  (lambda (observation)
    (match-define (list trace big) observation)
    (list trace (Q-Big big))))

(struct row-api
  (name
   corpus
   wf?
   decompose
   refocus
   machineize
   compress
   big
   observed-big
   d-step
   z-step
   m-step
   b-step
   flatten
   D?
   Z?
   M?
   B?
   Big?)
  #:transparent)

(define-syntax-rule
  (define-row-api
    api-id row-name corpus-id wf-id
    decomposition-language-id refocused-language-id machine-language-id
    compressed-language-id big-language-id
    decompose-id refocus-id machineize-id compress-id
    promote-id closure-square-id
    d-step-id z-step-id m-step-id b-step-id flatten-id)
  (define api-id
    (row-api
     row-name
     corpus-id
     (lambda (frontier) (judgment-holds (wf-id ,frontier)))
     (lambda (frontier)
       (raw-observations
        (build-derivations (decompose-id ,frontier D))
        1))
     (lambda (decomposition) (term (refocus-id ,decomposition)))
     (lambda (refocused) (term (machineize-id ,refocused)))
     (lambda (machine) (term (compress-id ,machine)))
     (lambda (compressed)
       (raw-observations
        (build-derivations (promote-id ,compressed Big))
        1))
     (lambda (compressed)
       (raw-observations
        (build-derivations
         (closure-square-id ,compressed BTrace Big))
        2))
     (lambda (decomposition)
       (raw-observations
        (build-derivations
         (d-step-id ,decomposition RuleName D_next))
        2))
     (lambda (refocused)
       (raw-observations
        (build-derivations
         (z-step-id ,refocused RuleName Z_next))
        2))
     (lambda (machine)
       (raw-observations
        (build-derivations
         (m-step-id ,machine RuleName M_next))
        2))
     (lambda (compressed)
       (raw-observations
        (build-derivations
         (b-step-id ,compressed TransitionSpan B_next))
        2))
     (lambda (trace) (term (flatten-id ,trace)))
     (lambda (datum)
       (redex-match? decomposition-language-id D datum))
     (lambda (datum)
       (redex-match? refocused-language-id Z datum))
     (lambda (datum)
       (redex-match? machine-language-id M datum))
     (lambda (datum)
       (redex-match? compressed-language-id B datum))
     (lambda (datum)
       (redex-match? big-language-id Big datum)))))

(define-row-api
  ROW/S 'S CORE-CORPUS/S source-s:wf-core/generated/s?
  stage-s:generated-core-stage-s-decomposition-lang
  stage-s:generated-core-stage-s-refocused-lang
  stage-s:generated-core-stage-s-machine-lang
  stage-s:generated-core-stage-s-compressed-lang
  stage-s:generated-core-stage-s-big-lang
  stage-s:generated-stage-decompose/s
  stage-s:generated-stage-refocus-phase/s
  stage-s:generated-stage-machineize/s
  stage-s:generated-stage-compress/s
  stage-s:generated-stage-promote-B/direct/s
  stage-s:generated-stage-B-Big-closure-square/s
  stage-s:generated-stage-decomposed-step/s
  stage-s:generated-stage-refocused-step/direct/s
  stage-s:generated-stage-machine-step/direct/s
  stage-s:generated-stage-compressed-step/direct/s
  stage-s:generated-stage-flatten-BTrace/s)

(define-row-api
  ROW/E 'E CORE-CORPUS/E source-e:wf-core/generated/e?
  stage-e:generated-core-stage-e-decomposition-lang
  stage-e:generated-core-stage-e-refocused-lang
  stage-e:generated-core-stage-e-machine-lang
  stage-e:generated-core-stage-e-compressed-lang
  stage-e:generated-core-stage-e-big-lang
  stage-e:generated-stage-decompose/e
  stage-e:generated-stage-refocus-phase/e
  stage-e:generated-stage-machineize/e
  stage-e:generated-stage-compress/e
  stage-e:generated-stage-promote-B/direct/e
  stage-e:generated-stage-B-Big-closure-square/e
  stage-e:generated-stage-decomposed-step/e
  stage-e:generated-stage-refocused-step/direct/e
  stage-e:generated-stage-machine-step/direct/e
  stage-e:generated-stage-compressed-step/direct/e
  stage-e:generated-stage-flatten-BTrace/e)

(define-row-api
  ROW/N 'N CORE-CORPUS/N source-n:wf-core/generated/n?
  stage-n:generated-core-stage-n-decomposition-lang
  stage-n:generated-core-stage-n-refocused-lang
  stage-n:generated-core-stage-n-machine-lang
  stage-n:generated-core-stage-n-compressed-lang
  stage-n:generated-core-stage-n-big-lang
  stage-n:generated-stage-decompose/n
  stage-n:generated-stage-refocus-phase/n
  stage-n:generated-stage-machineize/n
  stage-n:generated-stage-compress/n
  stage-n:generated-stage-promote-B/direct/n
  stage-n:generated-stage-B-Big-closure-square/n
  stage-n:generated-stage-decomposed-step/n
  stage-n:generated-stage-refocused-step/direct/n
  stage-n:generated-stage-machine-step/direct/n
  stage-n:generated-stage-compressed-step/direct/n
  stage-n:generated-stage-flatten-BTrace/n)

(struct edge-api
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
  (edge-api
   'S->E ROW/S ROW/E
   stage-q:Q-SE/R/stages
   stage-q:Q-SE/D/stages
   stage-q:Q-SE/Z/stages
   stage-q:Q-SE/M/stages
   stage-q:Q-SE/B/stages
   stage-q:Q-SE/Big/stages
   stage-q:Q-SE/decompose-commutes/stages?
   stage-q:Q-SE/refocus-commutes/stages?
   stage-q:Q-SE/machineize-commutes/stages?
   stage-q:Q-SE/compress-commutes/stages?
   stage-q:Q-SE/big-commutes/stages?
   #f #f #f #f #f))

(define EDGE/EN
  (edge-api
   'E->N ROW/E ROW/N
   stage-q:Q-EN/R/stages
   stage-q:Q-EN/D/stages
   stage-q:Q-EN/Z/stages
   stage-q:Q-EN/M/stages
   stage-q:Q-EN/B/stages
   stage-q:Q-EN/Big/stages
   stage-q:Q-EN/decompose-commutes/stages?
   stage-q:Q-EN/refocus-commutes/stages?
   stage-q:Q-EN/machineize-commutes/stages?
   stage-q:Q-EN/compress-commutes/stages?
   stage-q:Q-EN/big-commutes/stages?
   #f #f #f #f #f))

(define EDGE/SN
  (edge-api
   'S->N ROW/S ROW/N
   stage-q:Q-SN/R/stages
   stage-q:Q-SN/D/stages
   stage-q:Q-SN/Z/stages
   stage-q:Q-SN/M/stages
   stage-q:Q-SN/B/stages
   stage-q:Q-SN/Big/stages
   stage-q:Q-SN/decompose-commutes/stages?
   stage-q:Q-SN/refocus-commutes/stages?
   stage-q:Q-SN/machineize-commutes/stages?
   stage-q:Q-SN/compress-commutes/stages?
   stage-q:Q-SN/big-commutes/stages?
   stage-q:Q-SN/D-composition/stages?
   stage-q:Q-SN/Z-composition/stages?
   stage-q:Q-SN/M-composition/stages?
   stage-q:Q-SN/B-composition/stages?
   stage-q:Q-SN/Big-composition/stages?))

(define EDGES (list EDGE/SE EDGE/EN EDGE/SN))

(define (check-step-square who source-step target-step source-carrier
                           target-carrier Q)
  (check-raw-square
   who
   (source-step source-carrier)
   (target-step target-carrier)
   (lift-labeled Q)))

(define (check-big-square edge source-B target-B)
  (define source-row (edge-api-source edge))
  (define target-row (edge-api-target edge))
  (check-raw-square
   `(,(edge-api-name edge) Big)
   ((row-api-big source-row) source-B)
   ((row-api-big target-row) target-B)
   (edge-api-Q-Big edge))
  ;; BigFinal carries no transition labels.  The independently generated
  ;; closure certificate retains the exact BTrace alongside the same result.
  (define source-observed
    ((row-api-observed-big source-row) source-B))
  (define target-observed
    ((row-api-observed-big target-row) target-B))
  (check-raw-square
   `(,(edge-api-name edge) observed-Big)
   source-observed
   target-observed
   (lift-observed-big (edge-api-Q-Big edge)))
  (for ([observation (in-list source-observed)])
    (match-define (list trace _big) observation)
    (check-equal?
     ((row-api-flatten source-row) trace)
     ((row-api-flatten target-row) trace)
     (format "~a exact flattened BTrace" (edge-api-name edge)))))

(define (check-SN-composition edge D Z M B)
  (when (eq? (edge-api-name edge) 'S->N)
    (check-true ((edge-api-D-composition? edge) D))
    (check-true ((edge-api-Z-composition? edge) Z))
    (check-true ((edge-api-M-composition? edge) M))
    (check-true ((edge-api-B-composition? edge) B))
    (for ([big (in-list ((row-api-big (edge-api-source edge)) B))])
      (check-true ((edge-api-Big-composition? edge) big)))))

(define (check-transformation-chain edge source)
  (define source-row (edge-api-source edge))
  (define target-row (edge-api-target edge))
  (define target ((edge-api-Q-R edge) source))
  (check-true ((row-api-wf? source-row) source))
  (check-true ((row-api-wf? target-row) target))
  (when (eq? (edge-api-name edge) 'S->N)
    (check-true (stage-q:Q-SN/R-composition/stages? source)))

  ;; Q_D o decompose_source = decompose_target o Q_R, as a complete raw
  ;; derivation multiset rather than only a successor set.
  (define source-Ds ((row-api-decompose source-row) source))
  (define target-Ds ((row-api-decompose target-row) target))
  (check-raw-square
   `(,(edge-api-name edge) decompose)
   source-Ds target-Ds (edge-api-Q-D edge))
  (check-true ((edge-api-decompose-commutes? edge) source))

  (for ([source-D (in-list source-Ds)])
    (define target-D ((edge-api-Q-D edge) source-D))
    (check-true ((row-api-D? source-row) source-D))
    (check-true ((row-api-D? target-row) target-D))

    ;; Q_Z o refocus_source = refocus_target o Q_D.
    (define source-Z ((row-api-refocus source-row) source-D))
    (define target-Z ((row-api-refocus target-row) target-D))
    (check-equal? ((edge-api-Q-Z edge) source-Z) target-Z)
    (check-true ((edge-api-refocus-commutes? edge) source-D))
    (check-true ((row-api-Z? source-row) source-Z))
    (check-true ((row-api-Z? target-row) target-Z))

    ;; Q_M o machineize_source = machineize_target o Q_Z.
    (define source-M ((row-api-machineize source-row) source-Z))
    (define target-M ((row-api-machineize target-row) target-Z))
    (check-equal? ((edge-api-Q-M edge) source-M) target-M)
    (check-true ((edge-api-machineize-commutes? edge) source-Z))
    (check-true ((row-api-M? source-row) source-M))
    (check-true ((row-api-M? target-row) target-M))

    ;; Q_B o compress_source = compress_target o Q_M.
    (define source-B ((row-api-compress source-row) source-M))
    (define target-B ((row-api-compress target-row) target-M))
    (check-equal? ((edge-api-Q-B edge) source-B) target-B)
    (check-true ((edge-api-compress-commutes? edge) source-M))
    (check-true ((row-api-B? source-row) source-B))
    (check-true ((row-api-B? target-row) target-B))

    ;; Q_Big o big_source = big_target o Q_B.
    (check-big-square edge source-B target-B)
    (check-true ((edge-api-big-commutes? edge) source-B))

    ;; Representation translation also commutes with each visibly direct
    ;; transition system, preserving labels/spans and every raw proof.
    (check-step-square
     `(,(edge-api-name edge) D-step)
     (row-api-d-step source-row)
     (row-api-d-step target-row)
     source-D target-D (edge-api-Q-D edge))
    (check-step-square
     `(,(edge-api-name edge) Z-step)
     (row-api-z-step source-row)
     (row-api-z-step target-row)
     source-Z target-Z (edge-api-Q-Z edge))
    (check-step-square
     `(,(edge-api-name edge) M-step)
     (row-api-m-step source-row)
     (row-api-m-step target-row)
     source-M target-M (edge-api-Q-M edge))
    (check-step-square
     `(,(edge-api-name edge) B-step)
     (row-api-b-step source-row)
     (row-api-b-step target-row)
     source-B target-B (edge-api-Q-B edge))

    (check-SN-composition edge source-D source-Z source-M source-B)))

(define (initial-B row source)
  (match ((row-api-decompose row) source)
    [(list decomposition)
     ((row-api-compress row)
      ((row-api-machineize row)
       ((row-api-refocus row) decomposition)))]
    [other
     (error 'initial-B
            "expected one raw decomposition for ~a, received ~e"
            (row-api-name row)
            other)]))

(define (finite-B-suffixes row compressed [remaining 64])
  (when (zero? remaining)
    (error 'finite-B-suffixes
           "bounded corpus trace for ~a exceeded 64 B steps"
           (row-api-name row)))
  (match ((row-api-b-step row) compressed)
    ['() (list compressed)]
    [(list (list _span next))
     (cons compressed
           (finite-B-suffixes row next (sub1 remaining)))]
    [other
     (error 'finite-B-suffixes
            "expected one direct B proof for bounded core corpus, received ~e"
            other)]))

(define (check-finite-B-suffixes edge source)
  (define source-row (edge-api-source edge))
  (define target-row (edge-api-target edge))
  (for ([source-B
         (in-list
          (finite-B-suffixes source-row (initial-B source-row source)))])
    (define target-B ((edge-api-Q-B edge) source-B))
    (check-step-square
     `(,(edge-api-name edge) finite-B-suffix-step)
     (row-api-b-step source-row)
     (row-api-b-step target-row)
     source-B target-B (edge-api-Q-B edge))
    (check-big-square edge source-B target-B)
    (check-true ((edge-api-big-commutes? edge) source-B))))

(define GENERATED-CORE-STAGES-VERTICAL-TRANSFORMATIONS
  (test-suite
   "selected direct stage-transformation commuting laws"

   (test-case "all five phase laws and direct steps hold for all 13 rules"
     (for* ([edge (in-list EDGES)]
            [rule-name (in-list CORE-RULE-NAMES)])
       (define source
         (row-source-ref
          (row-api-corpus (edge-api-source edge))
          rule-name))
       (define expected-target
         (row-source-ref
          (row-api-corpus (edge-api-target edge))
          rule-name))
       (check-equal? ((edge-api-Q-R edge) source) expected-target)
       (check-transformation-chain edge source)))

   (test-case "sparse support follows the direct five-arrow chain"
     (for ([edge (in-list EDGES)]
           [source (in-list (list SPARSE-VERTICAL-WITNESS/S
                                  SPARSE-VERTICAL-WITNESS/E
                                  SPARSE-VERTICAL-WITNESS/S))]
           [target (in-list (list SPARSE-VERTICAL-WITNESS/E
                                  SPARSE-VERTICAL-WITNESS/N
                                  SPARSE-VERTICAL-WITNESS/N))])
       (check-equal? ((edge-api-Q-R edge) source) target)
       (check-transformation-chain edge source)))

   (test-case "finite success and failure traces commute at every B suffix"
     (for ([edge (in-list EDGES)])
       (define source-corpus
         (row-api-corpus (edge-api-source edge)))
       (define target-corpus
         (row-api-corpus (edge-api-target edge)))
       (define source-success (row-corpus-finite-source source-corpus))
       (check-equal?
        ((edge-api-Q-R edge) source-success)
        (row-corpus-finite-source target-corpus))
       (check-transformation-chain edge source-success)
       (check-finite-B-suffixes edge source-success)
       (for ([source-failure
              (in-list (row-corpus-failures source-corpus))]
             [target-failure
              (in-list (row-corpus-failures target-corpus))])
         (check-equal? (failure-case-name source-failure)
                       (failure-case-name target-failure))
         (define source (failure-case-source source-failure))
         (check-equal? ((edge-api-Q-R edge) source)
                       (failure-case-source target-failure))
         (check-transformation-chain edge source)
         (check-finite-B-suffixes edge source))))

   (test-case "allocation remains exact trace evidence, not a carrier node"
     (for ([row (in-list (list ROW/S ROW/E ROW/N))])
       (define source
         (row-source-ref (row-api-corpus row) 'allocate-fresh))
       (define B (initial-B row source))
       (match-define (list (list trace _big))
         ((row-api-observed-big row) B))
       (define labels ((row-api-flatten row) trace))
       (check-equal? (first labels) 'allocate-fresh)
       (check-false (regexp-match? #rx"AllocateEvent" (~s trace)))))))

(module+ test
  (run-tests GENERATED-CORE-STAGES-VERTICAL-TRANSFORMATIONS))
