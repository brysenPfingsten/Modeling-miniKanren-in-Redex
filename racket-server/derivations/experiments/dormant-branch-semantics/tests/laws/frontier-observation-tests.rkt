#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in red:
                    "../../source/reduction-relations/all.rkt")
         (prefix-in wf:
                    "../../source/wf/all.rkt")
         "../../source/structural-observations.rkt"
         "../frontier-observable-support.rkt"
         "../search-lattice-support.rkt"
         "../support.rkt")

(provide FRONTIER-OBSERVATIONS)

(define TRACE-CAP 48)

(define (count-step-name steps expected [count 0])
  (match steps
    ['() count]
    [(cons step-name rest)
     (count-step-name rest
                      expected
                      (if (string=? step-name expected)
                          (add1 count)
                          count))]))

(define (structural-observation-tuple cfg)
  (list (term (structural-answer-count ,cfg))
        (term (structural-forced-count ,cfg))
        (term (structural-owner-record-occurrence-count ,cfg))
        (term (structural-introduced-name-occurrence-count ,cfg))))

(define scoped-delay-fresh
  (term
   (More
    (Work (Owners)
     (∃ (x:0)
        (suspend (x:0 =? (sym "cat") (label "eq"))
                 (label "zz"))
        (label "ex"))
     (state () () () (label "s"))))))

(define cfg-double-delay
  (term
   (More
    (Work (Owners)
     (suspend
      (suspend (succeed (label "inner"))
               (label "zz-inner"))
      (label "zz-outer"))
     ,sigma-s))))

(define/provide-test-suite FRONTIER-OBSERVATIONS
  (test-case "structural observations distinguish settled work, answers, and owner occurrences"
    (define sigma-u0
      (term (state () () () (label "su0"))))
    (define sigma-fresh-state
      (term (state () () () (label "fresh-state"))))
    (define work-owned-success
      (term
       (More
        (Returned (Owners (Owner (u:0) (label "fresh")))
                  ,sigma-u0))))
    (define forced-owned-answer
      (term
       (Forced (Owners (Owner (u:0) (label "fresh")))
               (Last (Owners) (Answer (Owners) ,sigma-u0)))))
    (define answer-owned-answer
      (term
       (Emit (Owners)
             (Answer (Owners (Owner (u:0) (label "fresh-answer")))
                     ,sigma-fresh-state)
             (More (Dead (Owners))))))
    (define two-answer-frontier
      (term
       (Emit (Owners)
             (Answer (Owners) ,sigma-a)
             (Emit (Owners)
                   (Answer (Owners) ,sigma-b)
                   (Done (Owners))))))

    (check-true (judgment-holds (wf:wf-cfg/core? ,work-owned-success)))
    (check-true (judgment-holds (wf:wf-cfg/delay? ,forced-owned-answer)))
    (check-true (judgment-holds (wf:wf-cfg/disj? ,answer-owned-answer)))
    (check-true (judgment-holds (wf:wf-cfg/disj? ,two-answer-frontier)))
    (check-true (produced-answer-spine-only? answer-owned-answer))
    (check-equal? (structural-observation-tuple work-owned-success)
                  '(0 0 1 1))
    (check-equal? (structural-observation-tuple forced-owned-answer)
                  '(1 1 1 1))
    (check-equal? (structural-observation-tuple answer-owned-answer)
                  '(1 0 1 1))
    (check-equal? (structural-observation-tuple two-answer-frontier)
                  '(2 0 0 0)))

  (test-case "produced answers remain on the spine through Forced and right-active commitment"
    (define forced-commitment
      (term
       (Forced (Owners)
        (Emit (Owners)
              (Answer (Owners) ,sigma-a)
              (More
               (DisjL (Owners)
                      (Dead (Owners))
                      (Returned (Owners) ,sigma-b)))))))
    (define right-active-commitment
      (term
       (Emit (Owners)
             (Answer (Owners) ,sigma-b)
             (More (Dead (Owners))))))

    (check-true (produced-answer-spine-only? forced-commitment))
    (check-true (produced-answer-spine-only? right-active-commitment)))

  (test-case "owner occurrences stay exact when fresh and delay interact"
    (for ([entry (in-list (list red:search-red))])
      (define-values (steps final-cfg status)
        (trace-deterministic entry scoped-delay-fresh TRACE-CAP))
      (check-equal? status 'done)
      (check-true (structurally-well-formed? final-cfg))
      (check-equal? (count-step-name steps "allocate-fresh") 1)
      (check-equal?
       (term (structural-owner-record-occurrence-count ,final-cfg))
       1)
      (check-equal?
       (term (structural-introduced-name-occurrence-count ,final-cfg))
       1)
      (check-equal? (count-step-name steps "force-delay") 1)
      (check-equal? (term (structural-forced-count ,final-cfg)) 1)))

  (test-case "delay forcing transfers pending owners directly to Forced"
    (define scoped-delay
      (term
       (More
        (PendingDelay
         (Owners (Owner (u:0) (label "fresh")))
         (Work (Owners)
               (succeed (label "ok"))
               (state () () () (label "s")))))))
    (for ([rel (in-list (list red:delay-red
                              red:search-red))])
      (define-values (force-name forced)
        (named-step (apply-reduction-relation/tag-with-names rel scoped-delay)))
      (check-equal? force-name "force-delay")
      (check-equal?
       forced
       (term
        (Forced
         (Owners (Owner (u:0) (label "fresh")))
         (More
          (Work (Owners)
                (succeed (label "ok"))
                (state () () () (label "s")))))))
      (check-true (structurally-well-formed? forced))))

  (test-case "Forced accounting matches force-delay steps across representative machines"
    (for ([entry
           (in-list
            (list (list "delay" red:delay-red cfg-delay-goal)
                  (list "search" red:search-red cfg-delay-goal)
                  (list "relcall" red:relcall-red cfg-call)
                  (list "search-dfs-relcall" red:search-dfs-relcall-red cfg-call)
                  (list "search-flip-relcall" red:search-flip-relcall-red cfg-call)
                  (list "search-dfs" red:search-dfs-red cfg-flip)
                  (list "search-flip" red:search-flip-red cfg-flip)
                  (list "rail" red:rail-red cfg-rail)
                  (list "rail-relcall" red:rail-relcall-red cfg-call-rail)))])
      (match-define (list label rel cfg) entry)
      (define-values (steps final-cfg status)
        (trace-deterministic rel cfg TRACE-CAP))
      (check-true (or (eq? status 'done)
                      (eq? status 'cap)))
      (check-true (structurally-well-formed? final-cfg))
      (check-equal? (term (structural-forced-count ,final-cfg))
                    (count-step-name steps "force-delay")
                    label)
      (check-true (>= (term (structural-forced-count ,final-cfg)) 1)
                  label)))

  (test-case "nested suspensions record one Forced per force"
    (define-values (steps final-cfg status)
      (trace-deterministic red:delay-red cfg-double-delay TRACE-CAP))
    (check-equal? status 'done)
    (check-equal? (count-step-name steps "force-delay") 2)
    (check-equal? (term (structural-forced-count ,final-cfg)) 2)))

(module+ test
  (run-tests FRONTIER-OBSERVATIONS))
