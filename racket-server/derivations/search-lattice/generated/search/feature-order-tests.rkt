#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in cs: "source/s.rkt")
         (prefix-in ce: "source/e.rkt")
         (prefix-in cn: "source/n.rkt")
         (prefix-in rs: "source/feature-order/s.rkt")
         (prefix-in re: "source/feature-order/e.rkt")
         (prefix-in rn: "source/feature-order/n.rkt")
         (prefix-in os-lang: "../../oracles/search/s/language.rkt")
         (prefix-in os: "../../oracles/search/s/source.rkt")
         (prefix-in os-wf: "../../oracles/search/s/wf.rkt")
         (prefix-in oe-lang: "../../oracles/search/e/language.rkt")
         (prefix-in oe: "../../oracles/search/e/source.rkt")
         (prefix-in oe-wf: "../../oracles/search/e/wf.rkt")
         (prefix-in on-lang: "../../oracles/search/n/language.rkt")
         (prefix-in on: "../../oracles/search/n/source.rkt")
         (prefix-in on-wf: "../../oracles/search/n/wf.rkt")
         (prefix-in oq: "../../oracles/search/vertical.rkt")
         "corpus.rkt")

(provide GENERATED-SEARCH-FEATURE-ORDER-TESTS)

;; These are multiset normalizers, not set conversions.  Lengths are compared
;; before sorting and duplicate observations/proofs remain duplicate entries.
(define (canonical-multiset values)
  (sort values string<? #:key ~s))

(define (canonical-top-level-proof-multiset proofs)
  (canonical-multiset
   (for/list ([proof (in-list proofs)])
     (match (derivation-term proof)
       [(cons _judgment arguments) (cons 'judgment arguments)]))))

(define (rule-names relation)
  (sort
   (map (lambda (name) (string->symbol (~a name)))
        (reduction-relation->rule-names relation))
   symbol<?))

(define (trace raw source [fuel 64] [reversed-steps '()])
  (when (zero? fuel)
    (error 'trace "bounded Search trace exceeded 64 source steps"))
  (match (raw source)
    ['() (reverse reversed-steps)]
    [(list (and step (list _label target)))
     (trace raw target (sub1 fuel) (cons step reversed-steps))]
    [other
     (error 'trace
            "expected one complete raw Search successor, received ~e"
            other)]))

(define (trace-states source steps)
  (cons source (map second steps)))

(struct order-row
  (name
   corpus
   canonical-relation
   reverse-relation
   oracle-relation
   canonical-raw
   reverse-raw
   oracle-raw
   canonical-member?
   reverse-member?
   oracle-member?
   canonical-wf-proofs
   reverse-wf-proofs
   oracle-wf-proofs
   canonical-export
   canonical-rebuild
   reverse-export
   reverse-rebuild)
  #:transparent)

(define-syntax-rule
  (define-order-row
    row-id row-name corpus-id
    canonical-relation-id reverse-relation-id oracle-relation-id
    canonical-raw-id reverse-raw-id oracle-raw-id
    canonical-language-id reverse-language-id oracle-language-id
    canonical-wf-id reverse-wf-id oracle-wf-id
    canonical-export-id canonical-rebuild-id
    reverse-export-id reverse-rebuild-id)
  (define row-id
    (order-row
     row-name
     corpus-id
     canonical-relation-id
     reverse-relation-id
     oracle-relation-id
     canonical-raw-id
     reverse-raw-id
     oracle-raw-id
     (lambda (source) (redex-match? canonical-language-id F source))
     (lambda (source) (redex-match? reverse-language-id F source))
     (lambda (source) (redex-match? oracle-language-id F source))
     (lambda (source) (build-derivations (canonical-wf-id ,source)))
     (lambda (source) (build-derivations (reverse-wf-id ,source)))
     (lambda (source) (build-derivations (oracle-wf-id ,source)))
     canonical-export-id
     canonical-rebuild-id
     reverse-export-id
     reverse-rebuild-id)))

(define-order-row
  ROW/S 'S SEARCH-CORPUS/S
  cs:generated-search-s-red rs:generated-search-reverse-s-red
  os:search-s-oracle-red
  cs:raw-successors/generated/search/s
  rs:raw-successors/generated/search/reverse/s
  os:raw-successors/search/s
  cs:generated-search-s-lang rs:generated-search-reverse-s-lang
  os-lang:search-s-oracle-lang
  cs:wf-search/generated/s? rs:wf-search/generated/reverse/s?
  os-wf:wf-search-oracle/s?
  cs:q-export/generated/search/s cs:q-rebuild/generated/search/s
  rs:q-export/generated/search/reverse/s rs:q-rebuild/generated/search/reverse/s)

(define-order-row
  ROW/E 'E SEARCH-CORPUS/E
  ce:generated-search-e-red re:generated-search-reverse-e-red
  oe:search-e-oracle-red
  ce:raw-successors/generated/search/e
  re:raw-successors/generated/search/reverse/e
  oe:raw-successors/search/e
  ce:generated-search-e-lang re:generated-search-reverse-e-lang
  oe-lang:search-e-oracle-lang
  ce:wf-search/generated/e? re:wf-search/generated/reverse/e?
  oe-wf:wf-search-oracle/e?
  ce:q-export/generated/search/e ce:q-rebuild/generated/search/e
  re:q-export/generated/search/reverse/e re:q-rebuild/generated/search/reverse/e)

(define-order-row
  ROW/N 'N SEARCH-CORPUS/N
  cn:generated-search-n-red rn:generated-search-reverse-n-red
  on:search-n-oracle-red
  cn:raw-successors/generated/search/n
  rn:raw-successors/generated/search/reverse/n
  on:raw-successors/search/n
  cn:generated-search-n-lang rn:generated-search-reverse-n-lang
  on-lang:search-n-oracle-lang
  cn:wf-search/generated/n? rn:wf-search/generated/reverse/n?
  on-wf:wf-search-oracle/n?
  cn:q-export/generated/search/n cn:q-rebuild/generated/search/n
  rn:q-export/generated/search/reverse/n rn:q-rebuild/generated/search/reverse/n)

(define ROWS (list ROW/S ROW/E ROW/N))

(define (check-order-successors row source)
  (define canonical ((order-row-canonical-raw row) source))
  (define reverse ((order-row-reverse-raw row) source))
  (define oracle ((order-row-oracle-raw row) source))
  (check-equal? (length canonical) (length reverse))
  (check-equal? (length canonical) (length oracle))
  (check-equal? (canonical-multiset canonical)
                (canonical-multiset reverse))
  (check-equal? (canonical-multiset canonical)
                (canonical-multiset oracle)))

(define (check-order-wf row source expected?)
  (define canonical ((order-row-canonical-wf-proofs row) source))
  (define reverse ((order-row-reverse-wf-proofs row) source))
  (define oracle ((order-row-oracle-wf-proofs row) source))
  (check-equal? (pair? canonical) expected?)
  (check-equal? (pair? reverse) expected?)
  (check-equal? (pair? oracle) expected?)
  (check-equal? (length canonical) (length reverse))
  (check-equal? (length canonical) (length oracle))
  (check-equal? (canonical-top-level-proof-multiset canonical)
                (canonical-top-level-proof-multiset reverse))
  (check-equal? (canonical-top-level-proof-multiset canonical)
                (canonical-top-level-proof-multiset oracle)))

(define (check-order-Q row source)
  (define canonical-neutral ((order-row-canonical-export row) source))
  (define reverse-neutral ((order-row-reverse-export row) source))
  (check-equal? canonical-neutral reverse-neutral)
  (check-equal? ((order-row-canonical-rebuild row) canonical-neutral)
                source)
  (check-equal? ((order-row-reverse-rebuild row) reverse-neutral)
                source))

(define (check-oracle-representation-cube source/s expected/e expected/n)
  (check-equal? (oq:Q-SE/F/search source/s) expected/e)
  (check-equal? (oq:Q-SN/F/search source/s) expected/n)
  (check-equal? (oq:Q-EN/F/search expected/e) expected/n)
  (check-true (oq:Q-SN-composition?/search source/s))
  (check-true (oq:Q-SE-step-square/raw?/search source/s))
  (check-true (oq:Q-EN-step-square/raw?/search expected/e))
  (check-true (oq:Q-SN-step-square/raw?/search source/s)))

(define GENERATED-SEARCH-FEATURE-ORDER-TESTS
  (test-suite
   "generated Search feature-order independence"

   (test-case "canonical and reverse generators expose the same twenty-one rules"
     (for ([row (in-list ROWS)])
       (check-equal? (rule-names (order-row-canonical-relation row))
                     SEARCH-RULE-NAMES)
       (check-equal? (rule-names (order-row-reverse-relation row))
                     SEARCH-RULE-NAMES)
       (check-equal? (rule-names (order-row-oracle-relation row))
                     SEARCH-RULE-NAMES)
       (check-equal?
        (length
         (reduction-relation->rule-names
          (order-row-canonical-relation row)))
        21)
       (check-equal?
        (length
         (reduction-relation->rule-names
          (order-row-reverse-relation row)))
        21)
       (check-equal?
        (length
         (reduction-relation->rule-names
          (order-row-oracle-relation row)))
        21))
     (check-equal? (canonical-multiset '((same target) (same target)))
                   '((same target) (same target)))
     (check-not-equal? (canonical-multiset '((same target) (same target)))
                       (canonical-multiset '((same target)))))

   (test-case "all representatives and mixed equations preserve raw multiplicity"
     (for ([row (in-list ROWS)])
       (define corpus (order-row-corpus row))
       (define mixed (search-row-corpus-mixed-feature-cases corpus))
       (for ([representative
              (in-list (search-row-corpus-rule-sources corpus))])
         (match-define (list expected-label source) representative)
         (with-check-info (['row (order-row-name row)]
                           ['label expected-label]
                           ['source source])
           (define successors ((order-row-canonical-raw row) source))
           (check-order-successors row source)
           (check-equal? (length successors) 1)
           (check-equal? (map first successors) (list expected-label))))
       (check-equal? (map search-mixed-case-name mixed)
                     EXPECTED-SEARCH-MIXED-CASE-NAMES)
       (for ([case (in-list mixed)])
         (check-order-successors row (search-mixed-case-source case))
         (check-order-successors row (search-mixed-case-target case))
         (check-equal?
          ((order-row-canonical-raw row)
           (search-mixed-case-source case))
          (list
           (list (search-mixed-case-label case)
                 (search-mixed-case-target case)))))
       (check-order-successors
        row
        (search-row-corpus-joint-focus-witness corpus))
       (check-order-successors
        row
        (search-row-corpus-scheduler-barrier corpus))))

   (test-case "raw WF proof multisets agree without deduplication"
     (for ([row (in-list ROWS)])
       (define corpus (order-row-corpus row))
       (for ([representative
              (in-list (search-row-corpus-rule-sources corpus))])
         (check-order-wf row (second representative) #t))
       (for ([case
              (in-list (search-row-corpus-mixed-feature-cases corpus))])
         (check-order-wf row (search-mixed-case-source case) #t)
         (check-order-wf row (search-mixed-case-target case) #t))
       (check-order-wf row
                       (search-row-corpus-joint-focus-witness corpus)
                       #t)
       (check-order-wf row
                       (search-row-corpus-scheduler-barrier corpus)
                       #t)
       (for ([negative
              (in-list (search-row-corpus-grammar-negatives corpus))])
         (define source (search-negative-case-source negative))
         (check-false ((order-row-canonical-member? row) source))
         (check-false ((order-row-reverse-member? row) source))
         (check-false ((order-row-oracle-member? row) source)))
       (for ([negative (in-list (search-row-corpus-wf-negatives corpus))])
         (define source (search-negative-case-source negative))
         (check-true ((order-row-canonical-member? row) source))
         (check-true ((order-row-reverse-member? row) source))
         (check-true ((order-row-oracle-member? row) source))
         (check-order-wf row source #f))))

   (test-case "three bounded traces and scheduler barrier are order-independent"
     (for ([row (in-list ROWS)])
       (define corpus (order-row-corpus row))
       (define traces (search-row-corpus-finite-traces corpus))
       (define barrier (search-row-corpus-scheduler-barrier corpus))
       (check-equal? (map search-trace-case-name traces)
                     EXPECTED-SEARCH-TRACE-NAMES)
       (for ([trace-case (in-list traces)])
         (define source (search-trace-case-source trace-case))
         (define canonical (trace (order-row-canonical-raw row) source))
         (define reverse (trace (order-row-reverse-raw row) source))
         (define oracle (trace (order-row-oracle-raw row) source))
         (check-equal? (length canonical) (length reverse))
         (check-equal? (length canonical) (length oracle))
         (check-equal? canonical reverse)
         (check-equal? canonical oracle)
         (check-equal? (map first canonical)
                       (search-trace-case-labels trace-case))
         (check-equal? (if (null? canonical)
                           source
                           (second (last canonical)))
                       (search-trace-case-terminal trace-case)))
       (check-equal? ((order-row-canonical-raw row) barrier) '())
       (check-equal? ((order-row-reverse-raw row) barrier) '())
       (check-equal? ((order-row-oracle-raw row) barrier) '())))

   (test-case "joint neutral Q views and round-trips are order-independent"
     (for ([row (in-list ROWS)])
       (define corpus (order-row-corpus row))
       (for ([representative
              (in-list (search-row-corpus-rule-sources corpus))])
         (check-order-Q row (second representative)))
       (for ([case
              (in-list (search-row-corpus-mixed-feature-cases corpus))])
         (check-order-Q row (search-mixed-case-source case))
         (check-order-Q row (search-mixed-case-target case)))
       (check-order-Q row
                      (search-row-corpus-joint-focus-witness corpus))
       (check-order-Q row
                      (search-row-corpus-scheduler-barrier corpus))
       (for ([trace-case
              (in-list (search-row-corpus-finite-traces corpus))])
         (define source (search-trace-case-source trace-case))
         (define steps (trace (order-row-canonical-raw row) source))
         (for ([state (in-list (trace-states source steps))])
           (check-order-Q row state)))))

   (test-case "independent direct representation maps cover the same corpus"
     (define sources/s (search-row-corpus-rule-sources SEARCH-CORPUS/S))
     (define sources/e (search-row-corpus-rule-sources SEARCH-CORPUS/E))
     (define sources/n (search-row-corpus-rule-sources SEARCH-CORPUS/N))
     (define mixed/s
       (search-row-corpus-mixed-feature-cases SEARCH-CORPUS/S))
     (define mixed/e
       (search-row-corpus-mixed-feature-cases SEARCH-CORPUS/E))
     (define mixed/n
       (search-row-corpus-mixed-feature-cases SEARCH-CORPUS/N))
     (check-equal? (map first sources/s) (map first sources/e))
     (check-equal? (map first sources/s) (map first sources/n))
     (check-equal? (length sources/s) 21)
     (for ([pair/s (in-list sources/s)]
           [pair/e (in-list sources/e)]
           [pair/n (in-list sources/n)])
       (check-equal? (first pair/s) (first pair/e))
       (check-equal? (first pair/s) (first pair/n))
       (check-oracle-representation-cube
        (second pair/s) (second pair/e) (second pair/n)))
     (check-equal? (map search-mixed-case-name mixed/s)
                   (map search-mixed-case-name mixed/e))
     (check-equal? (map search-mixed-case-name mixed/s)
                   (map search-mixed-case-name mixed/n))
     (check-equal? (length mixed/s) 8)
     (for ([case/s (in-list mixed/s)]
           [case/e (in-list mixed/e)]
           [case/n (in-list mixed/n)])
       (check-equal? (search-mixed-case-name case/s)
                     (search-mixed-case-name case/e))
       (check-equal? (search-mixed-case-name case/s)
                     (search-mixed-case-name case/n))
       (check-oracle-representation-cube
        (search-mixed-case-source case/s)
        (search-mixed-case-source case/e)
        (search-mixed-case-source case/n))
       (check-oracle-representation-cube
        (search-mixed-case-target case/s)
        (search-mixed-case-target case/e)
        (search-mixed-case-target case/n)))
     (check-oracle-representation-cube
      (search-row-corpus-joint-focus-witness SEARCH-CORPUS/S)
      (search-row-corpus-joint-focus-witness SEARCH-CORPUS/E)
      (search-row-corpus-joint-focus-witness SEARCH-CORPUS/N))
     (check-oracle-representation-cube
      (search-row-corpus-scheduler-barrier SEARCH-CORPUS/S)
      (search-row-corpus-scheduler-barrier SEARCH-CORPUS/E)
      (search-row-corpus-scheduler-barrier SEARCH-CORPUS/N)))))

(module+ test
  (run-tests GENERATED-SEARCH-FEATURE-ORDER-TESTS))
