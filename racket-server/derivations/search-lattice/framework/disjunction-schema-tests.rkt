#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "./disjunction-schema-source-s-fixture.rkt"
         "./disjunction-schema-source-e-fixture.rkt"
         "./disjunction-schema-source-fixture.rkt")

(provide DISJUNCTION-SCHEMA-TESTS)

(define N-STATE
  '(state
    2
    ((0 (sym "shared")))
    ((0 (sym "blocked")))
    ((0 =? (sym "shared") (label "trail")))
    (label "state")))
(define S-STATE
  '(state () () () (label "state")))
(define OWNER-U0
  '(Owners (Owner (u:0) (label "u0"))))
(define OWNER-U1
  '(Owners (Owner (u:1) (label "u1"))))
(define OWNER-U2
  '(Owners (Owner (u:2) (label "u2"))))
(define OWNER-U2-U3
  '(Owners
    (Owner (u:2) (label "u2"))
    (Owner (u:3) (label "u3"))))

(define DISJUNCTION-SCHEMA-TESTS
  (test-suite
   "DISJUNCTION-SCHEMA-TESTS"

   (test-case "all five direct source equations are named and singleton"
     (define left
       `(Work (succeed (label "left")) ,N-STATE))
     (define right
       `(Work (fail (label "right")) ,N-STATE))
     (define returned `(Returned ,N-STATE))
     (check-equal?
      (disjunction-n-smoke-successors
       `(More
         (Work
          ((succeed (label "left"))
           ∨
           (fail (label "right"))
           (label "choice"))
          ,N-STATE)))
      (list
       (list 'expand-disjunction
             `(More (DisjL ,left ,right)))))
     (check-equal?
      (disjunction-n-smoke-successors
       `(More (DisjL (Dead 2) ,right)))
      (list (list 'skip-left-failure `(More ,right))))
     (check-equal?
      (disjunction-n-smoke-successors
       `(More
         (DisjL
          (DisjL ,returned ,left)
          ,right)))
      (list
       (list
        'reassociate-left-result
        `(More
          (DisjL
           ,returned
           (DisjL ,left ,right))))))
     (check-equal?
      (disjunction-n-smoke-successors
       `(More (DisjL ,returned ,right)))
      (list
       (list
        'commit-choice-answer
        `(Emit (Answer ,N-STATE) (More ,right)))))
     (check-equal?
      (disjunction-n-smoke-successors
       `(More
         (Conj
          (DisjL ,returned ,right)
          (succeed (label "continue")))))
      (list
       (list
        'resume-left-choice-success
        `(More
          (DisjL
           (Work (succeed (label "continue")) ,N-STATE)
           (Conj ,right (succeed (label "continue")))))))))

   (test-case "S resume preserves answer ownership on the resumed Work"
     (check-equal?
      (disjunction-s-smoke-successors
       `(More
         (Conj
          ,OWNER-U0
          (DisjL
           ,OWNER-U1
           (Returned ,OWNER-U2 ,S-STATE)
           (Dead ,OWNER-U2))
          (succeed (label "continue")))))
      (list
       (list
        'resume-left-choice-success
        `(More
          (DisjL
           (Owners
            (Owner (u:0) (label "u0"))
            (Owner (u:1) (label "u1")))
           (Work ,OWNER-U2 (succeed (label "continue")) ,S-STATE)
           (Conj
            (Owners)
            (Dead ,OWNER-U2)
            (succeed (label "continue")))))))))

   (test-case "S commit keeps the choice and answer prefixes distinct"
     (check-equal?
      (disjunction-s-smoke-successors
       `(More
         (DisjL
          ,OWNER-U0
          (Returned ,OWNER-U1 ,S-STATE)
          (Dead ,OWNER-U2))))
      (list
       (list
        'commit-choice-answer
        `(Emit
          ,OWNER-U0
          (Answer ,OWNER-U1 ,S-STATE)
          (More (Dead ,OWNER-U2)))))))

   (test-case "Choice and Emit each have one raw WF proof"
     (define left
       `(Work (succeed (label "left")) ,N-STATE))
     (define right
       `(Work (fail (label "right")) ,N-STATE))
     (check-equal?
      (length
       (build-derivations
        (wf-disjunction-n-smoke?
         (More (DisjL ,left ,right)))))
      1)
     (check-equal?
      (length
       (build-derivations
        (wf-disjunction-n-smoke?
         (Emit (Answer ,N-STATE) (More (Dead 2))))))
      1))

   (test-case "Emit residual allocation excludes the settled answer support"
     (check-equal?
      (disjunction-s-smoke-successors
       `(Emit
         ,OWNER-U0
         (Answer ,OWNER-U1 ,S-STATE)
         (More
          (Work
           (Owners)
           (∃ (x:q)
              (x:q =? (nat 7) (label "body"))
              (label "fresh"))
           ,S-STATE))))
      (list
       (list
        'allocate-fresh
        `(Emit
          ,OWNER-U0
          (Answer ,OWNER-U1 ,S-STATE)
          (More
           (Work
            (Owners (Owner (u:1) (label "fresh")))
            (u:1 =? (nat 7) (label "body"))
            ,S-STATE)))))))

   (test-case "Q retains incomparable sibling supports through S to E to N"
     (define source
       `(More
         (DisjL
          ,OWNER-U0
          (Work
           ,OWNER-U1
           (succeed (label "left"))
           (state () () () (label "left-state")))
          (Work
           ,OWNER-U2-U3
           (fail (label "right"))
           (state () () () (label "right-state"))))))
     (define neutral-s (q-export/disjunction-s-smoke source))
     (define in-e (q-rebuild/disjunction-e-smoke neutral-s))
     (check-equal?
      (q-rebuild/disjunction-s-smoke neutral-s)
      source)
     (check-equal?
      in-e
      `(More
        (DisjL
         (Work
          (succeed (label "left"))
          (state (Support u:0 u:1) () () () (label "left-state")))
         (Work
          (fail (label "right"))
          (state
           (Support u:0 u:2 u:3)
           () () () (label "right-state"))))))
     (check-equal?
      (q-rebuild/disjunction-n-smoke
       (q-export/disjunction-e-smoke in-e))
     `(More
        (DisjL
         (Work
          (succeed (label "left"))
          (state 2 () () () (label "left-state")))
         (Work
          (fail (label "right"))
          (state 3 () () () (label "right-state")))))))

   (test-case "Q focus traverses an emitted-answer spine"
     (define focused
       `(Returned ,OWNER-U2 ,S-STATE))
     (define focus
       `(Emit
         ,OWNER-U0
         (Answer ,OWNER-U1 ,S-STATE)
         (More ,(term hole))))
     (define neutral
       (q-focus-export/disjunction-s-smoke focused focus))
     (check-equal?
      (q-focus-rebuild/disjunction-s-smoke neutral)
      (list focused focus)))))

(module+ test
  (run-tests DISJUNCTION-SCHEMA-TESTS))
