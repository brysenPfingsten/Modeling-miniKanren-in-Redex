#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in gs: "source/s.rkt")
         (prefix-in ge: "source/e.rkt")
         (prefix-in gn: "source/n.rkt")
         (prefix-in gq: "source/vertical.rkt")
         (prefix-in delay: "../delay/corpus.rkt")
         (prefix-in disjunction: "../disjunction/corpus.rkt")
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

(provide GENERATED-SEARCH-SOURCE-TESTS)

;; Sorting changes enumeration order only.  It never removes duplicate
;; successors or duplicate top-level derivations.
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

(define (trace-final source steps)
  (match steps
    ['() source]
    [_ (second (last steps))]))

(struct source-row
  (name
   corpus
   relation
   oracle-relation
   raw
   oracle-raw
   member?
   oracle-member?
   wf-proofs
   oracle-wf-proofs
   q-roundtrip
   J-core
   J-delay
   J-disjunction)
  #:transparent)

(define-syntax-rule
  (define-source-row
    row-id row-name corpus-id
    relation-id oracle-relation-id
    raw-id oracle-raw-id
    language-id oracle-language-id
    wf-id oracle-wf-id
    export-id rebuild-id
    J-core-id J-delay-id J-disjunction-id)
  (define row-id
    (source-row
     row-name
     corpus-id
     relation-id
     oracle-relation-id
     raw-id
     oracle-raw-id
     (lambda (source) (redex-match? language-id F source))
     (lambda (source) (redex-match? oracle-language-id F source))
     (lambda (source) (build-derivations (wf-id ,source)))
     (lambda (source) (build-derivations (oracle-wf-id ,source)))
     (lambda (source) (rebuild-id (export-id source)))
     J-core-id
     J-delay-id
     J-disjunction-id)))

(define-source-row
  ROW/S 'S SEARCH-CORPUS/S
  gs:generated-search-s-red os:search-s-oracle-red
  gs:raw-successors/generated/search/s os:raw-successors/search/s
  gs:generated-search-s-lang os-lang:search-s-oracle-lang
  gs:wf-search/generated/s? os-wf:wf-search-oracle/s?
  gs:q-export/generated/search/s gs:q-rebuild/generated/search/s
  gs:J-core->search/R/S gs:J-delay->search/R/S
  gs:J-disjunction->search/R/S)

(define-source-row
  ROW/E 'E SEARCH-CORPUS/E
  ge:generated-search-e-red oe:search-e-oracle-red
  ge:raw-successors/generated/search/e oe:raw-successors/search/e
  ge:generated-search-e-lang oe-lang:search-e-oracle-lang
  ge:wf-search/generated/e? oe-wf:wf-search-oracle/e?
  ge:q-export/generated/search/e ge:q-rebuild/generated/search/e
  ge:J-core->search/R/E ge:J-delay->search/R/E
  ge:J-disjunction->search/R/E)

(define-source-row
  ROW/N 'N SEARCH-CORPUS/N
  gn:generated-search-n-red on:search-n-oracle-red
  gn:raw-successors/generated/search/n on:raw-successors/search/n
  gn:generated-search-n-lang on-lang:search-n-oracle-lang
  gn:wf-search/generated/n? on-wf:wf-search-oracle/n?
  gn:q-export/generated/search/n gn:q-rebuild/generated/search/n
  gn:J-core->search/R/N gn:J-delay->search/R/N
  gn:J-disjunction->search/R/N)

(define ROWS (list ROW/S ROW/E ROW/N))

(define (check-wf row source expected?)
  (define generated ((source-row-wf-proofs row) source))
  (define oracle ((source-row-oracle-wf-proofs row) source))
  (check-equal? (pair? generated) expected?)
  (check-equal? (pair? oracle) expected?)
  (check-equal? (length generated) (length oracle))
  (check-equal? (canonical-top-level-proof-multiset generated)
                (canonical-top-level-proof-multiset oracle))
  ;; Retain both actual proof lists and their full multiplicities.  No set
  ;; conversion appears in this suite.
  (list generated oracle))

(define (check-row-successors row source)
  (define generated ((source-row-raw row) source))
  (define oracle ((source-row-oracle-raw row) source))
  (check-equal? (length generated) (length oracle))
  (check-equal? (canonical-multiset generated)
                (canonical-multiset oracle))
  generated)

(define (transport-successors Q successors)
  (for/list ([successor (in-list successors)])
    (match-define (list label target) successor)
    (list label (Q target))))

(define (check-source-square source-row target-row Q source)
  (define transported
    (transport-successors Q ((source-row-raw source-row) source)))
  (define target-successors
    ((source-row-raw target-row) (Q source)))
  (check-equal? (length transported) (length target-successors))
  (check-equal? (canonical-multiset transported)
                (canonical-multiset target-successors)))

(define (check-source-cube source/s expected/e expected/n)
  (match-define (list generated-wf/s oracle-wf/s)
    (check-wf ROW/S source/s #t))
  (match-define (list generated-wf/e oracle-wf/e)
    (check-wf ROW/E expected/e #t))
  (match-define (list generated-wf/n oracle-wf/n)
    (check-wf ROW/N expected/n #t))
  (check-row-successors ROW/S source/s)
  (check-row-successors ROW/E expected/e)
  (check-row-successors ROW/N expected/n)
  (check-equal? (gq:Q-SE/R/search source/s) expected/e)
  (check-equal? (gq:Q-SN/R/search source/s) expected/n)
  (check-equal? (gq:Q-EN/R/search expected/e) expected/n)
  (check-equal? (gq:Q-SE/R/search source/s)
                (oq:Q-SE/F/search source/s))
  (check-equal? (gq:Q-SN/R/search source/s)
                (oq:Q-SN/F/search source/s))
  (check-equal? (gq:Q-EN/R/search expected/e)
                (oq:Q-EN/F/search expected/e))
  (check-true (gq:Q-SN/R-composition/search? source/s))
  (check-true (oq:Q-SN-composition?/search source/s))
  (check-true (oq:Q-SE-step-square/raw?/search source/s))
  (check-true (oq:Q-EN-step-square/raw?/search expected/e))
  (check-true (oq:Q-SN-step-square/raw?/search source/s))
  (check-source-square ROW/S ROW/E gq:Q-SE/R/search source/s)
  (check-source-square ROW/E ROW/N gq:Q-EN/R/search expected/e)
  (check-source-square ROW/S ROW/N gq:Q-SN/R/search source/s)
  (check-equal? (length generated-wf/s) (length generated-wf/e))
  (check-equal? (length generated-wf/s) (length generated-wf/n))
  (check-equal? (length oracle-wf/s) (length oracle-wf/e))
  (check-equal? (length oracle-wf/s) (length oracle-wf/n)))

(define (split-joint-focus frontier)
  (define redex-hole (term hole))
  (match frontier
    [`(Forced ,outer-prefix
              (Emit ,emit-prefix ,answer
                    (Forced ,inner-prefix
                            (More
                             (DisjL ,choice-prefix
                                    (PendingDelay ,pending-prefix ,work)
                                    ,right)))))
     (list
      `(PendingDelay ,pending-prefix ,work)
      `(Forced
        ,outer-prefix
        (Emit
         ,emit-prefix
         ,answer
         (Forced
          ,inner-prefix
          (More (DisjL ,choice-prefix ,redex-hole ,right))))))]
    [`(Forced
       (Emit ,answer
             (Forced
              (More (DisjL (PendingDelay ,work) ,right)))))
     (list
      `(PendingDelay ,work)
      `(Forced
        (Emit ,answer
              (Forced (More (DisjL ,redex-hole ,right))))))]
    [`(Forced ,forced-prefix
              (Emit ,emit-prefix ,answer
                    (More
                     (DisjL ,choice-prefix
                            (PendingDelay ,pending-prefix ,work)
                            ,right))))
     (list
      `(PendingDelay ,pending-prefix ,work)
      `(Forced
        ,forced-prefix
        (Emit
         ,emit-prefix
         ,answer
         (More
          (DisjL ,choice-prefix
                 ,redex-hole
                 ,right)))))]
    [`(Forced
       (Emit ,answer
             (More (DisjL (PendingDelay ,work) ,right))))
     (list
      `(PendingDelay ,work)
      `(Forced
        (Emit ,answer
              (More (DisjL ,redex-hole ,right)))))]))

(define (split-joint-root frontier)
  (define redex-hole (term hole))
  (match frontier
    [`(Forced ,forced-prefix (Emit ,emit-prefix ,answer ,root))
     (list root
           `(Forced ,forced-prefix
                    (Emit ,emit-prefix ,answer ,redex-hole)))]
    [`(Forced (Emit ,answer ,root))
     (list root `(Forced (Emit ,answer ,redex-hole)))]))

(define (plug-focused focused-and-focus)
  (match-define (list focused focus) focused-and-focus)
  (term (in-hole ,focus ,focused)))

(define GENERATED-SEARCH-SOURCE-TESTS
  (test-suite
   "generated Search source rows"

   (test-case "zero-rule join exposes exactly twenty-one inherited labels"
     (for ([row (in-list ROWS)])
       (define representatives
         (search-row-corpus-rule-sources (source-row-corpus row)))
       (check-equal? (length representatives) 21)
       (check-false (check-duplicates (map first representatives)))
       (check-equal? (sort (map first representatives) symbol<?)
                     SEARCH-RULE-NAMES)
       (check-equal? (rule-names (source-row-relation row))
                     SEARCH-RULE-NAMES)
       (check-equal? (rule-names (source-row-oracle-relation row))
                     SEARCH-RULE-NAMES)
       (check-equal?
        (length (reduction-relation->rule-names (source-row-relation row)))
        21)
       (check-equal?
        (length
         (reduction-relation->rule-names
          (source-row-oracle-relation row)))
        21)
       (for ([representative (in-list representatives)])
         (match-define (list expected-label source) representative)
         (with-check-info (['row (source-row-name row)]
                           ['label expected-label]
                           ['source source])
           (define successors (check-row-successors row source))
           (check-true ((source-row-member? row) source))
           (check-true ((source-row-oracle-member? row) source))
           (check-wf row source #t)
           (check-equal? (length successors) 1)
           (check-equal? (map first successors) (list expected-label)))))
     ;; Multiplicity canary: sorting is not deduplication.
     (check-equal? (canonical-multiset '((same target) (same target)))
                   '((same target) (same target)))
     (check-not-equal? (canonical-multiset '((same target) (same target)))
                       (canonical-multiset '((same target)))))

   (test-case "all eight inherited feature equations have literal targets"
     (for ([row (in-list ROWS)])
       (define cases
         (search-row-corpus-feature-rule-cases (source-row-corpus row)))
       (check-equal? (map search-rule-case-label cases)
                     SEARCH-FEATURE-RULE-NAMES)
       (check-equal? (length cases) 8)
       (for ([case (in-list cases)])
         (define expected
           (list (list (search-rule-case-label case)
                       (search-rule-case-target case))))
         (check-equal?
          ((source-row-raw row) (search-rule-case-source case))
          expected)
         (check-equal?
          ((source-row-oracle-raw row) (search-rule-case-source case))
          expected)
         (check-wf row (search-rule-case-target case) #t))))

   (test-case "eight opposite-feature contexts preserve exact raw equations"
     (for ([row (in-list ROWS)])
       (define cases
         (search-row-corpus-mixed-feature-cases (source-row-corpus row)))
       (check-equal? (map search-mixed-case-name cases)
                     EXPECTED-SEARCH-MIXED-CASE-NAMES)
       (check-equal? (length cases) 8)
       (for ([case (in-list cases)])
         (with-check-info (['row (source-row-name row)]
                           ['case (search-mixed-case-name case)])
           (define expected
             (list (list (search-mixed-case-label case)
                         (search-mixed-case-target case))))
           (check-equal?
            ((source-row-raw row) (search-mixed-case-source case))
            expected)
           (check-equal?
            ((source-row-oracle-raw row)
             (search-mixed-case-source case))
            expected)
           (check-wf row (search-mixed-case-source case) #t)
           (check-wf row (search-mixed-case-target case) #t)))))

   (test-case "three bounded mixed traces preserve labels terminals and stuckness"
     (for ([row (in-list ROWS)])
       (define traces
         (search-row-corpus-finite-traces (source-row-corpus row)))
       (check-equal? (map search-trace-case-name traces)
                     EXPECTED-SEARCH-TRACE-NAMES)
       (check-equal? (length traces) 3)
       (for ([trace-case (in-list traces)])
         (define source (search-trace-case-source trace-case))
         (define generated-steps (trace (source-row-raw row) source))
         (define oracle-steps (trace (source-row-oracle-raw row) source))
         (define generated-terminal (trace-final source generated-steps))
         (define oracle-terminal (trace-final source oracle-steps))
         (check-equal? (length generated-steps) (length oracle-steps))
         (check-equal? generated-steps oracle-steps)
         (check-equal? (map first generated-steps)
                       (search-trace-case-labels trace-case))
         (check-equal? (map first oracle-steps)
                       (search-trace-case-labels trace-case))
         (check-equal? generated-terminal
                       (search-trace-case-terminal trace-case))
         (check-equal? oracle-terminal
                       (search-trace-case-terminal trace-case))
         (check-equal? ((source-row-raw row) generated-terminal) '())
         (check-equal? ((source-row-oracle-raw row) oracle-terminal) '())
         (check-wf row source #t)
         (check-wf row generated-terminal #t))))

   (test-case "grammar WF and scheduler barriers remain distinct"
     (for ([row (in-list ROWS)])
       (define corpus (source-row-corpus row))
       (define barrier (search-row-corpus-scheduler-barrier corpus))
       (for ([negative
              (in-list (search-row-corpus-grammar-negatives corpus))])
         (define source (search-negative-case-source negative))
         (check-false ((source-row-member? row) source))
         (check-false ((source-row-oracle-member? row) source)))
       (for ([negative (in-list (search-row-corpus-wf-negatives corpus))])
         (define source (search-negative-case-source negative))
         (check-true ((source-row-member? row) source))
         (check-true ((source-row-oracle-member? row) source))
         (check-wf row source #f))
       (check-true ((source-row-member? row) barrier))
       (check-true ((source-row-oracle-member? row) barrier))
       (check-wf row barrier #t)
       (check-equal? ((source-row-raw row) barrier) '())
       (check-equal? ((source-row-oracle-raw row) barrier) '())))

   (test-case "direct SE EN and SN maps commute on all bounded source evidence"
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
       (check-source-cube (second pair/s) (second pair/e) (second pair/n)))

     (check-equal? (map search-mixed-case-name mixed/s)
                   (map search-mixed-case-name mixed/e))
     (check-equal? (map search-mixed-case-name mixed/s)
                   (map search-mixed-case-name mixed/n))
     (check-equal? (length mixed/s) 8)
     (for ([case/s (in-list mixed/s)]
           [case/e (in-list mixed/e)]
           [case/n (in-list mixed/n)])
       (check-source-cube (search-mixed-case-source case/s)
                          (search-mixed-case-source case/e)
                          (search-mixed-case-source case/n))
       (check-source-cube (search-mixed-case-target case/s)
                          (search-mixed-case-target case/e)
                          (search-mixed-case-target case/n)))
     (check-source-cube
      (search-row-corpus-joint-focus-witness SEARCH-CORPUS/S)
      (search-row-corpus-joint-focus-witness SEARCH-CORPUS/E)
      (search-row-corpus-joint-focus-witness SEARCH-CORPUS/N))
     (check-source-cube
      (search-row-corpus-scheduler-barrier SEARCH-CORPUS/S)
      (search-row-corpus-scheduler-barrier SEARCH-CORPUS/E)
      (search-row-corpus-scheduler-barrier SEARCH-CORPUS/N)))

   (test-case "joint focus and spine maps are direct and round-trip"
     (define source/s
       (search-row-corpus-joint-focus-witness SEARCH-CORPUS/S))
     (define source/e
       (search-row-corpus-joint-focus-witness SEARCH-CORPUS/E))
     (define source/n
       (search-row-corpus-joint-focus-witness SEARCH-CORPUS/N))
     (define focus/s (split-joint-focus source/s))
     (define focus/e (split-joint-focus source/e))
     (define focus/n (split-joint-focus source/n))
     (define root/s (split-joint-root source/s))
     (define root/e (split-joint-root source/e))
     (define root/n (split-joint-root source/n))
     (check-equal? (apply gq:Q-SE/focus/search focus/s) focus/e)
     (check-equal? (apply gq:Q-SN/focus/search focus/s) focus/n)
     (check-equal? (apply gq:Q-EN/focus/search focus/e) focus/n)
     (check-true (apply gq:Q-SN/focus-composition/search? focus/s))
     (check-equal? (plug-focused focus/e) (gq:Q-SE/R/search source/s))
     (check-equal? (plug-focused focus/n) (gq:Q-SN/R/search source/s))

     (check-equal? (apply gq:Q-SE/root-focus/search root/s) root/e)
     (check-equal? (apply gq:Q-SN/root-focus/search root/s) root/n)
     (check-equal? (apply gq:Q-EN/root-focus/search root/e) root/n)
     (check-true (apply gq:Q-SN/root-focus-composition/search? root/s))
     (check-equal?
      (gs:q-focus-rebuild/generated/search/s
       (apply gs:q-focus-export/generated/search/s focus/s))
      focus/s)
     (check-equal?
      (ge:q-focus-rebuild/generated/search/e
       (apply ge:q-focus-export/generated/search/e focus/e))
      focus/e)
     (check-equal?
      (gn:q-focus-rebuild/generated/search/n
       (apply gn:q-focus-export/generated/search/n focus/n))
      focus/n))

   (test-case "failure terminal and three child embeddings are direct"
     (define summary/s
       '(Owners (Owner (u:3) (label "failed"))))
     (define failure-focus/s
       (term
        (Forced
         (Owners (Owner (u:0) (label "forced")))
         (More
          (DisjL
           (Owners (Owner (u:2) (label "choice")))
           hole
           (PendingDelay
            (Owners (Owner (u:4) (label "pending")))
            (Dead (Owners))))))))
     (define summary/e '(Support u:0 u:2 u:3))
     (define failure-focus/e
       (term
        (Forced
         (More
          (DisjL
           hole
           (PendingDelay (Dead (Support u:0 u:2 u:4))))))))
     (define summary/n 3)
     (define failure-focus/n
       (term
        (Forced (More (DisjL hole (PendingDelay (Dead 3)))))))
     (define terminal/s
       (search-trace-case-terminal
        (third (search-row-corpus-finite-traces SEARCH-CORPUS/S))))
     (define terminal/e
       (search-trace-case-terminal
        (third (search-row-corpus-finite-traces SEARCH-CORPUS/E))))
     (define terminal/n
       (search-trace-case-terminal
        (third (search-row-corpus-finite-traces SEARCH-CORPUS/N))))
     (check-equal?
      (gq:Q-SE/failure-focus/search summary/s failure-focus/s)
      (list summary/e failure-focus/e))
     (check-equal?
      (gq:Q-SN/failure-focus/search summary/s failure-focus/s)
      (list summary/n failure-focus/n))
     (check-equal?
      (gq:Q-EN/failure-focus/search summary/e failure-focus/e)
      (list summary/n failure-focus/n))
     (check-true
      (gq:Q-SN/failure-focus-composition/search?
       summary/s failure-focus/s))

     (check-equal? (gq:Q-SE/terminal/search terminal/s) terminal/e)
     (check-equal? (gq:Q-SN/terminal/search terminal/s) terminal/n)
     (check-equal? (gq:Q-EN/terminal/search terminal/e) terminal/n)
     (check-true (gq:Q-SN/terminal-composition/search? terminal/s))

     (for ([row (in-list ROWS)])
       (define corpus (source-row-corpus row))
       (for ([representative
              (in-list (search-row-corpus-rule-sources corpus))])
         (match-define (list label source) representative)
         (when (member label delay:DELAY-RULE-NAMES)
           (check-equal? ((source-row-J-delay row) source) source))
         (when (member label disjunction:DISJUNCTION-RULE-NAMES)
           (check-equal? ((source-row-J-disjunction row) source) source))
         (unless (member label SEARCH-FEATURE-RULE-NAMES)
           (check-equal? ((source-row-J-core row) source) source)))
       (for ([representative
              (in-list (search-row-corpus-rule-sources corpus))])
         (define source (second representative))
         (check-equal? ((source-row-q-roundtrip row) source) source))))))

(module+ test
  (run-tests GENERATED-SEARCH-SOURCE-TESTS))
