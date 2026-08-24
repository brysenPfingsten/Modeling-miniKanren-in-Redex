#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "./delay-stage-extension-fixture.rkt"
         (submod "./delay-stage-extension-fixture.rkt" diagnostics))

(provide DELAY-STAGE-EXTENSION-TESTS)

(define N-STATE
  (term (state 0 () () () (label "state"))))

(define S-STATE
  (term (state () () () (label "state"))))

(define OWNER-U0
  (term (Owners (Owner (u:0) (label "outer")))))

(define OWNER-U1
  (term (Owners (Owner (u:1) (label "pending")))))

(define OWNER-U2
  (term (Owners (Owner (u:2) (label "inner")))))

(define S-BODY
  (term
   (Work
    (Owners)
    (succeed (label "body"))
    ,S-STATE)))

(define N-BODY
  (term
   (Work
    (succeed (label "body"))
    ,N-STATE)))

(define N-SUSPENDED
  (term
   (Work
    (suspend
     (succeed (label "body"))
     (label "delay"))
    ,N-STATE)))

(define N-PENDING
  (term (PendingDelay ,N-BODY)))

(define N-FORCE
  (term (More ,N-PENDING)))

(define N-FORCED
  (term (Forced (More ,N-BODY))))

(define N-BUBBLE
  (term
   (Conj
    ,N-PENDING
    (succeed (label "right")))))

(define N-BUBBLE-TARGET
  (term
   (PendingDelay
    (Conj
     ,N-BODY
     (succeed (label "right"))))))

(define N-ROOT-FOCUS (term (More hole)))

(define (proof-count derivations)
  (length derivations))

(define-test-suite DELAY-STAGE-EXTENSION-TESTS
  (test-case "the same Delay declaration reaches D, Z, and M directly"
    (check-equal?
     (judgment-holds
      (delay/stage-extension/N/D-step
       (DecWork ,N-SUSPENDED ,N-ROOT-FOCUS)
       RuleName D)
      (RuleName D))
     (list
      (list
       (term suspend-goal)
       (term (DecFrontier ,N-FORCE hole)))))
    (check-equal?
     (proof-count
      (build-derivations
       (delay/stage-extension/N/D-step
        (DecWork ,N-SUSPENDED ,N-ROOT-FOCUS)
        RuleName D)))
     1)
    (check-equal?
     (judgment-holds
      (delay/stage-extension/N/Z-step
       (ZWork ,N-SUSPENDED ,N-ROOT-FOCUS)
       RuleName Z)
      (RuleName Z))
     (list
      (list
       (term suspend-goal)
       (term (ZFrontier ,N-FORCE hole)))))
    (check-equal?
     (judgment-holds
      (delay/stage-extension/N/M-step
       (MWork ,N-SUSPENDED ,N-ROOT-FOCUS)
       RuleName M)
      (RuleName M))
     (list
      (list
       (term suspend-goal)
       (term (MFrontier ,N-FORCE hole))))))

  (test-case "bubble and force remain direct frontier transitions"
    (check-equal?
     (judgment-holds
      (delay/stage-extension/N/Z-step
       (ZWork ,N-BUBBLE ,N-ROOT-FOCUS)
       RuleName Z)
      (RuleName Z))
     (list
      (list
       (term bubble-delay-through-conj)
       (term (ZFrontier (More ,N-BUBBLE-TARGET) hole)))))
    (check-equal?
     (judgment-holds
      (delay/stage-extension/N/M-step
       (MFrontier ,N-FORCE hole)
       RuleName M)
      (RuleName M))
     (list
      (list
       (term force-delay)
       (term
        (MWork
         ,N-BODY
         (Forced (More hole)))))))
    (check-equal?
     (proof-count
      (build-derivations
       (delay/stage-extension/N/M-step
        (MFrontier ,N-FORCE hole)
        RuleName M)))
     1))

  (test-case "stage bubble transfers through a nested pending wrapper"
    (define source
      (term
       (Conj
        ,OWNER-U0
        (PendingDelay ,OWNER-U1 (PendingDelay ,OWNER-U2 ,S-BODY))
        (succeed (label "right")))))
    (check-equal?
     (judgment-holds
      (delay/stage-extension/S/D-step
       (DecWork ,source (More hole)) RuleName D)
      (RuleName D))
     (list
      (list
       (term bubble-delay-through-conj)
       (term
        (DecFrontier
         (More
          (PendingDelay
           ,OWNER-U0
           (Conj
            (Owners)
            (PendingDelay
             (Owners
              (Owner (u:1) (label "pending"))
              (Owner (u:2) (label "inner")))
             ,S-BODY)
            (succeed (label "right")))))
         hole)))))
    (check-equal?
     (proof-count
      (build-derivations
       (delay/stage-extension/S/D-step
        (DecWork ,source (More hole)) RuleName D)))
     1))

  (test-case "B classifies every Delay label as exactly one singleton"
    (define cases
      (list
       (list
        (term (BRun ,N-SUSPENDED ,N-ROOT-FOCUS))
        (term (transition-span suspend-goal))
        (term (BFrontier ,N-FORCE hole)))
       (list
        (term (BRun ,N-BUBBLE ,N-ROOT-FOCUS))
        (term (transition-span bubble-delay-through-conj))
        (term (BFrontier (More ,N-BUBBLE-TARGET) hole)))
       (list
        (term (BFrontier ,N-FORCE hole))
        (term (transition-span force-delay))
        (term (BRun ,N-BODY (Forced (More hole)))))))
    (for ([case (in-list cases)])
      (match-define (list source span target) case)
      (check-equal?
       (judgment-holds
        (delay/stage-extension/N/B-step
         ,source TransitionSpan B)
        (TransitionSpan B))
       (list (list span target)))
      (check-equal?
       (proof-count
        (build-derivations
         (delay/stage-extension/N/B-step
          ,source TransitionSpan B)))
       1)))

  (test-case "Big dispatches work rules and controls force without duplicates"
    (check-equal?
     (judgment-holds
     (delay/stage-extension/N/Big-dispatch-one
       ,N-SUSPENDED ,N-ROOT-FOCUS BigNext)
      BigNext)
     (list
      (term
       (BigFrontierContinue ,N-FORCE))))
    (check-equal?
     (proof-count
      (build-derivations
       (delay/stage-extension/N/Big-dispatch-one
        ,N-SUSPENDED ,N-ROOT-FOCUS BigNext)))
     1)
    (check-equal?
     (judgment-holds
      (delay/stage-extension/N/Big-control-one
       (BigWorkControl ,N-SUSPENDED ,N-ROOT-FOCUS)
       ControlNext)
      ControlNext)
     (list
      (term
       (BigControlContinue
        (BigFrontierControl ,N-FORCE hole)))))
    (check-equal?
     (judgment-holds
      (delay/stage-extension/N/Big-control-one
       (BigFrontierControl ,N-FORCE hole)
       ControlNext)
      ControlNext)
     (list
      (term
       (BigControlContinue
        (BigWorkControl ,N-BODY (Forced (More hole)))))))
    (check-equal?
     (proof-count
      (build-derivations
       (delay/stage-extension/N/Big-control-one
        (BigFrontierControl ,N-FORCE hole)
        ControlNext)))
     1))

  (test-case "phase-local allocation sees suspend and Forced"
    (define fresh-work
      (term
       (Work
        (Owners)
        (∃ (x:q)
           (suspend
            (x:q =? (nat 1) (label "unify"))
            (label "delay"))
           (label "fresh"))
        ,S-STATE)))
    (define focus
      (term (Forced ,OWNER-U0 (More hole))))
    (define expected-work
      (term
       (Work
        (Owners (Owner (u:1) (label "fresh")))
        (suspend
         (u:1 =? (nat 1) (label "unify"))
         (label "delay"))
        ,S-STATE)))
    (check-equal?
     (judgment-holds
      (delay/stage-extension/S/D-step
       (DecAllocate ,fresh-work ,focus)
       RuleName D)
      (RuleName D))
     (list
      (list
       (term allocate-fresh)
       (term (DecWork ,expected-work ,focus)))))
    (check-equal?
     (judgment-holds
      (delay/stage-extension/S/Z-step
       (ZAllocate ,fresh-work ,focus)
       RuleName Z)
      (RuleName Z))
     (list
      (list
       (term allocate-fresh)
       (term (ZWork ,expected-work ,focus)))))
    (check-equal?
     (judgment-holds
      (delay/stage-extension/S/M-step
       (MAllocate ,fresh-work ,focus)
       RuleName M)
      (RuleName M))
     (list
      (list
       (term allocate-fresh)
       (term (MWork ,expected-work ,focus)))))
    (check-equal?
     (judgment-holds
      (delay/stage-extension/S/B-step
       (BRun ,fresh-work ,focus)
       TransitionSpan B)
      (TransitionSpan B))
     (list
      (list
       (term (transition-span allocate-fresh))
       (term (BRun ,expected-work ,focus)))))
    (check-equal?
     (judgment-holds
      (delay/stage-extension/S/Big-dispatch-one
       ,fresh-work ,focus BigNext)
      BigNext)
     (list
      (term (BigContinue ,expected-work ,focus)))))

  (test-case "nested Forced terminals survive every direct phase"
    (define terminals
      (list
       (term (Forced (Forced (Last (Answer ,N-STATE)))))
       (term (Forced (Forced (Done 0))))))
    (for ([terminal (in-list terminals)])
      (define decomposition `(Final ,terminal))
      (define refocused `(ZFinal ,terminal))
      (define machine `(MFinal ,terminal))
      (define compressed `(BFinal ,terminal))
      (define big `(BigFinal ,terminal))
      (check-equal?
       (judgment-holds
        (delay/stage-extension/N/D-decompose ,terminal D)
        D)
       (list decomposition))
      (check-equal?
       (term
        (delay/stage-extension/N/Z-refocus-phase ,decomposition))
       refocused)
      (check-equal?
       (term (delay/stage-extension/N/M-machineize ,refocused))
       machine)
      (check-equal?
       (term (delay/stage-extension/N/B-compress ,machine))
       compressed)
      (check-equal?
       (judgment-holds
        (delay/stage-extension/N/Big-promote ,compressed Big)
        Big)
       (list big))
      (check-equal?
       (judgment-holds
        (delay/stage-extension/N/Big-evaluate ,terminal Big)
        Big)
       (list big))
      (check-equal?
       (term
        (delay/stage-extension/N/diagnostic-D->Z ,decomposition))
       refocused)
      (check-equal?
       (term
        (delay/stage-extension/N/diagnostic-encode-ZM ,refocused))
       machine)
      (check-equal?
       (term
        (delay/stage-extension/N/diagnostic-encode-MB ,machine))
       compressed)
      (check-equal?
       (term
        (delay/stage-extension/N/diagnostic-readback-Big ,big))
       terminal)))

  (test-case "diagnostic transport observes the direct Delay carriers"
    (check-equal?
     (term
      (delay/stage-extension/N/diagnostic-encode-ZM
       (ZFrontier ,N-FORCE hole)))
     (term (MFrontier ,N-FORCE hole)))
    (check-equal?
     (term
      (delay/stage-extension/N/diagnostic-encode-MB
       (MFrontier ,N-FORCE hole)))
     (term (BFrontier ,N-FORCE hole)))
    (check-equal?
     (judgment-holds
      (delay/stage-extension/N/diagnostic-ZM-square
       (ZFrontier ,N-FORCE hole)
       RuleName_0 Z_1 M_0 M_1)
      (RuleName_0 Z_1 M_0 M_1))
     (list
      (list
       (term force-delay)
       (term (ZWork ,N-BODY (Forced (More hole))))
       (term (MFrontier ,N-FORCE hole))
       (term (MWork ,N-BODY (Forced (More hole)))))))
    (check-equal?
     (proof-count
      (build-derivations
       (delay/stage-extension/N/diagnostic-ZM-square
        (ZFrontier ,N-FORCE hole)
        RuleName_0 Z_1 M_0 M_1)))
     1)
    (check-equal?
     (judgment-holds
      (delay/stage-extension/N/diagnostic-MB-square
       (BFrontier ,N-FORCE hole)
       TransitionSpan_0 B_1 M_0 M_1)
      (TransitionSpan_0 B_1 M_0 M_1))
     (list
      (list
       (term (transition-span force-delay))
       (term (BRun ,N-BODY (Forced (More hole))))
       (term (MFrontier ,N-FORCE hole))
       (term (MWork ,N-BODY (Forced (More hole)))))))
    (check-equal?
     (proof-count
     (build-derivations
       (delay/stage-extension/N/diagnostic-MB-square
        (BFrontier ,N-FORCE hole)
        TransitionSpan_0 B_1 M_0 M_1)))
     1))

  (test-case "diagnostic transport materializes the selected failed carrier"
    (define summary
      (term (Owners (Owner (u:0) (label "failed")))))
    (define compressed
      (term (BDead ,summary (More hole))))
    (define machine
      (term (MFrontier (More (Dead ,summary)) hole)))
    (check-equal?
     (term
      (delay/stage-extension/S/diagnostic-decode-BM ,compressed))
     machine)
    (check-equal?
     (term
      (delay/stage-extension/S/diagnostic-encode-MB ,machine))
     compressed)
    (check-equal?
     (term
      (delay/stage-extension/S/diagnostic-readback-B ,compressed))
     (term (More (Dead ,summary))))
    (check-equal?
     (proof-count
      (build-derivations
       (delay/stage-extension/S/diagnostic-MB-corresponds
        ,machine B_0)))
     1)))

(module+ test
  (run-tests DELAY-STAGE-EXTENSION-TESTS))
