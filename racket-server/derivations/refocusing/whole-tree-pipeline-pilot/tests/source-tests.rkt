#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../corpus.rkt"
         "../language.rkt"
         "../source.rkt"
         (prefix-in oracle:
                    "../../whole-tree-spike/main.rkt"))

(provide source-tests)

(define (trace tree)
  (define-values (steps final status trees)
    (source-trace tree))
  (values steps final status trees))

(define oracle-system
  (oracle:make-semantics 'search #:hoist 'late #:scheduler 'rail))

(define (normalize-oracle-steps steps)
  (for/list ([step (in-list steps)])
    (match step
      [(list (or "distribute-fresh-over-choice"
                 "distribute-fresh-over-right-choice")
             owner)
       (list "expose-choice-through-work-fresh" owner)]
      [_ step])))

(define outer-tag
  '(label "outer-fresh"))
(define branch-tag
  '(label "branch-fresh"))
(define inner-split-tag
  '(label "inner-split"))
(define outer-split-tag
  '(label "outer-split"))
(define unit-state
  '(state unit))
(define inner-state
  '(state (u:0 : u:1)))
(define outer-state
  '(state u:0))

(define inner-left-goal/x
  '(put (u:0 : x:inner) (label "inner-left")))
(define inner-right-goal/x
  '(put (u:0 : x:inner) (label "inner-right")))
(define inner-left-goal/u
  '(put (u:0 : u:1) (label "inner-left")))
(define inner-right-goal/u
  '(put (u:0 : u:1) (label "inner-right")))
(define outer-right-goal
  '(put u:0 (label "outer-right")))

(define inner-choice/x
  `(disj ,inner-left-goal/x ,inner-right-goal/x ,inner-split-tag))
(define inner-choice/u
  `(disj ,inner-left-goal/u ,inner-right-goal/u ,inner-split-tag))
(define branch-fresh/x
  `(fresh (x:inner) ,inner-choice/x ,branch-tag))
(define outer-choice-after-allocation
  `(disj ,branch-fresh/x ,outer-right-goal ,outer-split-tag))

(define inner-left-work
  `(Work ,inner-left-goal/u ,unit-state))
(define inner-right-work
  `(Work ,inner-right-goal/u ,unit-state))
(define outer-right-work
  `(Work ,outer-right-goal ,unit-state))

(define (under-outer-scope frontier)
  `(FrontierFresh (u:0) ,frontier ,outer-tag))

(define branch-work/allocated
  `(WorkFresh
    (u:1)
    (Work ,inner-choice/u ,unit-state)
    ,branch-tag))

(define branch-work/expanded
  `(WorkFresh
    (u:1)
    (DisjL ,inner-left-work ,inner-right-work)
    ,branch-tag))

(define branch-work/left-returned
  `(WorkFresh
    (u:1)
    (DisjL (Returned ,inner-state) ,inner-right-work)
    ,branch-tag))

(define scoped-left-returned
  `(WorkFresh (u:1) (Returned ,inner-state) ,branch-tag))
(define scoped-right-work
  `(WorkFresh (u:1) ,inner-right-work ,branch-tag))
(define scoped-right-returned
  `(WorkFresh (u:1) (Returned ,inner-state) ,branch-tag))
(define inner-answer
  `(AnswerFresh (u:1) (Answer ,inner-state) ,branch-tag))

(define golden-nested-steps
  '(("allocate-fresh" core)
    ("expose-frontier-fresh" core)
    ("expand-disjunction" disj)
    ("allocate-fresh" core)
    ("expand-disjunction" disj)
    ("work-put" core)
    ("expose-choice-through-work-fresh" disj)
    ("reassociate-left-result" disj)
    ("commit-choice-answer" disj)
    ("work-put" core)
    ("commit-choice-answer" disj)
    ("work-put" core)
    ("finish-success" core)))

(define golden-nested-trees
  (list
   nested-scope-witness-tree
   `(More
     (WorkFresh
      (u:0)
      (Work ,outer-choice-after-allocation ,unit-state)
      ,outer-tag))
   (under-outer-scope
    `(More (Work ,outer-choice-after-allocation ,unit-state)))
   (under-outer-scope
    `(More
      (DisjL (Work ,branch-fresh/x ,unit-state)
             ,outer-right-work)))
   (under-outer-scope
    `(More (DisjL ,branch-work/allocated ,outer-right-work)))
   (under-outer-scope
    `(More (DisjL ,branch-work/expanded ,outer-right-work)))
   (under-outer-scope
    `(More (DisjL ,branch-work/left-returned ,outer-right-work)))
   (under-outer-scope
    `(More
      (DisjL
       (DisjL ,scoped-left-returned ,scoped-right-work)
       ,outer-right-work)))
   (under-outer-scope
    `(More
      (DisjL ,scoped-left-returned
             (DisjL ,scoped-right-work ,outer-right-work))))
   (under-outer-scope
    `(Emit
      ,inner-answer
      (More (DisjL ,scoped-right-work ,outer-right-work))))
   (under-outer-scope
    `(Emit
      ,inner-answer
      (More (DisjL ,scoped-right-returned ,outer-right-work))))
   (under-outer-scope
    `(Emit
      ,inner-answer
      (Emit ,inner-answer (More ,outer-right-work))))
   (under-outer-scope
    `(Emit
      ,inner-answer
      (Emit ,inner-answer (More (Returned ,outer-state)))))
   (under-outer-scope
    `(Emit
      ,inner-answer
      (Emit ,inner-answer (Last (Answer ,outer-state)))))))

(define left-suspend-work
  '(Work
    (suspend (put (sym "left") (label "left"))
             (label "left-delay"))
    (state unit)))
(define right-suspend-work
  '(Work
    (suspend (put (sym "right") (label "right"))
             (label "right-delay"))
    (state unit)))
(define left-work
  '(Work (put (sym "left") (label "left")) (state unit)))
(define right-work
  '(Work (put (sym "right") (label "right")) (state unit)))
(define left-returned
  '(Returned (state (sym "left"))))
(define right-returned
  '(Returned (state (sym "right"))))
(define left-answer
  '(Answer (state (sym "left"))))
(define right-answer
  '(Answer (state (sym "right"))))

(define (forced tree)
  `(Forced ,tree))

(define (twice-forced tree)
  (forced (forced tree)))

(define golden-rail-steps
  '(("expand-disjunction" disj)
    ("suspend-goal" delay)
    ("rail-enter-right" search-join)
    ("force-delay" delay)
    ("suspend-goal" delay)
    ("rail-return-left" search-join)
    ("force-delay" delay)
    ("work-put" core)
    ("commit-choice-answer" disj)
    ("work-put" core)
    ("finish-success" core)))

(define golden-rail-trees
  (list
   rail-turn-witness-tree
   `(More (DisjL ,left-suspend-work ,right-suspend-work))
   `(More
     (DisjL (PendingDelay ,left-work) ,right-suspend-work))
   `(More
     (PendingDelay (DisjR ,left-work ,right-suspend-work)))
   (forced `(More (DisjR ,left-work ,right-suspend-work)))
   (forced
    `(More (DisjR ,left-work (PendingDelay ,right-work))))
   (forced
    `(More (PendingDelay (DisjL ,left-work ,right-work))))
   (twice-forced `(More (DisjL ,left-work ,right-work)))
   (twice-forced `(More (DisjL ,left-returned ,right-work)))
   (twice-forced `(Emit ,left-answer (More ,right-work)))
   (twice-forced `(Emit ,left-answer (More ,right-returned)))
   (twice-forced `(Emit ,left-answer (Last ,right-answer)))))

(define source-tests
  (test-suite
   "whole-tree pipeline pilot: frozen source"

   (test-case
    "the source grammar has implicit W/F sorts and no relcall overlay"
    (check-true (goal-in-language? nested-scope-witness-goal))
    (check-true (frontier-in-language? nested-scope-witness-tree))
    (check-true
     (work-in-language?
      '(WorkFresh (u:0)
                  (DisjL (Returned (state u:0))
                         (PendingDelay
                          (Work (succeed (label "ok")) (state u:0))))
                  (label "fresh"))))
    (check-false
     (goal-in-language? '(relcall (sym "p") (label "call"))))
    (check-false
     (frontier-in-language?
      '(More (Emit (Answer (state unit)) Done))))
    (check-false
     (answer-in-language?
      '(Answer (More (Returned (state unit)))))))

   (test-case
    "nested scopes follow the exact frozen golden trace"
    (define-values (steps final status trees)
      (trace nested-scope-witness-tree))
    (check-equal? status 'value)
    (check-equal? steps golden-nested-steps)
    (check-equal? trees golden-nested-trees)
    (check-equal? final (last golden-nested-trees)))

   (test-case
    "the outer marker owns all work while the inner marker stops before W2"
    (define-values (steps final status trees)
      (trace nested-scope-witness-tree))
    (check-equal? status 'value)
    (check-equal?
     (count (lambda (step)
              (equal? step '("allocate-fresh" core)))
            steps)
     2)
    ;; Once u:0 reaches the frontier it encloses every later source state.
    (for ([tree (in-list (drop trees 2))])
      (check-match tree
                   `(FrontierFresh (u:0) ,_frontier
                                   (label "outer-fresh"))))
    ;; Immediately before exposure, u:1 is factored around the inner choice.
    (check-equal? (list-ref trees 6)
                  (list-ref golden-nested-trees 6))
    ;; The one named exposure copies the identical u:1/tag onto S and W. W2 is
    ;; still the sibling outside both copies.
    (check-match
     (list-ref trees 7)
     `(FrontierFresh
       (u:0)
       (More
        (DisjL
         (DisjL
          (WorkFresh (u:1) ,_settled (label "branch-fresh"))
          (WorkFresh (u:1) ,_inner-rest (label "branch-fresh")))
         (Work (put u:0 (label "outer-right")) (state unit))))
       (label "outer-fresh")))
    (check-equal?
     (count (lambda (step)
              (equal? (first step)
                      "expose-choice-through-work-fresh"))
            steps)
     1)
    (check-equal?
     (scoped-answers final)
     (list
      (scoped-answer
       inner-state
       (list (scope-owner '(u:0) outer-tag)
             (scope-owner '(u:1) branch-tag)))
      (scoped-answer
       inner-state
       (list (scope-owner '(u:0) outer-tag)
             (scope-owner '(u:1) branch-tag)))
      (scoped-answer
       outer-state
       (list (scope-owner '(u:0) outer-tag))))))

   (test-case
    "expose-choice-through-work-fresh is not a general scope equation"
    (define before-settlement
      '(More
        (DisjL
         (WorkFresh
          (u:0)
          (DisjL
           (Work (put u:0 (label "left")) (state unit))
           (Work (put u:0 (label "right")) (state unit)))
          (label "fresh"))
         (Work (put (sym "outside") (label "outside")) (state unit)))))
    (define first-step
      (source-step before-settlement))
    (check-equal? (transition-name first-step) "work-put")
    (define second-step
      (source-step (transition-next first-step)))
    (check-equal? (transition-name second-step)
                  "expose-choice-through-work-fresh"))

   (test-case
    "rail scheduling follows the exact two-turn golden trace"
    (define-values (steps final status trees)
      (trace rail-turn-witness-tree))
    (check-equal? status 'value)
    (check-equal? steps golden-rail-steps)
    (check-equal? trees golden-rail-trees)
    (check-equal? (frontier-events final)
                  `(forced
                    forced
                    (emit ,left-answer)
                    (last ,right-answer)))
    (check-equal? (extensional-answers final)
                  '((state (sym "left"))
                    (state (sym "right")))))

   (test-case
    "the right-active fresh exposure retains identity and provenance"
    (define-values (steps final status trees)
      (trace right-active-fresh-witness-tree))
    (check-equal? status 'value)
    (check-equal?
     steps
     '(("expand-conjunction" core)
       ("expand-conjunction" core)
       ("allocate-fresh" core)
       ("work-put" core)
       ("conj-return" core)
       ("expand-disjunction" disj)
       ("suspend-goal" delay)
       ("rail-enter-right" search-join)
       ("bubble-delay-through-fresh" delay)
       ("bubble-delay-through-conj" delay)
       ("force-delay" delay)
       ("work-put" core)
       ("expose-choice-through-work-fresh" search-join)
       ("late-distribute-right-settled" search-join)
       ("work-succeed" core)
       ("commit-right-choice-answer" search-join)
       ("work-put" core)
       ("conj-return" core)
       ("expose-frontier-fresh" core)
       ("work-succeed" core)
       ("finish-success" core)))
    (check-match
     (list-ref trees 12)
     `(Forced
       (More
        (Conj
         (WorkFresh
          (u:0)
          (DisjR ,_alternate (Returned (state (sym "now"))))
          (label "fresh"))
         (succeed (label "continue"))))))
    (check-match
     (list-ref trees 13)
     `(Forced
       (More
        (Conj
         (DisjR
          (WorkFresh (u:0) ,_alternate (label "fresh"))
          (WorkFresh (u:0)
                     (Returned (state (sym "now")))
                     (label "fresh")))
         (succeed (label "continue"))))))
    (check-equal?
     (scoped-answers final)
     (list
      (scoped-answer
       '(state (sym "now"))
       (list (scope-owner '(u:0) '(label "fresh"))))
      (scoped-answer
       '(state (sym "later"))
       (list (scope-owner '(u:0) '(label "fresh")))))))

   (test-case
    "late hoisting remains an explicit source transition"
    (define-values (steps final status _trees)
      (trace late-hoist-witness-tree))
    (check-equal? status 'value)
    (check-equal?
     steps
     '(("expand-conjunction" core)
       ("expand-disjunction" disj)
       ("work-put" core)
       ("late-distribute-settled" disj)
       ("work-succeed" core)
       ("commit-choice-answer" disj)
       ("work-put" core)
       ("conj-return" core)
       ("work-succeed" core)
       ("finish-success" core)))
    (check-false
     (for/or ([step (in-list steps)])
       (regexp-match? #rx"early" (first step))))
    (check-equal? final
                  `(Emit ,left-answer (Last ,right-answer))))

   (test-case
    "the frozen source conforms one way to the selected spike oracle"
    (for ([tree (in-list (list nested-scope-witness-tree
                               late-hoist-witness-tree
                               rail-turn-witness-tree
                               right-active-fresh-witness-tree))])
      (define-values (pilot-steps pilot-final pilot-status pilot-trees)
        (source-trace tree))
      (define-values (oracle-steps oracle-final oracle-status oracle-trees)
        (oracle:source-trace oracle-system tree))
      ;; The new name freezes the selected operational interpretation.  No
      ;; source term is normalized or quotiented for this comparison.
      (check-equal? pilot-steps (normalize-oracle-steps oracle-steps))
      (check-equal? pilot-trees oracle-trees)
      (check-equal? pilot-final oracle-final)
      (check-equal? pilot-status oracle-status)))

   (test-case
    "the exported Redex relation is the same directed source step"
    (define expected
      (transition-next (source-step nested-scope-witness-tree)))
    (check-equal? (apply-reduction-relation source-red
                                            nested-scope-witness-tree)
                  (list expected)))))

(module+ test
  (run-tests source-tests))
