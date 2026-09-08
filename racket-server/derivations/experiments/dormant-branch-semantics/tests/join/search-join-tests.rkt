#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in delay-lang:
                    "../../source/languages/delay-lang.rkt")
         (prefix-in disj-lang:
                    "../../source/languages/disj-lang.rkt")
         (prefix-in search-lang:
                    "../../source/languages/search-lang.rkt")
         (prefix-in search:
                    "../../source/reduction-relations/search-red.rkt")
         (only-in "../search-lattice-support.rkt"
                  sigma-a
                  sigma-b
                  sigma-s
                  tagged-successor-cfg
                  tagged-successor-name))

(provide SEARCH-JOIN)

(define CORE-RULES
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
    finish-failure))

(define DELAY-RULES
  '(suspend-goal
    bubble-delay-through-conj
    force-delay))

(define DISJUNCTION-RULES
  '(expand-disjunction
    skip-left-failure
    reassociate-left-result
    commit-choice-answer
    resume-left-choice-success))

(define (sort-symbols names)
  (sort names symbol<?))

(define (rule-name-union . name-lists)
  (sort-symbols (remove-duplicates (append* name-lists))))

(define (rule-name-difference names inherited)
  (sort-symbols
   (for/list ([name (in-list names)]
              #:unless (member name inherited))
     name)))

(struct step-witness
  (owner name source target)
  #:transparent)

(define INHERITED-CONTEXT-WITNESSES
  (list
   (step-witness
    'core
    "succeed"
    (term
     (Forced (Owners (Owner (u:f) (label "forced")))
             (Emit (Owners (Owner (u:e) (label "emit")))
                   (Answer (Owners) ,sigma-a)
                   (More
                    (Work (Owners (Owner (u:p) (label "payload")))
                          (succeed (label "frontier-core"))
                          ,sigma-b)))))
    (term
     (Forced (Owners (Owner (u:f) (label "forced")))
             (Emit (Owners (Owner (u:e) (label "emit")))
                   (Answer (Owners) ,sigma-a)
                   (More
                    (Returned (Owners (Owner (u:p) (label "payload")))
                              ,sigma-b)))))))
  )

(define (check-exact-step relation witness)
  (define raw-successors
    (apply-reduction-relation/tag-with-names
     relation
     (step-witness-source witness)))
  (check-equal?
   (length raw-successors)
   1
   (format "~a witness ~a has ~a raw proofs: ~s"
           (step-witness-owner witness)
           (step-witness-name witness)
           (length raw-successors)
           raw-successors))
  (when (pair? raw-successors)
    (define successor
      (first raw-successors))
    (check-equal? (tagged-successor-name successor)
                  (step-witness-name witness))
    (check-equal? (tagged-successor-cfg successor)
                  (step-witness-target witness))))

(define/provide-test-suite SEARCH-JOIN
  (test-case "search is exactly the delay/disjunction rule union with one shared core"
    (define actual
      (reduction-relation->rule-names search:search-red))
    (define inherited
      (rule-name-union CORE-RULES DELAY-RULES DISJUNCTION-RULES))
    (check-equal? (length actual)
                  (length (remove-duplicates actual))
                  "search repeats a static source-rule name")
    (check-equal? (sort-symbols actual)
                  inherited
                  "search static source-rule inventory drifted")
    (check-equal? (rule-name-difference actual inherited)
                  '()
                  "search must add no rules beyond its two parents")
    (check-equal? (length actual) 21)
    (for ([name (in-list CORE-RULES)])
      (check-equal? (count (lambda (actual-name) (eq? actual-name name)) actual)
                    1
                    (format "search did not inherit exactly one core rule named ~a"
                            name))))

  (test-case "parent clauses lift through additive search contexts"
    (for ([witness (in-list INHERITED-CONTEXT-WITNESSES)])
      (check-exact-step search:search-red witness)))

  (test-case "search adds no right-active carrier syntax"
    (define delay-only
      (term
       (More
        (PendingDelay (Owners)
                      (Work (Owners) (succeed (label "delay")) ,sigma-s)))))
    (define disjunction-only
      (term
       (More
        (DisjL (Owners)
               (Returned (Owners) ,sigma-a)
               (Dead (Owners))))))
    (define combined
      (term
       (Forced (Owners)
               (Emit (Owners)
                     (Answer (Owners) ,sigma-a)
                     (More
                      (PendingDelay (Owners)
                                    (DisjL (Owners)
                                           (Dead (Owners))
                                           (Returned (Owners) ,sigma-b))))))))
    (define right-active
      (term
       (More
        (DisjR (Owners)
               (Dead (Owners))
               (Returned (Owners) ,sigma-b)))))

    (check-true (redex-match? delay-lang:delay-lang F delay-only))
    (check-true (redex-match? search-lang:search-lang F delay-only))
    (check-true (redex-match? disj-lang:disj-lang F disjunction-only))
    (check-true (redex-match? search-lang:search-lang F disjunction-only))
    (check-false (redex-match? delay-lang:delay-lang F combined))
    (check-false (redex-match? disj-lang:disj-lang F combined))
    (check-true (redex-match? search-lang:search-lang F combined))
    (check-false (redex-match? search-lang:search-lang F right-active)))

  (test-case "settled choices reassociate and commit through a Forced spine"
    (define forced-branch
      (term
       (Forced (Owners (Owner (u:f) (label "forced")))
               (More
                (DisjL (Owners (Owner (u:o) (label "outer-choice")))
                       (DisjL (Owners (Owner (u:i) (label "inner-choice")))
                              (Returned (Owners (Owner (u:a) (label "answer")))
                                        ,sigma-a)
                              (Dead (Owners (Owner (u:d) (label "dead")))))
                       (Returned (Owners) ,sigma-b))))))
    (define forced-mid
      (term
       (Forced (Owners (Owner (u:f) (label "forced")))
               (More
                (DisjL (Owners (Owner (u:o) (label "outer-choice")))
                       (Returned (Owners (Owner (u:i) (label "inner-choice"))
                                  (Owner (u:a) (label "answer")))
                                 ,sigma-a)
                       (DisjL (Owners)
                              (Dead (Owners (Owner (u:i) (label "inner-choice"))
                                     (Owner (u:d) (label "dead"))))
                              (Returned (Owners) ,sigma-b)))))))
    (define forced-next
      (term
       (Forced (Owners (Owner (u:f) (label "forced")))
               (Emit (Owners (Owner (u:o) (label "outer-choice")))
                     (Answer (Owners (Owner (u:i) (label "inner-choice"))
                              (Owner (u:a) (label "answer")))
                             ,sigma-a)
                     (More
                      (DisjL (Owners)
                             (Dead (Owners (Owner (u:i) (label "inner-choice"))
                                    (Owner (u:d) (label "dead"))))
                             (Returned (Owners) ,sigma-b)))))))
    (check-exact-step
     search:search-red
     (step-witness 'disjunction
                   "reassociate-left-result"
                   forced-branch
                   forced-mid))
    (check-exact-step
     search:search-red
     (step-witness 'disjunction
                   "commit-choice-answer"
                   forced-mid
                   forced-next)))

  (test-case "a produced prefix remains on the spine while the next answer commits"
    (check-exact-step
     search:search-red
     (step-witness
      'disjunction
      "commit-choice-answer"
      (term
       (Forced (Owners)
               (Emit (Owners)
                     (Answer (Owners) ,sigma-a)
                     (More
                      (DisjL (Owners (Owner (u:o) (label "next-choice")))
                             (Returned (Owners (Owner (u:a) (label "next-answer")))
                                       ,sigma-b)
                             (Dead (Owners)))))))
      (term
       (Forced (Owners)
               (Emit (Owners)
                     (Answer (Owners) ,sigma-a)
                     (Emit (Owners (Owner (u:o) (label "next-choice")))
                           (Answer (Owners (Owner (u:a) (label "next-answer")))
                                   ,sigma-b)
                           (More (Dead (Owners))))))))))
)

(module+ test
  (run-tests SEARCH-JOIN))
