#lang racket

(require (prefix-in delay: "../delay/corpus.rkt")
         (prefix-in disjunction: "../disjunction/corpus.rkt"))

(provide SEARCH-RULE-NAMES
         SEARCH-FEATURE-RULE-NAMES
         SEARCH-B-SINGLETON-RULE-NAMES
         EXPECTED-SEARCH-MIXED-CASE-NAMES
         EXPECTED-SEARCH-TRACE-NAMES
         (struct-out search-rule-case)
         (struct-out search-mixed-case)
         (struct-out search-trace-case)
         (struct-out search-negative-case)
         (struct-out search-row-corpus)
         search-row-source-ref
         SEARCH-CORPUS/S
         SEARCH-CORPUS/E
         SEARCH-CORPUS/N)

;; Search is a zero-rule join.  This module is deliberately plain data: it
;; imports only the two API-neutral child corpora, never a generated relation,
;; renderer, representation map, or oracle.  The mixed S/E/N terms below are
;; stated literally rather than being produced by a Q map.

(define SEARCH-FEATURE-RULE-NAMES
  (append delay:DELAY-OWNED-RULE-NAMES
          disjunction:DISJUNCTION-OWNED-RULE-NAMES))

(define SEARCH-RULE-NAMES
  (sort (append disjunction:CORE-RULE-NAMES SEARCH-FEATURE-RULE-NAMES)
        symbol<?))

;; Neither child contributes a compression follower.  Every Delay or
;; Disjunction occurrence remains a singleton, including an immediate boundary
;; between the two features.
(define SEARCH-B-SINGLETON-RULE-NAMES
  (append delay:DELAY-OWNED-RULE-NAMES
          disjunction:DISJUNCTION-OWNED-RULE-NAMES))

(define EXPECTED-SEARCH-MIXED-CASE-NAMES
  '(suspend-under-emit
    bubble-choice-payload
    force-under-emit
    expand-under-forced
    skip-to-pending
    reassociate-pending-residual
    commit-under-forced
    resume-with-delayed-residual))

(define EXPECTED-SEARCH-TRACE-NAMES
  '(suspended-choice-left-failure
    left-failure-then-delayed-right
    answer-then-delayed-answer))

(struct search-rule-case (label source target) #:transparent)
(struct search-mixed-case (name label source target) #:transparent)
(struct search-trace-case (name source labels spans terminal) #:transparent)
(struct search-negative-case (name source) #:transparent)

(struct search-row-corpus
  (name
   rule-sources
   feature-rule-cases
   mixed-feature-cases
   finite-traces
   joint-focus-witness
   scheduler-barrier
   grammar-negatives
   wf-negatives)
  #:transparent)

(define (search-row-source-ref corpus rule-name)
  (match (assoc rule-name (search-row-corpus-rule-sources corpus))
    [(list _ source) source]
    [#f
     (error 'search-row-source-ref
            "row ~a has no representative for ~a"
            (search-row-corpus-name corpus)
            rule-name)]))

(define (delay-rule-case->search rule-case)
  (search-rule-case
   (delay:delay-rule-case-label rule-case)
   (delay:delay-rule-case-source rule-case)
   (delay:delay-rule-case-target rule-case)))

(define (disjunction-rule-case->search rule-case)
  (search-rule-case
   (disjunction:disjunction-rule-case-label rule-case)
   (disjunction:disjunction-rule-case-source rule-case)
   (disjunction:disjunction-rule-case-target rule-case)))

(define (feature-rule-cases delay-corpus disjunction-corpus)
  (append
   (map delay-rule-case->search
        (delay:delay-row-corpus-owned-rule-cases delay-corpus))
   (map disjunction-rule-case->search
        (disjunction:disjunction-row-corpus-owned-rule-cases
         disjunction-corpus))))

(define (rule-sources disjunction-corpus feature-cases)
  (append
   (disjunction:disjunction-row-corpus-core-rule-sources
    disjunction-corpus)
   (for/list ([rule-case (in-list feature-cases)])
     (list (search-rule-case-label rule-case)
           (search-rule-case-source rule-case)))))

(define STATE-TAG '(label "search-state"))

(define OWNERS-EMPTY '(Owners))
(define OWNERS-U0 '(Owners (Owner (u:0) (label "u0"))))
(define OWNERS-U1 '(Owners (Owner (u:1) (label "u1"))))
(define OWNERS-U2 '(Owners (Owner (u:2) (label "u2"))))
(define OWNERS-U3 '(Owners (Owner (u:3) (label "u3"))))
(define OWNERS-U4 '(Owners (Owner (u:4) (label "u4"))))
(define SIGMA/S `(state () () () ,STATE-TAG))
(define SIGMA/E `(state (Support) () () () ,STATE-TAG))
(define SIGMA/N `(state 0 () () () ,STATE-TAG))

(define SUCCEED-GOAL '(succeed (label "mixed-success")))
(define FAIL-GOAL '(fail (label "mixed-failure")))
(define RIGHT-GOAL '(succeed (label "mixed-right")))

;; Exactly one mixed-context witness for each of the eight inherited feature
;; rules.  Empty prefixes make the three rows literal Q counterparts while the
;; surrounding opposite-feature constructor still exercises transitive goal,
;; WorkOwnerSlot, WorkPath, and SpineContext lifting.

(define MIXED-CASES/S
  (list
   (search-mixed-case
    'suspend-under-emit
    'suspend-goal
    `(Emit
      ,OWNERS-EMPTY
      (Answer ,OWNERS-EMPTY ,SIGMA/S)
      (More
       (Work
        ,OWNERS-EMPTY
        (suspend ,SUCCEED-GOAL (label "suspend-under-emit"))
        ,SIGMA/S)))
    `(Emit
      ,OWNERS-EMPTY
      (Answer ,OWNERS-EMPTY ,SIGMA/S)
      (More
       (PendingDelay
        ,OWNERS-EMPTY
        (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S)))))
   (search-mixed-case
    'bubble-choice-payload
    'bubble-delay-through-conj
    `(More
      (Conj
       ,OWNERS-EMPTY
       (PendingDelay
        ,OWNERS-EMPTY
        (DisjL
         ,OWNERS-EMPTY
         (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S)
         (Dead ,OWNERS-EMPTY)))
       ,RIGHT-GOAL))
    `(More
      (PendingDelay
       ,OWNERS-EMPTY
       (Conj
        ,OWNERS-EMPTY
        (DisjL
         ,OWNERS-EMPTY
         (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S)
         (Dead ,OWNERS-EMPTY))
        ,RIGHT-GOAL))))
   (search-mixed-case
    'force-under-emit
    'force-delay
    `(Emit
      ,OWNERS-EMPTY
      (Answer ,OWNERS-EMPTY ,SIGMA/S)
      (More
       (PendingDelay
        ,OWNERS-EMPTY
        (DisjL
         ,OWNERS-EMPTY
         (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S)
         (Dead ,OWNERS-EMPTY)))))
    `(Emit
      ,OWNERS-EMPTY
      (Answer ,OWNERS-EMPTY ,SIGMA/S)
      (Forced
       ,OWNERS-EMPTY
       (More
        (DisjL
         ,OWNERS-EMPTY
         (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S)
         (Dead ,OWNERS-EMPTY))))))
   (search-mixed-case
    'expand-under-forced
    'expand-disjunction
    `(Forced
      ,OWNERS-EMPTY
      (More
       (Work
        ,OWNERS-EMPTY
        (,FAIL-GOAL ∨ ,SUCCEED-GOAL (label "choice-under-forced"))
        ,SIGMA/S)))
    `(Forced
      ,OWNERS-EMPTY
      (More
       (DisjL
        ,OWNERS-EMPTY
        (Work ,OWNERS-EMPTY ,FAIL-GOAL ,SIGMA/S)
        (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S)))))
   (search-mixed-case
    'skip-to-pending
    'skip-left-failure
    `(More
      (DisjL
       ,OWNERS-EMPTY
       (Dead ,OWNERS-EMPTY)
       (PendingDelay
        ,OWNERS-EMPTY
        (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S))))
    `(More
      (PendingDelay
       ,OWNERS-EMPTY
       (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S))))
   (search-mixed-case
    'reassociate-pending-residual
    'reassociate-left-result
    `(More
      (DisjL
       ,OWNERS-EMPTY
       (DisjL
        ,OWNERS-EMPTY
        (Returned ,OWNERS-EMPTY ,SIGMA/S)
        (Dead ,OWNERS-EMPTY))
       (PendingDelay
        ,OWNERS-EMPTY
        (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S))))
    `(More
      (DisjL
       ,OWNERS-EMPTY
       (Returned ,OWNERS-EMPTY ,SIGMA/S)
       (DisjL
        ,OWNERS-EMPTY
        (Dead ,OWNERS-EMPTY)
        (PendingDelay
         ,OWNERS-EMPTY
         (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S))))))
   (search-mixed-case
    'commit-under-forced
    'commit-choice-answer
    `(Forced
      ,OWNERS-EMPTY
      (More
       (DisjL
        ,OWNERS-EMPTY
        (Returned ,OWNERS-EMPTY ,SIGMA/S)
        (PendingDelay
         ,OWNERS-EMPTY
         (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S)))))
    `(Forced
      ,OWNERS-EMPTY
      (Emit
       ,OWNERS-EMPTY
       (Answer ,OWNERS-EMPTY ,SIGMA/S)
       (More
        (PendingDelay
         ,OWNERS-EMPTY
         (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S))))))
   (search-mixed-case
    'resume-with-delayed-residual
    'resume-left-choice-success
    `(Forced
      ,OWNERS-EMPTY
      (More
       (Conj
        ,OWNERS-EMPTY
        (DisjL
         ,OWNERS-EMPTY
         (Returned ,OWNERS-EMPTY ,SIGMA/S)
         (PendingDelay
          ,OWNERS-EMPTY
          (Work ,OWNERS-EMPTY ,FAIL-GOAL ,SIGMA/S)))
        ,RIGHT-GOAL)))
    `(Forced
      ,OWNERS-EMPTY
      (More
       (DisjL
        ,OWNERS-EMPTY
        (Work ,OWNERS-EMPTY ,RIGHT-GOAL ,SIGMA/S)
        (Conj
         ,OWNERS-EMPTY
         (PendingDelay
          ,OWNERS-EMPTY
          (Work ,OWNERS-EMPTY ,FAIL-GOAL ,SIGMA/S))
         ,RIGHT-GOAL)))))))

(define MIXED-CASES/E
  (list
   (search-mixed-case
    'suspend-under-emit 'suspend-goal
    `(Emit (Answer ,SIGMA/E)
           (More (Work (suspend ,SUCCEED-GOAL (label "suspend-under-emit"))
                       ,SIGMA/E)))
    `(Emit (Answer ,SIGMA/E)
           (More (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/E)))))
   (search-mixed-case
    'bubble-choice-payload 'bubble-delay-through-conj
    `(More (Conj (PendingDelay
                   (DisjL (Work ,SUCCEED-GOAL ,SIGMA/E) (Dead (Support))))
                 ,RIGHT-GOAL))
    `(More (PendingDelay
            (Conj (DisjL (Work ,SUCCEED-GOAL ,SIGMA/E) (Dead (Support)))
                  ,RIGHT-GOAL))))
   (search-mixed-case
    'force-under-emit 'force-delay
    `(Emit (Answer ,SIGMA/E)
           (More (PendingDelay
                  (DisjL (Work ,SUCCEED-GOAL ,SIGMA/E) (Dead (Support))))))
    `(Emit (Answer ,SIGMA/E)
           (Forced
            (More (DisjL (Work ,SUCCEED-GOAL ,SIGMA/E) (Dead (Support)))))))
   (search-mixed-case
    'expand-under-forced 'expand-disjunction
    `(Forced
      (More
       (Work (,FAIL-GOAL ∨ ,SUCCEED-GOAL (label "choice-under-forced"))
             ,SIGMA/E)))
    `(Forced
      (More
       (DisjL (Work ,FAIL-GOAL ,SIGMA/E)
              (Work ,SUCCEED-GOAL ,SIGMA/E)))))
   (search-mixed-case
    'skip-to-pending 'skip-left-failure
    `(More (DisjL (Dead (Support))
                  (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/E))))
    `(More (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/E))))
   (search-mixed-case
    'reassociate-pending-residual 'reassociate-left-result
    `(More
      (DisjL
       (DisjL (Returned ,SIGMA/E) (Dead (Support)))
       (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/E))))
    `(More
      (DisjL
       (Returned ,SIGMA/E)
       (DisjL (Dead (Support))
              (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/E))))))
   (search-mixed-case
    'commit-under-forced 'commit-choice-answer
    `(Forced
      (More
       (DisjL (Returned ,SIGMA/E)
              (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/E)))))
    `(Forced
      (Emit (Answer ,SIGMA/E)
            (More (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/E))))))
   (search-mixed-case
    'resume-with-delayed-residual 'resume-left-choice-success
    `(Forced
      (More
       (Conj
        (DisjL (Returned ,SIGMA/E)
               (PendingDelay (Work ,FAIL-GOAL ,SIGMA/E)))
        ,RIGHT-GOAL)))
    `(Forced
      (More
       (DisjL
        (Work ,RIGHT-GOAL ,SIGMA/E)
        (Conj (PendingDelay (Work ,FAIL-GOAL ,SIGMA/E)) ,RIGHT-GOAL)))))))

(define MIXED-CASES/N
  (list
   (search-mixed-case
    'suspend-under-emit 'suspend-goal
    `(Emit (Answer ,SIGMA/N)
           (More (Work (suspend ,SUCCEED-GOAL (label "suspend-under-emit"))
                       ,SIGMA/N)))
    `(Emit (Answer ,SIGMA/N)
           (More (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/N)))))
   (search-mixed-case
    'bubble-choice-payload 'bubble-delay-through-conj
    `(More (Conj (PendingDelay (DisjL (Work ,SUCCEED-GOAL ,SIGMA/N) (Dead 0)))
                 ,RIGHT-GOAL))
    `(More (PendingDelay
            (Conj (DisjL (Work ,SUCCEED-GOAL ,SIGMA/N) (Dead 0))
                  ,RIGHT-GOAL))))
   (search-mixed-case
    'force-under-emit 'force-delay
    `(Emit (Answer ,SIGMA/N)
           (More (PendingDelay
                  (DisjL (Work ,SUCCEED-GOAL ,SIGMA/N) (Dead 0)))))
    `(Emit (Answer ,SIGMA/N)
           (Forced (More (DisjL (Work ,SUCCEED-GOAL ,SIGMA/N) (Dead 0))))))
   (search-mixed-case
    'expand-under-forced 'expand-disjunction
    `(Forced
      (More
       (Work (,FAIL-GOAL ∨ ,SUCCEED-GOAL (label "choice-under-forced"))
             ,SIGMA/N)))
    `(Forced
      (More
       (DisjL (Work ,FAIL-GOAL ,SIGMA/N)
              (Work ,SUCCEED-GOAL ,SIGMA/N)))))
   (search-mixed-case
    'skip-to-pending 'skip-left-failure
    `(More (DisjL (Dead 0)
                  (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/N))))
    `(More (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/N))))
   (search-mixed-case
    'reassociate-pending-residual 'reassociate-left-result
    `(More
      (DisjL
       (DisjL (Returned ,SIGMA/N) (Dead 0))
       (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/N))))
    `(More
      (DisjL
       (Returned ,SIGMA/N)
       (DisjL (Dead 0) (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/N))))))
   (search-mixed-case
    'commit-under-forced 'commit-choice-answer
    `(Forced
      (More
       (DisjL (Returned ,SIGMA/N)
              (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/N)))))
    `(Forced
      (Emit (Answer ,SIGMA/N)
            (More (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/N))))))
   (search-mixed-case
    'resume-with-delayed-residual 'resume-left-choice-success
    `(Forced
      (More
       (Conj
        (DisjL (Returned ,SIGMA/N)
               (PendingDelay (Work ,FAIL-GOAL ,SIGMA/N)))
        ,RIGHT-GOAL)))
    `(Forced
      (More
       (DisjL
        (Work ,RIGHT-GOAL ,SIGMA/N)
        (Conj (PendingDelay (Work ,FAIL-GOAL ,SIGMA/N)) ,RIGHT-GOAL)))))))

(define SUSPENDED-CHOICE-LABELS
  '(suspend-goal force-delay expand-disjunction fail skip-left-failure
    succeed finish-success))
(define SUSPENDED-CHOICE-SPANS
  '((transition-span suspend-goal)
    (transition-span force-delay)
    (transition-span expand-disjunction)
    (transition-span fail)
    (transition-span skip-left-failure)
    (transition-span succeed finish-success)))

(define LEFT-FAILURE-DELAY-LABELS
  '(expand-disjunction fail skip-left-failure suspend-goal force-delay
    succeed finish-success))
(define LEFT-FAILURE-DELAY-SPANS
  '((transition-span expand-disjunction)
    (transition-span fail)
    (transition-span skip-left-failure)
    (transition-span suspend-goal)
    (transition-span force-delay)
    (transition-span succeed finish-success)))

(define ANSWER-THEN-DELAY-LABELS
  '(expand-disjunction succeed commit-choice-answer suspend-goal force-delay
    succeed finish-success))
(define ANSWER-THEN-DELAY-SPANS
  '((transition-span expand-disjunction)
    (transition-span succeed)
    (transition-span commit-choice-answer)
    (transition-span suspend-goal)
    (transition-span force-delay)
    (transition-span succeed finish-success)))

(define TRACES/S
  (list
   (search-trace-case
    'suspended-choice-left-failure
    `(More
      (Work
       ,OWNERS-EMPTY
       (suspend
        (,FAIL-GOAL ∨ ,SUCCEED-GOAL (label "suspended-choice"))
        (label "outer-suspend"))
       ,SIGMA/S))
    SUSPENDED-CHOICE-LABELS
    SUSPENDED-CHOICE-SPANS
    `(Forced
      ,OWNERS-EMPTY
      (Last ,OWNERS-EMPTY (Answer ,OWNERS-EMPTY ,SIGMA/S))))
   (search-trace-case
    'left-failure-then-delayed-right
    `(More
      (Work
       ,OWNERS-EMPTY
       (,FAIL-GOAL
        ∨
        (suspend ,SUCCEED-GOAL (label "right-delay"))
        (label "choice"))
       ,SIGMA/S))
    LEFT-FAILURE-DELAY-LABELS
    LEFT-FAILURE-DELAY-SPANS
    `(Forced
      ,OWNERS-EMPTY
      (Last ,OWNERS-EMPTY (Answer ,OWNERS-EMPTY ,SIGMA/S))))
   (search-trace-case
    'answer-then-delayed-answer
    `(More
      (Work
       ,OWNERS-EMPTY
       (,SUCCEED-GOAL
        ∨
        (suspend ,RIGHT-GOAL (label "right-delay"))
        (label "choice"))
       ,SIGMA/S))
    ANSWER-THEN-DELAY-LABELS
    ANSWER-THEN-DELAY-SPANS
    `(Emit
       ,OWNERS-EMPTY
       (Answer ,OWNERS-EMPTY ,SIGMA/S)
       (Forced
        ,OWNERS-EMPTY
       (Last ,OWNERS-EMPTY (Answer ,OWNERS-EMPTY ,SIGMA/S)))))))

(define TRACES/E
  (list
   (search-trace-case
    'suspended-choice-left-failure
    `(More
      (Work
       (suspend (,FAIL-GOAL ∨ ,SUCCEED-GOAL (label "suspended-choice"))
                (label "outer-suspend"))
       ,SIGMA/E))
    SUSPENDED-CHOICE-LABELS SUSPENDED-CHOICE-SPANS
    `(Forced (Last (Answer ,SIGMA/E))))
   (search-trace-case
    'left-failure-then-delayed-right
    `(More
      (Work
       (,FAIL-GOAL ∨
        (suspend ,SUCCEED-GOAL (label "right-delay"))
        (label "choice"))
       ,SIGMA/E))
    LEFT-FAILURE-DELAY-LABELS LEFT-FAILURE-DELAY-SPANS
    `(Forced (Last (Answer ,SIGMA/E))))
   (search-trace-case
    'answer-then-delayed-answer
    `(More
      (Work
       (,SUCCEED-GOAL ∨
        (suspend ,RIGHT-GOAL (label "right-delay"))
        (label "choice"))
       ,SIGMA/E))
    ANSWER-THEN-DELAY-LABELS ANSWER-THEN-DELAY-SPANS
    `(Emit (Answer ,SIGMA/E) (Forced (Last (Answer ,SIGMA/E)))))))

(define TRACES/N
  (list
   (search-trace-case
    'suspended-choice-left-failure
    `(More
      (Work
       (suspend (,FAIL-GOAL ∨ ,SUCCEED-GOAL (label "suspended-choice"))
                (label "outer-suspend"))
       ,SIGMA/N))
    SUSPENDED-CHOICE-LABELS SUSPENDED-CHOICE-SPANS
    `(Forced (Last (Answer ,SIGMA/N))))
   (search-trace-case
    'left-failure-then-delayed-right
    `(More
      (Work
       (,FAIL-GOAL ∨
        (suspend ,SUCCEED-GOAL (label "right-delay"))
        (label "choice"))
       ,SIGMA/N))
    LEFT-FAILURE-DELAY-LABELS LEFT-FAILURE-DELAY-SPANS
    `(Forced (Last (Answer ,SIGMA/N))))
   (search-trace-case
    'answer-then-delayed-answer
    `(More
      (Work
       (,SUCCEED-GOAL ∨
        (suspend ,RIGHT-GOAL (label "right-delay"))
        (label "choice"))
       ,SIGMA/N))
    ANSWER-THEN-DELAY-LABELS ANSWER-THEN-DELAY-SPANS
    `(Emit (Answer ,SIGMA/N) (Forced (Last (Answer ,SIGMA/N)))))))

(define JOINT-FOCUS/S
  `(Forced
    ,OWNERS-U0
    (Emit
     ,OWNERS-U1
     (Answer ,OWNERS-U2 ,SIGMA/S)
     (Forced
      ,OWNERS-U2
      (More
       (DisjL
        ,OWNERS-U3
        (PendingDelay
         ,OWNERS-U4
         (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S))
        (Dead ,OWNERS-U4)))))))

(define JOINT-FOCUS/E
  `(Forced
    (Emit
     (Answer
      (state (Support u:0 u:1 u:2) () () () ,STATE-TAG))
     (Forced
      (More
       (DisjL
        (PendingDelay
         (Work
          ,SUCCEED-GOAL
          (state (Support u:0 u:1 u:2 u:3 u:4) () () () ,STATE-TAG)))
        (Dead (Support u:0 u:1 u:2 u:3 u:4))))))))

(define JOINT-FOCUS/N
  `(Forced
    (Emit
     (Answer (state 3 () () () ,STATE-TAG))
     (Forced
      (More
       (DisjL
        (PendingDelay
         (Work ,SUCCEED-GOAL (state 5 () () () ,STATE-TAG)))
        (Dead 5)))))))

;; This is intentionally WF but has no Search-join successor: after emitting an
;; answer, forcing still cannot cross the active DisjL branch in the residual.
;; A scheduler may own such a turn later, but the zero-rule Search join must not
;; invent it.
(define SCHEDULER-BARRIER/S
  `(Emit
    ,OWNERS-EMPTY
    (Answer ,OWNERS-EMPTY ,SIGMA/S)
    (More
     (DisjL
      ,OWNERS-EMPTY
      (PendingDelay
       ,OWNERS-EMPTY
       (Work ,OWNERS-EMPTY ,SUCCEED-GOAL ,SIGMA/S))
      (Dead ,OWNERS-EMPTY)))))
(define SCHEDULER-BARRIER/E
  `(Emit
    (Answer ,SIGMA/E)
    (More
     (DisjL
      (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/E))
      (Dead (Support))))))
(define SCHEDULER-BARRIER/N
  `(Emit
    (Answer ,SIGMA/N)
    (More
     (DisjL
      (PendingDelay (Work ,SUCCEED-GOAL ,SIGMA/N))
      (Dead 0)))))

(define GRAMMAR-NEGATIVES/S
  (list
   (search-negative-case
    'rail-right-active-carrier
    `(More (DisjR ,OWNERS-EMPTY (Dead ,OWNERS-EMPTY) (Dead ,OWNERS-EMPTY))))
   (search-negative-case
    'pending-as-frontier
    `(PendingDelay ,OWNERS-EMPTY (Dead ,OWNERS-EMPTY)))))
(define GRAMMAR-NEGATIVES/E
  (list
   (search-negative-case
    'rail-right-active-carrier
    '(More (DisjR (Dead (Support)) (Dead (Support)))))
   (search-negative-case
    'pending-as-frontier
    '(PendingDelay (Dead (Support))))))
(define GRAMMAR-NEGATIVES/N
  (list
   (search-negative-case
    'rail-right-active-carrier
    '(More (DisjR (Dead 0) (Dead 0))))
   (search-negative-case 'pending-as-frontier '(PendingDelay (Dead 0)))))

(define WF-NEGATIVES/S
  (list
   (search-negative-case
    'unallocated-right-branch-under-forced
    `(Forced
      ,OWNERS-EMPTY
      (More
       (DisjL
        ,OWNERS-EMPTY
        (Dead ,OWNERS-EMPTY)
        (Work
         ,OWNERS-EMPTY
         (u:9 =? (nat 0) (label "unallocated"))
         ,SIGMA/S)))))))
(define WF-NEGATIVES/E
  (list
   (search-negative-case
    'unallocated-right-branch-under-forced
    `(Forced
      (More
       (DisjL
        (Dead (Support))
        (Work (u:9 =? (nat 0) (label "unallocated")) ,SIGMA/E)))))))
(define WF-NEGATIVES/N
  (list
   (search-negative-case
    'unallocated-right-branch-under-forced
    `(Forced
      (More
       (DisjL
        (Dead 0)
        (Work (9 =? (nat 0) (label "unallocated")) ,SIGMA/N)))))))

(define FEATURE-CASES/S
  (feature-rule-cases delay:DELAY-CORPUS/S disjunction:DISJUNCTION-CORPUS/S))
(define FEATURE-CASES/E
  (feature-rule-cases delay:DELAY-CORPUS/E disjunction:DISJUNCTION-CORPUS/E))
(define FEATURE-CASES/N
  (feature-rule-cases delay:DELAY-CORPUS/N disjunction:DISJUNCTION-CORPUS/N))

(define SEARCH-CORPUS/S
  (search-row-corpus
   'S
   (rule-sources disjunction:DISJUNCTION-CORPUS/S FEATURE-CASES/S)
   FEATURE-CASES/S
   MIXED-CASES/S
   TRACES/S
   JOINT-FOCUS/S
   SCHEDULER-BARRIER/S
   GRAMMAR-NEGATIVES/S
   WF-NEGATIVES/S))

(define SEARCH-CORPUS/E
  (search-row-corpus
   'E
   (rule-sources disjunction:DISJUNCTION-CORPUS/E FEATURE-CASES/E)
   FEATURE-CASES/E
   MIXED-CASES/E
   TRACES/E
   JOINT-FOCUS/E
   SCHEDULER-BARRIER/E
   GRAMMAR-NEGATIVES/E
   WF-NEGATIVES/E))

(define SEARCH-CORPUS/N
  (search-row-corpus
   'N
   (rule-sources disjunction:DISJUNCTION-CORPUS/N FEATURE-CASES/N)
   FEATURE-CASES/N
   MIXED-CASES/N
   TRACES/N
   JOINT-FOCUS/N
   SCHEDULER-BARRIER/N
   GRAMMAR-NEGATIVES/N
   WF-NEGATIVES/N))
