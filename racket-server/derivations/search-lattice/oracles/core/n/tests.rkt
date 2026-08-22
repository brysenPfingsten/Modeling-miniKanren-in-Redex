#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "./language.rkt"
         "./source.rkt"
         "./wf.rkt")

(provide CORE-N-ORACLE-TESTS)

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

(define STATE-0
  (term (state 0 () () () (label "state-0"))))

(define STATE-1
  (term (state 1 () () () (label "state-1"))))

(define STATE-3
  (term (state 3 () () () (label "state-3"))))

(define RULE-WITNESSES
  (list
   (list
    'expand-conjunction
    (term
     (More
      (Work
       ((succeed (label "left"))
        ∧
        (fail (label "right"))
        (label "and"))
       ,STATE-0)))
    (term
     (More
      (Conj
       (Work (succeed (label "left")) ,STATE-0)
       (fail (label "right"))))))
   (list
    'succeed
    (term (More (Work (succeed (label "yes")) ,STATE-1)))
   (term (More (Returned ,STATE-1))))
   (list
    'fail
    (term (More (Work (fail (label "no")) ,STATE-1)))
    (term (More (Dead 1))))
   (list
    'conj-return
    (term
     (More
      (Conj
       (Returned ,STATE-3)
       (2 =? (nat 2) (label "continue")))))
    (term
     (More
      (Work
       (2 =? (nat 2) (label "continue"))
       ,STATE-3))))
   (list
    'conj-fail
    (term
     (More
      (Conj (Dead 3) (succeed (label "unreachable")))))
    (term (More (Dead 3))))
   (list
    'allocate-fresh
    (term
     (More
      (Work
       (∃ (x:a x:b)
          ((x:a =? 0 (label "first"))
           ∧
           (x:b != (nat 7) (label "second"))
           (label "body"))
          (label "allocate-two"))
       ,STATE-1)))
    (term
     (More
      (Work
       ((1 =? 0 (label "first"))
        ∧
        (2 != (nat 7) (label "second"))
        (label "body"))
       (state 3 () () () (label "state-1"))))))
   (list
    'unify-success
    (term
     (More
      (Work
       (0 =? (nat 7) (label "bind"))
       ,STATE-1)))
    (term
     (More
      (Returned
       (state 1
              ((0 (nat 7)))
              ()
              ((0 =? (nat 7) (label "bind")))
              (label "state-1"))))))
   (list
    'unify-violates-disequality
    (term
     (More
      (Work
       (0 =? (nat 7) (label "violate"))
       (state 1
              ()
              ((0 (nat 7)))
              ()
              (label "disequality-state")))))
    (term (More (Dead 1))))
   (list
    'unify-fail
    (term
     (More
      (Work
       ((nat 0) =? (nat 1) (label "different-data"))
       ,STATE-0)))
    (term (More (Dead 0))))
   (list
    'disequality-success
    (term
     (More
      (Work
       ((nat 0) != (nat 1) (label "different-data"))
       ,STATE-0)))
    (term
     (More
      (Returned
       (state 0
              ()
              (((nat 0) (nat 1)))
              ()
              (label "state-0"))))))
   (list
    'disequality-fail
    (term
     (More
      (Work
       ((nat 0) != (nat 0) (label "same-data"))
       ,STATE-0)))
    (term (More (Dead 0))))
   (list
    'finish-success
    (term (More (Returned ,STATE-1)))
    (term (Last (Answer ,STATE-1))))
   (list
    'finish-failure
    (term (More (Dead 3)))
    (term (Done 3)))))

(define (wf? configuration)
  (judgment-holds (wf-core-oracle/n? ,configuration)))

(define (trace/n frontier [fuel 32] [reversed-labels '()])
  (when (zero? fuel)
    (error 'trace/n "numeric core trace exceeded its test bound"))
  (match (step-once/n frontier)
    ['() (values (reverse reversed-labels) frontier)]
    [(list (list label target))
     (trace/n target (sub1 fuel) (cons label reversed-labels))]))

(define/provide-test-suite CORE-N-ORACLE-TESTS
  (test-case "N is direct, ownerless, and distinguishes levels from numeric data"
    (check-true
     (redex-match?
      core-n-oracle-lang
      F
      (term
       (More
        (Work
         (0 =? (nat 0) (label "distinct"))
         (state 1 () () () (label "state")))))))
    (check-false
     (redex-match?
      core-n-oracle-lang
      F
      (term
       (More
        (Work
         (0 =? (nat 0) (label "ownerful"))
         (Owners)
         (state 1 () () () (label "state")))))))
    (check-false (redex-match? core-n-oracle-lang lv (term (nat 0))))
    (check-false (redex-match? core-n-oracle-lang lv (term -1)))
    (check-true (redex-match? core-n-oracle-lang pt (term (nat -1)))))

  (test-case "the direct N relation has exactly the thirteen core labels"
    (define actual
      (map (lambda (name) (string->symbol (~a name)))
           (reduction-relation->rule-names core-n-oracle-red)))
    (check-equal? (length actual) 13)
    (check-equal? (length actual) (length (remove-duplicates actual)))
    (check-equal? (sort actual symbol<?) CORE-RULE-NAMES))

  (test-case "every core label has one exact raw proof and a WF successor"
    (for ([witness (in-list RULE-WITNESSES)])
      (match-define (list expected-label source target) witness)
      (check-true (wf? source) (format "source WF for ~a" expected-label))
      (check-true (wf? target) (format "target WF for ~a" expected-label))
      (check-equal?
       (raw-successors/n source)
       (list (list expected-label target))
       (format "raw named proof for ~a" expected-label))
      (check-equal?
       (step-once/n source)
       (list (list expected-label target))
       (format "deterministic named successor for ~a" expected-label))))

  (test-case "fresh empty, singleton-unused, and multi allocate exact intervals"
    (define empty-source
      (term
       (More
        (Work
         (∃ () (succeed (label "body")) (label "empty"))
         ,STATE-3))))
    (define empty-target
      (term
       (More
        (Work (succeed (label "body")) ,STATE-3))))
    (check-equal?
     (raw-successors/n empty-source)
     (list (list 'allocate-fresh empty-target)))

    (define unused-source
      (term
       (More
        (Work
         (∃ (x:unused)
            (succeed (label "body"))
            (label "unused"))
         ,STATE-3))))
    (define unused-target
      (term
       (More
        (Work
         (succeed (label "body"))
         (state 4 () () () (label "state-3"))))))
    (check-equal?
     (raw-successors/n unused-source)
     (list (list 'allocate-fresh unused-target)))
    (check-true (wf? unused-target))

    (check-equal? (term (allocate-interval/n 7 (x:a x:b x:c)))
                  '(7 8 9))
    (check-equal? (term (advance-next/n 7 (x:a x:b x:c))) 10))

  (test-case "failure retains next after empty, singleton, multi, and unused fresh"
    (define cases
      (list
       (list
        'empty
        (term
         (More
          (Work
           (∃ () (fail (label "empty-fail")) (label "empty"))
           ,STATE-3)))
        '(allocate-fresh fail finish-failure)
        (term (Done 3)))
       (list
        'singleton
        (term
         (More
          (Work
           (∃ (x:q)
              ((x:q =? x:q (label "use-one"))
               ∧
               (fail (label "singleton-fail"))
               (label "singleton-body"))
              (label "singleton"))
           ,STATE-3)))
        '(allocate-fresh
          expand-conjunction
          unify-success
          conj-return
          fail
          finish-failure)
        (term (Done 4)))
       (list
        'multi
        (term
         (More
          (Work
           (∃ (x:a x:b)
              ((x:a =? x:b (label "use-two"))
               ∧
               (fail (label "multi-fail"))
               (label "multi-body"))
              (label "multi"))
           ,STATE-3)))
        '(allocate-fresh
          expand-conjunction
          unify-success
          conj-return
          fail
          finish-failure)
        (term (Done 5)))
       (list
        'unused
        (term
         (More
          (Work
           (∃ (x:used x:unused)
              ((x:used =? (nat 7) (label "use-first"))
               ∧
               (fail (label "unused-fail"))
               (label "unused-body"))
              (label "unused"))
           ,STATE-3)))
        '(allocate-fresh
          expand-conjunction
          unify-success
          conj-return
          fail
          finish-failure)
        (term (Done 5)))))
    (for ([case (in-list cases)])
      (match-define (list name source expected-labels expected-terminal) case)
      (check-true (wf? source) (format "source WF for ~a fresh" name))
      (define-values (labels terminal) (trace/n source))
      (check-equal? labels expected-labels
                    (format "labels for ~a fresh" name))
      (check-equal? terminal expected-terminal
                    (format "terminal next for ~a fresh" name))
      (check-true (wf? terminal)
                  (format "terminal WF for ~a fresh" name))))

  (test-case "direct and nested failure preserve next through root Done"
    (define direct-source
      (term
       (More
        (Work (fail (label "direct")) ,STATE-0))))
    (define-values (direct-labels direct-terminal) (trace/n direct-source))
    (check-equal? direct-labels '(fail finish-failure))
    (check-equal? direct-terminal (term (Done 0)))

    (define nested-source
      (term
       (More
        (Work
         (∃ (x:a x:b)
            (((fail (label "nested-fail"))
              ∧
              (x:b =? (nat 1) (label "inner-pending"))
              (label "inner-and"))
             ∧
             (x:a != (nat 2) (label "outer-pending"))
             (label "outer-and"))
            (label "allocate-two"))
         ,STATE-0))))
    (define nested-dead
      (term
       (More
        (Conj
         (Conj
          (Dead 2)
          (1 =? (nat 1) (label "inner-pending")))
         (0 != (nat 2) (label "outer-pending"))))))
    (define inner-propagated
      (term
       (More
        (Conj
         (Dead 2)
         (0 != (nat 2) (label "outer-pending"))))))
    (define root-dead (term (More (Dead 2))))
    (check-true (wf? nested-source))
    (check-true (wf? nested-dead))
    (check-equal?
     (raw-successors/n nested-dead)
     (list (list 'conj-fail inner-propagated)))
    (check-equal?
     (raw-successors/n inner-propagated)
     (list (list 'conj-fail root-dead)))
    (check-equal?
     (raw-successors/n root-dead)
     (list (list 'finish-failure (term (Done 2)))))
    (define-values (nested-labels nested-terminal) (trace/n nested-source))
    (check-equal?
     nested-labels
     '(allocate-fresh
       expand-conjunction
       expand-conjunction
       fail
       conj-fail
       conj-fail
       finish-failure))
    (check-equal? nested-terminal (term (Done 2)))
    (check-true (wf? nested-terminal)))

  (test-case "fresh substitution preserves mixed terms and lexical shadowing"
    (define source
      (term
       (More
        (Work
         (∃ (x:q)
            ((x:q =? 0 (label "outer-use"))
             ∧
             (∃ (x:q)
                ((x:q =? 0 (label "shadowed-use"))
                 ∧
                 (succeed (label "nested-success"))
                 (label "nested-and"))
                (label "shadow"))
             (label "outer-and"))
            (label "outer"))
         ,STATE-1))))
    (define target
      (term
       (More
        (Work
         ((1 =? 0 (label "outer-use"))
          ∧
          (∃ (x:q)
             ((x:q =? 0 (label "shadowed-use"))
              ∧
              (succeed (label "nested-success"))
              (label "nested-and"))
             (label "shadow"))
          (label "outer-and"))
         (state 2 () () () (label "state-1"))))))
    (check-equal?
     (term
      (subst-goal/n
       (x:inner =? (x:outer : 0) (label "mixed-boundaries"))
       ((x:inner 2))))
     (term
      (2 =? (x:outer : 0) (label "mixed-boundaries"))))
    (check-true (wf? source))
    (check-true (wf? target))
    (check-equal?
     (raw-successors/n source)
     (list (list 'allocate-fresh target))))

  (test-case "conjunction threads the returned next into right allocation"
    (define source
      (term
       (More
        (Work
         ((∃ (x:left)
             (succeed (label "left-success"))
             (label "left-fresh"))
          ∧
          (∃ (x:right)
             (x:right =? (nat 9) (label "right-bind"))
             (label "right-fresh"))
          (label "and"))
         ,STATE-0))))
    (define-values (labels terminal) (trace/n source))
    (check-equal?
     labels
     '(expand-conjunction
       allocate-fresh
       succeed
       conj-return
       allocate-fresh
       unify-success
       finish-success))
    (check-equal?
     terminal
     (term
      (Last
       (Answer
        (state 2
               ((1 (nat 9)))
               ()
               ((1 =? (nat 9) (label "right-bind")))
               (label "state-0"))))))
    (check-true (wf? terminal)))

  (test-case "copied sibling states independently reuse the same next level"
    ;; Core has no disjunction rule.  These are two independent core runs from
    ;; copies of the same possible-world state, the exact branch-copy witness
    ;; available before the disjunction augmentation exists.
    (define sibling-source
      (term
       (More
        (Work
         (∃ (x:new)
            (x:new != 0 (label "new-vs-shared"))
            (label "sibling-fresh"))
         (state 1 () () () (label "copied-state"))))))
    (define expected
      (term
       (More
        (Work
         (1 != 0 (label "new-vs-shared"))
         (state 2 () () () (label "copied-state"))))))
    (define left-run (raw-successors/n sibling-source))
    (define right-run (raw-successors/n sibling-source))
    (check-equal? left-run (list (list 'allocate-fresh expected)))
    (check-equal? right-run left-run)
    ;; The shared outer 0 remains 0; each sibling independently chooses 1.
    (check-true (wf? sibling-source))
    (check-true (wf? expected)))

  (test-case "WF bounds every runtime level in live goals and state stores"
    (define dead-continuation
      (term
       (Conj
        (Dead 3)
        (2 =? (nat 99) (label "allocated-pending")))))
    (define nested-dead-continuation
      (term
       (Conj
        ,dead-continuation
        (1 != (nat 99) (label "nested-pending")))))
    (define unallocated-dead-continuation
      (term
       (Conj
        (Dead 3)
        (3 =? (nat 99) (label "unallocated-pending")))))
    (check-true
     (wf?
      (term
       (More
        (Work
         ((nat -4) =? (nat -4) (label "data"))
         ,STATE-0)))))
    (check-false
     (wf?
      (term
       (More
        (Work
         (1 =? (nat 1) (label "not-yet-allocated"))
         ,STATE-1)))))
    (check-false
     (wf?
      (term
       (Last
        (Answer
         (state 1
                ((1 (nat 7)))
                ()
                ((1 =? (nat 7) (label "bad")))
                (label "bad-state")))))))
    (check-equal?
     (judgment-holds
      (live-next-oracle/n? ,dead-continuation next)
      next)
     '(3))
    (check-equal?
     (judgment-holds
      (live-next-oracle/n? ,nested-dead-continuation next)
      next)
     '(3))
    (check-true (wf? (term (More ,dead-continuation))))
    (check-true (wf? (term (More ,nested-dead-continuation))))
    (check-false (wf? (term (More ,unallocated-dead-continuation))))
    (check-true (wf? (term (More (Dead 0)))))
    (check-true (wf? (term (Done 0))))
    (check-false (redex-match? core-n-oracle-lang F (term (More (Dead -1)))))
    (check-false (redex-match? core-n-oracle-lang F (term (Done -1)))))

  (test-case "success, failure, stores, and terminals all occur in finite runs"
    (define success-source
      (term
       (More
        (Work
         ((∃ (x:q)
             (x:q =? (sym "cat") (label "bind"))
             (label "fresh"))
          ∧
          (0 != (sym "dog") (label "exclude"))
          (label "and"))
         ,STATE-0))))
    (define-values (success-labels success-terminal)
      (trace/n success-source))
    (check-equal?
     success-labels
     '(expand-conjunction
       allocate-fresh
       unify-success
       conj-return
       disequality-success
       finish-success))
    (check-match success-terminal `(Last (Answer (state 1 ,_ ,_ ,_ ,_))))
    (check-true (wf? success-terminal))

    (define-values (failure-labels failure-terminal)
      (trace/n
       (term
        (More
         (Work
          ((nat 1) =? (nat 2) (label "fail"))
          ,STATE-0)))))
    (check-equal? failure-labels '(unify-fail finish-failure))
    (check-equal? failure-terminal (term (Done 0)))
    (check-true (wf? failure-terminal))))

(module+ test
  (run-tests CORE-N-ORACLE-TESTS))
