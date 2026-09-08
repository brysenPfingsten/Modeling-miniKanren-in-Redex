#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in lang:
                    "../../source/languages/search-lang.rkt")
         (prefix-in red:
                    "../../source/reduction-relations/search-flip-red.rkt")
         (prefix-in search:
                    "../../source/reduction-relations/search-red.rkt")
         "../search-lattice-support.rkt"
         "../support.rkt")

(provide FLIP-FIBER-TESTS)

(define/provide-test-suite FLIP-FIBER-TESTS
  (test-case "flip adds exactly one scheduler rule to search"
    (define actual
      (reduction-relation->rule-names red:search-flip-red))
    (define inherited
      (reduction-relation->rule-names search:search-red))
    (check-equal? (length actual) 22)
    (check-equal? (length actual) (length (remove-duplicates actual)))
    (check-equal?
     (for/list ([name (in-list actual)]
                #:unless (member name inherited))
       name)
     '(flip-delay-left)))

  (test-case "flip grammar excludes rail right-active work"
    (check-false
     (redex-match?
      lang:search-lang
      F
      (term
       (More
        (DisjR (Owners)
               (Dead (Owners))
               (Returned (Owners) ,sigma-b)))))))

  (test-case "flip moves the delayed left branch behind the ready right branch"
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names red:search-flip-red cfg-flip)))

    (check-equal? (~a step-name) "flip-delay-left")
    (check-equal?
     next
     (term
      (More
       (PendingDelay (Owners)
        (DisjL (Owners)
         (Returned (Owners) ,sigma-b)
         (Work (Owners) (succeed (label "late")) ,sigma-s)))))))

  (test-case "flip moves delayed owners with the left payload in order"
    (define scoped-payload
      (term
       (Work (Owners (Owner (u:0) (label "fresh")))
             (succeed (label "late"))
             ,sigma-s)))
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:search-flip-red
        cfg-scoped-flip)))

    (check-equal? (~a step-name) "flip-delay-left")
    (check-equal?
     next
     (term
      (More
       (PendingDelay (Owners)
        (DisjL (Owners)
               (Returned (Owners) ,sigma-b)
               ,scoped-payload)))))))

(module+ test
  (run-tests FLIP-FIBER-TESTS))
