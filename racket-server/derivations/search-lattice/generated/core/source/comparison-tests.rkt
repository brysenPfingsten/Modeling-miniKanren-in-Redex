#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in gs: "./s.rkt")
         (prefix-in ge: "./e.rkt")
         (prefix-in gn: "./n.rkt")
         (prefix-in gq: "./vertical.rkt")
         (prefix-in os-lang: "../../../oracles/core/s/language.rkt")
         (prefix-in os: "../../../oracles/core/s/source.rkt")
         (prefix-in os-wf: "../../../oracles/core/s/wf.rkt")
         (prefix-in oe-lang: "../../../oracles/core/e/language.rkt")
         (prefix-in oe: "../../../oracles/core/e/source.rkt")
         (prefix-in oe-wf: "../../../oracles/core/e/wf.rkt")
         (prefix-in on-lang: "../../../oracles/core/n/language.rkt")
         (prefix-in on: "../../../oracles/core/n/source.rkt")
         (prefix-in on-wf: "../../../oracles/core/n/wf.rkt")
         (prefix-in oq: "../../../oracles/core/vertical.rkt")
         (prefix-in production-lang:
                    "../../../../../src/search-lattice/languages/core-lang.rkt")
         (prefix-in production:
                    "../../../../../src/search-lattice/reduction-relations/core-red.rkt")
         (prefix-in production-wf:
                    "../../../../../src/search-lattice/wf/core-wf.rkt"))

(provide GENERATED-CORE-SOURCE-COMPARISONS)

(define CORE-RULE-NAMES
  '(allocate-fresh
    conj-fail
    conj-return
    disequality-fail
    disequality-success
    expand-conjunction
    fail
    finish-failure
    finish-success
    succeed
    unify-fail
    unify-success
    unify-violates-disequality))

(define SIGMA-EMPTY
  (term (state () () () (label "comparison-state"))))

(define OWNERS-EMPTY (term (Owners)))
(define OWNERS-U0
  (term (Owners (Owner (u:0) (label "u0")))))
(define OWNERS-U1
  (term (Owners (Owner (u:1) (label "u1")))))

;; This corpus belongs to the comparison, not to either relation.  It names
;; one independently selected well-formed source for every core rule.
(define RULE-SOURCES/S
  (list
   (list
    'expand-conjunction
    (term
     (More
      (Work
       ,OWNERS-U0
       ((succeed (label "left"))
        ∧
        (u:0 =? u:0 (label "right"))
        (label "and"))
       ,SIGMA-EMPTY))))
   (list
    'succeed
    (term
     (More
      (Work ,OWNERS-U0 (succeed (label "yes")) ,SIGMA-EMPTY))))
   (list
    'fail
    (term
     (More
      (Work ,OWNERS-U0 (fail (label "no")) ,SIGMA-EMPTY))))
   (list
    'conj-return
    (term
     (More
      (Conj
       ,OWNERS-U0
       (Returned ,OWNERS-U1 ,SIGMA-EMPTY)
       (u:0 =? u:0 (label "continue"))))))
   (list
    'conj-fail
    (term
     (More
      (Conj
       ,OWNERS-U0
       (Dead ,OWNERS-U1)
       (u:0 =? u:0 (label "unreachable"))))))
   (list
    'unify-success
    (term
     (More
      (Work
       ,OWNERS-U0
       (u:0 =? (nat 7) (label "bind"))
       ,SIGMA-EMPTY))))
   (list
    'unify-violates-disequality
    (term
     (More
      (Work
       ,OWNERS-U0
       (u:0 =? (nat 7) (label "violate"))
       (state
        ()
        ((u:0 (nat 7)))
        ()
        (label "disequality-state"))))))
   (list
    'unify-fail
    (term
     (More
      (Work
       ,OWNERS-EMPTY
       ((nat 0) =? (nat 1) (label "unify-fail"))
       ,SIGMA-EMPTY))))
   (list
    'disequality-success
    (term
     (More
      (Work
       ,OWNERS-U0
       (u:0 != (nat 7) (label "exclude"))
       ,SIGMA-EMPTY))))
   (list
    'disequality-fail
    (term
     (More
      (Work
       ,OWNERS-EMPTY
       ((nat 0) != (nat 0) (label "same-data"))
       ,SIGMA-EMPTY))))
   (list
    'finish-success
    (term (More (Returned ,OWNERS-U0 ,SIGMA-EMPTY))))
   (list
    'finish-failure
    (term (More (Dead ,OWNERS-U0))))
   (list
    'allocate-fresh
    (term
     (More
      (Conj
       ,OWNERS-U0
       (Work
        (Owners (Owner (u:2) (label "u2")))
        (∃ (x:new)
           (x:new =? u:0 (label "fresh-body"))
           (label "allocate-u1"))
        ,SIGMA-EMPTY)
       (u:0 != (nat 9) (label "future"))))))))

(define SUCCESS-TRACE/S
  (term
   (More
    (Work
     (Owners)
     (∃ (x:q)
        ((x:q =? (sym "cat") (label "bind"))
         ∧
         (x:q != (sym "dog") (label "constrain"))
         (label "and"))
        (label "fresh"))
     ,SIGMA-EMPTY))))

(define SUCCESS-LABELS
  '(allocate-fresh
    expand-conjunction
    unify-success
    conj-return
    disequality-success
    finish-success))

(define FAILURE-TRACE/S
  (term
   (More
    (Work
     (Owners)
     (∃ (x:failed)
        ((fail (label "left-failure"))
         ∧
         (x:failed =? x:failed (label "unreached-right"))
         (label "failing-conjunction"))
        (label "fresh-fail"))
     ,SIGMA-EMPTY))))

(define FAILURE-LABELS
  '(allocate-fresh
    expand-conjunction
    fail
    conj-fail
    finish-failure))

(define FRESH-BOUNDARY-SOURCES/S
  (list
   (term
    (More
     (Work
      (Owners)
      (∃ ()
         (succeed (label "empty-body"))
         (label "empty-fresh"))
      ,SIGMA-EMPTY)))
   (term
    (More
     (Work
      ,OWNERS-U0
      (∃ (x:a x:b)
         (∃ (x:a)
            ((x:a =? x:b (label "nested"))
             ∧
             (u:0 =? x:b (label "mixed"))
             (label "inner-and"))
            (label "shadow"))
         (label "outer"))
      ,SIGMA-EMPTY)))))

(define (canonical-proof-multiset proofs)
  ;; Sorting makes relation enumeration order irrelevant while retaining every
  ;; duplicate proof.  Never use remove-duplicates in this comparison.
  (sort proofs string<? #:key ~s))

(define (rule-names relation)
  (sort
   (map (lambda (name) (string->symbol (~a name)))
        (reduction-relation->rule-names relation))
   symbol<?))

(define (raw-successors/production/s frontier)
  (for/list ([named-step
              (in-list
               (apply-reduction-relation/tag-with-names
                production:core-red
                frontier))])
    (match-define (list name target) named-step)
    (list (string->symbol (~a name)) target)))

(define (wf/generated/s? frontier)
  (judgment-holds (gs:wf-core/generated/s? ,frontier)))

(define (wf/oracle/s? frontier)
  (judgment-holds (os-wf:wf-core-oracle/s? ,frontier)))

(define (wf/generated/e? frontier)
  (judgment-holds (ge:wf-core/generated/e? ,frontier)))

(define (wf/oracle/e? frontier)
  (judgment-holds (oe-wf:wf-core-oracle/e? ,frontier)))

(define (wf/generated/n? frontier)
  (judgment-holds (gn:wf-core/generated/n? ,frontier)))

(define (wf/oracle/n? frontier)
  (judgment-holds (on-wf:wf-core-oracle/n? ,frontier)))

(define (check-one-row who
                       expected-label
                       source
                       generated-raw
                       oracle-raw
                       generated-wf?
                       oracle-wf?)
  (with-check-info (['row who]
                    ['rule expected-label]
                    ['source source])
    (check-true (generated-wf? source))
    (check-true (oracle-wf? source))
    (define generated-proofs (generated-raw source))
    (define oracle-proofs (oracle-raw source))
    (check-equal? (canonical-proof-multiset generated-proofs)
                  (canonical-proof-multiset oracle-proofs))
    (check-equal? (length generated-proofs) 1)
    (check-equal? (length oracle-proofs) 1)
    (match-define (list generated-name generated-target)
      (first generated-proofs))
    (match-define (list oracle-name oracle-target)
      (first oracle-proofs))
    (check-equal? generated-name expected-label)
    (check-equal? oracle-name expected-label)
    (check-equal? generated-target oracle-target)
    (check-true (generated-wf? generated-target))
    (check-true (oracle-wf? oracle-target))
    generated-target))

(define (check-cube-step expected-label s-source)
  (define e-source (oq:Q-SE/F s-source))
  (define n-source (oq:Q-SN/F s-source))
  (define s-target
    (check-one-row
     'S
     expected-label
     s-source
     gs:raw-successors/generated/s
     os:raw-successors/s
     wf/generated/s?
     wf/oracle/s?))
  (define e-target
    (check-one-row
     'E
     expected-label
     e-source
     ge:raw-successors/generated/e
     oe:raw-successors/e
     wf/generated/e?
     wf/oracle/e?))
  (define n-target
    (check-one-row
     'N
     expected-label
     n-source
     gn:raw-successors/generated/n
     on:raw-successors/n
     wf/generated/n?
     wf/oracle/n?))
  (check-equal? (gq:Q-SE/generated s-source) (oq:Q-SE/F s-source))
  (check-equal? (gq:Q-EN/generated e-source) (oq:Q-EN/F e-source))
  (check-equal? (gq:Q-SN/generated s-source) (oq:Q-SN/F s-source))
  (check-true (gq:Q-SN-composition/generated? s-source))
  (check-equal? (gq:Q-SE/generated s-target) e-target)
  (check-equal? (gq:Q-EN/generated e-target) n-target)
  (check-equal? (gq:Q-SN/generated s-target) n-target)
  (values s-target e-target n-target))

(define (transport-proofs q proofs)
  (for/list ([proof (in-list proofs)])
    (match-define (list name target) proof)
    (list name (q target))))

(define (plug-focused pair)
  (match-define (list focused focus) pair)
  (term (in-hole ,focus ,focused)))

(define (check-generated-squares s-source)
  (define e-source (gq:Q-SE/generated s-source))
  (define n-source (gq:Q-SN/generated s-source))
  (check-equal?
   (canonical-proof-multiset
    (transport-proofs
     gq:Q-SE/generated
     (gs:raw-successors/generated/s s-source)))
   (canonical-proof-multiset
    (ge:raw-successors/generated/e e-source)))
  (check-equal?
   (canonical-proof-multiset
    (transport-proofs
     gq:Q-EN/generated
     (ge:raw-successors/generated/e e-source)))
   (canonical-proof-multiset
    (gn:raw-successors/generated/n n-source)))
  (check-equal?
   (canonical-proof-multiset
    (transport-proofs
     gq:Q-SN/generated
     (gs:raw-successors/generated/s s-source)))
   (canonical-proof-multiset
    (gn:raw-successors/generated/n n-source))))

(define (trace-cube s-source expected-labels [fuel 32])
  (when (zero? fuel)
    (error 'trace-cube "generated core trace exceeded its test bound"))
  (match expected-labels
    ['()
     (define e-source (oq:Q-SE/F s-source))
     (define n-source (oq:Q-SN/F s-source))
     (check-equal? (gs:raw-successors/generated/s s-source) '())
     (check-equal? (ge:raw-successors/generated/e e-source) '())
     (check-equal? (gn:raw-successors/generated/n n-source) '())
     (values s-source e-source n-source)]
    [(cons expected-label remaining)
     (check-generated-squares s-source)
     (define-values (s-target _e-target _n-target)
       (check-cube-step expected-label s-source))
     (trace-cube s-target remaining (sub1 fuel))]))

(define-test-suite GENERATED-CORE-SOURCE-COMPARISONS
  (test-case "each generated row has exactly the independent oracle inventory"
    (for ([pair
           (in-list
            (list (list gs:generated-core-s-red os:core-s-oracle-red)
                  (list ge:generated-core-e-red oe:core-e-oracle-red)
                  (list gn:generated-core-n-red on:core-n-oracle-red)))])
      (match-define (list generated oracle) pair)
      (check-equal? (rule-names generated) CORE-RULE-NAMES)
      (check-equal? (rule-names generated) (rule-names oracle))
      (check-equal? (length (reduction-relation->rule-names generated)) 13))
    ;; Canary: the proof comparator retains duplicate equal proofs.
    (check-equal?
     (canonical-proof-multiset '((same target) (same target)))
     '((same target) (same target)))
    (check-not-equal?
     (canonical-proof-multiset '((same target) (same target)))
     (canonical-proof-multiset '((same target)))))

  (test-case "all thirteen generated rules equal independent S/E/N oracles"
    (for ([representative (in-list RULE-SOURCES/S)])
      (match-define (list expected-label s-source) representative)
      (check-cube-step expected-label s-source)
      (check-generated-squares s-source)))

  (test-case "generated S also agrees with production on the shared core corpus"
    ;; This is a deliberately bounded comparison.  In core there is one active
    ;; world path, so the selected world-local allocator and production's
    ;; current allocation policy agree on these thirteen witnesses.  This does
    ;; not claim policy equivalence once branching features are present.
    (for ([representative (in-list RULE-SOURCES/S)])
      (match-define (list expected-label source) representative)
      (check-true
       (redex-match? production-lang:core-lang F source))
      (check-true
       (judgment-holds (production-wf:wf-cfg/core? ,source)))
      (define generated (gs:raw-successors/generated/s source))
      (define direct-oracle (os:raw-successors/s source))
      (define production (raw-successors/production/s source))
      (check-equal? (canonical-proof-multiset generated)
                    (canonical-proof-multiset direct-oracle))
      (check-equal? (canonical-proof-multiset generated)
                    (canonical-proof-multiset production))
      (check-equal? (map first production) (list expected-label))))

  (test-case "generated grammars have the selected phase-sensitive carriers"
    (for ([representative (in-list RULE-SOURCES/S)])
      (match-define (list _ s-source) representative)
      (define e-source (oq:Q-SE/F s-source))
      (define n-source (oq:Q-SN/F s-source))
      (check-true (redex-match? gs:generated-core-s-lang F s-source))
      (check-true (redex-match? os-lang:core-s-oracle-lang F s-source))
      (check-true (redex-match? ge:generated-core-e-lang F e-source))
      (check-true (redex-match? oe-lang:core-e-oracle-lang F e-source))
      (check-true (redex-match? gn:generated-core-n-lang F n-source))
      (check-true (redex-match? on-lang:core-n-oracle-lang F n-source)))
    (check-false
     (redex-match?
      ge:generated-core-e-lang
      F
      (term
       (More
        (Work
         (Support u:0)
         (succeed (label "obsolete-node-support"))
         (state (Support u:0) () () () (label "state")))))))
    (check-false
     (redex-match?
      gn:generated-core-n-lang
      F
      (term
       (More
        (Work
         ,OWNERS-U0
         (succeed (label "ownerful-N"))
         (state 1 () () () (label "state")))))))
    (check-false
     (redex-match?
      gs:generated-core-s-lang
      F
      (term (Done (Support u:0)))))
    (check-false
     (redex-match? gn:generated-core-n-lang rv (term (nat 0))))
    (check-false
     (redex-match? gn:generated-core-n-lang rv (term -1)))
    (check-true
     (redex-match? gn:generated-core-n-lang pt (term (nat -1)))))

  (test-case "generated WF equals each independent representation oracle"
    (define valid-s
      (list
       (second (assoc 'conj-return RULE-SOURCES/S))
       (term (Done ,OWNERS-U0))
       (term
        (Last
         ,OWNERS-U0
         (Answer ,OWNERS-U1 ,SIGMA-EMPTY)))))
    (define invalid-s
      (list
       (term
        (More
         (Work
          (Owners
           (Owner (u:0) (label "first"))
           (Owner (u:0) (label "duplicate")))
          (succeed (label "body"))
          ,SIGMA-EMPTY)))
       (term
        (More
         (Work
          (Owners)
          (u:0 =? u:0 (label "unowned"))
          ,SIGMA-EMPTY)))
       (term
        (More
         (Conj
          (Owners)
          (Returned ,OWNERS-U0 ,SIGMA-EMPTY)
          (u:0 =? u:0 (label "child-only")))))))
    (for ([frontier (in-list valid-s)])
      (check-true (wf/generated/s? frontier))
      (check-equal? (wf/generated/s? frontier) (wf/oracle/s? frontier)))
    (for ([frontier (in-list invalid-s)])
      (check-false (wf/generated/s? frontier))
      (check-equal? (wf/generated/s? frontier) (wf/oracle/s? frontier)))

    (define valid-e
      (term
       (More
        (Conj
         (Dead (Support u:7 u:2))
         (u:2 =? u:7 (label "pending"))))))
    (define invalid-e
      (term
       (More
        (Conj
         (Dead (Support u:7 u:2))
         (u:9 =? u:7 (label "absent"))))))
    (check-true (wf/generated/e? valid-e))
    (check-equal? (wf/generated/e? valid-e) (wf/oracle/e? valid-e))
    (check-false (wf/generated/e? invalid-e))
    (check-equal? (wf/generated/e? invalid-e) (wf/oracle/e? invalid-e))

    (define valid-n
      (list
       (term
        (More
         (Work
          (0 =? (nat -4) (label "level-vs-data"))
          (state 1 () () () (label "state")))))
       ;; `(nat 0)` is object-language data, not a reference back to runtime
       ;; level 0 and therefore not a substitution cycle.
       (term
        (More
         (Returned
          (state
           1
           ((0 (nat 0)))
           ()
           ((0 =? (nat 0) (label "bind-data")))
           (label "bound-data")))))))
    (define invalid-n
      (term
       (More
        (Conj
         (Dead 2)
         (2 =? 0 (label "not-below-next"))))))
    (for ([frontier (in-list valid-n)])
      (check-true (wf/generated/n? frontier))
      (check-equal? (wf/generated/n? frontier) (wf/oracle/n? frontier)))
    (check-false (wf/generated/n? invalid-n))
    (check-equal? (wf/generated/n? invalid-n) (wf/oracle/n? invalid-n)))

  (test-case "fresh boundaries remain binder-local and S allocation reads WorkFocus"
    (for ([s-source (in-list FRESH-BOUNDARY-SOURCES/S)])
      (check-cube-step 'allocate-fresh s-source)
      (check-generated-squares s-source))
    (define path-source
      (second (assoc 'allocate-fresh RULE-SOURCES/S)))
    (match-define (list (list _ path-target))
      (gs:raw-successors/generated/s path-source))
    (check-match
     path-target
     `(More
       (Conj
        (Owners (Owner (u:0) (label "u0")))
        (Work
         (Owners
          (Owner (u:2) (label "u2"))
          (Owner (u:1) (label "allocate-u1")))
         . ,_)
        . ,_))))

  (test-case "branch copy is explicit and representation-local"
    (check-equal?
     (term (gs:branch-copy/generated/s ,OWNERS-U0))
     OWNERS-U0)
    (check-equal?
     (term (ge:branch-copy/generated/e (Support u:7 u:2)))
     (term (Support u:7 u:2)))
    (check-equal? (term (gn:branch-copy/generated/n 7)) 7))

  (test-case "successful and failing traces retain exact labels and summaries"
    (define-values (success-s success-e success-n)
      (trace-cube SUCCESS-TRACE/S SUCCESS-LABELS))
    (check-match success-s `(Last . ,_))
    (check-match success-e `(Last . ,_))
    (check-match success-n `(Last . ,_))

    (define-values (failure-s failure-e failure-n)
      (trace-cube FAILURE-TRACE/S FAILURE-LABELS))
    (check-equal?
     failure-s
     (term
      (Done
       (Owners
        (Owner (u:0) (label "fresh-fail"))))))
    (check-equal? failure-e (term (Done (Support u:0))))
    (check-equal? failure-n (term (Done 1)))
    (check-equal? (gq:Q-SE/generated failure-s) failure-e)
    (check-equal? (gq:Q-SN/generated failure-s) failure-n))

  (test-case "empty and unused allocation supply survives later failure"
    (define cases
      (list
       (list
        'empty
        (term
         (More
          (Work
           (Owners)
           (∃ () (fail (label "body")) (label "empty"))
           ,SIGMA-EMPTY)))
        (term
         (Done (Owners (Owner () (label "empty")))))
        (term (Done (Support)))
        (term (Done 0)))
       (list
        'unused-one
        (term
         (More
          (Work
           (Owners)
           (∃ (x:unused)
              (fail (label "body"))
              (label "unused-one"))
           ,SIGMA-EMPTY)))
        (term
         (Done
          (Owners
           (Owner (u:0) (label "unused-one")))))
        (term (Done (Support u:0)))
        (term (Done 1)))
       (list
        'unused-two
        (term
         (More
          (Work
           (Owners)
           (∃ (x:a x:b)
              (fail (label "body"))
              (label "unused-two"))
           ,SIGMA-EMPTY)))
        (term
         (Done
          (Owners
           (Owner (u:0 u:1) (label "unused-two")))))
        (term (Done (Support u:0 u:1)))
        (term (Done 2)))))
    (for ([case (in-list cases)])
      (match-define
        (list name source expected-s expected-e expected-n)
        case)
      (define-values (terminal-s terminal-e terminal-n)
        (trace-cube
         source
         '(allocate-fresh fail finish-failure)))
      (check-equal? terminal-s expected-s (format "S terminal for ~a" name))
      (check-equal? terminal-e expected-e (format "E terminal for ~a" name))
      (check-equal? terminal-n expected-n (format "N terminal for ~a" name))))

  (test-case "two conjunction frames preserve ordered failure supply"
    (define source
      (term
       (More
        (Work
         ,OWNERS-U0
         (∃ (x:q)
            (((fail (label "deep-failure"))
              ∧
              (x:q =? x:q (label "inner-unreached"))
              (label "inner-and"))
             ∧
             (succeed (label "outer-unreached"))
             (label "outer-and"))
            (label "nested-fresh"))
         ,SIGMA-EMPTY))))
    (define-values (terminal-s terminal-e terminal-n)
      (trace-cube
       source
       '(allocate-fresh
         expand-conjunction
         expand-conjunction
         fail
         conj-fail
         conj-fail
         finish-failure)))
    (check-equal?
     terminal-s
     (term
      (Done
       (Owners
        (Owner (u:0) (label "u0"))
        (Owner (u:1) (label "nested-fresh"))))))
    (check-equal? terminal-e (term (Done (Support u:0 u:1))))
    (check-equal? terminal-n (term (Done 2))))

  (test-case "sparse E support is addressed by stored order"
    (define sparse-e
      (term
       (More
        (Work
         (∃ (x:new)
            (x:new =? u:7 (label "body"))
            (label "fresh"))
         (state
          (Support u:7 u:2)
          ()
          ()
          ()
          (label "sparse-state"))))))
    (define expected-n-source
      (term
       (More
        (Work
         (∃ (x:new)
            (x:new =? 0 (label "body"))
            (label "fresh"))
         (state 2 () () () (label "sparse-state"))))))
    (check-equal? (gq:Q-EN/generated sparse-e) expected-n-source)
    (check-equal? (gq:Q-EN/generated sparse-e) (oq:Q-EN/F sparse-e))
    (define e-target
      (check-one-row
       'sparse-E
       'allocate-fresh
       sparse-e
       ge:raw-successors/generated/e
       oe:raw-successors/e
       wf/generated/e?
       wf/oracle/e?))
    (define n-target
      (check-one-row
       'sparse-N
       'allocate-fresh
       expected-n-source
       gn:raw-successors/generated/n
       on:raw-successors/n
       wf/generated/n?
       wf/oracle/n?))
    (check-match
     e-target
     `(More
       (Work
        (u:0 =? u:7 (label "body"))
        (state (Support u:7 u:2 u:0) . ,_))))
    (check-match
     n-target
     `(More
       (Work
        (2 =? 0 (label "body"))
        (state 3 . ,_))))
    (check-equal? (gq:Q-EN/generated e-target) n-target)

    (define absent-e
      (term
       (More
        (Conj
         (Dead (Support u:7 u:2))
         (u:9 =? u:7 (label "absent"))))))
    (check-false (wf/generated/e? absent-e))
    (check-exn exn:fail? (lambda () (gq:Q-EN/generated absent-e)))
    (check-exn exn:fail? (lambda () (oq:Q-EN/F absent-e))))

  (test-case "focused Q hooks retain context provenance and round-trip"
    (define s-focused
      (term
       (Work
        (Owners (Owner () (label "focused-empty-owner")))
        (u:9 =? u:2 (label "focused-goal"))
        (state
         ((u:9 u:7))
         ()
         ((u:9 =? u:7 (label "trail")))
         (label "focused-state")))))
    (define s-focus
      (term
       (More
        (Conj
         (Owners (Owner (u:7) (label "outer-owner")))
         (Conj
          (Owners
           (Owner () (label "empty-owner"))
           (Owner (u:2 u:9) (label "inner-owner")))
          hole
          (u:9 != u:7 (label "inner-deferred")))
         (u:7 =? (nat 0) (label "outer-deferred"))))))
    (define expected-e
      (list
       (term
        (Work
         (u:9 =? u:2 (label "focused-goal"))
         (state
          (Support u:7 u:2 u:9)
          ((u:9 u:7))
          ()
          ((u:9 =? u:7 (label "trail")))
          (label "focused-state"))))
       (term
        (More
         (Conj
          (Conj hole (u:9 != u:7 (label "inner-deferred")))
          (u:7 =? (nat 0) (label "outer-deferred")))))))
    (define expected-n
      (list
       (term
        (Work
         (2 =? 1 (label "focused-goal"))
         (state
          3
          ((2 0))
          ()
          ((2 =? 0 (label "trail")))
          (label "focused-state"))))
       (term
        (More
         (Conj
          (Conj hole (2 != 0 (label "inner-deferred")))
          (0 =? (nat 0) (label "outer-deferred")))))))
    (define actual-e (gq:Q-SE/focus/generated s-focused s-focus))
    (define actual-n (gq:Q-SN/focus/generated s-focused s-focus))
    (check-equal? actual-e expected-e)
    (check-equal? actual-n expected-n)
    (check-equal?
     (apply gq:Q-EN/focus/generated actual-e)
     expected-n)
    (check-true
     (gq:Q-SN/focus-composition/generated? s-focused s-focus))
    (check-equal?
     (gs:q-focus-rebuild/generated/s
      (gs:q-focus-export/generated/s s-focused s-focus))
     (list s-focused s-focus))
    (check-equal?
     (ge:q-focus-rebuild/generated/e
      (apply ge:q-focus-export/generated/e expected-e))
     expected-e)
    (check-equal?
     (gn:q-focus-rebuild/generated/n
      (apply gn:q-focus-export/generated/n expected-n))
     expected-n)
    ;; The focused views are the separated form of the unchanged CP3 whole-F
    ;; maps; plugging either side gives exactly the old output.
    (define s-frontier (plug-focused (list s-focused s-focus)))
    (check-equal? (plug-focused actual-e)
                  (gq:Q-SE/generated s-frontier))
    (check-equal? (plug-focused actual-n)
                  (gq:Q-SN/generated s-frontier))
    (check-true (wf/generated/s? s-frontier))
    (check-true (wf/generated/e? (plug-focused actual-e)))
    (check-true (wf/generated/n? (plug-focused actual-n))))

  (test-case "focused sparse E support addresses every deferred goal"
    (define e-focused
      (term
       (Work
        (u:2 =? u:7 (label "focused"))
        (state
         (Support u:7 u:2)
         ((u:2 u:7))
         ()
         ()
         (label "sparse-state")))))
    (define e-focus
      (term
       (More
        (Conj
         (Conj hole (u:7 != u:2 (label "inner-deferred")))
         (u:2 =? u:7 (label "outer-deferred"))))))
    (define expected-n
      (list
       (term
        (Work
         (1 =? 0 (label "focused"))
         (state
          2
          ((1 0))
          ()
          ()
          (label "sparse-state"))))
       (term
        (More
         (Conj
          (Conj hole (0 != 1 (label "inner-deferred")))
          (1 =? 0 (label "outer-deferred")))))))
    (check-equal?
     (gq:Q-EN/focus/generated e-focused e-focus)
     expected-n)
    (check-equal?
     (plug-focused expected-n)
     (gq:Q-EN/generated
      (plug-focused (list e-focused e-focus))))
    (define absent-focus
      (term
       (More
        (Conj hole (u:9 =? u:7 (label "absent-deferred"))))))
    (check-exn
     exn:fail?
     (lambda ()
       (gq:Q-EN/focus/generated e-focused absent-focus))))

  (test-case "focused failure retains only the mapped world summary"
    (define s-focused
      (term
       (Dead
        (Owners
         (Owner () (label "empty-failed-owner"))
         (Owner (u:9) (label "failed-owner"))))))
    (define s-focus
      (term
       (More
        (Conj
         (Owners (Owner (u:7 u:2) (label "outer-owner")))
         hole
         (u:7 != u:2 (label "deferred-after-failure"))))))
    (define expected-e
      (list
       (term (Dead (Support u:7 u:2 u:9)))
       (term
        (More
         (Conj hole (u:7 != u:2 (label "deferred-after-failure")))))))
    (define expected-n
      (list
       (term (Dead 3))
       (term
        (More
         (Conj hole (0 != 1 (label "deferred-after-failure")))))))
    (check-equal?
     (gq:Q-SE/focus/generated s-focused s-focus)
     expected-e)
    (check-equal?
     (gq:Q-SN/focus/generated s-focused s-focus)
     expected-n)
    (check-equal?
     (apply gq:Q-EN/focus/generated expected-e)
     expected-n)
    (check-true
     (gq:Q-SN/focus-composition/generated? s-focused s-focus))
    (check-equal?
     (gs:q-focus-rebuild/generated/s
      (gs:q-focus-export/generated/s s-focused s-focus))
     (list s-focused s-focus))
    (check-equal? (plug-focused expected-e)
                  (gq:Q-SE/generated
                   (plug-focused (list s-focused s-focus))))
    (check-equal? (plug-focused expected-n)
                  (gq:Q-SN/generated
                   (plug-focused (list s-focused s-focus))))

    ;; B carries the summary without a materialized Dead node.  The dedicated
    ;; failure-focus view must produce the same possible-world translation
    ;; directly, including every enclosing Owner prefix.
    (match-define `(Dead ,s-summary) s-focused)
    (define expected-failure-e
      (list
       (term (Support u:7 u:2 u:9))
       (second expected-e)))
    (define expected-failure-n
      (list 3 (second expected-n)))
    (check-equal?
     (gq:Q-SE/failure-focus/generated s-summary s-focus)
     expected-failure-e)
    (check-equal?
     (gq:Q-SN/failure-focus/generated s-summary s-focus)
     expected-failure-n)
    (check-equal?
     (apply gq:Q-EN/failure-focus/generated expected-failure-e)
     expected-failure-n)
    (check-true
     (gq:Q-SN/failure-focus-composition/generated? s-summary s-focus))
    (check-equal?
     (gs:q-failure-focus-rebuild/generated/s
      (gs:q-failure-focus-export/generated/s s-summary s-focus))
     (list s-summary s-focus))
    (check-equal?
     (ge:q-failure-focus-rebuild/generated/e
      (apply ge:q-failure-focus-export/generated/e expected-failure-e))
     expected-failure-e)
    (check-equal?
     (gn:q-failure-focus-rebuild/generated/n
      (apply gn:q-failure-focus-export/generated/n expected-failure-n))
     expected-failure-n))

  (test-case "root-focus Q rebuilds each row's own Redex root spine"
    (define s-roots
      (list
       (term (More (Returned ,OWNERS-U0 ,SIGMA-EMPTY)))
       (term (More (Dead ,OWNERS-U0)))))
    (for ([s-root (in-list s-roots)])
      (define e-root (oq:Q-SE/F s-root))
      (define n-root (oq:Q-SN/F s-root))
      (define s-root-focus (list s-root (term hole)))
      (define e-root-focus (list e-root (term hole)))
      (define n-root-focus (list n-root (term hole)))
      (check-equal?
       (apply gq:Q-SE/root-focus/generated s-root-focus)
       e-root-focus)
      (check-equal?
       (apply gq:Q-SN/root-focus/generated s-root-focus)
       n-root-focus)
      (check-equal?
       (apply gq:Q-EN/root-focus/generated e-root-focus)
       n-root-focus)
      (check-true
       (apply gq:Q-SN/root-focus-composition/generated? s-root-focus))
      (check-equal?
       (gs:q-root-focus-rebuild/generated/s
        (apply gs:q-root-focus-export/generated/s s-root-focus))
       s-root-focus)
      (check-equal?
       (ge:q-root-focus-rebuild/generated/e
        (apply ge:q-root-focus-export/generated/e e-root-focus))
       e-root-focus)
      (check-equal?
       (gn:q-root-focus-rebuild/generated/n
        (apply gn:q-root-focus-export/generated/n n-root-focus))
       n-root-focus)))

  (test-case "terminal Q uses direct success and failure views"
    (define s-terminals
      (list
       (term (Last ,OWNERS-EMPTY (Answer ,OWNERS-U0 ,SIGMA-EMPTY)))
       (term (Done ,OWNERS-U0))))
    (for ([s-terminal (in-list s-terminals)])
      (define e-terminal (oq:Q-SE/F s-terminal))
      (define n-terminal (oq:Q-SN/F s-terminal))
      (check-equal?
       (gq:Q-SE/terminal/generated s-terminal)
       e-terminal)
      (check-equal?
       (gq:Q-SN/terminal/generated s-terminal)
       n-terminal)
      (check-equal?
       (gq:Q-EN/terminal/generated e-terminal)
       n-terminal)
      (check-true
       (gq:Q-SN/terminal-composition/generated? s-terminal))
      (check-equal?
       (gs:q-terminal-rebuild/generated/s
        (gs:q-terminal-export/generated/s s-terminal))
       s-terminal)
      (check-equal?
       (ge:q-terminal-rebuild/generated/e
        (ge:q-terminal-export/generated/e e-terminal))
       e-terminal)
      (check-equal?
       (gn:q-terminal-rebuild/generated/n
        (gn:q-terminal-export/generated/n n-terminal))
       n-terminal)))

  (test-case "row Q hooks round-trip their own complete carrier views"
    (for ([representative (in-list RULE-SOURCES/S)])
      (match-define (list _ s-source) representative)
      (define e-source (oq:Q-SE/F s-source))
      (define n-source (oq:Q-SN/F s-source))
      (check-equal?
       (gs:q-rebuild/generated/s (gs:q-export/generated/s s-source))
       s-source)
      (check-equal?
       (ge:q-rebuild/generated/e (ge:q-export/generated/e e-source))
       e-source)
      (check-equal?
       (gn:q-rebuild/generated/n (gn:q-export/generated/n n-source))
       n-source))))

(module+ test
  (run-tests GENERATED-CORE-SOURCE-COMPARISONS))
