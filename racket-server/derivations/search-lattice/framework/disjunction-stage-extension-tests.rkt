#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "./disjunction-stage-extension-fixture.rkt"
         (submod "./disjunction-stage-extension-fixture.rkt" diagnostics))

(provide DISJUNCTION-STAGE-EXTENSION-TESTS)

(define SIGMA
  (term
   (state
    2
    ((0 (sym "shared")))
    ((0 (sym "blocked")))
    ((0 =? (sym "shared") (label "trail")))
    (label "state"))))
(define LEFT (term (Work (succeed (label "left")) ,SIGMA)))
(define RIGHT (term (Work (fail (label "right")) ,SIGMA)))
(define RETURNED (term (Returned ,SIGMA)))
(define EXPANSION
  (term
   (Work
    ((succeed (label "left"))
     ∨
     (fail (label "right"))
     (label "choice"))
    ,SIGMA)))
(define SKIP (term (DisjL (Dead 2) ,RIGHT)))
(define REASSOCIATE
  (term (DisjL (DisjL ,RETURNED ,LEFT) ,RIGHT)))
(define COMMIT (term (More (DisjL ,RETURNED ,RIGHT))))
(define RESUME
  (term
   (Conj
    (DisjL ,RETURNED ,RIGHT)
    (succeed (label "continue")))))
(define ROOT-FOCUS (term (More hole)))
(define COMMIT-FOCUS (term (More (DisjL hole ,RIGHT))))
(define REASSOCIATE-FOCUS
  (term (More (DisjL (DisjL hole ,LEFT) ,RIGHT))))
(define REASSOCIATE-TARGET-FOCUS
  (term (More (DisjL hole (DisjL ,LEFT ,RIGHT)))))

(define D-SOURCES
  (list
   (term (DecWork ,EXPANSION ,ROOT-FOCUS))
   (term (DecWork ,SKIP ,ROOT-FOCUS))
   (term (DecWork ,REASSOCIATE ,ROOT-FOCUS))
   (term (DecFrontier ,COMMIT hole))
   (term (DecWork ,RESUME ,ROOT-FOCUS))))
(define Z-SOURCES
  (list
   (term (ZWork ,EXPANSION ,ROOT-FOCUS))
   (term (ZWork ,SKIP ,ROOT-FOCUS))
   (term (ZWork ,REASSOCIATE ,ROOT-FOCUS))
   (term (ZFrontier ,COMMIT hole))
   (term (ZWork ,RESUME ,ROOT-FOCUS))))
(define M-SOURCES
  (list
   (term (MWork ,EXPANSION ,ROOT-FOCUS))
   (term (MWork ,SKIP ,ROOT-FOCUS))
   (term (MWork ,REASSOCIATE ,ROOT-FOCUS))
   (term (MFrontier ,COMMIT hole))
   (term (MWork ,RESUME ,ROOT-FOCUS))))
(define B-SOURCES
  (list
   (term (BRun ,EXPANSION ,ROOT-FOCUS))
   (term (BDead 2 (More (DisjL hole ,RIGHT))))
   (term
    (BSettled
     ,RETURNED
     (More (DisjL (DisjL hole ,LEFT) ,RIGHT))))
   (term (BFrontier ,COMMIT hole))
   (term
    (BSettled
     ,RETURNED
     (More
      (Conj
       (DisjL hole ,RIGHT)
       (succeed (label "continue"))))))))
(define BIG-SOURCES
  (list
   (term (More ,EXPANSION))
   (term (More ,SKIP))
   (term (More ,REASSOCIATE))
   COMMIT
   (term (More ,RESUME))))

(define FEATURE-LABELS
  '(expand-disjunction
    skip-left-failure
    reassociate-left-result
    commit-choice-answer
    resume-left-choice-success))

(define (proof-count derivations)
  (length derivations))

(define DISJUNCTION-STAGE-EXTENSION-TESTS
  (test-suite
   "DISJUNCTION-STAGE-EXTENSION-TESTS"

   (test-case "one declaration supplies all five direct D/Z/M/B rules"
     (for ([source (in-list D-SOURCES)]
           [label (in-list FEATURE-LABELS)])
       (check-equal?
        (judgment-holds
         (disjunction/stage-extension/N/D-step
          ,source RuleName_0 D_0)
         RuleName_0)
        (list label))
       (check-equal?
        (proof-count
         (build-derivations
          (disjunction/stage-extension/N/D-step
           ,source RuleName D)))
        1))
     (for ([source (in-list Z-SOURCES)]
           [label (in-list FEATURE-LABELS)])
       (check-equal?
        (judgment-holds
         (disjunction/stage-extension/N/Z-step
          ,source RuleName_0 Z_0)
         RuleName_0)
        (list label))
       (check-equal?
        (proof-count
         (build-derivations
          (disjunction/stage-extension/N/Z-step
           ,source RuleName Z)))
        1))
     (for ([source (in-list M-SOURCES)]
           [label (in-list FEATURE-LABELS)])
       (check-equal?
        (judgment-holds
         (disjunction/stage-extension/N/M-step
          ,source RuleName_0 M_0)
         RuleName_0)
        (list label))
       (check-equal?
        (proof-count
         (build-derivations
          (disjunction/stage-extension/N/M-step
           ,source RuleName M)))
        1))
     (for ([source (in-list B-SOURCES)]
           [label (in-list FEATURE-LABELS)])
       (check-equal?
        (judgment-holds
         (disjunction/stage-extension/N/B-step
          ,source TransitionSpan_0 B_0)
         TransitionSpan_0)
        (list (term (transition-span ,label))))
       (check-equal?
        (proof-count
         (build-derivations
          (disjunction/stage-extension/N/B-step
           ,source TransitionSpan B)))
        1)))

   (test-case "producer boundaries remain separate singleton B steps"
     (define producer
       (term (BRun ,LEFT ,COMMIT-FOCUS)))
     (define boundary
       (term (BSettled ,RETURNED ,COMMIT-FOCUS)))
     (check-equal?
      (judgment-holds
       (disjunction/stage-extension/N/B-step
        ,producer TransitionSpan_0 B_0)
       (TransitionSpan_0 B_0))
      (list (list (term (transition-span succeed)) boundary)))
     (check-equal?
      (judgment-holds
       (disjunction/stage-extension/N/B-step
        ,boundary TransitionSpan_0 B_0)
       TransitionSpan_0)
      (list (term (transition-span commit-choice-answer))))
     (check-equal?
      (proof-count
       (build-derivations
        (disjunction/stage-extension/N/diagnostic-MB-square
         ,producer TransitionSpan B M_0 M_1)))
      1))

   (test-case "canonical commit and its boundary promote uniquely"
     (define canonical
       (term (BFrontier ,COMMIT hole)))
     (define boundary
       (term (BSettled ,RETURNED ,COMMIT-FOCUS)))
     (check-equal?
      (term
       (disjunction/stage-extension/N/B-compress
        (MFrontier ,COMMIT hole)))
      canonical)
     (check-equal?
      (term
       (disjunction/stage-extension/N/B-refocus-frontier ,COMMIT))
      canonical)
     (check-equal?
      (proof-count
       (build-derivations
        (disjunction/stage-extension/N/Big-evaluate ,COMMIT Big)))
      1)
     (check-equal?
      (proof-count
       (build-derivations
        (disjunction/stage-extension/N/Big-promote ,canonical Big)))
      1)
     (check-equal?
      (proof-count
       (build-derivations
        (disjunction/stage-extension/N/Big-promote ,boundary Big)))
      1)
     (check-equal?
      (proof-count
       (build-derivations
        (disjunction/stage-extension/N/diagnostic-ZM-square
         (ZFrontier ,COMMIT hole) RuleName Z_0 M_0 M_1)))
      1)
     (check-equal?
      (proof-count
       (build-derivations
        (disjunction/stage-extension/N/diagnostic-MB-square
         ,canonical TransitionSpan B_0 M_0 M_1)))
      1))

   (test-case "Big work controls choose one reassociation continuation"
     (for ([source (in-list BIG-SOURCES)])
       (check-equal?
        (proof-count
         (build-derivations
          (disjunction/stage-extension/N/Big-evaluate ,source Big)))
        1
        (~a "Big source " source)))
     (check-equal?
      (judgment-holds
       (disjunction/stage-extension/N/Big-control-one
        (BigWorkControl ,RETURNED ,REASSOCIATE-FOCUS)
        ControlNext_0)
       ControlNext_0)
      (list
       (term
        (BigControlContinue
         (BigWorkControl ,RETURNED ,REASSOCIATE-TARGET-FOCUS))))))

   (test-case "recursive Emit terminals survive D and direct Big"
     (define two-answer-source
       (term
        (More
         (Work
          ((succeed (label "left"))
           ∨
           (succeed (label "right"))
           (label "choice"))
          ,SIGMA))))
     (define two-answer-terminal
       (term
        (Emit
         (Answer ,SIGMA)
         (Last (Answer ,SIGMA)))))
     (check-equal?
      (proof-count
       (build-derivations
        (disjunction/stage-extension/N/D-decompose
         ,two-answer-terminal D)))
      1)
     (check-equal?
      (judgment-holds
       (disjunction/stage-extension/N/Big-evaluate
        ,two-answer-source Big_0)
       Big_0)
      (list (term (BigFinal ,two-answer-terminal)))))))

(module+ test
  (run-tests DISJUNCTION-STAGE-EXTENSION-TESTS))
