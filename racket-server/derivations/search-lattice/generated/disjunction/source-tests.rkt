#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in gs: "source/s.rkt")
         (prefix-in ge: "source/e.rkt")
         (prefix-in gn: "source/n.rkt")
         (prefix-in gq: "source/vertical.rkt")
         (prefix-in os-lang: "../../oracles/disjunction/s/language.rkt")
         (prefix-in os: "../../oracles/disjunction/s/source.rkt")
         (prefix-in os-wf: "../../oracles/disjunction/s/wf.rkt")
         (prefix-in oe-lang: "../../oracles/disjunction/e/language.rkt")
         (prefix-in oe: "../../oracles/disjunction/e/source.rkt")
         (prefix-in oe-wf: "../../oracles/disjunction/e/wf.rkt")
         (prefix-in on-lang: "../../oracles/disjunction/n/language.rkt")
         (prefix-in on: "../../oracles/disjunction/n/source.rkt")
         (prefix-in on-wf: "../../oracles/disjunction/n/wf.rkt")
         (prefix-in oq: "../../oracles/disjunction/vertical.rkt")
         "corpus.rkt")

(provide GENERATED-DISJUNCTION-SOURCE-TESTS)

(define EXPECTED-DISJUNCTION-TRACE-NAMES
  '(left-failure
    two-answers-sibling-allocation-reuse
    nested-left-reassociation
    conjunction-resume
    outer-shared-variable))

;; Sorting changes enumeration order only.  Duplicate top-level results and
;; duplicate derivations remain duplicate entries throughout every comparison.
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
    (error 'trace "bounded Disjunction trace exceeded 64 source steps"))
  (match (raw source)
    ['() (reverse reversed-steps)]
    [(list (and step (list _label target)))
     (trace raw target (sub1 fuel) (cons step reversed-steps))]
    [other
     (error 'trace
            "expected one complete raw successor, received ~e"
            other)]))

(define (trace-states source steps)
  (cons source (map second steps)))

(define (trace-final source steps)
  (match steps
    ['() source]
    [_ (second (last steps))]))

(define (terminal-answers terminal)
  (match terminal
    [`(Emit ,_prefix ,answer ,residual)
     (cons answer (terminal-answers residual))]
    [`(Emit ,answer ,residual)
     (cons answer (terminal-answers residual))]
    [`(Last ,_prefix ,answer) (list answer)]
    [`(Last ,answer) (list answer)]
    [`(Done . ,_) '()]
    [_
     (error 'terminal-answers
            "expected a Disjunction terminal, received ~e"
            terminal)]))

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
   q-roundtrip
   J-core)
  #:transparent)

(define-syntax-rule
  (define-source-row
    row-id row-name corpus-id
    generated-relation-id oracle-relation-id
    generated-raw-id oracle-raw-id
    generated-language-id oracle-language-id
    generated-wf-id oracle-wf-id
    generated-export-id generated-rebuild-id
    J-core-id)
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
       (generated-rebuild-id (generated-export-id source)))
     J-core-id)))

(define-source-row
  ROW/S 'S DISJUNCTION-CORPUS/S
  gs:generated-disjunction-s-red os:disjunction-s-oracle-red
  gs:raw-successors/generated/disjunction/s os:raw-successors/disjunction/s
  gs:generated-disjunction-s-lang os-lang:disjunction-s-oracle-lang
  gs:wf-disjunction/generated/s? os-wf:wf-disjunction-oracle/s?
  gs:q-export/generated/disjunction/s gs:q-rebuild/generated/disjunction/s
  gs:J-core->disjunction/R/S)

(define-source-row
  ROW/E 'E DISJUNCTION-CORPUS/E
  ge:generated-disjunction-e-red oe:disjunction-e-oracle-red
  ge:raw-successors/generated/disjunction/e oe:raw-successors/disjunction/e
  ge:generated-disjunction-e-lang oe-lang:disjunction-e-oracle-lang
  ge:wf-disjunction/generated/e? oe-wf:wf-disjunction-oracle/e?
  ge:q-export/generated/disjunction/e ge:q-rebuild/generated/disjunction/e
  ge:J-core->disjunction/R/E)

(define-source-row
  ROW/N 'N DISJUNCTION-CORPUS/N
  gn:generated-disjunction-n-red on:disjunction-n-oracle-red
  gn:raw-successors/generated/disjunction/n on:raw-successors/disjunction/n
  gn:generated-disjunction-n-lang on-lang:disjunction-n-oracle-lang
  gn:wf-disjunction/generated/n? on-wf:wf-disjunction-oracle/n?
  gn:q-export/generated/disjunction/n gn:q-rebuild/generated/disjunction/n
  gn:J-core->disjunction/R/N)

(define ROWS (list ROW/S ROW/E ROW/N))

(define (check-wf-agreement row source expected?)
  (define generated ((source-row-generated-wf-proofs row) source))
  (define oracle ((source-row-oracle-wf-proofs row) source))
  (check-equal? (pair? generated) expected?)
  (check-equal? (pair? oracle) expected?)
  (check-equal? (length generated) (length oracle))
  (check-equal?
   (canonical-top-level-proof-multiset generated)
   (canonical-top-level-proof-multiset oracle)))

(define (check-row-rule row rule-name)
  (define source
    (disjunction-row-source-ref (source-row-corpus row) rule-name))
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
  (check-equal? (gq:Q-SE/R/disjunction s-source) expected-e)
  (check-equal? (gq:Q-SN/R/disjunction s-source) expected-n)
  (check-equal? (gq:Q-EN/R/disjunction expected-e) expected-n)
  (check-equal? (gq:Q-SE/R/disjunction s-source)
                (oq:Q-SE/F/disjunction s-source))
  (check-equal? (gq:Q-SN/R/disjunction s-source)
                (oq:Q-SN/F/disjunction s-source))
  (check-equal? (gq:Q-EN/R/disjunction expected-e)
                (oq:Q-EN/F/disjunction expected-e))
  (check-true (gq:Q-SN/R-composition/disjunction? s-source))
  (check-source-square ROW/S ROW/E gq:Q-SE/R/disjunction s-source)
  (check-source-square ROW/E ROW/N gq:Q-EN/R/disjunction expected-e)
  (check-source-square ROW/S ROW/N gq:Q-SN/R/disjunction s-source))

(define (check-row-trace row trace-case)
  (define source (disjunction-trace-case-source trace-case))
  (define expected-labels (disjunction-trace-case-labels trace-case))
  (define expected-terminal (disjunction-trace-case-terminal trace-case))
  (define expected-answers (disjunction-trace-case-answers trace-case))
  (define generated-steps (trace (source-row-generated-raw row) source))
  (define oracle-steps (trace (source-row-oracle-raw row) source))
  (define generated-terminal (trace-final source generated-steps))
  (define oracle-terminal (trace-final source oracle-steps))
  (check-equal? (map first generated-steps) expected-labels)
  (check-equal? (map first oracle-steps) expected-labels)
  (check-equal? generated-terminal expected-terminal)
  (check-equal? oracle-terminal expected-terminal)
  (check-equal? (terminal-answers generated-terminal) expected-answers)
  (check-equal? (terminal-answers oracle-terminal) expected-answers)
  (check-equal? ((source-row-generated-raw row) generated-terminal) '())
  (check-equal? ((source-row-oracle-raw row) oracle-terminal) '())
  (check-wf-agreement row source #t)
  (check-wf-agreement row generated-terminal #t))

(define (plug-focused focused-and-focus)
  (match-define (list focused focus) focused-and-focus)
  (term (in-hole ,focus ,focused)))

(define GENERATED-DISJUNCTION-SOURCE-TESTS
  (test-suite
   "generated Disjunction source rows"

   (test-case "inventory and all eighteen source equations equal the oracle"
     (for ([row (in-list ROWS)])
       (define representatives
         (disjunction-row-corpus-rule-sources (source-row-corpus row)))
       (check-equal? (length representatives) 18)
       (check-equal? (length representatives)
                     (length (remove-duplicates (map first representatives))))
       (check-equal? (sort (map first representatives) symbol<?)
                     DISJUNCTION-RULE-NAMES)
       (check-equal? (rule-names (source-row-generated-relation row))
                     DISJUNCTION-RULE-NAMES)
       (check-equal? (rule-names (source-row-oracle-relation row))
                     DISJUNCTION-RULE-NAMES)
       (check-equal?
        (length
         (reduction-relation->rule-names
          (source-row-generated-relation row)))
        18)
       (for ([rule-name (in-list DISJUNCTION-RULE-NAMES)])
         (check-row-rule row rule-name)))
     ;; Multiplicity canary: sorting a multiset must not turn it into a set.
     (check-equal? (canonical-multiset '((same target) (same target)))
                   '((same target) (same target)))
     (check-not-equal? (canonical-multiset '((same target) (same target)))
                       (canonical-multiset '((same target)))))

   (test-case "five direct Disjunction targets are literal row evidence"
     (for ([row (in-list ROWS)])
       (define cases
         (disjunction-row-corpus-owned-rule-cases (source-row-corpus row)))
       (check-equal? (map disjunction-rule-case-label cases)
                     DISJUNCTION-OWNED-RULE-NAMES)
       (for ([case (in-list cases)])
         (define expected
           (list (list (disjunction-rule-case-label case)
                       (disjunction-rule-case-target case))))
         (check-equal?
          ((source-row-generated-raw row)
           (disjunction-rule-case-source case))
          expected)
         (check-equal?
          ((source-row-oracle-raw row)
           (disjunction-rule-case-source case))
          expected)
         (check-wf-agreement row (disjunction-rule-case-target case) #t))))

   (test-case "five bounded traces preserve answers and sibling-local reuse"
     (for ([row (in-list ROWS)])
       (define trace-cases
         (disjunction-row-corpus-finite-traces (source-row-corpus row)))
       (check-equal? (length trace-cases) 5)
       (check-equal? (map disjunction-trace-case-name trace-cases)
                     EXPECTED-DISJUNCTION-TRACE-NAMES)
       (for ([trace-case (in-list trace-cases)])
         (check-row-trace row trace-case)))
     (define reuse/s
       (second
        (disjunction-row-corpus-finite-traces DISJUNCTION-CORPUS/S)))
     (define reuse/e
       (second
        (disjunction-row-corpus-finite-traces DISJUNCTION-CORPUS/E)))
     (define reuse/n
       (second
        (disjunction-row-corpus-finite-traces DISJUNCTION-CORPUS/N)))
     (check-equal? (disjunction-trace-case-shared-outer reuse/s) 'u:0)
     (check-equal? (disjunction-trace-case-shared-outer reuse/e) 'u:0)
     (check-equal? (disjunction-trace-case-shared-outer reuse/n) 0)
     (check-equal? (disjunction-trace-case-sibling-allocations reuse/s)
                   '(u:1 u:1))
     (check-equal? (disjunction-trace-case-sibling-allocations reuse/e)
                   '(u:1 u:1))
     (check-equal? (disjunction-trace-case-sibling-allocations reuse/n)
                   '(1 1)))

   (test-case "grammar exclusions and right-branch WF failures stay distinct"
     (define malformed/s
       '(More (DisjL (Dead (Owners)) (Dead (Owners)))))
     (define malformed/e
       '(More
         (DisjL
          (Owners)
          (Dead (Support))
          (Dead (Support)))))
     (define malformed/n
       '(More (DisjL 0 (Dead 0) (Dead 0))))
     (for ([row (in-list ROWS)]
           [source (in-list (list malformed/s malformed/e malformed/n))])
       (check-false ((source-row-generated-member? row) source))
       (check-false ((source-row-oracle-member? row) source)))

     (define ill-scoped/s
       '(Emit
         (Owners)
         (Answer (Owners) (state () () () (label "state")))
         (More
          (DisjL
           (Owners (Owner (u:0) (label "choice")))
           (Work (Owners) (succeed (label "left"))
                 (state () () () (label "state")))
           (Work (Owners) (u:9 =? (nat 0) (label "unbound"))
                 (state () () () (label "state")))))))
     (define ill-scoped/e
       '(Emit
         (Answer (state (Support) () () () (label "state")))
         (More
          (DisjL
           (Work (succeed (label "left"))
                 (state (Support u:0) () () () (label "state")))
           (Work (u:9 =? (nat 0) (label "unbound"))
                 (state (Support u:0) () () () (label "state")))))))
     (define ill-scoped/n
       '(Emit
         (Answer (state 0 () () () (label "state")))
         (More
          (DisjL
           (Work (succeed (label "left"))
                 (state 1 () () () (label "state")))
           (Work (1 =? (nat 0) (label "unbound"))
                 (state 1 () () () (label "state")))))))
     (for ([row (in-list ROWS)]
           [source (in-list (list ill-scoped/s ill-scoped/e ill-scoped/n))])
       (check-true ((source-row-generated-member? row) source))
       (check-true ((source-row-oracle-member? row) source))
       (check-wf-agreement row source #f)))

   (test-case "whole-frontier representation squares use all literal rows"
     (define sources/s
       (disjunction-row-corpus-rule-sources DISJUNCTION-CORPUS/S))
     (define sources/e
       (disjunction-row-corpus-rule-sources DISJUNCTION-CORPUS/E))
     (define sources/n
       (disjunction-row-corpus-rule-sources DISJUNCTION-CORPUS/N))
     (check-equal? (map first sources/s) (map first sources/e))
     (check-equal? (map first sources/s) (map first sources/n))
     (check-equal? (length sources/s) 18)
     (for ([pair/s (in-list sources/s)]
           [pair/e (in-list sources/e)]
           [pair/n (in-list sources/n)])
       (check-source-cube (second pair/s) (second pair/e) (second pair/n)))

     (define cases/s
       (disjunction-row-corpus-owned-rule-cases DISJUNCTION-CORPUS/S))
     (define cases/e
       (disjunction-row-corpus-owned-rule-cases DISJUNCTION-CORPUS/E))
     (define cases/n
       (disjunction-row-corpus-owned-rule-cases DISJUNCTION-CORPUS/N))
     (check-equal? (map disjunction-rule-case-label cases/s)
                   (map disjunction-rule-case-label cases/e))
     (check-equal? (map disjunction-rule-case-label cases/s)
                   (map disjunction-rule-case-label cases/n))
     (check-equal? (length cases/s) 5)
     (for ([case/s (in-list cases/s)]
           [case/e (in-list cases/e)]
           [case/n (in-list cases/n)])
       (check-source-cube
        (disjunction-rule-case-target case/s)
        (disjunction-rule-case-target case/e)
        (disjunction-rule-case-target case/n))))

   (test-case "every bounded trace state crosses the direct source cube"
     (define traces/s
       (disjunction-row-corpus-finite-traces DISJUNCTION-CORPUS/S))
     (define traces/e
       (disjunction-row-corpus-finite-traces DISJUNCTION-CORPUS/E))
     (define traces/n
       (disjunction-row-corpus-finite-traces DISJUNCTION-CORPUS/N))
     (check-equal? (map disjunction-trace-case-name traces/s)
                   (map disjunction-trace-case-name traces/e))
     (check-equal? (map disjunction-trace-case-name traces/s)
                   (map disjunction-trace-case-name traces/n))
     (check-equal? (length traces/s) 5)
     (for ([case/s (in-list traces/s)]
           [case/e (in-list traces/e)]
           [case/n (in-list traces/n)])
       (define source/s (disjunction-trace-case-source case/s))
       (define source/e (disjunction-trace-case-source case/e))
       (define source/n (disjunction-trace-case-source case/n))
       (define steps/s (trace gs:raw-successors/generated/disjunction/s source/s))
       (define steps/e (trace ge:raw-successors/generated/disjunction/e source/e))
       (define steps/n (trace gn:raw-successors/generated/disjunction/n source/n))
       (define states/s (trace-states source/s steps/s))
       (define states/e (trace-states source/e steps/e))
       (define states/n (trace-states source/n steps/n))
       (check-equal? (map first steps/s) (map first steps/e))
       (check-equal? (map first steps/s) (map first steps/n))
       (check-equal? (length states/s) (length states/e))
       (check-equal? (length states/s) (length states/n))
       (for ([state/s (in-list states/s)]
             [state/e (in-list states/e)]
             [state/n (in-list states/n)])
         (check-equal? (gq:Q-SE/R/disjunction state/s) state/e)
         (check-equal? (gq:Q-SN/R/disjunction state/s) state/n)
         (check-equal? (gq:Q-EN/R/disjunction state/e) state/n)
         (check-true (gq:Q-SN/R-composition/disjunction? state/s)))))

   (test-case "choice focus and Emit spine maps are direct and round-trip"
     (define s-state '(state () () () (label "focus-state")))
     (define e-state/u0-u2
       '(state (Support u:0 u:2) () () () (label "focus-state")))
     (define n-state/2 '(state 2 () () () (label "focus-state")))
     (define s-focused
       `(Work
         (Owners (Owner (u:2) (label "focused")))
         (u:2 =? u:0 (label "focus-goal"))
         ,s-state))
     (define s-focus
       (term
        (More
         (DisjL
          (Owners (Owner (u:0) (label "choice")))
          hole
          (Dead (Owners (Owner (u:1) (label "right"))))))))
     (define e-focused
       `(Work (u:2 =? u:0 (label "focus-goal")) ,e-state/u0-u2))
     (define e-focus
       (term (More (DisjL hole (Dead (Support u:0 u:1))))))
     (define n-focused
       `(Work (1 =? 0 (label "focus-goal")) ,n-state/2))
     (define n-focus (term (More (DisjL hole (Dead 2)))))
     (check-equal? (gq:Q-SE/focus/disjunction s-focused s-focus)
                   (list e-focused e-focus))
     (check-equal? (gq:Q-SN/focus/disjunction s-focused s-focus)
                   (list n-focused n-focus))
     (check-equal? (gq:Q-EN/focus/disjunction e-focused e-focus)
                   (list n-focused n-focus))
     (check-true
      (gq:Q-SN/focus-composition/disjunction? s-focused s-focus))
     (check-equal? (plug-focused (list e-focused e-focus))
                   (gq:Q-SE/R/disjunction
                    (plug-focused (list s-focused s-focus))))
     (check-equal? (plug-focused (list n-focused n-focus))
                   (gq:Q-SN/R/disjunction
                    (plug-focused (list s-focused s-focus))))
     (check-equal?
      (gs:q-focus-rebuild/generated/disjunction/s
       (gs:q-focus-export/generated/disjunction/s s-focused s-focus))
      (list s-focused s-focus))
     (check-equal?
      (ge:q-focus-rebuild/generated/disjunction/e
       (ge:q-focus-export/generated/disjunction/e e-focused e-focus))
      (list e-focused e-focus))
     (check-equal?
      (gn:q-focus-rebuild/generated/disjunction/n
       (gn:q-focus-export/generated/disjunction/n n-focused n-focus))
      (list n-focused n-focus))

     (define s-root
       '(More
         (DisjL
          (Owners (Owner (u:2) (label "choice")))
          (Dead (Owners (Owner (u:3) (label "left"))))
          (Dead (Owners (Owner (u:4) (label "right")))))))
     (define s-spine
       (term
        (Emit
         (Owners (Owner (u:0) (label "emit")))
         (Answer
          (Owners (Owner (u:1) (label "answer")))
          (state () () () (label "answer-state")))
         hole)))
     (define e-root
       '(More
         (DisjL
          (Dead (Support u:0 u:2 u:3))
          (Dead (Support u:0 u:2 u:4)))))
     (define e-spine
       (term
        (Emit
         (Answer
          (state
           (Support u:0 u:1)
           () () ()
           (label "answer-state")))
         hole)))
     (define n-root '(More (DisjL (Dead 3) (Dead 3))))
     (define n-spine
       (term
        (Emit
         (Answer (state 2 () () () (label "answer-state")))
         hole)))
     (check-equal? (gq:Q-SE/root-focus/disjunction s-root s-spine)
                   (list e-root e-spine))
     (check-equal? (gq:Q-SN/root-focus/disjunction s-root s-spine)
                   (list n-root n-spine))
     (check-equal? (gq:Q-EN/root-focus/disjunction e-root e-spine)
                   (list n-root n-spine))
     (check-true
      (gq:Q-SN/root-focus-composition/disjunction? s-root s-spine)))

   (test-case "failure-summary terminal and core embedding views are direct"
     (define s-summary
       '(Owners (Owner (u:3) (label "failed"))))
     (define s-focus
       (term
        (More
         (DisjL
          (Owners (Owner (u:2) (label "choice")))
          hole
          (Dead (Owners (Owner (u:4) (label "right"))))))))
     (define e-summary '(Support u:2 u:3))
     (define e-focus
       (term
        (More (DisjL hole (Dead (Support u:2 u:4))))))
     (define n-summary 2)
     (define n-focus
       (term (More (DisjL hole (Dead 2)))))
     (check-equal?
      (gq:Q-SE/failure-focus/disjunction s-summary s-focus)
      (list e-summary e-focus))
     (check-equal?
      (gq:Q-SN/failure-focus/disjunction s-summary s-focus)
      (list n-summary n-focus))
     (check-equal?
      (gq:Q-EN/failure-focus/disjunction e-summary e-focus)
      (list n-summary n-focus))
     (check-true
      (gq:Q-SN/failure-focus-composition/disjunction? s-summary s-focus))

     (define terminal/s
       (disjunction-trace-case-terminal
        (second
         (disjunction-row-corpus-finite-traces DISJUNCTION-CORPUS/S))))
     (define terminal/e
       (disjunction-trace-case-terminal
        (second
         (disjunction-row-corpus-finite-traces DISJUNCTION-CORPUS/E))))
     (define terminal/n
       (disjunction-trace-case-terminal
        (second
         (disjunction-row-corpus-finite-traces DISJUNCTION-CORPUS/N))))
     (check-equal? (gq:Q-SE/terminal/disjunction terminal/s) terminal/e)
     (check-equal? (gq:Q-SN/terminal/disjunction terminal/s) terminal/n)
     (check-equal? (gq:Q-EN/terminal/disjunction terminal/e) terminal/n)
     (check-true
      (gq:Q-SN/terminal-composition/disjunction? terminal/s))

     (for ([row (in-list ROWS)])
       (define corpus (source-row-corpus row))
       (for ([core-pair
              (in-list
               (disjunction-row-corpus-core-rule-sources corpus))])
         (define core-source (second core-pair))
         (check-equal? ((source-row-J-core row) core-source) core-source))
       (for ([source-pair
              (in-list (disjunction-row-corpus-rule-sources corpus))])
         (define source (second source-pair))
         (check-equal? ((source-row-q-roundtrip row) source) source))))))

(module+ test
  (run-tests GENERATED-DISJUNCTION-SOURCE-TESTS))
