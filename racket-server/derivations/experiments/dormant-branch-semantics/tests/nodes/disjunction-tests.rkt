#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in red:
                    "../../source/reduction-relations/disj-red.rkt")
         (prefix-in wf:
                    "../../source/wf/disj-wf.rkt")
         "../search-lattice-support.rkt"
         "../support.rkt")

(provide DISJUNCTION-NODE-TESTS)

(define DISJUNCTION-RULES
  '(expand-conjunction
    succeed
    fail
    conj-return
    conj-fail
    allocate-fresh
    unify-success
    unify-violates-disequality
    unify-fail
    disequality-success
    disequality-fail
    finish-success
    finish-failure
    expand-disjunction
    skip-left-failure
    reassociate-left-result
    commit-choice-answer
    resume-left-choice-success))

(define DISJUNCTION-OWNED-RULE-REPRESENTATIVES
  (list
   (term
    (More
     (Work (Owners)
           ((succeed (label "left"))
            ∨
            (fail (label "right"))
            (label "disj"))
           ,sigma-s)))
   (term
    (More
     (DisjL (Owners (Owner (u:o) (label "choice")))
            (Dead (Owners (Owner (u:d) (label "dead"))))
            (Work (Owners (Owner (u:p) (label "survivor")))
                  (succeed (label "right"))
                  ,sigma-s))))
   (term
    (More
     (DisjL (Owners (Owner (u:k) (label "outer")))
            (DisjL (Owners (Owner (u:o) (label "inner")))
                   (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
                   (Work (Owners (Owner (u:p) (label "residual")))
                         (succeed (label "residual"))
                         ,sigma-s))
            (Dead (Owners)))))
   (term
    (More
     (DisjL (Owners (Owner (u:o) (label "choice")))
            (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
            (Dead (Owners)))))
   (term
    (More
     (Conj (Owners (Owner (u:k) (label "conj")))
           (DisjL (Owners (Owner (u:o) (label "choice")))
                  (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
                  (Dead (Owners)))
           (succeed (label "k")))))))

(define/provide-test-suite DISJUNCTION-NODE-TESTS
  (test-case "disjunction static rule inventory and live witnesses stay exact"
    (check-static-rule-inventory
     "disjunction"
     red:disj-red
     DISJUNCTION-RULES)
    (check-live-rule-coverage
     "disjunction"
     red:disj-red
     (append CORE-RULE-REPRESENTATIVES
             DISJUNCTION-OWNED-RULE-REPRESENTATIVES)
     DISJUNCTION-RULES))

  (test-case "disjunction expansion retains root owners and starts empty branches"
    (define source
      (first DISJUNCTION-OWNED-RULE-REPRESENTATIVES))
    (define owned-source
      (match source
        [`(More (Work (Owners) ,goal ,state))
         `(More
           (Work (Owners (Owner (u:o) (label "choice"))) ,goal ,state))]))
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names red:disj-red owned-source)))

    (check-equal? (~a step-name) "expand-disjunction")
    (check-equal?
     next
     (term
      (More
       (DisjL (Owners (Owner (u:o) (label "choice")))
              (Work (Owners) (succeed (label "left")) ,sigma-s)
              (Work (Owners) (fail (label "right")) ,sigma-s))))))

  (test-case "left prune discards dead owners and prepends choice owners to the survivor"
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:disj-red
        (second DISJUNCTION-OWNED-RULE-REPRESENTATIVES))))

    (check-equal? (~a step-name) "skip-left-failure")
    (check-equal?
     next
     (term
      (More
       (Work (Owners (Owner (u:o) (label "choice"))
              (Owner (u:p) (label "survivor")))
             (succeed (label "right"))
             ,sigma-s)))))

  (test-case "left reassociation attaches inner owners only to their old children"
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:disj-red
        (third DISJUNCTION-OWNED-RULE-REPRESENTATIVES))))

    (check-equal? (~a step-name) "reassociate-left-result")
    (check-equal?
     next
     (term
      (More
       (DisjL (Owners (Owner (u:k) (label "outer")))
              (Returned (Owners (Owner (u:o) (label "inner"))
                         (Owner (u:a) (label "answer")))
                        ,sigma-a)
              (DisjL (Owners)
                     (Work (Owners (Owner (u:o) (label "inner"))
                            (Owner (u:p) (label "residual")))
                           (succeed (label "residual"))
                           ,sigma-s)
                     (Dead (Owners))))))))

  (test-case "left commit keeps choice owners on Emit and answer owners on Answer"
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:disj-red
        (fourth DISJUNCTION-OWNED-RULE-REPRESENTATIVES))))

    (check-equal? (~a step-name) "commit-choice-answer")
    (check-equal?
     next
     (term
      (Emit (Owners (Owner (u:o) (label "choice")))
            (Answer (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
            (More (Dead (Owners)))))))

  (test-case "an emitted answer stays partitioned from an owner-bearing residual failure"
    (define source
      (term
       (More
        (DisjL (Owners (Owner (u:shared) (label "shared-choice")))
               (Returned (Owners (Owner (u:answer) (label "first-answer")))
                         ,sigma-a)
               (Work (Owners (Owner (u:residual) (label "residual-root")))
                     (∃ (x:dead)
                         (fail (label "residual-fail"))
                         (label "residual-fresh"))
                     ,sigma-s)))))
    (define-values (commit-name committed)
      (named-step
       (apply-reduction-relation/tag-with-names red:disj-red source)))
    (define-values (allocate-name allocated)
      (named-step
       (apply-reduction-relation/tag-with-names red:disj-red committed)))
    (define-values (fail-name failed)
      (named-step
       (apply-reduction-relation/tag-with-names red:disj-red allocated)))
    (define-values (finish-name finished)
      (named-step
       (apply-reduction-relation/tag-with-names red:disj-red failed)))

    (check-equal?
     (map ~a (list commit-name allocate-name fail-name finish-name))
     '("commit-choice-answer" "allocate-fresh" "fail" "finish-failure"))
    (check-equal?
     committed
     (term
      (Emit (Owners (Owner (u:shared) (label "shared-choice")))
            (Answer (Owners (Owner (u:answer) (label "first-answer"))) ,sigma-a)
            (More
             (Work (Owners (Owner (u:residual) (label "residual-root")))
                   (∃ (x:dead)
                       (fail (label "residual-fail"))
                       (label "residual-fresh"))
                   ,sigma-s)))))
    (check-equal?
     allocated
     (term
      (Emit (Owners (Owner (u:shared) (label "shared-choice")))
            (Answer (Owners (Owner (u:answer) (label "first-answer"))) ,sigma-a)
            (More
             (Work (Owners (Owner (u:residual) (label "residual-root"))
                    (Owner (u:0) (label "residual-fresh")))
                   (fail (label "residual-fail"))
                   ,sigma-s)))))
    (check-equal?
     failed
     (term
      (Emit (Owners (Owner (u:shared) (label "shared-choice")))
            (Answer (Owners (Owner (u:answer) (label "first-answer"))) ,sigma-a)
            (More
             (Dead (Owners (Owner (u:residual) (label "residual-root"))
                    (Owner (u:0) (label "residual-fresh"))))))))
    (check-equal?
     finished
     (term
      (Emit (Owners (Owner (u:shared) (label "shared-choice")))
            (Answer (Owners (Owner (u:answer) (label "first-answer"))) ,sigma-a)
            (Done (Owners (Owner (u:residual) (label "residual-root"))
                   (Owner (u:0) (label "residual-fresh"))))))))

  (test-case "factored left resume merges parent and choice owners only at the result choice"
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:disj-red
        (fifth DISJUNCTION-OWNED-RULE-REPRESENTATIVES))))

    (check-equal? (~a step-name) "resume-left-choice-success")
    (check-equal?
     next
     (term
      (More
       (DisjL (Owners (Owner (u:k) (label "conj"))
               (Owner (u:o) (label "choice")))
              (Work (Owners (Owner (u:a) (label "answer")))
                    (succeed (label "k"))
                    ,sigma-a)
              (Conj (Owners) (Dead (Owners)) (succeed (label "k"))))))))

  (test-case "disjunction node WF accepts left-active choice"
    (check-true
     (judgment-holds
      (wf:wf-cfg/disj?
       (More
        (DisjL (Owners)
               (Returned (Owners) ,sigma-a)
               (Dead (Owners)))))))))

(module+ test
  (run-tests DISJUNCTION-NODE-TESTS))
