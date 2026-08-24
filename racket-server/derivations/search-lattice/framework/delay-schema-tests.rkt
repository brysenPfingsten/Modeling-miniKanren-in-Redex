#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "./delay-schema-source-fixture.rkt"
         "./delay-schema-prefix-fixture.rkt"
         "./delay-schema-extension-fixture.rkt")

(provide DELAY-SCHEMA-TESTS)

(define N-STATE
  '(state 0 () () () (label "state")))

(define S-STATE
  '(state () () () (label "state")))

(define OWNER-U0
  '(Owners (Owner (u:0) (label "outer"))))

(define OWNER-U1
  '(Owners (Owner (u:1) (label "pending"))))

(define OWNER-U2
  '(Owners (Owner (u:2) (label "box"))))

(define DELAY-SCHEMA-TESTS
  (test-suite
   "DELAY-SCHEMA-TESTS"

   (test-case "direct source equations retain raw labels and multiplicity"
     (define body
       `(Work (succeed (label "body")) ,N-STATE))
     (check-equal?
      (delay-n-smoke-successors
       `(More
         (Work
          (suspend
           (succeed (label "body"))
           (label "delay"))
          ,N-STATE)))
      (list
       (list
        'suspend-goal
        `(More (PendingDelay ,body)))))
     (check-equal?
      (delay-n-smoke-successors
       `(More (PendingDelay ,body)))
      (list
       (list 'force-delay `(Forced (More ,body)))))
     (check-equal?
      (delay-n-smoke-successors
       `(More
         (Conj
          (PendingDelay ,body)
          (succeed (label "right")))))
      (list
       (list
        'bubble-delay-through-conj
        `(More
          (PendingDelay
           (Conj ,body (succeed (label "right")))))))))

   (test-case "pending and forced prefixes come from distinct view fields"
     (define body
       `(Work (Owners) (succeed (label "body")) ,S-STATE))
     (check-equal?
      (delay-s-asymmetric-successors
       `(More (PendingAsymmetric ,OWNER-U0 ,body)))
      (list
       (list
        'force-delay
        `(ForcedAsymmetric (Owners) (More ,body))))))

   (test-case "S bubble transfers through a nested pending wrapper"
     (define body
       `(Work (Owners) (succeed (label "body")) ,S-STATE))
     (check-equal?
      (delay-s-smoke-successors
       `(More
         (Conj
          ,OWNER-U0
          (PendingDelay ,OWNER-U1 (PendingDelay ,OWNER-U2 ,body))
          (succeed (label "right")))))
      (list
       (list
        'bubble-delay-through-conj
        `(More
          (PendingDelay
           ,OWNER-U0
           (Conj
            (Owners)
            (PendingDelay
             (Owners
              (Owner (u:1) (label "pending"))
             (Owner (u:2) (label "box")))
             ,body)
            (succeed (label "right")))))))))

   (test-case "inherited allocation uses Delay goal and focus extensions"
     (check-equal?
      (delay-n-smoke-successors
       `(More
         (Work
          (∃ (x:q)
             (suspend
              (x:q =? (nat 1) (label "unify"))
              (label "delay"))
             (label "fresh"))
          ,N-STATE)))
      (list
       (list
        'allocate-fresh
        `(More
          (Work
           (suspend
            (0 =? (nat 1) (label "unify"))
            (label "delay"))
           (state 1 () () () (label "state")))))))

     ;; The inherited S allocation equation sees the Owner prefix contributed
     ;; by Forced and therefore chooses u:1 rather than reusing u:0.
     (check-equal?
      (delay-s-smoke-successors
       `(Forced
         ,OWNER-U0
         (More
          (Work
           (Owners)
           (∃ (x:q)
              (suspend
               (x:q =? (nat 1) (label "unify"))
               (label "delay"))
              (label "fresh"))
           ,S-STATE))))
      (list
       (list
        'allocate-fresh
        `(Forced
          ,OWNER-U0
          (More
           (Work
            (Owners (Owner (u:1) (label "fresh")))
            (suspend
             (u:1 =? (nat 1) (label "unify"))
             (label "delay"))
            ,S-STATE)))))))

   (test-case "binary WF carries prefixes through Pending and Forced"
     (check-equal?
      (judgment-holds
       (live-supply/delay-n-smoke
        (PendingDelay (Dead 0))
        0
        supply_out)
       supply_out)
      '(0))
     (check-true
      (judgment-holds
       (wf-delay-n-smoke?
        (More (PendingDelay (Dead 0))))))
     (check-true
      (judgment-holds
       (wf-delay-n-smoke?
        (Forced
         (More
          (PendingDelay
           (Work
            (succeed (label "body"))
            (state 0 () () () (label "state")))))))))
     (check-true
      (judgment-holds
       (wf-delay-s-smoke?
        (Forced
         (Owners (Owner (u:0) (label "forced")))
         (More
          (PendingDelay
           (Owners (Owner (u:1) (label "pending")))
           (Work
            (Owners)
            (succeed (label "body"))
            (state () () () (label "state"))))))))))

   (test-case "Q retains Pending and the forced spine directly"
     (define n-frontier
       `(Forced
         (More
          (PendingDelay
           (Work (succeed (label "body")) ,N-STATE)))))
     (define s-frontier
       `(Forced
         ,OWNER-U0
         (More
          (PendingDelay
           ,OWNER-U1
           (Work (Owners) (succeed (label "body")) ,S-STATE)))))
     (check-equal?
      (q-rebuild/delay-n-smoke
       (q-export/delay-n-smoke n-frontier))
      n-frontier)
     (check-equal?
      (q-rebuild/delay-s-smoke
       (q-export/delay-s-smoke s-frontier))
      s-frontier)
     (check-true
      (match
        (q-focus-export/delay-n-smoke
         `(PendingDelay
           (Work (succeed (label "body")) ,N-STATE))
         `(Forced (More ,(term hole))))
        [`(q-focused
           (q-pending ,_ ,_)
           (q-work-focus
            (q-spine-forced ,_ q-spine-hole)
            q-focus-hole))
         #t]
        [_ #f])))

   (test-case "a second source feature lifts Delay rules without copying them"
     (define body
       `(Work (Owners) (succeed (label "body")) ,S-STATE))
     (check-equal?
      (delay-box-successors
       `(More
         (Box
          ,OWNER-U0
          (Work
           (Owners)
           (suspend
            (succeed (label "body"))
            (label "delay"))
           ,S-STATE))))
      (list
       (list
        'suspend-goal
        `(More
          (Box
           ,OWNER-U0
           (PendingDelay (Owners) ,body))))))
     (check-equal?
      (delay-box-successors
       `(More
         (Conj
          ,OWNER-U0
          (PendingDelay
           ,OWNER-U1
           (Box ,OWNER-U2 ,body))
          (succeed (label "right")))))
      (list
       (list
        'bubble-delay-through-conj
        `(More
          (PendingDelay
           ,OWNER-U0
           (Conj
            (Owners)
            (Box
             (Owners
              (Owner (u:1) (label "pending"))
              (Owner (u:2) (label "box")))
             ,body)
            (succeed (label "right"))))))))
     (check-equal?
      (delay-box-successors
       `(More
         (PendingDelay
          ,OWNER-U0
          (Box ,OWNER-U1 ,body))))
      (list
       (list
        'force-delay
        `(Forced
          ,OWNER-U0
          (More (Box ,OWNER-U1 ,body)))))))

   (test-case "second-layer allocation, WF, and Q use lifted dependencies"
     (check-equal?
      (delay-box-successors
       `(More
         (Box
          ,OWNER-U0
          (Work
           (Owners)
           (∃ (x:q)
              (suspend
               (x:q =? (nat 1) (label "unify"))
               (label "delay"))
              (label "fresh"))
           ,S-STATE))))
      (list
       (list
        'allocate-fresh
        `(More
          (Box
           ,OWNER-U0
           (Work
            (Owners (Owner (u:1) (label "fresh")))
            (suspend
             (u:1 =? (nat 1) (label "unify"))
             (label "delay"))
            ,S-STATE))))))
     (define frontier
       `(Forced
         ,OWNER-U0
         (More
          (PendingDelay
           ,OWNER-U1
           (Box
            ,OWNER-U2
            (Work
             (Owners)
             (succeed (label "body"))
             ,S-STATE))))))
     (check-true
      (judgment-holds (wf-delay-box? ,frontier)))
     (define neutral (q-export/delay-box frontier))
     (check-match
      neutral
      `(q-forced
        ,OWNER-U0
        (q-more
         (q-pending
          ,OWNER-U1
          (q-box ,OWNER-U2 ,_)))))
     (check-equal? (q-rebuild/delay-box neutral) frontier))))

(module+ test
  (run-tests DELAY-SCHEMA-TESTS))
