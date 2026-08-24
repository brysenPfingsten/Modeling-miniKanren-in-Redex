#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in gs: "source/s.rkt")
         (prefix-in ge: "source/e.rkt")
         (prefix-in gn: "source/n.rkt")
         (prefix-in gq: "source/vertical.rkt")
         (prefix-in os-lang: "../../oracles/delay/s/language.rkt")
         (prefix-in os: "../../oracles/delay/s/source.rkt")
         (prefix-in os-wf: "../../oracles/delay/s/wf.rkt")
         (prefix-in oe-lang: "../../oracles/delay/e/language.rkt")
         (prefix-in oe: "../../oracles/delay/e/source.rkt")
         (prefix-in oe-wf: "../../oracles/delay/e/wf.rkt")
         (prefix-in on-lang: "../../oracles/delay/n/language.rkt")
         (prefix-in on: "../../oracles/delay/n/source.rkt")
         (prefix-in on-wf: "../../oracles/delay/n/wf.rkt")
         (prefix-in oq: "../../oracles/delay/vertical.rkt")
         "corpus.rkt")

(provide GENERATED-DELAY-SOURCE-TESTS)

(define EXPECTED-DELAY-TRACE-NAMES
  '(suspend-success
    bubble-success
    suspend-failure
    nested-suspend
    fresh-inside-suspend
    unused-fresh-outside-delayed-failure))

;; Sorting changes only enumeration order.  Equal observations and equal
;; top-level proofs remain separate entries; no comparison deduplicates them.
(define (canonical-multiset values)
  (sort values string<? #:key ~s))

(define (forced-preorder/reversed value [reversed '()])
  (match value
    [`(Forced ,owners ,frontier)
     (forced-preorder/reversed frontier (cons owners reversed))]
    [`(Forced ,frontier)
     (forced-preorder/reversed frontier (cons 'Forced reversed))]
    [(cons first rest)
     (forced-preorder/reversed
      rest
      (forced-preorder/reversed first reversed))]
    [_ reversed]))

(define (forced-preorder value)
  (reverse (forced-preorder/reversed value)))

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

(define (trace raw source [fuel 64] [reversed-labels '()])
  (when (zero? fuel)
    (error 'trace "bounded Delay trace exceeded 64 source steps"))
  (match (raw source)
    ['() (values (reverse reversed-labels) source)]
    [(list (list label target))
     (trace raw target (sub1 fuel) (cons label reversed-labels))]
    [other
     (error 'trace "expected a deterministic source step, received ~e" other)]))

(struct source-row
  (name
   corpus
   generated-relation
   oracle-relation
   generated-raw
   oracle-raw
   generated-member?
   oracle-member?
   generated-wf-proofs
   oracle-wf-proofs
   q-roundtrip)
  #:transparent)

(define-syntax-rule
  (define-source-row
    row-id row-name corpus-id
    generated-relation-id oracle-relation-id
    generated-raw-id oracle-raw-id
    generated-language-id oracle-language-id
    generated-wf-id oracle-wf-id
    generated-export-id generated-rebuild-id)
  (define row-id
    (source-row
     row-name
     corpus-id
     generated-relation-id
     oracle-relation-id
     generated-raw-id
     oracle-raw-id
     (lambda (source) (redex-match? generated-language-id F source))
     (lambda (source) (redex-match? oracle-language-id F source))
     (lambda (source) (build-derivations (generated-wf-id ,source)))
     (lambda (source) (build-derivations (oracle-wf-id ,source)))
     (lambda (source)
       (generated-rebuild-id (generated-export-id source))))))

(define-source-row
  ROW/S 'S DELAY-CORPUS/S
  gs:generated-delay-s-red os:delay-s-oracle-red
  gs:raw-successors/generated/delay/s os:raw-successors/delay/s
  gs:generated-delay-s-lang os-lang:delay-s-oracle-lang
  gs:wf-delay/generated/s? os-wf:wf-delay-oracle/s?
  gs:q-export/generated/delay/s gs:q-rebuild/generated/delay/s)

(define-source-row
  ROW/E 'E DELAY-CORPUS/E
  ge:generated-delay-e-red oe:delay-e-oracle-red
  ge:raw-successors/generated/delay/e oe:raw-successors/delay/e
  ge:generated-delay-e-lang oe-lang:delay-e-oracle-lang
  ge:wf-delay/generated/e? oe-wf:wf-delay-oracle/e?
  ge:q-export/generated/delay/e ge:q-rebuild/generated/delay/e)

(define-source-row
  ROW/N 'N DELAY-CORPUS/N
  gn:generated-delay-n-red on:delay-n-oracle-red
  gn:raw-successors/generated/delay/n on:raw-successors/delay/n
  gn:generated-delay-n-lang on-lang:delay-n-oracle-lang
  gn:wf-delay/generated/n? on-wf:wf-delay-oracle/n?
  gn:q-export/generated/delay/n gn:q-rebuild/generated/delay/n)

(define ROWS (list ROW/S ROW/E ROW/N))

(define (check-wf-agreement row source expected?)
  (define generated
    ((source-row-generated-wf-proofs row) source))
  (define oracle
    ((source-row-oracle-wf-proofs row) source))
  (check-equal? (pair? generated) expected?)
  (check-equal? (pair? oracle) expected?)
  (check-equal? (length generated) (length oracle))
  (check-equal?
   (canonical-top-level-proof-multiset generated)
   (canonical-top-level-proof-multiset oracle)))

(define (check-row-rule row rule-name)
  (define source (delay-row-source-ref (source-row-corpus row) rule-name))
  (with-check-info (['row (source-row-name row)]
                    ['rule rule-name]
                    ['source source])
    (check-true ((source-row-generated-member? row) source))
    (check-true ((source-row-oracle-member? row) source))
    (check-wf-agreement row source #t)
    (define generated ((source-row-generated-raw row) source))
    (define oracle ((source-row-oracle-raw row) source))
    (check-equal? (canonical-multiset generated)
                  (canonical-multiset oracle))
    (check-equal? (length generated) 1)
    (check-equal? (map first generated) (list rule-name))))

(define (check-row-trace row trace-case)
  (define source (delay-trace-case-source trace-case))
  (define expected-labels (delay-trace-case-labels trace-case))
  (define expected-terminal (delay-trace-case-terminal trace-case))
  (define expected-forced-before
    (delay-trace-case-forced-before trace-case))
  (define expected-forced-after
    (delay-trace-case-forced-after trace-case))
  (define-values (generated-labels generated-terminal)
    (trace (source-row-generated-raw row) source))
  (define-values (oracle-labels oracle-terminal)
    (trace (source-row-oracle-raw row) source))
  (check-equal? (length (forced-preorder source))
                expected-forced-before)
  (check-equal? generated-labels expected-labels)
  (check-equal? oracle-labels expected-labels)
  (check-equal? generated-terminal expected-terminal)
  (check-equal? oracle-terminal expected-terminal)
  (check-equal? (length (forced-preorder generated-terminal))
                expected-forced-after)
  (check-equal? (length (forced-preorder oracle-terminal))
                expected-forced-after)
  ;; The literal expected terminal fixes outer-to-inner Forced order, not just
  ;; the number of wrappers recorded by the corpus metadata.
  (check-equal? (forced-preorder generated-terminal)
                (forced-preorder expected-terminal))
  (check-equal? (forced-preorder oracle-terminal)
                (forced-preorder expected-terminal))
  (check-wf-agreement row generated-terminal #t))

(define (transport-successors Q successors)
  (for/list ([successor (in-list successors)])
    (match-define (list label target) successor)
    (list label (Q target))))

(define (check-source-square source-row target-row Q source)
  (check-equal?
   (canonical-multiset
    (transport-successors Q ((source-row-generated-raw source-row) source)))
   (canonical-multiset
    ((source-row-generated-raw target-row) (Q source)))))

(define (check-source-cube s-source expected-e expected-n)
  (check-equal? (gq:Q-SE/R/delay s-source) expected-e)
  (check-equal? (gq:Q-SN/R/delay s-source) expected-n)
  (check-equal? (gq:Q-EN/R/delay expected-e) expected-n)
  (check-equal? (gq:Q-SE/R/delay s-source) (oq:Q-SE/F/delay s-source))
  (check-equal? (gq:Q-SN/R/delay s-source) (oq:Q-SN/F/delay s-source))
  (check-equal? (gq:Q-EN/R/delay expected-e) (oq:Q-EN/F/delay expected-e))
  (check-true (gq:Q-SN/R-composition/delay? s-source))
  (check-source-square ROW/S ROW/E gq:Q-SE/R/delay s-source)
  (check-source-square ROW/E ROW/N gq:Q-EN/R/delay expected-e)
  (check-source-square ROW/S ROW/N gq:Q-SN/R/delay s-source))

(define (split-sparse corpus)
  (match (delay-row-corpus-sparse-witness corpus)
    [`(Forced ,owners (More ,work))
     (list work (term (Forced ,owners (More hole))))]
    [`(Forced (More ,work))
     (list work (term (Forced (More hole))))]))

(define (plug-focused focused-and-focus)
  (match-define (list focused focus) focused-and-focus)
  (term (in-hole ,focus ,focused)))

(define GENERATED-DELAY-SOURCE-TESTS
  (test-suite
   "generated Delay source rows"

   (test-case "inventory and all sixteen source equations equal the oracle"
     (for ([row (in-list ROWS)])
       (check-equal? (rule-names (source-row-generated-relation row))
                     DELAY-RULE-NAMES)
       (check-equal? (rule-names (source-row-oracle-relation row))
                     DELAY-RULE-NAMES)
       (check-equal?
        (length (reduction-relation->rule-names
                 (source-row-generated-relation row)))
        16)
       (for ([rule-name (in-list DELAY-RULE-NAMES)])
         (check-row-rule row rule-name)))
     ;; Multiplicity canary: canonicalization never turns a multiset into a set.
     (check-equal? (canonical-multiset '((same target) (same target)))
                   '((same target) (same target)))
     (check-not-equal? (canonical-multiset '((same target) (same target)))
                       (canonical-multiset '((same target)))))

   (test-case "three direct Delay targets are literal row evidence"
     (for ([row (in-list ROWS)])
       (for ([case (in-list
                    (delay-row-corpus-owned-rule-cases
                     (source-row-corpus row)))])
         (check-equal?
          ((source-row-generated-raw row) (delay-rule-case-source case))
          (list (list (delay-rule-case-label case)
                      (delay-rule-case-target case)))))))

   (test-case "production S bubble transfers through nested Pending owners"
     (define body
       '(Work
         (Owners)
         (succeed (label "body"))
         (state () () () (label "state"))))
     (define source
       `(More
         (Conj
          (Owners (Owner (u:0) (label "outer")))
          (PendingDelay
           (Owners (Owner (u:1) (label "pending")))
           (PendingDelay
            (Owners (Owner (u:2) (label "inner")))
            ,body))
          (succeed (label "right")))))
     (define expected
       (list
        (list
         'bubble-delay-through-conj
         `(More
           (PendingDelay
            (Owners (Owner (u:0) (label "outer")))
            (Conj
             (Owners)
             (PendingDelay
              (Owners
               (Owner (u:1) (label "pending"))
               (Owner (u:2) (label "inner")))
              ,body)
             (succeed (label "right"))))))))
     (check-equal? (gs:raw-successors/generated/delay/s source) expected)
     (check-equal? (os:raw-successors/delay/s source) expected))

   (test-case "six bounded traces retain labels terminals and Forced order"
     (for ([row (in-list ROWS)])
       (define trace-cases
         (delay-row-corpus-finite-traces (source-row-corpus row)))
       (check-equal? (map delay-trace-case-name trace-cases)
                     EXPECTED-DELAY-TRACE-NAMES)
       (for ([trace-case (in-list trace-cases)])
         (check-row-trace row trace-case))))

   (test-case "grammar exclusions and grammatical WF failures stay separate"
     (for ([row (in-list ROWS)])
       (for ([negative
              (in-list
               (delay-row-corpus-grammar-negatives
                (source-row-corpus row)))])
         (define source (delay-negative-case-source negative))
         (check-false ((source-row-generated-member? row) source))
         (check-false ((source-row-oracle-member? row) source)))
       (define duplicate
         (delay-row-corpus-duplicate-binder-source
          (source-row-corpus row)))
       (check-false ((source-row-generated-member? row) duplicate))
       (check-false ((source-row-oracle-member? row) duplicate))
       (for ([negative
              (in-list
               (delay-row-corpus-wf-negatives (source-row-corpus row)))])
         (define source (delay-negative-case-source negative))
         (check-true ((source-row-generated-member? row) source))
         (check-true ((source-row-oracle-member? row) source))
         (check-wf-agreement row source #f))))

   (test-case "whole-frontier direct representation squares use literal rows"
     (for ([s-pair (in-list (delay-row-corpus-rule-sources DELAY-CORPUS/S))]
           [e-pair (in-list (delay-row-corpus-rule-sources DELAY-CORPUS/E))]
           [n-pair (in-list (delay-row-corpus-rule-sources DELAY-CORPUS/N))])
       (check-equal? (first s-pair) (first e-pair))
       (check-equal? (first s-pair) (first n-pair))
       (check-source-cube (second s-pair) (second e-pair) (second n-pair)))
     (check-source-cube
      (delay-row-corpus-sparse-witness DELAY-CORPUS/S)
      (delay-row-corpus-sparse-witness DELAY-CORPUS/E)
      (delay-row-corpus-sparse-witness DELAY-CORPUS/N)))

   (test-case "focused path and spine views translate directly and round-trip"
     (define s-focus (split-sparse DELAY-CORPUS/S))
     (define e-focus (split-sparse DELAY-CORPUS/E))
     (define n-focus (split-sparse DELAY-CORPUS/N))
     (check-equal? (apply gq:Q-SE/focus/delay s-focus) e-focus)
     (check-equal? (apply gq:Q-SN/focus/delay s-focus) n-focus)
     (check-equal? (apply gq:Q-EN/focus/delay e-focus) n-focus)
     (check-true (apply gq:Q-SN/focus-composition/delay? s-focus))
     (check-equal? (plug-focused e-focus)
                   (gq:Q-SE/R/delay (plug-focused s-focus)))
     (check-equal? (plug-focused n-focus)
                   (gq:Q-SN/R/delay (plug-focused s-focus)))
     (check-equal?
      (gs:q-focus-rebuild/generated/delay/s
       (apply gs:q-focus-export/generated/delay/s s-focus))
      s-focus)
     (check-equal?
      (ge:q-focus-rebuild/generated/delay/e
       (apply ge:q-focus-export/generated/delay/e e-focus))
      e-focus)
     (check-equal?
      (gn:q-focus-rebuild/generated/delay/n
       (apply gn:q-focus-export/generated/delay/n n-focus))
      n-focus)
     (for ([row (in-list ROWS)])
       (define sparse
         (delay-row-corpus-sparse-witness (source-row-corpus row)))
       (check-equal? ((source-row-q-roundtrip row) sparse) sparse)))

   (test-case "root failure-summary and terminal views are independently direct"
     (define s-root
       '(More
         (PendingDelay
          (Owners (Owner (u:2) (label "pending")))
          (Dead (Owners)))))
     (define s-spine
       (term
        (Forced (Owners (Owner (u:0) (label "forced"))) hole)))
     (define e-root '(More (PendingDelay (Dead (Support u:0 u:2)))))
     (define e-spine (term (Forced hole)))
     (define n-root '(More (PendingDelay (Dead 2))))
     (define n-spine (term (Forced hole)))
     (check-equal? (gq:Q-SE/root-focus/delay s-root s-spine)
                   (list e-root e-spine))
     (check-equal? (gq:Q-SN/root-focus/delay s-root s-spine)
                   (list n-root n-spine))
     (check-equal? (gq:Q-EN/root-focus/delay e-root e-spine)
                   (list n-root n-spine))
     (check-true
      (gq:Q-SN/root-focus-composition/delay? s-root s-spine))

     (define s-summary
       '(Owners (Owner (u:2) (label "failed"))))
     (define s-failure-focus
       (term
        (Forced
         (Owners (Owner (u:0) (label "forced")))
         (More (Conj (Owners) hole (u:0 != u:2 (label "later")))))))
     (define expected-e-summary '(Support u:0 u:2))
     (define expected-e-focus
       (term (Forced (More (Conj hole (u:0 != u:2 (label "later")))))))
     (define expected-n-summary 2)
     (define expected-n-focus
       (term (Forced (More (Conj hole (0 != 1 (label "later")))))))
     (check-equal?
      (gq:Q-SE/failure-focus/delay s-summary s-failure-focus)
      (list expected-e-summary expected-e-focus))
     (check-equal?
      (gq:Q-SN/failure-focus/delay s-summary s-failure-focus)
      (list expected-n-summary expected-n-focus))
     (check-equal?
      (gq:Q-EN/failure-focus/delay expected-e-summary expected-e-focus)
      (list expected-n-summary expected-n-focus))
     (check-true
      (gq:Q-SN/failure-focus-composition/delay?
       s-summary s-failure-focus))

     (define s-terminal
       '(Done (Owners (Owner (u:0 u:2) (label "done")))))
     (define e-terminal '(Done (Support u:0 u:2)))
     (define n-terminal '(Done 2))
     (check-equal? (gq:Q-SE/terminal/delay s-terminal) e-terminal)
     (check-equal? (gq:Q-SN/terminal/delay s-terminal) n-terminal)
     (check-equal? (gq:Q-EN/terminal/delay e-terminal) n-terminal)
     (check-true (gq:Q-SN/terminal-composition/delay? s-terminal)))))

(module+ test
  (run-tests GENERATED-DELAY-SOURCE-TESTS))
