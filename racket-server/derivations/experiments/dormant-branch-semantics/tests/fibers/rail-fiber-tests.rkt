#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in lang:
                    "../../source/languages/rail-lang.rkt")
         (prefix-in red:
                    "../../source/reduction-relations/rail-red.rkt")
         (prefix-in search:
                    "../../source/reduction-relations/search-red.rkt")
         "../search-lattice-support.rkt"
         "../support.rkt")

(provide RAIL-FIBER-TESTS)

(define RAIL-OWNED-RULES
  '(skip-right-failure
    reassociate-left-result/search-join
    reassociate-right-result/left-nested
    reassociate-right-result/right-nested
    commit-right-choice-answer
    resume-right-choice-success
    rail-enter-right
    rail-return-left))

(struct step-witness
  (name source target)
  #:transparent)

(define RIGHT-ACTIVE-WITNESSES
  (list
   (step-witness
    "skip-right-failure"
    (term
     (More
      (DisjR (Owners (Owner (u:o) (label "choice")))
             (Work (Owners (Owner (u:p) (label "survivor")))
                   (succeed (label "left"))
                   ,sigma-s)
             (Dead (Owners (Owner (u:d) (label "dead")))))))
    (term
     (More
      (Work (Owners (Owner (u:o) (label "choice"))
             (Owner (u:p) (label "survivor")))
            (succeed (label "left"))
            ,sigma-s))))
   (step-witness
    "reassociate-left-result/search-join"
    (term
     (More
      (DisjL (Owners (Owner (u:k) (label "outer")))
             (DisjR (Owners (Owner (u:o) (label "inner")))
                    (Work (Owners (Owner (u:p) (label "residual")))
                          (succeed (label "residual"))
                          ,sigma-s)
                    (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a))
             (Dead (Owners)))))
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
                    (Dead (Owners)))))))
   (step-witness
    "reassociate-right-result/left-nested"
    (term
     (More
      (DisjR (Owners (Owner (u:k) (label "outer")))
             (Dead (Owners))
             (DisjL (Owners (Owner (u:o) (label "inner")))
                    (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
                    (Work (Owners (Owner (u:p) (label "residual")))
                          (succeed (label "residual"))
                          ,sigma-s)))))
    (term
     (More
      (DisjR (Owners (Owner (u:k) (label "outer")))
             (DisjR (Owners)
                    (Dead (Owners))
                    (Work (Owners (Owner (u:o) (label "inner"))
                           (Owner (u:p) (label "residual")))
                          (succeed (label "residual"))
                          ,sigma-s))
             (Returned (Owners (Owner (u:o) (label "inner"))
                        (Owner (u:a) (label "answer")))
                       ,sigma-a)))))
   (step-witness
    "reassociate-right-result/right-nested"
    (term
     (More
      (DisjR (Owners (Owner (u:k) (label "outer")))
             (Dead (Owners))
             (DisjR (Owners (Owner (u:o) (label "inner")))
                    (Work (Owners (Owner (u:p) (label "residual")))
                          (succeed (label "residual"))
                          ,sigma-s)
                    (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a)))))
    (term
     (More
      (DisjR (Owners (Owner (u:k) (label "outer")))
             (DisjR (Owners)
                    (Dead (Owners))
                    (Work (Owners (Owner (u:o) (label "inner"))
                           (Owner (u:p) (label "residual")))
                          (succeed (label "residual"))
                          ,sigma-s))
             (Returned (Owners (Owner (u:o) (label "inner"))
                        (Owner (u:a) (label "answer")))
                       ,sigma-a)))))
   (step-witness
    "commit-right-choice-answer"
    (term
     (More
      (DisjR (Owners (Owner (u:o) (label "choice")))
             (Dead (Owners))
             (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a))))
    (term
     (Emit (Owners (Owner (u:o) (label "choice")))
           (Answer (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
           (More (Dead (Owners))))))
   (step-witness
    "resume-right-choice-success"
    (term
     (More
      (Conj (Owners (Owner (u:k) (label "conj")))
            (DisjR (Owners (Owner (u:o) (label "choice")))
                   (Dead (Owners))
                   (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a))
            (succeed (label "k")))))
    (term
     (More
      (DisjR (Owners (Owner (u:k) (label "conj"))
              (Owner (u:o) (label "choice")))
             (Conj (Owners) (Dead (Owners)) (succeed (label "k")))
             (Work (Owners (Owner (u:a) (label "answer")))
                   (succeed (label "k"))
                   ,sigma-a)))))))

(define INHERITED-RIGHT-FRAME-WITNESSES
  (list
   (step-witness
    "succeed"
    (term
     (More
      (DisjR (Owners)
             (Returned (Owners) ,sigma-a)
             (Work (Owners (Owner (u:p) (label "right")))
                   (succeed (label "right-core"))
                   ,sigma-b))))
    (term
     (More
      (DisjR (Owners)
             (Returned (Owners) ,sigma-a)
             (Returned (Owners (Owner (u:p) (label "right"))) ,sigma-b)))))
   (step-witness
    "suspend-goal"
    (term
     (More
      (DisjR (Owners)
             (Returned (Owners) ,sigma-a)
             (Work (Owners (Owner (u:p) (label "right")))
                   (suspend (succeed (label "body")) (label "right-delay"))
                   ,sigma-b))))
    (term
     (More
      (DisjR (Owners)
             (Returned (Owners) ,sigma-a)
             (PendingDelay (Owners (Owner (u:p) (label "right")))
                           (Work (Owners) (succeed (label "body")) ,sigma-b))))))
   (step-witness
    "skip-left-failure"
    (term
     (More
      (DisjR (Owners)
             (Returned (Owners) ,sigma-a)
             (DisjL (Owners (Owner (u:o) (label "nested-choice")))
                    (Dead (Owners (Owner (u:d) (label "dead"))))
                    (Returned (Owners (Owner (u:p) (label "survivor")))
                              ,sigma-b)))))
    (term
     (More
      (DisjR (Owners)
             (Returned (Owners) ,sigma-a)
             (Returned (Owners (Owner (u:o) (label "nested-choice"))
                        (Owner (u:p) (label "survivor")))
                       ,sigma-b)))))))

(define (check-exact-step witness)
  (define raw-successors
    (apply-reduction-relation/tag-with-names
     red:rail-red
     (step-witness-source witness)))
  (check-equal?
   (length raw-successors)
   1
   (format "~a has ~a raw proofs: ~s"
           (step-witness-name witness)
           (length raw-successors)
           raw-successors))
  (when (pair? raw-successors)
    (check-equal? (~a (first (first raw-successors)))
                  (step-witness-name witness))
    (check-equal? (second (first raw-successors))
                  (step-witness-target witness))))

(define/provide-test-suite RAIL-FIBER-TESTS
  (test-case "rail adds exactly the right-active and scheduling rule fiber"
    (define actual
      (reduction-relation->rule-names red:rail-red))
    (define inherited
      (reduction-relation->rule-names search:search-red))
    (define added
      (for/list ([name (in-list actual)]
                 #:unless (member name inherited))
        name))

    (check-equal? (length actual) 29)
    (check-equal? (length actual) (length (remove-duplicates actual)))
    (check-equal? (sort added symbol<?)
                  (sort RAIL-OWNED-RULES symbol<?)))

  (test-case "rail owns six exact right-active owner-transfer clauses"
    (for ([witness (in-list RIGHT-ACTIVE-WITNESSES)])
      (check-exact-step witness)))

  (test-case "inherited core, delay, and disjunction rules lift through the right frame once"
    (for ([witness (in-list INHERITED-RIGHT-FRAME-WITNESSES)])
      (check-exact-step witness)))

  (test-case "rail scheduler enters the right rail in the factored source"
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names red:rail-red cfg-rail)))

    (check-equal? (~a step-name) "rail-enter-right")
    (check-true (redex-match? lang:rail-lang F next)))

  (test-case "rail moves delayed owners with the payload across entry and return"
    (define scoped-payload
      (term
       (Work (Owners (Owner (u:0) (label "fresh")))
             (succeed (label "late"))
             ,sigma-s)))
    (define scoped-return-source
      (term
       (More
        (DisjR (Owners)
               (Returned (Owners) ,sigma-b)
               ,scoped-delayed-left-search))))

    (define-values (enter-name enter-next)
      (named-step
       (apply-reduction-relation/tag-with-names red:rail-red cfg-scoped-rail)))
    (define-values (return-name return-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:rail-red
        scoped-return-source)))

    (check-equal? (~a enter-name) "rail-enter-right")
    (check-equal?
     enter-next
     (term
      (More
       (PendingDelay (Owners)
        (DisjR (Owners)
               ,scoped-payload
               (Returned (Owners) ,sigma-b))))))
    (check-equal? (~a return-name) "rail-return-left")
    (check-equal?
     return-next
     (term
      (More
       (PendingDelay (Owners)
        (DisjL (Owners)
               (Returned (Owners) ,sigma-b)
               ,scoped-payload))))))

  (test-case "factored rail continues reducing right-branch work after forcing delay"
    (define delayed-right-work
      (term
       (More
        (DisjL (Owners)
         (PendingDelay (Owners)
          (Work (Owners) (u:0 =? (sym "later") (label "later")) ,sigma-s))
         (Work (Owners) (u:0 =? (sym "now") (label "now")) ,sigma-s)))))
    (define-values (enter-name enter-next)
      (named-step
       (apply-reduction-relation/tag-with-names red:rail-red delayed-right-work)))
    (define-values (force-name force-next)
      (named-step
       (apply-reduction-relation/tag-with-names red:rail-red enter-next)))
    (define-values (resume-name resume-next)
      (named-step
       (apply-reduction-relation/tag-with-names red:rail-red force-next)))

    (check-equal? (~a enter-name) "rail-enter-right")
    (check-equal? (~a force-name) "force-delay")
    (check-equal? (~a resume-name) "unify-success")
    (check-true (redex-match? lang:rail-lang F resume-next)))

  (test-case "rail promotes bare right-branch answers"
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:rail-red
        (term (More (DisjR (Owners) (Dead (Owners)) (Returned (Owners) ,sigma-b)))))))

    (check-equal? (~a step-name) "commit-right-choice-answer")
    (check-true (redex-match? lang:rail-lang F next))))

(module+ test
  (run-tests RAIL-FIBER-TESTS))
