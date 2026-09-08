#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in red: "../source/reduction-relations/all.rkt")
         "../source/picture.rkt"
         "../../../../src/search-strategy.rkt"
         "./frontier-observable-support.rkt"
         "./search-lattice-support.rkt"
         (only-in "support.rkt" online-relation online-in-domain?))

(provide PROPERTY-NON-CORE)

(define TRACE-CAP 96)
(define ACCOUNTING-TRACE-CAP 160)

(define/match (strategy-label strategy)
  [((search-strategy scheduler)) scheduler])

(define (count-step-name steps expected [count 0])
  (match steps
    ['() count]
    [(cons step-name rest)
     (count-step-name rest
                      expected
                      (if (string=? step-name expected)
                          (add1 count)
                          count))]))

(define duplication-rule-names
  '("reassociate-left-result"
    "reassociate-left-result/search-join"
    "reassociate-right-result/left-nested"
    "reassociate-right-result/right-nested"))

(define prune-rule-names
  '("skip-left-failure" "skip-right-failure"))

(define (owner-record-occurrence-count datum)
  (term (structural-owner-record-occurrence-count ,datum)))

(define (introduced-name-occurrence-count datum)
  (term (structural-introduced-name-occurrence-count ,datum)))

(define (check-owner-occurrence-laws cfgs steps who)
  (check-equal? (length cfgs)
                (add1 (length steps))
                (format "~a trace/state lengths disagree" who))
  (for ([before (in-list cfgs)]
        [after (in-list (rest cfgs))]
        [step-name (in-list steps)]
        [idx (in-naturals)])
    (define before-records (owner-record-occurrence-count before))
    (define after-records (owner-record-occurrence-count after))
    (define before-names (introduced-name-occurrence-count before))
    (define after-names (introduced-name-occurrence-count after))
    (define law-holds?
      (cond
        [(string=? step-name "allocate-fresh")
         (and (= after-records (add1 before-records))
              (>= after-names before-names))]
        [(member step-name duplication-rule-names)
         (and (>= after-records before-records)
              (>= after-names before-names))]
        [(member step-name prune-rule-names)
         (and (<= after-records before-records)
              (<= after-names before-names))]
        [else
         (and (= after-records before-records)
              (= after-names before-names))]))
    (check-true
     law-holds?
     (format
      "~a owner/name occurrence law drifted at step ~a (~a): ~a/~a -> ~a/~a"
      who
      idx
      step-name
      before-records
      before-names
      after-records
      after-names))))

(define (trace-stepper stepper cfg [remaining TRACE-CAP] [cfgs '()] [steps '()])
  (define cfgs^ (cons cfg cfgs))
  (match (remove-duplicates (stepper cfg))
    ['()
     (values (reverse cfgs^)
             (reverse steps)
             cfg
             (if (final-program? cfg) 'value 'stuck))]
    [_ #:when (zero? remaining)
       (values (reverse cfgs^) (reverse steps) cfg 'cap)]
    [(list (list name cfg^))
     (trace-stepper stepper
                    cfg^
                    (sub1 remaining)
                    cfgs^
                    (cons (~a name) steps))]
    [_ (values (reverse cfgs^) (reverse steps) cfg 'nondeterministic)]))

(define (picture-contains-name? node expected)
  (match node
    [(? hash?)
     (or (equal? (hash-ref node 'name #f) expected)
         (for/or ([child (in-list (hash-ref node 'children '()))])
           (picture-contains-name? child expected)))]
    [_ #f]))

(define (owner-observations-consistent? cfg)
  (define records (owner-record-occurrence-count cfg))
  (define names (introduced-name-occurrence-count cfg))
  (and (exact-nonnegative-integer? records)
       (exact-nonnegative-integer? names)
       (or (positive? records) (zero? names))))

(define (zero-forced-implies-pictures-agree? cfg)
  (if (zero? (term (structural-forced-count ,cfg)))
      (equal? (cfg->operational-picture cfg)
              (cfg->extensional-picture cfg))
      #t))

(define (non-core-picture-invariants? cfg)
  (and (structurally-well-formed? cfg)
       (owner-observations-consistent? cfg)
       (visible-json-wf? (cfg->operational-picture cfg))
       (visible-json-wf? (cfg->extensional-picture cfg))
       (not (picture-contains-name? (cfg->extensional-picture cfg)
                                    "Deferred"))
       (zero-forced-implies-pictures-agree? cfg)))

(define sigma-u0
  (term (state () () () (label "su0"))))

(define valid-fresh-delayed-left-work
  (term (PendingDelay
         (Owners (Owner (u:0) (label "fresh")))
         (Work (Owners) (succeed (label "late")) ,sigma-u0))))

(define valid-fresh-flip-frontier
  (term (More
         (DisjL (Owners)
                ,valid-fresh-delayed-left-work
                (Returned (Owners) ,sigma-b)))))

(define valid-fresh-rail-frontier
  (term (More
         (DisjL (Owners)
                ,valid-fresh-delayed-left-work
                (Returned (Owners) ,sigma-b)))))

(define representative-internal-trace-cases
  (list
   (list "delay"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:delay-red cfg))
         cfg-delay-goal)
   (list "search"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:search-red cfg))
         cfg-disj)
   (list "search-dfs"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:search-dfs-red cfg))
         valid-fresh-flip-frontier)
   (list "search-flip"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:search-flip-red cfg))
         valid-fresh-flip-frontier)
   (list "rail"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:rail-red cfg))
         valid-fresh-rail-frontier)
   (list "relcall"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:relcall-red cfg))
         cfg-call)
   (list "search-dfs-relcall"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:search-dfs-relcall-red cfg))
         cfg-call-branch)
   (list "search-flip-relcall"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:search-flip-relcall-red cfg))
         cfg-call-branch)
   (list "rail-relcall"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:rail-relcall-red cfg))
         cfg-call-rail)))

(define representative-search-configs
  (list
   (list
    "fresh shared disj"
    (term
     (()
      (More
       (Work (Owners)
        (∃ (x:x)
           ((x:x =? (sym "left") (label "left"))
            ∨
            (x:x =? (sym "right") (label "right"))
            (label "choice"))
           (label "fresh"))
        ,sigma-s)))))
   (list
    "fresh branch disj"
    (term
     (()
      (More
       (Work (Owners)
        ((∃ (x:left)
            (x:left =? (sym "left") (label "left"))
            (label "fresh-left"))
         ∨
         (∃ (x:right)
            (x:right =? (sym "right") (label "right"))
            (label "fresh-right"))
         (label "choice"))
        ,sigma-s)))))
   (list
    "fresh split conj"
    (term
     (()
      (More
       (Work (Owners)
        ((∃ (x:left)
            (x:left =? (sym "left") (label "left"))
            (label "fresh-left"))
         ∧
         (∃ (x:right)
            (x:right =? (sym "right") (label "right"))
            (label "fresh-right"))
         (label "conj"))
        ,sigma-s)))))
   (list
    "fresh delay witness"
    (term
     (()
      (More
       (Work (Owners)
        (∃ (x:x)
           ((suspend
             (x:x =? (sym "nap") (label "delayed-equality"))
             (label "delay"))
            ∧
            (x:x =? (sym "nap") (label "continuation-equality"))
            (label "conj"))
           (label "fresh"))
        ,sigma-s)))))))

(define representative-surfaced-trace-cases
  (for*/list ([strategy (in-list all-surfaced-search-strategies)]
              [entry (in-list representative-search-configs)])
    (match-define (list label cfg) entry)
    (list strategy label cfg)))

;; These two source-shaped configurations are the smallest witnesses that
;; distinguish proof-relevant owner occurrences from introduction events.
;; The first duplicates one local owner across two successful descendants;
;; the second prunes one local owner with its dead branch.
(define duplicated-local-fresh-config
  (term
   (()
    (More
     (Work (Owners)
      ((∃ (x:inner)
          ((succeed (label "inner-left"))
           ∨
           (succeed (label "inner-right"))
           (label "inner-choice"))
          (label "fresh"))
       ∨
       (succeed (label "outer-right"))
       (label "outer-choice"))
      ,sigma-s)))))

(define erased-local-fresh-config
  (term
   (()
    (More
     (Work (Owners)
      ((∃ (x:inner)
          (fail (label "inner-fail"))
          (label "fresh"))
       ∨
       (succeed (label "outer-right"))
       (label "outer-choice"))
      ,sigma-s)))))

(define-test-suite NON-CORE-PROPERTIES
  (test-case "representative internal non-core traces preserve structural WF and picture invariants"
    (for ([entry (in-list representative-internal-trace-cases)])
      (match-define (list label stepper cfg0) entry)
      (define-values (cfgs steps final-cfg status)
        (trace-stepper stepper cfg0))
      (check-true (or (eq? status 'value) (eq? status 'cap))
                  (format "~a unexpectedly ~a at ~s"
                          label
                          status
                          final-cfg))
      (for ([cfg (in-list cfgs)]
            [idx (in-naturals)])
        (check-true (non-core-picture-invariants? cfg)
                    (format "~a violated invariants at step ~a: ~s"
                            label
                            idx
                            cfg)))
      (check-owner-occurrence-laws cfgs steps label)))

  (test-case "earlier scheduler traces preserve domain, structural WF, and picture invariants"
    (for ([entry (in-list representative-surfaced-trace-cases)])
      (match-define (list strategy label cfg0) entry)
      (define-values (cfgs steps final-cfg status)
        (trace-stepper
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names (online-relation strategy) cfg))
         cfg0))
      (check-true (or (eq? status 'value) (eq? status 'cap))
                  (format "~a / ~a unexpectedly ~a at ~s"
                          (strategy-label strategy)
                          label
                          status
                          final-cfg))
      (for ([cfg (in-list cfgs)]
            [idx (in-naturals)])
        (check-true (online-in-domain? strategy cfg)
                    (format "~a / ~a left its strategy domain at step ~a: ~s"
                            (strategy-label strategy)
                            label
                            idx
                            cfg))
        (check-true (non-core-picture-invariants? cfg)
                    (format "~a / ~a violated invariants at step ~a: ~s"
                            (strategy-label strategy)
                            label
                            idx
                            cfg)))
      (check-owner-occurrence-laws
       cfgs
       steps
       (format "~a / ~a" (strategy-label strategy) label))))

  (test-case "Forced frontiers are neutral except for forced count"
    (define scoped-answer
      (term
       (Last (Owners (Owner (u:0) (label "fresh")))
             (Answer (Owners) (state () () () (label "s"))))))
    (define forced-scoped-answer
      (term (Forced (Owners) ,scoped-answer)))
    (check-true (non-core-picture-invariants? scoped-answer))
    (check-true (non-core-picture-invariants? forced-scoped-answer))
    (check-equal? (term (structural-answer-count ,forced-scoped-answer))
                  (term (structural-answer-count ,scoped-answer)))
    (check-equal?
     (owner-record-occurrence-count forced-scoped-answer)
     (owner-record-occurrence-count scoped-answer))
    (check-equal?
     (introduced-name-occurrence-count forced-scoped-answer)
     (introduced-name-occurrence-count scoped-answer))
    (check-equal? (term (structural-forced-count ,forced-scoped-answer))
                  (add1 (term (structural-forced-count ,scoped-answer))))
    (check-equal? (cfg->extensional-picture forced-scoped-answer)
                  (cfg->extensional-picture scoped-answer)))

  (test-case "answer and terminal owner placement render identically"
    (define answer-cfg
      (term
       (Last (Owners)
             (Answer (Owners (Owner (u:0) (label "fresh")))
                     (state () () () (label "s"))))))
    (define terminal-cfg
      (term
       (Last (Owners (Owner (u:0) (label "fresh")))
             (Answer (Owners) (state () () () (label "s"))))))
    (check-true (non-core-picture-invariants? answer-cfg))
    (check-true (non-core-picture-invariants? terminal-cfg))
    (check-equal? (term (structural-answer-count ,answer-cfg)) 1)
    (check-equal? (term (structural-answer-count ,terminal-cfg)) 1)
    (check-equal? (owner-record-occurrence-count answer-cfg) 1)
    (check-equal? (owner-record-occurrence-count terminal-cfg) 1)
    (check-equal? (introduced-name-occurrence-count answer-cfg) 1)
    (check-equal?
     (introduced-name-occurrence-count terminal-cfg)
     1)
    (check-equal? (cfg->operational-picture answer-cfg)
                  (cfg->operational-picture terminal-cfg))
    (check-equal? (cfg->extensional-picture answer-cfg)
                  (cfg->extensional-picture terminal-cfg)))

  (test-case "completed earlier scheduler traces obey owner occurrence laws and Forced history"
    (for ([entry (in-list representative-surfaced-trace-cases)])
      (match-define (list strategy label cfg0) entry)
      (define-values (cfgs steps final-cfg status)
        (trace-stepper (lambda (cfg)
                         (apply-reduction-relation/tag-with-names
                          (online-relation strategy) cfg))
                       cfg0
                       ACCOUNTING-TRACE-CAP))
      (check-equal? status
                    'value
                    (format "~a / ~a did not finish under accounting cap"
                            (strategy-label strategy)
                            label))
      (check-true (non-core-picture-invariants? final-cfg)
                  (format "~a / ~a final config violated invariants: ~s"
                          (strategy-label strategy)
                          label
                          final-cfg))
      (check-owner-occurrence-laws
       cfgs
       steps
       (format "~a / ~a" (strategy-label strategy) label))
      (check-equal? (term (structural-forced-count ,final-cfg))
                    (count-step-name steps "force-delay")
                    (format "~a / ~a forced accounting drifted"
                            (strategy-label strategy)
                            label))))

  (test-case "branch-local duplication and pruning have exact owner occurrence outcomes"
    (for ([strategy (in-list all-surfaced-search-strategies)])
      (define who (strategy-label strategy))
      (for ([entry (in-list
                    (list
                     (list "duplicated"
                           duplicated-local-fresh-config
                           2
                           "reassociate-left-result")
                     (list "pruned"
                           erased-local-fresh-config
                           0
                           "skip-left-failure")))])
        (match-define (list case-name cfg0 expected-final expected-rule) entry)
        (define-values (cfgs steps final-cfg status)
          (trace-stepper
           (lambda (cfg)
             (apply-reduction-relation/tag-with-names (online-relation strategy) cfg))
           cfg0))
        (define case-who (format "~a / ~a" who case-name))
        (check-equal? status 'value case-who)
        (check-equal? (count-step-name steps "allocate-fresh") 1 case-who)
        (check-equal? (count-step-name steps expected-rule) 1 case-who)
        (check-equal? (owner-record-occurrence-count final-cfg)
                      expected-final
                      case-who)
        (check-equal? (introduced-name-occurrence-count final-cfg)
                      expected-final
                      case-who)
        (check-owner-occurrence-laws cfgs steps case-who)))))

(define/provide-test-suite PROPERTY-NON-CORE
  NON-CORE-PROPERTIES)

(module+ test
  (define failures (run-tests PROPERTY-NON-CORE))
  (unless (zero? failures)
    (error 'PROPERTY-NON-CORE "~a test case(s) failed" failures)))
