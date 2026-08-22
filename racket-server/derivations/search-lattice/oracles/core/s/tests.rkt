#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "./language.rkt"
         "./source.rkt"
         "./wf.rkt")

(provide CORE-S-ORACLE-TESTS)

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

(define sigma-empty
  (term (state () () () (label "state"))))

(define owners-empty
  (term (Owners)))

(define owners-u0
  (term (Owners (Owner (u:0) (label "intro-u0")))))

(define owners-u1
  (term (Owners (Owner (u:1) (label "intro-u1")))))

(define owners-u2
  (term (Owners (Owner (u:2) (label "intro-u2")))))

(define owners-u0-u1
  (term
   (Owners
    (Owner (u:0) (label "intro-u0"))
    (Owner (u:1) (label "intro-u1")))))

(define rich-state
  (term
   (state
    ((u:0 (nat 0)))
    ((u:0 (nat 1)))
    ((u:0 =? (nat 0) (label "bind-u0")))
    (label "rich-state"))))

(define allocation-source
  (term
   (More
    (Conj
     ,owners-u0
     (Work
      ,owners-u2
      (∃ (x:q)
         (x:q =? u:0 (label "fresh-body"))
         (label "fresh-u1"))
      ,sigma-empty)
     (u:0 != (nat 7) (label "future-goal"))))))

(define allocation-target
  (term
   (More
    (Conj
     ,owners-u0
     (Work
      (Owners
       (Owner (u:2) (label "intro-u2"))
       (Owner (u:1) (label "fresh-u1")))
      (u:1 =? u:0 (label "fresh-body"))
      ,sigma-empty)
     (u:0 != (nat 7) (label "future-goal"))))))

;; Each triple is a separately stated source clause witness.  Exact named
;; results check the rule observation, target, and raw multiplicity together.
(define RULE-REPRESENTATIVES
  (list
   (list
    'expand-conjunction
    (term
     (More
      (Work
       ,owners-u0
       ((succeed (label "left"))
        ∧
        (u:0 =? u:0 (label "right"))
        (label "conjunction"))
       ,sigma-empty)))
    (term
     (More
      (Conj
       ,owners-u0
       (Work (Owners) (succeed (label "left")) ,sigma-empty)
       (u:0 =? u:0 (label "right"))))))
   (list
    'succeed
    (term
     (More
      (Work ,owners-u0 (succeed (label "yes")) ,sigma-empty)))
    (term (More (Returned ,owners-u0 ,sigma-empty))))
   (list
    'fail
    (term
     (More
      (Work ,owners-u0 (fail (label "no")) ,sigma-empty)))
    (term (More (Dead ,owners-u0))))
   (list
    'conj-return
    (term
     (More
      (Conj
       ,owners-u0
       (Returned ,owners-u1 ,sigma-empty)
       (succeed (label "continue")))))
    (term
     (More
      (Work ,owners-u0-u1
            (succeed (label "continue"))
            ,sigma-empty))))
   (list
    'conj-fail
    (term
     (More
      (Conj
       ,owners-u0
       (Dead ,owners-u1)
       (succeed (label "unreachable")))))
    (term (More (Dead ,owners-u0-u1))))
   (list 'allocate-fresh allocation-source allocation-target)
   (list
    'unify-success
    (term
     (More
      (Work
       ,owners-u0
       (u:0 =? (nat 0) (label "unify"))
       ,sigma-empty)))
    (term
     (More
      (Returned
       ,owners-u0
       (state
        ((u:0 (nat 0)))
        ()
        ((u:0 =? (nat 0) (label "unify")))
        (label "state"))))))
   (list
    'unify-violates-disequality
    (term
     (More
      (Work
       ,owners-u0
       (u:0 =? (nat 0) (label "violates"))
       (state
        ()
        ((u:0 (nat 0)))
        ()
        (label "violates-state")))))
    (term (More (Dead ,owners-u0))))
   (list
    'unify-fail
    (term
     (More
      (Work
       ,owners-empty
       ((nat 0) =? (nat 1) (label "unify-fail"))
       ,sigma-empty)))
    (term (More (Dead ,owners-empty))))
   (list
    'disequality-success
    (term
     (More
      (Work
       ,owners-u0
       (u:0 != (nat 0) (label "disequality-ok"))
       ,sigma-empty)))
    (term
     (More
      (Returned
       ,owners-u0
       (state
        ()
        ((u:0 (nat 0)))
        ()
        (label "state"))))))
   (list
    'disequality-fail
    (term
     (More
      (Work
       ,owners-empty
       ((nat 0) != (nat 0) (label "disequality-fail"))
       ,sigma-empty)))
    (term (More (Dead ,owners-empty))))
   (list
    'finish-success
    (term (More (Returned ,owners-u0 ,rich-state)))
    (term
     (Last
      ,owners-u0
      (Answer (Owners) ,rich-state))))
   (list
    'finish-failure
    (term (More (Dead ,owners-u0)))
    (term (Done ,owners-u0)))))

(define TERMINAL-REPRESENTATIVES
  (list
   (term (Done ,owners-u0))
   (term
    (Last ,owners-u0 (Answer (Owners) ,rich-state)))))

(define (wf-core/s? frontier)
  (judgment-holds (wf-core-oracle/s? ,frontier)))

(define (normalize-rule-name name)
  (string->symbol (~a name)))

(define (only-named-step source)
  (match (raw-successors/s source)
    [(list (list name target))
     (values (normalize-rule-name name) target)]
    [results
     (error 'only-named-step
            "expected one raw named successor for ~e; received ~e"
            source
            results)]))

(define (advance/s source expected-name)
  (define-values (actual-name target) (only-named-step source))
  (check-equal? actual-name expected-name)
  target)

(define nested-shadow-source
  (term
   (More
    (Work
     ,owners-u0
     (∃ (x:a x:b)
        ((x:a =? u:0 (label "mixed"))
         ∧
         (∃ (x:a)
            (x:a =? x:b (label "shadow-body"))
            (label "inner-shadow"))
         (label "shadow-conjunction"))
        (label "outer-fresh"))
     ,sigma-empty))))

(define nested-shadow-target
  (term
   (More
    (Work
     (Owners
      (Owner (u:0) (label "intro-u0"))
      (Owner (u:1 u:2) (label "outer-fresh")))
     ((u:1 =? u:0 (label "mixed"))
      ∧
      (∃ (x:a)
         (x:a =? u:2 (label "shadow-body"))
         (label "inner-shadow"))
      (label "shadow-conjunction"))
     ,sigma-empty))))

(define empty-fresh-source
  (term
   (More
    (Work
     ,owners-u0
     (∃ ()
        (succeed (label "empty-body"))
        (label "empty-fresh"))
     ,sigma-empty))))

(define empty-fresh-target
  (term
   (More
    (Work
     (Owners
      (Owner (u:0) (label "intro-u0"))
      (Owner () (label "empty-fresh")))
     (succeed (label "empty-body"))
     ,sigma-empty))))

(define conjunction-allocation-source
  (term
   (More
    (Work
     (Owners)
     ((∃ (x:left)
         (succeed (label "left-success"))
         (label "left-fresh"))
      ∧
      (∃ (x:right)
         (succeed (label "right-success"))
         (label "right-fresh"))
      (label "conjunction"))
     ,sigma-empty))))

(define sibling-left-source
  (term
   (More
    (Work
     ,owners-u0
     (∃ (x:left)
        (x:left =? u:0 (label "left-body"))
        (label "left-intro"))
     ,sigma-empty))))

(define sibling-right-source
  (term
   (More
    (Work
     ,owners-u0
     (∃ (x:right)
        (x:right != u:0 (label "right-body"))
        (label "right-intro"))
     ,sigma-empty))))

(define-test-suite CORE-S-ORACLE-TESTS
  (test-case
   "direct grammar retains Owner provenance and excludes cached Support"
   (check-true (redex-match? core-s-oracle-lang F allocation-source))
   (check-true (redex-match? core-s-oracle-lang F empty-fresh-source))
   (check-false
    (redex-match?
     core-s-oracle-lang
     F
     (term
      (More
       (Work
        (Support u:0)
        (succeed (label "not-S"))
        ,sigma-empty)))))
   (check-false
    (redex-match?
     core-s-oracle-lang
     F
     (term
      (More
       (Fresh
        (Owner (u:0) (label "not-a-carrier"))
        (Work (Owners) (succeed (label "body")) ,sigma-empty)))))))

  (test-case
   "the source has exactly the thirteen core labels"
   (define actual
     (reduction-relation->rule-names core-s-oracle-red))
   (check-equal? (length actual) 13)
   (check-equal? (length actual) (length (remove-duplicates actual)))
   (check-equal? (sort actual symbol<?) CORE-RULE-NAMES))

  (test-case
   "every direct rule has one exact named successor and preserves WF"
   (for ([representative (in-list RULE-REPRESENTATIVES)])
     (match-define (list expected-name source expected-target)
       representative)
     (check-true (wf-core/s? source)
                 (format "source WF for ~a" expected-name))
     (define raw-results (raw-successors/s source))
     (check-equal? (length raw-results)
                   1
                   (format "raw multiplicity for ~a" expected-name))
     (match-define (list (list actual-name actual-target)) raw-results)
     (check-equal? (normalize-rule-name actual-name) expected-name)
     (check-equal? actual-target expected-target)
     (check-true (wf-core/s? actual-target)
                 (format "target WF for ~a" expected-name))
     (check-equal? (step-once/s source) raw-results)))

  (test-case
   "terminal success and failure answers are WF and have no successor"
   (for ([terminal (in-list TERMINAL-REPRESENTATIVES)])
     (check-true (wf-core/s? terminal))
     (check-equal? (raw-successors/s terminal) '())
     (check-equal? (step-once/s terminal) '())))

  (test-case
   "allocation reconstructs ordered support only from the active path"
   (check-equal? (world-path-support/s allocation-source)
                 '(u:0 u:2))
   (check-equal? (fresh-u-atoms/s '(u:0 u:2) 3)
                 '(u:1 u:3 u:4))
   (check-equal? (raw-successors/s allocation-source)
                 (list (list 'allocate-fresh allocation-target)))
   (check-true (wf-core/s? allocation-target)))

  (test-case
   "empty binders retain an empty tagged Owner group"
   (check-true (wf-core/s? empty-fresh-source))
   (check-equal? (raw-successors/s empty-fresh-source)
                 (list (list 'allocate-fresh empty-fresh-target)))
   (check-equal? (world-path-support/s empty-fresh-target)
                 '(u:0))
   (check-true (wf-core/s? empty-fresh-target)))

  (test-case
   "multi-variable fresh is simultaneous, mixed, nested, and shadow-aware"
   (check-equal?
    (subst-goal/s
     (term (x:current =? (x:outer : u:0) (label "mixed-scope")))
     (term ((x:current u:1))))
    (term (u:1 =? (x:outer : u:0) (label "mixed-scope"))))
   (check-true (wf-core/s? nested-shadow-source))
   (check-equal? (raw-successors/s nested-shadow-source)
                 (list (list 'allocate-fresh nested-shadow-target)))
   (check-equal? (world-path-support/s nested-shadow-target)
                 '(u:0 u:1 u:2))
   (check-true (wf-core/s? nested-shadow-target)))

  (test-case
   "an unused left fresh still advances the world-local supply for the right"
   (define after-expand
     (advance/s conjunction-allocation-source 'expand-conjunction))
   (define after-left-allocation
     (advance/s after-expand 'allocate-fresh))
   (check-equal? (world-path-support/s after-left-allocation) '(u:0))
   (define after-left-success
     (advance/s after-left-allocation 'succeed))
   (define after-conj-return
     (advance/s after-left-success 'conj-return))
   (check-equal? (world-path-support/s after-conj-return) '(u:0))
   (define after-right-allocation
     (advance/s after-conj-return 'allocate-fresh))
   (check-equal? (world-path-support/s after-right-allocation)
                 '(u:0 u:1))
   (check-true (wf-core/s? after-right-allocation)))

  (test-case
   "incomparable sibling worlds independently reuse a post-prefix atom"
   ;; Core deliberately has no disjunction syntax.  These are the two core
   ;; configurations obtained by selecting sibling possible worlds after a
   ;; hypothetical split.  Each copies the u:0 prefix and steps independently.
   (define left-target
     (advance/s sibling-left-source 'allocate-fresh))
   (define right-target
     (advance/s sibling-right-source 'allocate-fresh))
   (check-equal? (world-path-support/s left-target) '(u:0 u:1))
   (check-equal? (world-path-support/s right-target) '(u:0 u:1))
   (check-match
    left-target
    `(More
      (Work
       (Owners
        (Owner (u:0) (label "intro-u0"))
        (Owner (u:1) (label "left-intro")))
       . ,_)))
   (check-match
    right-target
    `(More
      (Work
       (Owners
        (Owner (u:0) (label "intro-u0"))
        (Owner (u:1) (label "right-intro")))
       . ,_)))
   (check-true (wf-core/s? left-target))
   (check-true (wf-core/s? right-target)))

  (test-case
   "WF is path-local, cumulative, and rejects missing or duplicate names"
   (check-true
    (wf-core/s?
     (term
      (More
       (Work
        (Owners (Owner () (label "empty")))
        (succeed (label "ok"))
        ,sigma-empty)))))
   (check-false
    (wf-core/s?
     (term
      (More
       (Work
        (Owners
         (Owner (u:0) (label "first"))
         (Owner (u:0) (label "duplicate")))
        (succeed (label "bad"))
        ,sigma-empty)))))
   (check-false
    (wf-core/s?
     (term
      (More
       (Work
        (Owners)
        (u:0 =? (nat 0) (label "missing-owner"))
        ,sigma-empty)))))
   ;; u:1 is owned only by the active left child and cannot occur in the
   ;; future right goal stored at the outer frame.
   (check-false
    (wf-core/s?
     (term
      (More
       (Conj
        ,owners-u0
        (Returned ,owners-u1 ,sigma-empty)
        (u:1 =? u:0 (label "not-in-prefix"))))))))

  (test-case
   "substitutions, disequalities, and terminal answer stores retain support"
   (check-true
    (judgment-holds
     (wf-state-oracle/s? ,rich-state (u:0))))
   (check-false
    (judgment-holds
     (wf-state-oracle/s? ,rich-state ())))
   (define-values (name terminal)
     (only-named-step
      (term (More (Returned ,owners-u0 ,rich-state)))))
   (check-equal? name 'finish-success)
   (check-equal?
    terminal
    (term (Last ,owners-u0 (Answer (Owners) ,rich-state))))
   (check-true (wf-core/s? terminal))))

(module+ test
  (run-tests CORE-S-ORACLE-TESTS))
