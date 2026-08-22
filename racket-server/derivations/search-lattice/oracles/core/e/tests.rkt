#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "./language.rkt"
         "./source.rkt"
         "./wf.rkt")

(provide CORE-E-ORACLE-TESTS)

(define empty-state
  (term (state (Support) () () () (label "state"))))

(define u0-state
  (term (state (Support u:0) () () () (label "state"))))

(define u0-u1-state
  (term (state (Support u:0 u:1) () () () (label "state"))))

(define expected-core-rule-names
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

(define rule-representatives
  (list
   (list
    'expand-conjunction
    (term
     (More
      (Work
       ((succeed (label "left"))
        ∧
        (fail (label "right"))
        (label "conjunction"))
       ,empty-state)))
    (term
     (More
      (Conj
       (Work (succeed (label "left")) ,empty-state)
       (fail (label "right"))))))

   (list
    'succeed
    (term (More (Work (succeed (label "yes")) ,u0-state)))
    (term (More (Returned ,u0-state))))

   (list
    'fail
    (term (More (Work (fail (label "no")) ,u0-state)))
    (term (More (Dead (Support u:0)))))

   (list
    'conj-return
    (term
     (More
      (Conj
       (Returned ,u0-u1-state)
       (u:0 =? u:1 (label "continue")))))
    (term
     (More
      (Work
       (u:0 =? u:1 (label "continue"))
       ,u0-u1-state))))

   (list
    'conj-fail
    (term
     (More
      (Conj
       (Dead (Support u:9))
       (u:9 =? (nat 9) (label "unreachable")))))
    (term (More (Dead (Support u:9)))))

   (list
    'unify-success
    (term
     (More
      (Work
       (u:0 =? (nat 0) (label "unify"))
       ,u0-state)))
    (term
     (More
      (Returned
       (state
        (Support u:0)
        ((u:0 (nat 0)))
        ()
        ((u:0 =? (nat 0) (label "unify")))
        (label "state"))))))

   (list
    'unify-violates-disequality
    (term
     (More
      (Work
       (u:0 =? (nat 0) (label "violates"))
       (state
        (Support u:0)
        ()
        ((u:0 (nat 0)))
        ()
        (label "state")))))
    (term (More (Dead (Support u:0)))))

   (list
    'unify-fail
    (term
     (More
      (Work
       ((nat 0) =? (nat 1) (label "unify-fail"))
       ,u0-state)))
    (term (More (Dead (Support u:0)))))

   (list
    'disequality-success
    (term
     (More
      (Work
       ((nat 0) != (nat 1) (label "disequality-ok"))
       ,empty-state)))
    (term
     (More
      (Returned
       (state
        (Support)
        ()
        (((nat 0) (nat 1)))
        ()
        (label "state"))))))

   (list
    'disequality-fail
    (term
     (More
      (Work
       ((nat 0) != (nat 0) (label "disequality-fail"))
       ,u0-state)))
    (term (More (Dead (Support u:0)))))

   (list
    'finish-success
    (term (More (Returned ,u0-state)))
    (term (Last (Answer ,u0-state))))

   (list
    'finish-failure
    (term (More (Dead (Support u:0))))
    (term (Done (Support u:0))))

   (list
    'allocate-fresh
    (term
     (More
      (Work
       (∃ (x:q)
          (x:q =? u:0 (label "mixed-body"))
          (label "fresh"))
       ,u0-state)))
    (term
     (More
      (Work
       (u:1 =? u:0 (label "mixed-body"))
       ,u0-u1-state))))))

(define (only-named-step/e source)
  (match (raw-successors/e source)
    [(list named-step) named-step]
    [results
     (error 'only-named-step/e
            "expected one raw E proof for ~e, got ~e"
            source
            results)]))

(define (trace/e source [fuel 40] [reversed-labels '()])
  (when (zero? fuel)
    (error 'trace/e "core E trace exceeded its witness bound"))
  (match (step-once/e source)
    ['() (values (reverse reversed-labels) source)]
    [(list (list label target))
     (trace/e target (sub1 fuel) (cons label reversed-labels))]))

(define (step-until-right/e frontier [reversed-labels '()])
  (match frontier
    [`(More (Work (succeed (label "right")) ,state))
     (values (reverse reversed-labels) frontier)]
    [_
     (match-define
       (list label next)
       (only-named-step/e frontier))
     (step-until-right/e next (cons label reversed-labels))]))

(define empty-fresh-source
  (term
   (More
    (Work
     (∃ () (succeed (label "body")) (label "empty-fresh"))
     ,u0-state))))

(define multi-fresh-source
  (term
   (More
    (Work
     (∃ (x:a x:b x:unused)
        (x:a =? (x:b : u:0) (label "multi-body"))
        (label "multi-fresh"))
     (state
      (Support u:0 u:2)
      ()
      ()
      ()
      (label "state"))))))

(define nested-shadow-source
  (term
   (More
    (Work
     (∃ (x:q)
        (∃ (x:q)
           (x:q =? (sym "inner") (label "inner-body"))
           (label "inner-fresh"))
        (label "outer-fresh"))
     ,empty-state))))

(define left-allocation-source
  (term
   (More
    (Work
     ((∃ (x:left)
         (succeed (label "left-done"))
         (label "left-fresh"))
      ∧
      (succeed (label "right"))
      (label "conjunction"))
     ,empty-state))))

;; Core has no disjunction constructor.  These are the two independently
;; stepped core worlds required to witness the copy premise used by the future
;; disjunction augmentation: both receive the same state and may allocate the
;; same sibling-local atom while retaining the common outer u:0.
(define copied-world-left
  (term
   (More
    (Work
     (∃ (x:left)
        (x:left =? u:0 (label "left-body"))
        (label "left-fresh"))
     ,u0-state))))

(define copied-world-right
  (term
   (More
    (Work
     (∃ (x:right)
        (x:right != u:0 (label "right-body"))
        (label "right-fresh"))
     ,u0-state))))

(define finite-success-source
  (term
   (More
    (Work
     (∃ (x:q)
        (x:q =? (sym "cat") (label "bind"))
        (label "fresh"))
     ,empty-state))))

(define finite-success-target
  (term
   (Last
    (Answer
     (state
      (Support u:0)
      ((u:0 (sym "cat")))
      ()
      ((u:0 =? (sym "cat") (label "bind")))
      (label "state"))))))

(define finite-disequality-source
  (term
   (More
    (Work
     ((nat 0) != (nat 1) (label "apart"))
     ,empty-state))))

(define empty-binder-failure-source
  (term
   (More
    (Work
     (∃ () (fail (label "body-fail")) (label "empty-fresh"))
     ,u0-state))))

(define one-fresh-failure-source
  (term
   (More
    (Work
     (∃ (x:unused)
        (fail (label "body-fail"))
        (label "one-fresh"))
     ,empty-state))))

(define multi-fresh-failure-source
  (term
   (More
    (Work
     (∃ (x:a x:b x:unused)
        (fail (label "body-fail"))
        (label "multi-fresh"))
     (state
      (Support u:7 u:2)
      ()
      ()
      ()
      (label "state"))))))

(define nested-failure-source
  (term
   (More
    (Work
     (∃ (x:used x:unused)
        (((fail (label "fail-left"))
          ∧
          (x:used =? (nat 0) (label "inner-right"))
          (label "inner-conjunction"))
         ∧
         (x:unused != (nat 1) (label "outer-right"))
         (label "outer-conjunction"))
        (label "fresh"))
     ,empty-state))))

(define CORE-E-ORACLE-TESTS
  (test-suite
   "independent state-local core E oracle"

   (test-case
    "exact ownerless grammar and state shape"
    (check-true
     (redex-match?
      core-e-oracle-lang
      σ
      (term (state (Support u:7 u:2) () () () (label "state")))))
    (check-true
     (redex-match?
      core-e-oracle-lang
      F
      (term (More (Conj (Returned ,u0-state) (succeed (label "g")))))))
    (check-true
     (redex-match?
      core-e-oracle-lang
      F
      (term (Last (Answer ,u0-state)))))
    (check-true
     (redex-match?
      core-e-oracle-lang
      F
      (term (More (Dead (Support u:7 u:2))))))
    (check-true
     (redex-match?
      core-e-oracle-lang
      F
      (term (Done (Support u:7 u:2)))))
    (check-false
     (redex-match?
      core-e-oracle-lang
      F
      (term
       (More
        (Work
         (Support u:0)
         (succeed (label "prototype-shape"))
         ,empty-state)))))
    (check-false (redex-match? core-e-oracle-lang F (term (More (Dead)))))
    (check-false (redex-match? core-e-oracle-lang F (term (Done)))))

   (test-case
    "exact thirteen-rule inventory"
    (define actual
      (reduction-relation->rule-names core-e-oracle-red))
    (check-equal? (length actual) 13)
    (check-equal? (length actual) (length (remove-duplicates actual)))
    (check-equal? (sort actual symbol<?)
                  (sort expected-core-rule-names symbol<?)))

   (test-case
    "every direct clause has one raw proof and its exact named successor"
    (for ([representative (in-list rule-representatives)])
      (match-define (list expected-label source expected-target)
        representative)
      (define raw (raw-successors/e source))
      (check-equal? (length raw) 1 (format "raw proof count: ~a" expected-label))
      (check-equal?
       raw
       (list (list expected-label expected-target))
       (format "named successor: ~a" expected-label))
      (check-equal? (step-once/e source) raw)
      (check-true
       (judgment-holds (wf-core-oracle/e? ,source))
       (format "source WF: ~a" expected-label))
      (check-true
       (judgment-holds (wf-core-oracle/e? ,expected-target))
       (format "target WF: ~a" expected-label))))

   (test-case
    "support order, closure, and sparse-name policy"
    (check-true
     (judgment-holds (wf-support-oracle/e? (Support u:8 u:2 u:5))))
    (check-false
     (redex-match?
      core-e-oracle-lang
      support
      (term (Support u:8 u:2 u:8))))
    (check-true
     (judgment-holds
      (wf-state-oracle/e?
       (state
        (Support u:8 u:2)
        ((u:8 u:2))
        ((u:2 (nat 7)))
        ((u:8 =? u:2 (label "bind")))
        (label "sparse")))))
    (check-false
     (judgment-holds
      (wf-state-oracle/e?
       (state
        (Support u:8)
        ((u:8 u:2))
        ()
        ()
        (label "missing-u2")))))
    (check-equal?
     (term (support-prefix?/e (Support u:8 u:2) (Support u:8 u:2 u:1)))
     #t)
    (check-equal?
     (term (support-prefix?/e (Support u:2) (Support u:8 u:2)))
     #f))

   (test-case
    "empty fresh remains an observed allocation transition"
    (check-equal?
     (raw-successors/e empty-fresh-source)
     (list
      (list
       'allocate-fresh
       (term (More (Work (succeed (label "body")) ,u0-state)))))))

   (test-case
    "multi-variable fresh is ordered, least-unused, and preserves unused allocation"
    (check-equal?
     (raw-successors/e multi-fresh-source)
     (list
      (list
       'allocate-fresh
       (term
        (More
         (Work
          (u:1 =? (u:3 : u:0) (label "multi-body"))
          (state
           (Support u:0 u:2 u:1 u:3 u:4)
           ()
           ()
           ()
           (label "state"))))))))
    (check-true (judgment-holds (wf-core-oracle/e? ,multi-fresh-source))))

   (test-case
    "nested fresh shadowing stops outer substitution"
    (match-define
      (list 'allocate-fresh after-outer)
      (only-named-step/e nested-shadow-source))
    (check-equal?
     after-outer
     (term
      (More
       (Work
        (∃ (x:q)
           (x:q =? (sym "inner") (label "inner-body"))
           (label "inner-fresh"))
        (state (Support u:0) () () () (label "state"))))))
    (check-equal?
     (raw-successors/e after-outer)
     (list
      (list
       'allocate-fresh
       (term
        (More
         (Work
          (u:1 =? (sym "inner") (label "inner-body"))
          (state (Support u:0 u:1) () () () (label "state")))))))))

   (test-case
    "left-conjunct allocation is threaded into the right conjunct"
    (define-values (labels terminal)
      (step-until-right/e left-allocation-source))
    (check-equal?
     labels
     '(expand-conjunction allocate-fresh succeed conj-return))
    (check-equal?
     terminal
     (term (More (Work (succeed (label "right")) ,u0-state))))
    (check-true (judgment-holds (wf-core-oracle/e? ,terminal))))

   (test-case
    "copied sibling worlds independently reuse one atom and retain outer support"
    (match-define
      (list 'allocate-fresh left-target)
      (only-named-step/e copied-world-left))
    (match-define
      (list 'allocate-fresh right-target)
      (only-named-step/e copied-world-right))
    (check-equal?
     left-target
     (term
      (More
       (Work
        (u:1 =? u:0 (label "left-body"))
        ,u0-u1-state))))
    (check-equal?
     right-target
     (term
      (More
       (Work
        (u:1 != u:0 (label "right-body"))
        ,u0-u1-state))))
    (check-true (judgment-holds (wf-core-oracle/e? ,left-target)))
    (check-true (judgment-holds (wf-core-oracle/e? ,right-target))))

   (test-case
    "success substitution trail and terminal answer"
    (define-values (labels terminal) (trace/e finite-success-source))
    (check-equal? labels '(allocate-fresh unify-success finish-success))
    (check-equal? terminal finite-success-target)
    (check-true (judgment-holds (wf-core-oracle/e? ,terminal)))
    (check-equal? (step-once/e terminal) '()))

   (test-case
    "disequality and direct failure reach their supply-carrying terminals"
    (define-values (disequality-labels disequality-terminal)
      (trace/e finite-disequality-source))
    (check-equal?
     disequality-labels
     '(disequality-success finish-success))
    (check-equal?
     disequality-terminal
     (term
      (Last
       (Answer
        (state
         (Support)
         ()
         (((nat 0) (nat 1)))
         ()
         (label "state"))))))
    (define-values (failure-labels failure-terminal)
      (trace/e
       (term
        (More
         (Work (fail (label "fail")) ,empty-state)))))
    (check-equal?
     (raw-successors/e
      (term (More (Work (fail (label "fail")) ,empty-state))))
     (list (list 'fail (term (More (Dead (Support)))))))
    (check-equal? failure-labels '(fail finish-failure))
    (check-equal? failure-terminal (term (Done (Support))))
    (check-true (judgment-holds (wf-core-oracle/e? ,failure-terminal))))

   (test-case
    "fresh followed by failure retains empty, singleton, multiple, and unused allocations"
    (for ([witness
           (in-list
            (list
             (list
              'empty-binder
              empty-binder-failure-source
              '(allocate-fresh fail finish-failure)
              (term (Done (Support u:0))))
             (list
              'one-variable
              one-fresh-failure-source
              '(allocate-fresh fail finish-failure)
              (term (Done (Support u:0))))
             (list
              'multiple-with-unused
              multi-fresh-failure-source
              '(allocate-fresh fail finish-failure)
              (term (Done (Support u:7 u:2 u:0 u:1 u:3))))))])
      (match-define (list description source expected-labels expected-terminal)
        witness)
      (define-values (labels terminal) (trace/e source))
      (check-equal? labels expected-labels (format "labels: ~a" description))
      (check-equal?
       terminal
       expected-terminal
       (format "terminal support: ~a" description))
      (check-true
       (judgment-holds (wf-core-oracle/e? ,terminal))
       (format "terminal WF: ~a" description))))

   (test-case
    "sparse failed support remains ordered and is exposed without predecessor history"
    (define sparse-support (term (Support u:7 u:2)))
    (define sparse-dead (term (More (Dead ,sparse-support))))
    (define sparse-done (term (Done ,sparse-support)))
    (check-equal?
     (raw-successors/e
      (term
       (More
        (Work
         (fail (label "sparse-fail"))
         (state ,sparse-support () () () (label "state"))))))
     (list (list 'fail sparse-dead)))
    (check-equal?
     (judgment-holds
      (live-support-oracle/e? (Dead ,sparse-support) support)
      support)
     (list sparse-support))
    (check-equal?
     (raw-successors/e sparse-dead)
     (list (list 'finish-failure sparse-done)))
    (check-true (judgment-holds (wf-core-oracle/e? ,sparse-dead)))
    (check-true (judgment-holds (wf-core-oracle/e? ,sparse-done))))

   (test-case
    "dead conjunction checks its pending goal against stored support"
    (define supported-conjunction
      (term
       (More
        (Conj
         (Dead (Support u:7 u:2))
         (u:2 =? (nat 91) (label "pending"))))))
    (define unsupported-conjunction
      (term
       (More
        (Conj
         (Dead (Support u:7 u:2))
         (u:9 =? (nat 91) (label "pending"))))))
    (check-true (judgment-holds (wf-core-oracle/e? ,supported-conjunction)))
    (check-false (judgment-holds (wf-core-oracle/e? ,unsupported-conjunction)))
    (check-equal?
     (judgment-holds
      (live-support-oracle/e?
       (Conj
        (Dead (Support u:7 u:2))
        (u:2 =? (nat 91) (label "pending")))
       support)
      support)
     (list (term (Support u:7 u:2))))
    (check-equal?
     (raw-successors/e supported-conjunction)
     (list
      (list
       'conj-fail
       (term (More (Dead (Support u:7 u:2))))))))

   (test-case
    "nested conjunction failure propagates one support through every phase"
    (define-values (labels terminal) (trace/e nested-failure-source))
    (check-equal?
     labels
     '(allocate-fresh
       expand-conjunction
       expand-conjunction
       fail
       conj-fail
       conj-fail
       finish-failure))
    (check-equal? terminal (term (Done (Support u:0 u:1))))
    (check-true (judgment-holds (wf-core-oracle/e? ,terminal)))
    (match-define
      (list 'allocate-fresh after-allocation)
      (only-named-step/e nested-failure-source))
    (match-define
      (list 'expand-conjunction after-outer-expansion)
      (only-named-step/e after-allocation))
    (match-define
      (list 'expand-conjunction after-inner-expansion)
      (only-named-step/e after-outer-expansion))
    (match-define
      (list 'fail after-fail)
      (only-named-step/e after-inner-expansion))
    (check-equal?
     after-fail
     (term
      (More
       (Conj
        (Conj
         (Dead (Support u:0 u:1))
         (u:0 =? (nat 0) (label "inner-right")))
        (u:1 != (nat 1) (label "outer-right"))))))
    (match-define
      (list 'conj-fail after-inner-failure)
      (only-named-step/e after-fail))
    (check-equal?
     after-inner-failure
     (term
      (More
       (Conj
        (Dead (Support u:0 u:1))
        (u:1 != (nat 1) (label "outer-right"))))))
    (check-equal?
     (only-named-step/e after-inner-failure)
     (list 'conj-fail (term (More (Dead (Support u:0 u:1)))))))

   (test-case
    "Dead and Done reject duplicate support"
    (check-false
     (redex-match?
      core-e-oracle-lang
      F
      (term (More (Dead (Support u:0 u:0))))))
    (check-false
     (redex-match?
      core-e-oracle-lang
      F
      (term (Done (Support u:0 u:0))))))))

(module+ test
  (run-tests CORE-E-ORACLE-TESTS))
