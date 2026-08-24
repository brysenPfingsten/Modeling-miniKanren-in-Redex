#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "./stage-extension-dependencies-delay-first-fixture.rkt"
         "./stage-extension-dependencies-disjunction-first-fixture.rkt"
         (prefix-in
          diag-delay-first:
          (submod
           "./stage-extension-dependencies-delay-first-fixture.rkt"
           diagnostics))
         (prefix-in
          diag-disjunction-first:
          (submod
           "./stage-extension-dependencies-disjunction-first-fixture.rkt"
           diagnostics)))

(provide STAGE-EXTENSION-DEPENDENCIES-TESTS)

(define STATE
  (term (state () () () (label "state"))))

(define OWNERS-OUTER
  (term (Owners (Owner (u:0) (label "outer")))))
(define OWNERS-INNER
  (term (Owners (Owner (u:1) (label "inner")))))
(define OWNERS-NESTED
  (term (Owners (Owner (u:2) (label "nested")))))
(define OWNERS-INNER+NESTED
  (term
   (Owners
    (Owner (u:1) (label "inner"))
    (Owner (u:2) (label "nested")))))
(define OWNERS-OUTER+INNER
  (term
   (Owners
    (Owner (u:0) (label "outer"))
    (Owner (u:1) (label "inner")))))

(define LEFT
  (term
   (Work
    (Owners)
    (succeed (label "left"))
    ,STATE)))
(define RIGHT
  (term
   (Work
    (Owners)
    (fail (label "right"))
    ,STATE)))
(define BODY
  (term
   (Work
    (Owners)
    (succeed (label "body"))
    ,STATE)))
(define CONTINUATION
  (term (succeed (label "continue"))))
(define ROOT-FOCUS (term (More hole)))

(define (proof-count derivations)
  (length derivations))

(define (proof-output derivation)
  (last (derivation-term derivation)))

(define-syntax-rule
  (check-B-diagnostic-order encode-MB decode-BM replay-M
                            machine compressed producer)
  (begin
    (check-equal? (term (encode-MB ,machine)) compressed)
    (check-equal? (term (decode-BM ,compressed)) machine)
    (check-equal?
     (judgment-holds
      (replay-M ,producer TransitionSpan_0 M_1)
      (TransitionSpan_0 M_1))
     (list (list (term (transition-span fail)) machine)))
    ;; Retain raw proof multiplicity: generic replay is inherited rather than
    ;; re-emitted, so this boundary must produce exactly one derivation.
    (check-equal?
     (proof-count
      (build-derivations
       (replay-M ,producer TransitionSpan M)))
     1)))

(define-syntax-rule
  (check-singleton-replay M-step replay-M source expected-rule)
  (let ([machine-steps
         (judgment-holds
          (M-step ,source RuleName_0 M_1)
          (RuleName_0 M_1))]
        [replay-steps
         (judgment-holds
          (replay-M ,source TransitionSpan_0 M_1)
          (TransitionSpan_0 M_1))])
    (match-define (list (list actual-rule target)) machine-steps)
    (check-equal? actual-rule (term expected-rule))
    (check-equal?
     replay-steps
     (list
      (list (term (transition-span ,actual-rule)) target)))
    (check-equal?
     (proof-count
      (build-derivations
       (replay-M ,source TransitionSpan M)))
     1)))

(define-syntax-rule
  (check-commit-boundary-square step-spec square
                                producer-B boundary-B producer-M target-M)
  (begin
    (check-equal?
     (judgment-holds
      (step-spec ,producer-B TransitionSpan_0 B_1)
      (TransitionSpan_0 B_1))
     (list (list (term (transition-span succeed)) boundary-B)))
    (check-equal?
     (proof-count
      (build-derivations
       (step-spec ,producer-B TransitionSpan B)))
     1)
    (check-equal?
     (judgment-holds
      (square ,producer-B TransitionSpan_0 B_1 M_0 M_1)
      (TransitionSpan_0 B_1 M_0 M_1))
     (list
      (list (term (transition-span succeed))
            boundary-B producer-M target-M)))
    (check-equal?
     (proof-count
      (build-derivations
       (square ,producer-B TransitionSpan B M_0 M_1)))
     1)))

(define STAGE-EXTENSION-DEPENDENCIES-TESTS
  (test-suite
   "STAGE-EXTENSION-DEPENDENCIES-TESTS"

   (test-case "Delay-first bubble transfers into later Choice"
     (define source
       (term
        (Conj
         ,OWNERS-OUTER
         (PendingDelay
          ,OWNERS-INNER
          (DisjL ,OWNERS-NESTED ,LEFT ,RIGHT))
         ,CONTINUATION)))
     (define target
       (term
        (DecFrontier
         (More
          (PendingDelay
           ,OWNERS-OUTER
           (Conj
            (Owners)
            (DisjL ,OWNERS-INNER+NESTED ,LEFT ,RIGHT)
            ,CONTINUATION)))
         hole)))
     (check-equal?
      (judgment-holds
       (delay-first/disjunction-extension/D-step
        (DecWork ,source ,ROOT-FOCUS)
        RuleName D)
       (RuleName D))
      (list (list (term bubble-delay-through-conj) target)))
     (check-equal?
      (proof-count
       (build-derivations
        (delay-first/disjunction-extension/D-step
         (DecWork ,source ,ROOT-FOCUS)
         RuleName D)))
      1))

   (test-case "Disjunction-first skip transfers into later Pending"
     (define source
       (term
        (DisjL
         ,OWNERS-OUTER
         (Dead (Owners))
         (PendingDelay ,OWNERS-INNER ,BODY))))
     (define target
       (term
        (DecFrontier
         (More
          (PendingDelay ,OWNERS-OUTER+INNER ,BODY))
         hole)))
     (check-equal?
      (judgment-holds
       (disjunction-first/delay-extension/D-step
        (DecWork ,source ,ROOT-FOCUS)
        RuleName D)
       (RuleName D))
      (list (list (term skip-left-failure) target)))
     (check-equal?
      (proof-count
      (build-derivations
        (disjunction-first/delay-extension/D-step
         (DecWork ,source ,ROOT-FOCUS)
         RuleName D)))
      1))

   (test-case "Disjunction-first Big commit classifier sees later Pending"
     (define commit-frontier
       (term
        (More
         (DisjL
          ,OWNERS-INNER
          (Returned ,OWNERS-NESTED ,STATE)
          (PendingDelay (Owners) ,BODY)))))
     (define source
       (term (Forced ,OWNERS-OUTER ,commit-frontier)))
     (define B
       (term
        (BFrontier
         ,commit-frontier
         (Forced ,OWNERS-OUTER hole))))
     (define evaluate-proofs
       (build-derivations
        (disjunction-first/delay-extension/Big-evaluate ,source Big)))
     (define promote-proofs
       (build-derivations
        (disjunction-first/delay-extension/Big-promote ,B Big)))
     (check-equal? (proof-count evaluate-proofs) 1)
     (check-equal?
      (for/list ([proof (in-list evaluate-proofs)])
        (derivation-name (first (derivation-subs proof))))
      '("commit-choice-answer/classify"))
     (check-equal? (proof-count promote-proofs) 1)
     (check-equal?
      (map proof-output evaluate-proofs)
      (map proof-output promote-proofs)))

   (test-case "B diagnostics retain skip-to-pending in both feature orders"
     (define pending
       (term (PendingDelay ,OWNERS-NESTED ,BODY)))
     (define machine
       (term
        (MWork
         (DisjL ,OWNERS-OUTER (Dead ,OWNERS-INNER) ,pending)
         (More hole))))
     (define compressed
       (term
        (BDead
         ,OWNERS-INNER
         (More (DisjL ,OWNERS-OUTER hole ,pending)))))
     (define producer
       (term
        (MWork
         (Work
          ,OWNERS-INNER
          (fail (label "diagnostic-failure"))
          ,STATE)
         (More (DisjL ,OWNERS-OUTER hole ,pending)))))
     (check-B-diagnostic-order
      diag-delay-first:delay-first/disjunction-extension/diagnostic-encode-MB
      diag-delay-first:delay-first/disjunction-extension/diagnostic-decode-BM
      diag-delay-first:delay-first/disjunction-extension/diagnostic-replay-M
      machine compressed producer)
     (check-B-diagnostic-order
      diag-disjunction-first:disjunction-first/delay-extension/diagnostic-encode-MB
      diag-disjunction-first:disjunction-first/delay-extension/diagnostic-decode-BM
      diag-disjunction-first:disjunction-first/delay-extension/diagnostic-replay-M
      machine compressed producer))

   (test-case "B diagnostic replay retains both singletons in both orders"
     (define delay-source
       (term
        (MWork
         (Work
          ,OWNERS-INNER
          (suspend
           ((succeed (label "delayed-left"))
            ∨
            (fail (label "delayed-right"))
            (label "delayed-choice"))
           (label "direct-delay"))
          ,STATE)
         (More hole))))
     (define disjunction-source
       (term
        (MWork
         (Work
          ,OWNERS-INNER
          ((suspend
            (succeed (label "choice-left"))
            (label "choice-delay"))
           ∨
           (fail (label "choice-right"))
           (label "direct-disjunction"))
          ,STATE)
         (More hole))))
     (check-singleton-replay
      delay-first/disjunction-extension/M-step
      diag-delay-first:delay-first/disjunction-extension/diagnostic-replay-M
      delay-source suspend-goal)
     (check-singleton-replay
      delay-first/disjunction-extension/M-step
      diag-delay-first:delay-first/disjunction-extension/diagnostic-replay-M
      disjunction-source expand-disjunction)
     (check-singleton-replay
      disjunction-first/delay-extension/M-step
      diag-disjunction-first:disjunction-first/delay-extension/diagnostic-replay-M
      delay-source suspend-goal)
     (check-singleton-replay
      disjunction-first/delay-extension/M-step
      diag-disjunction-first:disjunction-first/delay-extension/diagnostic-replay-M
      disjunction-source expand-disjunction))

   (test-case "B diagnostics retain the commit boundary in both orders"
     (define pending
       (term (PendingDelay ,OWNERS-NESTED ,BODY)))
     (define returned
       (term (Returned (Owners) ,STATE)))
     (define commit
       (term
        (More
         (DisjL ,OWNERS-OUTER ,returned ,pending))))
     (define commit-focus
       (term
        (More
         (DisjL ,OWNERS-OUTER hole ,pending))))
     (define producer-M
       (term (MWork ,LEFT ,commit-focus)))
     (define target-M
       (term (MFrontier ,commit hole)))
     (define producer-B
       (term (BRun ,LEFT ,commit-focus)))
     (define boundary-B
       (term (BSettled ,returned ,commit-focus)))
     (check-commit-boundary-square
      diag-delay-first:delay-first/disjunction-extension/diagnostic-B-step
      diag-delay-first:delay-first/disjunction-extension/diagnostic-MB-square
      producer-B boundary-B producer-M target-M)
     (check-commit-boundary-square
      diag-disjunction-first:disjunction-first/delay-extension/diagnostic-B-step
      diag-disjunction-first:disjunction-first/delay-extension/diagnostic-MB-square
      producer-B boundary-B producer-M target-M))

   (test-case "Q dependencies remain open in both feature orders"
     (define pending-inside-choice
       `(More
         (DisjL
          ,OWNERS-OUTER
          (PendingDelay ,OWNERS-INNER ,BODY)
          ,RIGHT)))
     (define forced-under-emit
       `(Emit
         ,OWNERS-OUTER
         (Answer ,OWNERS-INNER ,STATE)
         (Forced ,OWNERS-NESTED (More ,RIGHT))))
     (define pending-sibling-focus
       `(More
         (DisjL
          ,OWNERS-OUTER
          ,(term hole)
          (PendingDelay ,OWNERS-INNER ,BODY))))
     (define choice-inside-pending
       `(More
         (PendingDelay
          ,OWNERS-OUTER
          (DisjL ,OWNERS-INNER ,LEFT ,RIGHT))))
     (define alternating-focused
       (term (PendingDelay ,OWNERS-NESTED ,BODY)))
     ;; Keep the context under `term`: an unquoted host symbol named `hole`
     ;; is not Redex's context hole.
     (define alternating-focus
       (term
        (Forced
         ,OWNERS-OUTER
         (Emit
          ,OWNERS-INNER
          (Answer ,OWNERS-NESTED ,STATE)
          (Forced
           ,OWNERS-NESTED
           (More
            (DisjL ,OWNERS-OUTER hole ,RIGHT)))))))
     (check-equal?
      (q-rebuild/disjunction-first/search
       (q-export/disjunction-first/search pending-inside-choice))
      pending-inside-choice)
     (check-equal?
      (q-rebuild/disjunction-first/search
       (q-export/disjunction-first/search forced-under-emit))
      forced-under-emit)
     (check-equal?
      (q-failure-focus-rebuild/disjunction-first/search
       (q-failure-focus-export/disjunction-first/search
        OWNERS-NESTED pending-sibling-focus))
      (list OWNERS-NESTED pending-sibling-focus))
     (check-equal?
      (q-rebuild/delay-first/search
       (q-export/delay-first/search choice-inside-pending))
      choice-inside-pending)
     (check-equal?
      (q-focus-rebuild/disjunction-first/search
       (q-focus-export/disjunction-first/search
        alternating-focused alternating-focus))
      (list alternating-focused alternating-focus))
     (check-equal?
      (q-focus-rebuild/delay-first/search
      (q-focus-export/delay-first/search
        alternating-focused alternating-focus))
      (list alternating-focused alternating-focus)))))

(module+ test
  (run-tests STAGE-EXTENSION-DEPENDENCIES-TESTS))
