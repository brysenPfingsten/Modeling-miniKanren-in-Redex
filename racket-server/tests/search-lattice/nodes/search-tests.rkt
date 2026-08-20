#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in lang:
                    "../../../src/search-lattice/languages/search-lang.rkt")
         (prefix-in red:
                    "../../../src/search-lattice/reduction-relations/search-red.rkt")
         (prefix-in wf:
                    "../../../src/search-lattice/wf/search-wf.rkt")
         "../../frontier-observable-support.rkt"
         "../../search-lattice-support.rkt"
         "../support.rkt")

(provide SEARCH-NODE-TESTS)

(define/provide-test-suite SEARCH-NODE-TESTS
  (test-case "factored search commits settled choices only at the frontier"
    (define source
      (term
       (More
        (DisjL (Owners (Owner (u:o) (label "choice")))
               (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
               (Returned (Owners) ,sigma-b)))))
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names red:search-red source)))
    (define illegal-prefix-conjunction
      (term
       (More
        (Conj (Owners)
              (Emit (Owners) (Answer (Owners) ,sigma-a) (Done (Owners)))
              (succeed (label "k"))))))

    (check-false
     (redex-match? lang:search-lang F illegal-prefix-conjunction))
    (check-equal? (~a step-name) "commit-choice-answer")
    (check-equal?
     next
     (term
      (Emit (Owners (Owner (u:o) (label "choice")))
            (Answer (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
            (More (Returned (Owners) ,sigma-b)))))
    (check-true (produced-answer-spine-only? next))
    (check-true (redex-match? lang:search-lang F next)))

  (test-case "search is the additive carrier union and rejects rail right-active work"
    (check-false
     (redex-match?
      lang:search-lang
      F
      (term
       (More
        (DisjR (Owners)
               (Dead (Owners))
               (Returned (Owners) ,sigma-b)))))))

  (test-case "search node WF accepts inherited delay/disjunction combinations"
    (check-true
     (judgment-holds
      (wf:wf-cfg/search?
       (More
        (DisjL (Owners)
               (PendingDelay (Owners) (Dead (Owners)))
               (Returned (Owners) ,sigma-b))))))))

(module+ test
  (run-tests SEARCH-NODE-TESTS))
