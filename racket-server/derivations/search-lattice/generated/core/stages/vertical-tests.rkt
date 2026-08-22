#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in source-s: "../source/s.rkt")
         (prefix-in source-e: "../source/e.rkt")
         (prefix-in source-n: "../source/n.rkt")
         (prefix-in source-q: "../source/vertical.rkt")
         (prefix-in stage-s: "./s.rkt")
         (prefix-in stage-e: "./e.rkt")
         (prefix-in stage-n: "./n.rkt")
         (prefix-in stage-q: "./vertical.rkt")
         "./corpus.rkt")

(provide GENERATED-CORE-STAGES-VERTICAL)

(struct row-api
  (name
   corpus
   wf?
   decompose
   contract
   d-step
   plug-D
   D->Z
   Z->D
   z-step
   encode-ZM
   decode-MZ
   m-step
   encode-MB
   decode-BM
   b-step
   readback-Z
   readback-M
   readback-B
   readback-Big
   big-direct
   big-spec
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
    decompose-id contract-id d-step-id plug-D-id
    D->Z-id Z->D-id z-step-id
    encode-ZM-id decode-MZ-id m-step-id
    encode-MB-id decode-BM-id b-step-id
    readback-Z-id readback-M-id readback-B-id readback-Big-id
    big-direct-id big-spec-id flatten-id)
  (define api-id
    (row-api
     row-name
     corpus-id
     (lambda (frontier) (judgment-holds (wf-id ,frontier)))
     (lambda (frontier)
       (values
        (judgment-holds (decompose-id ,frontier D) D)
        (length (build-derivations (decompose-id ,frontier D)))))
     (lambda (decomposition)
       (values
        (judgment-holds (contract-id ,decomposition C) C)
        (length (build-derivations (contract-id ,decomposition C)))))
     (lambda (decomposition)
       (values
        (judgment-holds
         (d-step-id ,decomposition RuleName D_next)
         (RuleName D_next))
        (length
         (build-derivations
          (d-step-id ,decomposition RuleName D_next)))))
     (lambda (decomposition) (term (plug-D-id ,decomposition)))
     (lambda (decomposition) (term (D->Z-id ,decomposition)))
     (lambda (refocused) (term (Z->D-id ,refocused)))
     (lambda (refocused)
       (values
        (judgment-holds
         (z-step-id ,refocused RuleName Z_next)
         (RuleName Z_next))
        (length
         (build-derivations
          (z-step-id ,refocused RuleName Z_next)))))
     (lambda (refocused) (term (encode-ZM-id ,refocused)))
     (lambda (machine) (term (decode-MZ-id ,machine)))
     (lambda (machine)
       (values
        (judgment-holds
         (m-step-id ,machine RuleName M_next)
         (RuleName M_next))
        (length
         (build-derivations
          (m-step-id ,machine RuleName M_next)))))
     (lambda (machine) (term (encode-MB-id ,machine)))
     (lambda (compressed) (term (decode-BM-id ,compressed)))
     (lambda (compressed)
       (values
        (judgment-holds
         (b-step-id ,compressed TransitionSpan B_next)
         (TransitionSpan B_next))
        (length
         (build-derivations
          (b-step-id ,compressed TransitionSpan B_next)))))
     (lambda (refocused) (term (readback-Z-id ,refocused)))
     (lambda (machine) (term (readback-M-id ,machine)))
     (lambda (compressed) (term (readback-B-id ,compressed)))
     (lambda (big) (term (readback-Big-id ,big)))
     (lambda (frontier)
       (values
        (judgment-holds (big-direct-id ,frontier Big) Big)
        (length (build-derivations (big-direct-id ,frontier Big)))))
     (lambda (frontier)
       (values
        (judgment-holds
         (big-spec-id ,frontier BTrace Big)
         (BTrace Big))
        (length
         (build-derivations
          (big-spec-id ,frontier BTrace Big)))))
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
  stage-s:generated-stage-contract/s
  stage-s:generated-stage-decomposed-step/s
  stage-s:generated-stage-plug-D/s
  stage-s:generated-stage-D->Z/s
  stage-s:generated-stage-Z->D/s
  stage-s:generated-stage-refocused-step/direct/s
  stage-s:generated-stage-encode-ZM/s
  stage-s:generated-stage-decode-MZ/s
  stage-s:generated-stage-machine-step/direct/s
  stage-s:generated-stage-encode-MB/s
  stage-s:generated-stage-decode-BM/s
  stage-s:generated-stage-compressed-step/direct/s
  stage-s:generated-stage-readback-Z/s
  stage-s:generated-stage-readback-M/s
  stage-s:generated-stage-readback-B/s
  stage-s:generated-stage-readback-Big/s
  stage-s:generated-stage-big-evaluate/direct/s
  stage-s:generated-stage-big-evaluate/spec/s
  stage-s:generated-stage-flatten-BTrace/s)

(define-row-api
  ROW/E 'E CORE-CORPUS/E source-e:wf-core/generated/e?
  stage-e:generated-core-stage-e-decomposition-lang
  stage-e:generated-core-stage-e-refocused-lang
  stage-e:generated-core-stage-e-machine-lang
  stage-e:generated-core-stage-e-compressed-lang
  stage-e:generated-core-stage-e-big-lang
  stage-e:generated-stage-decompose/e
  stage-e:generated-stage-contract/e
  stage-e:generated-stage-decomposed-step/e
  stage-e:generated-stage-plug-D/e
  stage-e:generated-stage-D->Z/e
  stage-e:generated-stage-Z->D/e
  stage-e:generated-stage-refocused-step/direct/e
  stage-e:generated-stage-encode-ZM/e
  stage-e:generated-stage-decode-MZ/e
  stage-e:generated-stage-machine-step/direct/e
  stage-e:generated-stage-encode-MB/e
  stage-e:generated-stage-decode-BM/e
  stage-e:generated-stage-compressed-step/direct/e
  stage-e:generated-stage-readback-Z/e
  stage-e:generated-stage-readback-M/e
  stage-e:generated-stage-readback-B/e
  stage-e:generated-stage-readback-Big/e
  stage-e:generated-stage-big-evaluate/direct/e
  stage-e:generated-stage-big-evaluate/spec/e
  stage-e:generated-stage-flatten-BTrace/e)

(define-row-api
  ROW/N 'N CORE-CORPUS/N source-n:wf-core/generated/n?
  stage-n:generated-core-stage-n-decomposition-lang
  stage-n:generated-core-stage-n-refocused-lang
  stage-n:generated-core-stage-n-machine-lang
  stage-n:generated-core-stage-n-compressed-lang
  stage-n:generated-core-stage-n-big-lang
  stage-n:generated-stage-decompose/n
  stage-n:generated-stage-contract/n
  stage-n:generated-stage-decomposed-step/n
  stage-n:generated-stage-plug-D/n
  stage-n:generated-stage-D->Z/n
  stage-n:generated-stage-Z->D/n
  stage-n:generated-stage-refocused-step/direct/n
  stage-n:generated-stage-encode-ZM/n
  stage-n:generated-stage-decode-MZ/n
  stage-n:generated-stage-machine-step/direct/n
  stage-n:generated-stage-encode-MB/n
  stage-n:generated-stage-decode-BM/n
  stage-n:generated-stage-compressed-step/direct/n
  stage-n:generated-stage-readback-Z/n
  stage-n:generated-stage-readback-M/n
  stage-n:generated-stage-readback-B/n
  stage-n:generated-stage-readback-Big/n
  stage-n:generated-stage-big-evaluate/direct/n
  stage-n:generated-stage-big-evaluate/spec/n
  stage-n:generated-stage-flatten-BTrace/n)

(struct edge-api
  (name
   source
   target
   Q-R
   Q-C
   Q-D
   Q-D/transport
   Q-Z
   Q-Z/transport
   Q-M
   Q-M/transport
   Q-B
   Q-B/transport
   Q-Big
   C-composition?
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
   stage-q:Q-SE/C/stages
   stage-q:Q-SE/D/stages
   stage-q:Q-SE/D/transport/stages
   stage-q:Q-SE/Z/stages
   stage-q:Q-SE/Z/transport/stages
   stage-q:Q-SE/M/stages
   stage-q:Q-SE/M/transport/stages
   stage-q:Q-SE/B/stages
   stage-q:Q-SE/B/transport/stages
   stage-q:Q-SE/Big/stages
   #f #f #f #f #f #f))

(define EDGE/EN
  (edge-api
   'E->N ROW/E ROW/N
   stage-q:Q-EN/R/stages
   stage-q:Q-EN/C/stages
   stage-q:Q-EN/D/stages
   stage-q:Q-EN/D/transport/stages
   stage-q:Q-EN/Z/stages
   stage-q:Q-EN/Z/transport/stages
   stage-q:Q-EN/M/stages
   stage-q:Q-EN/M/transport/stages
   stage-q:Q-EN/B/stages
   stage-q:Q-EN/B/transport/stages
   stage-q:Q-EN/Big/stages
   #f #f #f #f #f #f))

(define EDGE/SN
  (edge-api
   'S->N ROW/S ROW/N
   stage-q:Q-SN/R/stages
   stage-q:Q-SN/C/stages
   stage-q:Q-SN/D/stages
   stage-q:Q-SN/D/transport/stages
   stage-q:Q-SN/Z/stages
   stage-q:Q-SN/Z/transport/stages
   stage-q:Q-SN/M/stages
   stage-q:Q-SN/M/transport/stages
   stage-q:Q-SN/B/stages
   stage-q:Q-SN/B/transport/stages
   stage-q:Q-SN/Big/stages
   stage-q:Q-SN/C-composition/stages?
   stage-q:Q-SN/D-composition/stages?
   stage-q:Q-SN/Z-composition/stages?
   stage-q:Q-SN/M-composition/stages?
   stage-q:Q-SN/B-composition/stages?
   stage-q:Q-SN/Big-composition/stages?))

(define EDGES (list EDGE/SE EDGE/EN EDGE/SN))

(define (only-result who values count)
  (check-equal? count 1 (format "~a raw proof multiplicity" who))
  (match values
    [(list value) value]
    [_ (error who "expected one result, received ~e" values)]))

(define (canonical-multiset values)
  (sort values string<? #:key ~s))

(define (map-labeled results Q)
  (for/list ([result (in-list results)])
    (match-define (list label target) result)
    (list label (Q target))))

(define (check-step-square who source-step target-step source-carrier
                           target-carrier Q)
  (define-values (source-results source-count)
    (source-step source-carrier))
  (define-values (target-results target-count)
    (target-step target-carrier))
  (check-equal? source-count 1
                (format "~a source raw proof multiplicity" who))
  (check-equal? target-count 1
                (format "~a target raw proof multiplicity" who))
  (check-equal? source-count (length source-results))
  (check-equal? target-count (length target-results))
  (check-equal? source-count target-count
                (format "~a raw proof multiplicity" who))
  (check-equal?
   (canonical-multiset (map-labeled source-results Q))
   (canonical-multiset target-results)
   (format "~a labeled target multiset" who)))

(define (check-edge-representative edge rule-name)
  (define source-row (edge-api-source edge))
  (define target-row (edge-api-target edge))
  (define source
    (row-source-ref (row-api-corpus source-row) rule-name))
  (define expected-target
    (row-source-ref (row-api-corpus target-row) rule-name))
  (define target ((edge-api-Q-R edge) source))
  (check-equal? target expected-target)
  (check-true ((row-api-wf? source-row) source))
  (check-true ((row-api-wf? target-row) target))

  (define-values (source-Ds source-D-count)
    ((row-api-decompose source-row) source))
  (define-values (target-Ds target-D-count)
    ((row-api-decompose target-row) target))
  (define source-D
    (only-result `(,(edge-api-name edge) ,rule-name source-D)
                 source-Ds source-D-count))
  (define target-D
    (only-result `(,(edge-api-name edge) ,rule-name target-D)
                 target-Ds target-D-count))
  (check-equal? ((edge-api-Q-D edge) source-D) target-D)
  (check-equal? ((edge-api-Q-D/transport edge) source-D) target-D)
  (check-true ((row-api-D? target-row) target-D))
  (check-equal?
   ((row-api-plug-D target-row) target-D)
   target)
  (check-equal?
   ((row-api-plug-D target-row) ((edge-api-Q-D edge) source-D))
   ((edge-api-Q-R edge) ((row-api-plug-D source-row) source-D)))

  (define-values (source-Cs source-C-count)
    ((row-api-contract source-row) source-D))
  (define-values (target-Cs target-C-count)
    ((row-api-contract target-row) target-D))
  (define source-C
    (only-result `(,(edge-api-name edge) ,rule-name source-C)
                 source-Cs source-C-count))
  (define target-C
    (only-result `(,(edge-api-name edge) ,rule-name target-C)
                 target-Cs target-C-count))
  (check-equal? ((edge-api-Q-C edge) source-C) target-C)

  (check-step-square
   `(,(edge-api-name edge) ,rule-name D)
   (row-api-d-step source-row)
   (row-api-d-step target-row)
   source-D target-D (edge-api-Q-D edge))

  (define source-Z ((row-api-D->Z source-row) source-D))
  (define target-Z ((row-api-D->Z target-row) target-D))
  (check-equal? ((edge-api-Q-Z edge) source-Z) target-Z)
  (check-equal? ((edge-api-Q-Z/transport edge) source-Z) target-Z)
  (check-true ((row-api-Z? target-row) target-Z))
  (check-equal?
   ((row-api-readback-Z target-row) target-Z)
   ((edge-api-Q-R edge) ((row-api-readback-Z source-row) source-Z)))
  (check-step-square
   `(,(edge-api-name edge) ,rule-name Z)
   (row-api-z-step source-row)
   (row-api-z-step target-row)
   source-Z target-Z (edge-api-Q-Z edge))

  (define source-M ((row-api-encode-ZM source-row) source-Z))
  (define target-M ((row-api-encode-ZM target-row) target-Z))
  (check-equal? ((edge-api-Q-M edge) source-M) target-M)
  (check-equal? ((edge-api-Q-M/transport edge) source-M) target-M)
  (check-true ((row-api-M? target-row) target-M))
  (check-equal?
   ((row-api-readback-M target-row) target-M)
   ((edge-api-Q-R edge) ((row-api-readback-M source-row) source-M)))
  (check-step-square
   `(,(edge-api-name edge) ,rule-name M)
   (row-api-m-step source-row)
   (row-api-m-step target-row)
   source-M target-M (edge-api-Q-M edge))

  (define source-B ((row-api-encode-MB source-row) source-M))
  (define target-B ((row-api-encode-MB target-row) target-M))
  (check-equal? ((edge-api-Q-B edge) source-B) target-B)
  (check-equal? ((edge-api-Q-B/transport edge) source-B) target-B)
  (check-true ((row-api-B? target-row) target-B))
  (check-equal?
   ((row-api-readback-B target-row) target-B)
   ((edge-api-Q-R edge) ((row-api-readback-B source-row) source-B)))
  (check-step-square
   `(,(edge-api-name edge) ,rule-name B)
   (row-api-b-step source-row)
   (row-api-b-step target-row)
   source-B target-B (edge-api-Q-B edge))

  (define-values (source-Bigs source-Big-count)
    ((row-api-big-direct source-row) source))
  (define-values (target-Bigs target-Big-count)
    ((row-api-big-direct target-row) target))
  (define source-Big
    (only-result `(,(edge-api-name edge) ,rule-name source-Big)
                 source-Bigs source-Big-count))
  (define target-Big
    (only-result `(,(edge-api-name edge) ,rule-name target-Big)
                 target-Bigs target-Big-count))
  (check-equal? ((edge-api-Q-Big edge) source-Big) target-Big)
  (check-true ((row-api-Big? target-row) target-Big))
  (check-equal?
   ((row-api-readback-Big target-row) target-Big)
   ((edge-api-Q-R edge)
    ((row-api-readback-Big source-row) source-Big)))

  ;; BigFinal intentionally carries no labels.  The retained observation lives
  ;; in the exact BTrace produced by the independent finite-closure spec.
  (define-values (source-spec source-spec-count)
    ((row-api-big-spec source-row) source))
  (define-values (target-spec target-spec-count)
    ((row-api-big-spec target-row) target))
  (check-equal? source-spec-count 1)
  (check-equal? target-spec-count 1)
  (check-equal? source-spec-count (length source-spec))
  (check-equal? target-spec-count (length target-spec))
  (check-equal? source-spec-count target-spec-count)
  (check-equal?
   (canonical-multiset
    (for/list ([result (in-list source-spec)])
      (match-define (list trace big) result)
      (list trace ((edge-api-Q-Big edge) big))))
   (canonical-multiset target-spec))
  (for ([result (in-list source-spec)])
    (match-define (list trace _big) result)
    (check-equal?
     ((row-api-flatten source-row) trace)
     ((row-api-flatten target-row) trace)))

  (when (eq? (edge-api-name edge) 'S->N)
    (check-true (stage-q:Q-SN/R-composition/stages? source))
    (check-true ((edge-api-C-composition? edge) source-C))
    (check-true ((edge-api-D-composition? edge) source-D))
    (check-true ((edge-api-Z-composition? edge) source-Z))
    (check-true ((edge-api-M-composition? edge) source-M))
    (check-true ((edge-api-B-composition? edge) source-B))
    (check-true ((edge-api-Big-composition? edge) source-Big))))

(define (check-complete-execution edge source expected-target)
  (define source-row (edge-api-source edge))
  (define target-row (edge-api-target edge))
  (define target ((edge-api-Q-R edge) source))
  (check-equal? target expected-target)
  (check-true ((row-api-wf? source-row) source))
  (check-true ((row-api-wf? target-row) target))

  (define-values (source-Ds source-D-count)
    ((row-api-decompose source-row) source))
  (define-values (target-Ds target-D-count)
    ((row-api-decompose target-row) target))
  (define source-D
    (only-result `(,(edge-api-name edge) complete-source-D)
                 source-Ds source-D-count))
  (define target-D
    (only-result `(,(edge-api-name edge) complete-target-D)
                 target-Ds target-D-count))
  (check-equal? ((edge-api-Q-D edge) source-D) target-D)
  (check-equal? ((edge-api-Q-D/transport edge) source-D) target-D)

  (define source-Z ((row-api-D->Z source-row) source-D))
  (define target-Z ((row-api-D->Z target-row) target-D))
  (check-equal? ((edge-api-Q-Z edge) source-Z) target-Z)
  (check-equal? ((edge-api-Q-Z/transport edge) source-Z) target-Z)

  (define source-M ((row-api-encode-ZM source-row) source-Z))
  (define target-M ((row-api-encode-ZM target-row) target-Z))
  (check-equal? ((edge-api-Q-M edge) source-M) target-M)
  (check-equal? ((edge-api-Q-M/transport edge) source-M) target-M)

  (define source-B ((row-api-encode-MB source-row) source-M))
  (define target-B ((row-api-encode-MB target-row) target-M))
  (check-equal? ((edge-api-Q-B edge) source-B) target-B)
  (check-equal? ((edge-api-Q-B/transport edge) source-B) target-B)

  (define-values (source-Bigs source-Big-count)
    ((row-api-big-direct source-row) source))
  (define-values (target-Bigs target-Big-count)
    ((row-api-big-direct target-row) target))
  (define source-Big
    (only-result `(,(edge-api-name edge) complete-source-Big)
                 source-Bigs source-Big-count))
  (define target-Big
    (only-result `(,(edge-api-name edge) complete-target-Big)
                 target-Bigs target-Big-count))
  (check-equal? ((edge-api-Q-Big edge) source-Big) target-Big)

  (when (eq? (edge-api-name edge) 'S->N)
    (check-true (stage-q:Q-SN/R-composition/stages? source))
    (check-true ((edge-api-D-composition? edge) source-D))
    (check-true ((edge-api-Z-composition? edge) source-Z))
    (check-true ((edge-api-M-composition? edge) source-M))
    (check-true ((edge-api-B-composition? edge) source-B))
    (check-true ((edge-api-Big-composition? edge) source-Big)))

  (define-values (source-spec source-count)
    ((row-api-big-spec source-row) source))
  (define-values (target-spec target-count)
    ((row-api-big-spec target-row) target))
  (check-equal? source-count 1)
  (check-equal? target-count 1)
  (check-equal? source-count (length source-spec))
  (check-equal? target-count (length target-spec))
  (check-equal? source-count target-count)
  (check-equal?
   (canonical-multiset
    (for/list ([result (in-list source-spec)])
      (match-define (list trace big) result)
      (list trace ((edge-api-Q-Big edge) big))))
   (canonical-multiset target-spec)))

(define GENERATED-CORE-STAGES-VERTICAL
  (test-suite
   "selected core stage vertical faces"

   (test-case "all 13 rule representatives commute at D Z M B and Big"
     (for* ([edge (in-list EDGES)]
            [rule-name (in-list CORE-RULE-NAMES)])
       (check-edge-representative edge rule-name)))

   (test-case "sparse ordered support maps positionally through every stage"
     (check-equal?
      (source-q:Q-SE/generated SPARSE-VERTICAL-WITNESS/S)
      SPARSE-VERTICAL-WITNESS/E)
     (check-equal?
      (source-q:Q-SN/generated SPARSE-VERTICAL-WITNESS/S)
      SPARSE-VERTICAL-WITNESS/N)
     (check-equal?
      (source-q:Q-EN/generated SPARSE-VERTICAL-WITNESS/E)
      SPARSE-VERTICAL-WITNESS/N)
     (for ([edge (in-list EDGES)]
           [source (in-list (list SPARSE-VERTICAL-WITNESS/S
                                  SPARSE-VERTICAL-WITNESS/E
                                  SPARSE-VERTICAL-WITNESS/S))]
           [target (in-list (list SPARSE-VERTICAL-WITNESS/E
                                  SPARSE-VERTICAL-WITNESS/N
                                  SPARSE-VERTICAL-WITNESS/N))])
       (check-complete-execution edge source target)))

   (test-case "success and all failure-summary traces preserve exact BTrace"
     (for ([edge (in-list EDGES)])
       (define source-corpus
         (row-api-corpus (edge-api-source edge)))
       (define target-corpus
         (row-api-corpus (edge-api-target edge)))
       (check-complete-execution
        edge
        (row-corpus-finite-source source-corpus)
        (row-corpus-finite-source target-corpus))
       (for ([source-failure
              (in-list (row-corpus-failures source-corpus))]
             [target-failure
              (in-list (row-corpus-failures target-corpus))])
         (check-equal? (failure-case-name source-failure)
                       (failure-case-name target-failure))
         (check-complete-execution
          edge
          (failure-case-source source-failure)
          (failure-case-source target-failure)))))

   (test-case "allocation remains a label observation, never a carrier node"
     (for ([edge (in-list EDGES)])
       (define source-row (edge-api-source edge))
       (define source
         (row-source-ref (row-api-corpus source-row) 'allocate-fresh))
       (define-values (results count)
         ((row-api-big-spec source-row) source))
       (check-equal? count 1)
       (match-define (list (list trace _big)) results)
       (define labels ((row-api-flatten source-row) trace))
       (check-equal? (first labels) 'allocate-fresh)
       (check-false (regexp-match? #rx"AllocateEvent" (~s trace)))))))

(module+ test
  (run-tests GENERATED-CORE-STAGES-VERTICAL))
