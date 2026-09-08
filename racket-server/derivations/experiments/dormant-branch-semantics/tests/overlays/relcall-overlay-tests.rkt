#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in lang:
                    "../../source/languages/all.rkt")
         (prefix-in red:
                    "../../source/reduction-relations/all.rkt")
         "../../source/reduction-relations/private/common.rkt"
         (prefix-in wf:
                    "../../source/wf/all.rkt")
         "../search-lattice-support.rkt"
         "../support.rkt")

(provide RELCALL-OVERLAY-TESTS)

(define/provide-test-suite RELCALL-OVERLAY-TESTS
  (test-case "relcall overlay expands relcalls once and still omits proceed"
    (check-true
     (redex-match? lang:relcall-lang g '(r:delay (label "call"))))
    (check-true
     (redex-match? lang:relcall-lang config (term ,cfg-call)))

    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names red:relcall-red cfg-call)))
    (check-equal? (~a step-name) "expand-relcall")
    (check-false
     (redex-match? lang:relcall-lang F '(proceed (Dead (Owners)))))
    (check-true (redex-match? lang:relcall-lang config next)))

  (test-case "relcall expansion preserves the exact ordered owner stack"
    (define owned-call
      (term
       (,gamma-delay
        (More
         (Work (Owners (Owner (u:0) (label "outer-owner"))
                (Owner (u:1) (label "inner-owner")))
               (r:delay (label "call"))
               ,sigma-a)))))
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names red:relcall-red owned-call)))

    (check-equal? (~a step-name) "expand-relcall")
    (check-equal?
     next
     (term
      (,gamma-delay
       (More
        (Work (Owners (Owner (u:0) (label "outer-owner"))
               (Owner (u:1) (label "inner-owner")))
              (suspend (succeed (label "inner")) (label "zz"))
              ,sigma-a))))))

  (test-case "factored search plus relcall expands inside the selected branch"
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names
        red:search-relcall-red
        cfg-call-branch)))

    (check-equal? (~a step-name) "expand-relcall")
    (check-true
     (redex-match? lang:search-relcall-lang config next)))

  (test-case "rail and relcall assembly order preserves the same successor"
    (define alternate-relcall-expansion
      (reduction-relation
       lang:rail-relcall-lang
       #:domain config
       [--> (Γ (in-hole WorkFocus (Work owners (r t ... tag) σ)))
            (Γ (in-hole WorkFocus (Work owners g_new σ)))
            (where g_new
                   ,(instantiate-call-host
                     (term Γ)
                     (term r)
                     (term (t ...))))
            "expand-relcall"]))
    (define alternate-rail-relcall
      (union-reduction-relations
       (context-closure
        (extend-reduction-relation red:rail-red lang:rail-relcall-lang)
        lang:rail-relcall-lang
        (Γ hole))
       alternate-relcall-expansion))

    (check-equal?
     (apply-reduction-relation red:rail-relcall-red cfg-call-rail)
     (apply-reduction-relation alternate-rail-relcall cfg-call-rail)))

  (test-case "relcall overlay WF covers delayed and assembled search configurations"
    (check-true
     (judgment-holds (wf:wf-config/relcall? ,cfg-call)))
    (check-true
     (judgment-holds
      (wf:wf-config/search-relcall? ,cfg-call-branch)))
    (check-true
     (judgment-holds
      (wf:wf-config/rail-relcall?
       (,gamma-delay
        (More
         (DisjR (Owners)
                ,delayed-left-search
                (Returned (Owners) ,sigma-b)))))))))

(module+ test
  (run-tests RELCALL-OVERLAY-TESTS))
