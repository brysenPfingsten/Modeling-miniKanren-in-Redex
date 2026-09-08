#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in lang:
                    "../../source/languages/delay-lang.rkt")
         (prefix-in red:
                    "../../source/reduction-relations/delay-red.rkt")
         (prefix-in wf:
                    "../../source/wf/delay-wf.rkt")
         "../frontier-observable-support.rkt"
         "../search-lattice-support.rkt"
         "../support.rkt")

(provide DELAY-NODE-TESTS)

(define DELAY-RULES
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
    suspend-goal
    bubble-delay-through-conj
    force-delay))

(define DELAY-OWNED-RULE-REPRESENTATIVES
  (list
   (term
    (More
     (Work (Owners)
           (suspend (succeed (label "body")) (label "suspend"))
           ,sigma-s)))
   (term
    (More
     (Conj (Owners (Owner (u:k) (label "conj-owner")))
           (PendingDelay
            (Owners (Owner (u:d) (label "delay-owner")))
            (Work (Owners (Owner (u:p) (label "payload-owner")))
                  (succeed (label "pending"))
                  ,sigma-s))
           (succeed (label "k")))))
   (term
    (More
     (PendingDelay (Owners)
                   (Work (Owners) (succeed (label "forced")) ,sigma-s))))))

(define/provide-test-suite DELAY-NODE-TESTS
  (test-case "delay static rule inventory and live witnesses stay exact"
    (check-static-rule-inventory "delay" red:delay-red DELAY-RULES)
    (check-live-rule-coverage
     "delay"
     red:delay-red
     (append CORE-RULE-REPRESENTATIVES DELAY-OWNED-RULE-REPRESENTATIVES)
     DELAY-RULES))

  (test-case "delay carrier separates pending work from frontier syntax"
    (check-false
     (redex-match? lang:delay-lang F '(PendingDelay (Owners) (Dead (Owners)))))
    (check-true
     (redex-match?
      lang:delay-lang
      W
      (term
       (PendingDelay (Owners)
                     (Work (Owners) (succeed (label "late")) ,sigma-s)))))
    (check-true
     (redex-match?
      lang:delay-lang
      F
      (term
       (Forced (Owners)
               (Last (Owners) (Answer (Owners) ,sigma-a)))))))

  (test-case "delay executes suspend and force as an exact pair"
    (define source
      (term
       (More
        (Work (Owners)
              (suspend (succeed (label "body")) (label "suspend"))
              ,sigma-s))))
    (define-values (suspend-name suspended)
      (named-step
       (apply-reduction-relation/tag-with-names red:delay-red source)))
    (define-values (force-name forced)
      (named-step
       (apply-reduction-relation/tag-with-names red:delay-red suspended)))

    (check-equal? (~a suspend-name) "suspend-goal")
    (check-equal?
     suspended
     (term
      (More
       (PendingDelay (Owners)
                     (Work (Owners) (succeed (label "body")) ,sigma-s)))))
    (check-equal? (~a force-name) "force-delay")
    (check-equal?
     forced
     (term
      (Forced (Owners)
              (More (Work (Owners) (succeed (label "body")) ,sigma-s))))))

  (test-case "delay promotion partitions conjunction and payload owners exactly"
    (define source
      (first (rest DELAY-OWNED-RULE-REPRESENTATIVES)))
    (define-values (step-name next)
      (named-step
       (apply-reduction-relation/tag-with-names red:delay-red source)))

    (check-equal? (~a step-name) "bubble-delay-through-conj")
    (check-equal?
     next
     (term
      (More
       (PendingDelay
        (Owners (Owner (u:k) (label "conj-owner")))
        (Conj (Owners)
              (Work (Owners (Owner (u:d) (label "delay-owner"))
                     (Owner (u:p) (label "payload-owner")))
                    (succeed (label "pending"))
                    ,sigma-s)
              (succeed (label "k")))))))

  (test-case "fresh outside suspend remains on the delayed frontier root"
    (define source
      (term
       (More
        (Work (Owners)
              (∃ (x:0)
                  (suspend (x:0 =? (sym "nap") (label "eq"))
                           (label "suspend"))
                  (label "fresh"))
              ,sigma-s))))
    (define-values (_allocation-name allocated)
      (named-step
       (apply-reduction-relation/tag-with-names red:delay-red source)))
    (define-values (suspend-name suspended)
      (named-step
       (apply-reduction-relation/tag-with-names red:delay-red allocated)))
    (define-values (force-name forced)
      (named-step
       (apply-reduction-relation/tag-with-names red:delay-red suspended)))

    (check-equal? (~a suspend-name) "suspend-goal")
    (check-equal?
     suspended
     (term
      (More
       (PendingDelay
        (Owners (Owner (u:0) (label "fresh")))
        (Work (Owners)
              (u:0 =? (sym "nap") (label "eq"))
              ,sigma-s)))))
    (check-equal? (~a force-name) "force-delay")
    (check-equal?
     forced
     (term
      (Forced (Owners (Owner (u:0) (label "fresh")))
              (More
               (Work (Owners)
                     (u:0 =? (sym "nap") (label "eq"))
                     ,sigma-s))))))

  (test-case "nested delays execute and finish in source order"
    (define source
      (term
       (More
        (Work (Owners)
              (suspend
               (suspend (succeed (label "inner"))
                        (label "inner-delay"))
               (label "outer-delay"))
              ,sigma-s))))
    (define-values (steps _final-configuration status)
      (trace-deterministic red:delay-red source 64))

    (check-equal? status 'done)
    (check-equal? (take steps 4)
                  '("suspend-goal"
                    "force-delay"
                    "suspend-goal"
                    "force-delay")))

  (test-case "delay node WF accepts delayed work"
    (check-true
     (judgment-holds
      (wf:wf-cfg/delay?
       (More
       (Work (Owners)
              (suspend (succeed (label "body")) (label "delay"))
              ,sigma-s)))))))
)

(module+ test
  (run-tests DELAY-NODE-TESTS))
