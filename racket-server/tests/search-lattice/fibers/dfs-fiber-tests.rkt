#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in lang:
                    "../../../src/search-lattice/languages/search-lang.rkt")
         (prefix-in red:
                    "../../../src/search-lattice/reduction-relations/search-dfs-red.rkt")
         (prefix-in search:
                    "../../../src/search-lattice/reduction-relations/search-red.rkt")
         "../../search-lattice-support.rkt"
         "../support.rkt")

(provide DFS-FIBER-TESTS)

(define/provide-test-suite DFS-FIBER-TESTS
  (test-case "DFS adds exactly one scheduler rule to search"
    (define actual
      (reduction-relation->rule-names red:search-dfs-red))
    (define inherited
      (reduction-relation->rule-names search:search-red))
    (check-equal? (length actual) 22)
    (check-equal? (length actual) (length (remove-duplicates actual)))
    (check-equal?
     (for/list ([name (in-list actual)]
                #:unless (member name inherited))
       name)
     '(dfs-delay-left)))

  (test-case "DFS grammar excludes rail right-active work"
    (check-false
     (redex-match?
      lang:search-lang
      F
      (term
       (More
        (DisjR (Owners)
               (Dead (Owners))
               (Returned (Owners) ,sigma-b)))))))

  (test-case "DFS delays the active left branch without flipping"
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names red:search-dfs-red cfg-flip)))

    (check-equal? (~a step-name) "dfs-delay-left")
    (check-equal?
     next
     (term
      (More
       (PendingDelay (Owners)
        (DisjL (Owners)
         (Work (Owners) (succeed (label "late")) ,sigma-s)
         (Returned (Owners) ,sigma-b)))))))

  (test-case "DFS moves delayed owners onto the left payload in order"
    (define scoped-payload
      (term
       (Work (Owners (Owner (u:0) (label "fresh")))
             (succeed (label "late"))
             ,sigma-s)))
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:search-dfs-red
        cfg-scoped-flip)))

    (check-equal? (~a step-name) "dfs-delay-left")
    (check-equal?
     next
     (term
      (More
       (PendingDelay (Owners)
        (DisjL (Owners)
               ,scoped-payload
               (Returned (Owners) ,sigma-b))))))))

(module+ test
  (run-tests DFS-FIBER-TESTS))
