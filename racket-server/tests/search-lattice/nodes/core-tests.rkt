#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in lang:
                    "../../../src/search-lattice/languages/core-lang.rkt")
         (prefix-in red:
                    "../../../src/search-lattice/reduction-relations/core-red.rkt")
         (prefix-in wf:
                    "../../../src/search-lattice/wf/core-wf.rkt")
         "../../search-lattice-support.rkt"
         "../support.rkt")

(provide CORE-NODE-TESTS)

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

(define OWNER-K
  (term (Owners (Owner (u:k) (label "outer")))))
(define OWNER-P
  (term (Owners (Owner (u:p) (label "inner")))))

(define/provide-test-suite CORE-NODE-TESTS
  (test-case "core static rule inventory and live witnesses stay exact"
    (check-static-rule-inventory "core" red:core-red CORE-RULES)
    (check-live-rule-coverage
     "core"
     red:core-red
     CORE-RULE-REPRESENTATIVES
     CORE-RULES))

  (test-case "core carrier excludes additive feature constructors"
    (check-false
     (redex-match?
      lang:core-lang
      W
      (term
       (PendingDelay
        (Owners)
        (Work (Owners) (succeed (label "late")) ,sigma-s)))))
    (check-false
     (redex-match?
      lang:core-lang
      F
      (term (Forced (Owners) (Last (Owners) (Answer (Owners) ,sigma-a))))))
    (check-false
     (redex-match?
      lang:core-lang
      F
      (term (Emit (Owners) (Answer (Owners) ,sigma-a) (Done (Owners)))))))

  (test-case "core work rules preserve root owner stacks"
    (define succeed-source
      (term (More (Work ,OWNER-K (succeed (label "ok")) ,sigma-a))))
    (define fail-source
      (term (More (Work ,OWNER-K (fail (label "no")) ,sigma-a))))
    (define-values (succeed-name succeed-next)
      (named-step
       (apply-reduction-relation/tag-with-names red:core-red succeed-source)))
    (define-values (fail-name fail-next)
      (named-step
       (apply-reduction-relation/tag-with-names red:core-red fail-source)))

    (check-equal? (~a succeed-name) "succeed")
    (check-equal?
     succeed-next
     (term (More (Returned ,OWNER-K ,sigma-a))))
    (check-equal? (~a fail-name) "fail")
    (check-equal?
     fail-next
     (term (More (Dead ,OWNER-K)))))

  (test-case "conjunction expansion keeps nonempty owners at the parent and starts empty child work"
    (define source
      (term
       (More
        (Work ,OWNER-K
              ((succeed (label "left"))
               ∧
               (fail (label "right"))
               (label "conjunction"))
              ,sigma-s))))
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names red:core-red source)))

    (check-equal? (~a step-name) "expand-conjunction")
    (check-equal?
     next
     (term
      (More
       (Conj ,OWNER-K
             (Work (Owners) (succeed (label "left")) ,sigma-s)
             (fail (label "right")))))))

  (test-case "conjunction collapse appends successful and failed child owners"
    (define conjunction-success-source
      (term
       (More
        (Conj ,OWNER-K
              (Returned ,OWNER-P ,sigma-a)
              (succeed (label "k"))))))
    (define conjunction-failure-source
      (term
       (More
        (Conj ,OWNER-K
              (Dead ,OWNER-P)
              (succeed (label "never"))))))
    (define-values (success-name success-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:core-red
        conjunction-success-source)))
    (define-values (failure-name failure-next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:core-red
        conjunction-failure-source)))

    (check-equal? (~a success-name) "conj-return")
    (check-equal?
     success-next
     (term
      (More
       (Work (Owners (Owner (u:k) (label "outer"))
              (Owner (u:p) (label "inner")))
             (succeed (label "k"))
             ,sigma-a))))
    (check-equal? (~a failure-name) "conj-fail")
    (check-equal?
     failure-next
     (term
      (More
       (Dead (Owners (Owner (u:k) (label "outer"))
              (Owner (u:p) (label "inner"))))))))

  (test-case "an empty binder records one empty introduction owner"
    (define source
      (term
       (More
        (Work (Owners)
              (∃ ()
                  (succeed (label "inner"))
                  (label "fresh-empty"))
              ,sigma-s))))
    (define-values (allocation-name allocated)
      (named-step
       (apply-reduction-relation/tag-with-names red:core-red source)))
    (define-values (succeed-name returned)
      (named-step
       (apply-reduction-relation/tag-with-names red:core-red allocated)))
    (define-values (finish-name finished)
      (named-step
       (apply-reduction-relation/tag-with-names red:core-red returned)))

    (check-equal?
     (map ~a (list allocation-name succeed-name finish-name))
     '("allocate-fresh" "succeed" "finish-success"))
    (check-equal?
     allocated
     (term
      (More
       (Work (Owners (Owner () (label "fresh-empty")))
             (succeed (label "inner"))
             ,sigma-s))))
    (check-equal?
     returned
     (term
      (More
       (Returned (Owners (Owner () (label "fresh-empty"))) ,sigma-s))))
    (check-equal?
     finished
     (term
      (Last (Owners (Owner () (label "fresh-empty")))
            (Answer (Owners) ,sigma-s)))))

  (test-case "failure commitment preserves a nonempty owner stack on Done"
    (define source
      (term (More (Dead ,OWNER-K))))
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names red:core-red source)))

    (check-equal? (~a step-name) "finish-failure")
    (check-equal? next (term (Done ,OWNER-K))))

  (test-case "core node accepts committed terminal answers"
    (check-true
     (judgment-holds
      (wf:wf-cfg/core? (Last (Owners) (Answer (Owners) ,sigma-a)))))))

(module+ test
  (run-tests CORE-NODE-TESTS))
