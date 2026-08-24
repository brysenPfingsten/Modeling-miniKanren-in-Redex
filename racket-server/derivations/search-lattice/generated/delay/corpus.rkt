#lang racket

(require "../core/stages/corpus.rkt")

(provide DELAY-OWNED-RULE-NAMES
         DELAY-RULE-NAMES
         (struct-out delay-rule-case)
         (struct-out delay-trace-case)
         (struct-out delay-negative-case)
         (struct-out delay-row-corpus)
         delay-row-source-ref
         DELAY-CORPUS/S
         DELAY-CORPUS/E
         DELAY-CORPUS/N)

;; The corpus is deliberately plain data.  It names no generated framework
;; artifact, and the E/N coordinates below are written literally rather than
;; constructed by a representation map.

(define DELAY-OWNED-RULE-NAMES
  '(suspend-goal
    bubble-delay-through-conj
    force-delay))

(define DELAY-RULE-NAMES
  (sort (append CORE-RULE-NAMES DELAY-OWNED-RULE-NAMES) symbol<?))

(struct delay-rule-case (label source target) #:transparent)

(struct delay-trace-case
  (name
   source
   labels
   spans
   terminal
   forced-before
   forced-after)
  #:transparent)

(struct delay-negative-case (name source) #:transparent)

(struct delay-row-corpus
  (name
   core
   rule-sources
   owned-rule-cases
   finite-traces
   sparse-witness
   duplicate-binder-source
   grammar-negatives
   wf-negatives)
  #:transparent)

(define (delay-row-source-ref corpus rule-name)
  (match (assoc rule-name (delay-row-corpus-rule-sources corpus))
    [(list _ source) source]
    [#f
     (error 'delay-row-source-ref
            "row ~a has no representative for ~a"
            (delay-row-corpus-name corpus)
            rule-name)]))

(define (extend-rule-sources core-corpus owned-cases)
  (append
   (row-corpus-rule-sources core-corpus)
   (for/list ([owned-case (in-list owned-cases)])
     (list (delay-rule-case-label owned-case)
           (delay-rule-case-source owned-case)))))

(define STATE-TAG '(label "state"))

(define SIGMA-EMPTY/S `(state () () () ,STATE-TAG))
(define SIGMA-EMPTY/E `(state (Support) () () () ,STATE-TAG))
(define SIGMA-U0/E `(state (Support u:0) () () () ,STATE-TAG))
(define SIGMA-U0-U1/E `(state (Support u:0 u:1) () () () ,STATE-TAG))
(define SIGMA-U0-U1-U2/E
  `(state (Support u:0 u:1 u:2) () () () ,STATE-TAG))
(define SIGMA-0/N `(state 0 () () () ,STATE-TAG))
(define SIGMA-1/N `(state 1 () () () ,STATE-TAG))
(define SIGMA-2/N `(state 2 () () () ,STATE-TAG))
(define SIGMA-3/N `(state 3 () () () ,STATE-TAG))

(define OWNERS-EMPTY '(Owners))
(define OWNERS-U0 '(Owners (Owner (u:0) (label "u0"))))
(define OWNERS-U1 '(Owners (Owner (u:1) (label "u1"))))
(define OWNERS-U2 '(Owners (Owner (u:2) (label "u2"))))

;; Delay-owned one-step witnesses and exact direct targets.

(define DELAY-RULE-CASES/S
  (list
   (delay-rule-case
    'suspend-goal
    `(More
      (Work
       ,OWNERS-U0
       (suspend (succeed (label "body")) (label "suspend"))
       ,SIGMA-EMPTY/S))
    `(More
      (PendingDelay
       ,OWNERS-U0
       (Work ,OWNERS-EMPTY (succeed (label "body")) ,SIGMA-EMPTY/S))))
   (delay-rule-case
    'bubble-delay-through-conj
    `(More
      (Conj
       ,OWNERS-U0
       (PendingDelay
        ,OWNERS-U1
        (Work ,OWNERS-U2 (succeed (label "delayed")) ,SIGMA-EMPTY/S))
       (succeed (label "right"))))
    `(More
      (PendingDelay
       ,OWNERS-U0
       (Conj
        ,OWNERS-EMPTY
        (Work
         (Owners
          (Owner (u:1) (label "u1"))
          (Owner (u:2) (label "u2")))
         (succeed (label "delayed"))
         ,SIGMA-EMPTY/S)
        (succeed (label "right"))))))
   (delay-rule-case
    'force-delay
    `(More
      (PendingDelay
       ,OWNERS-U0
       (Work ,OWNERS-U1 (succeed (label "forced-body")) ,SIGMA-EMPTY/S)))
    `(Forced
      ,OWNERS-U0
      (More
       (Work ,OWNERS-U1 (succeed (label "forced-body")) ,SIGMA-EMPTY/S))))))

(define DELAY-RULE-CASES/E
  (list
   (delay-rule-case
    'suspend-goal
    `(More
      (Work
       (suspend (succeed (label "body")) (label "suspend"))
       ,SIGMA-U0/E))
    `(More
      (PendingDelay
       (Work (succeed (label "body")) ,SIGMA-U0/E))))
   (delay-rule-case
    'bubble-delay-through-conj
    `(More
      (Conj
       (PendingDelay
        (Work (succeed (label "delayed")) ,SIGMA-U0-U1-U2/E))
       (succeed (label "right"))))
    `(More
      (PendingDelay
       (Conj
        (Work (succeed (label "delayed")) ,SIGMA-U0-U1-U2/E)
        (succeed (label "right"))))))
   (delay-rule-case
    'force-delay
    `(More
      (PendingDelay
       (Work (succeed (label "forced-body")) ,SIGMA-U0-U1/E)))
    `(Forced
      (More
       (Work (succeed (label "forced-body")) ,SIGMA-U0-U1/E))))))

(define DELAY-RULE-CASES/N
  (list
   (delay-rule-case
    'suspend-goal
    `(More
      (Work
       (suspend (succeed (label "body")) (label "suspend"))
       ,SIGMA-1/N))
    `(More
      (PendingDelay
       (Work (succeed (label "body")) ,SIGMA-1/N))))
   (delay-rule-case
    'bubble-delay-through-conj
    `(More
      (Conj
       (PendingDelay
        (Work (succeed (label "delayed")) ,SIGMA-3/N))
       (succeed (label "right"))))
    `(More
      (PendingDelay
       (Conj
        (Work (succeed (label "delayed")) ,SIGMA-3/N)
        (succeed (label "right"))))))
   (delay-rule-case
    'force-delay
    `(More
      (PendingDelay
       (Work (succeed (label "forced-body")) ,SIGMA-2/N)))
    `(Forced
      (More
       (Work (succeed (label "forced-body")) ,SIGMA-2/N))))))

;; Six finite trace families.  Every Delay-owned label is a singleton B span;
;; only the already established core producer/follower pairs remain fused.

(define SUSPEND-SUCCESS-LABELS
  '(suspend-goal force-delay succeed finish-success))
(define SUSPEND-SUCCESS-SPANS
  '((transition-span suspend-goal)
    (transition-span force-delay)
    (transition-span succeed finish-success)))

(define BUBBLE-SUCCESS-LABELS
  '(bubble-delay-through-conj
    force-delay
    succeed
    conj-return
    succeed
    finish-success))
(define BUBBLE-SUCCESS-SPANS
  '((transition-span bubble-delay-through-conj)
    (transition-span force-delay)
    (transition-span succeed conj-return)
    (transition-span succeed finish-success)))

(define SUSPEND-FAILURE-LABELS
  '(suspend-goal force-delay fail finish-failure))
(define SUSPEND-FAILURE-SPANS
  '((transition-span suspend-goal)
    (transition-span force-delay)
    (transition-span fail finish-failure)))

(define NESTED-SUSPEND-LABELS
  '(suspend-goal
    force-delay
    suspend-goal
    force-delay
    succeed
    finish-success))
(define NESTED-SUSPEND-SPANS
  '((transition-span suspend-goal)
    (transition-span force-delay)
    (transition-span suspend-goal)
    (transition-span force-delay)
    (transition-span succeed finish-success)))

(define FRESH-INSIDE-LABELS
  '(suspend-goal
    force-delay
    allocate-fresh
    succeed
    finish-success))
(define FRESH-INSIDE-SPANS
  '((transition-span suspend-goal)
    (transition-span force-delay)
    (transition-span allocate-fresh)
    (transition-span succeed finish-success)))

(define UNUSED-FRESH-FAILURE-LABELS
  '(allocate-fresh
    suspend-goal
    force-delay
    fail
    finish-failure))
(define UNUSED-FRESH-FAILURE-SPANS
  '((transition-span allocate-fresh)
    (transition-span suspend-goal)
    (transition-span force-delay)
    (transition-span fail finish-failure)))

(define DELAY-TRACES/S
  (list
   (delay-trace-case
    'suspend-success
    `(More
      (Work
       ,OWNERS-EMPTY
       (suspend (succeed (label "body")) (label "suspend"))
       ,SIGMA-EMPTY/S))
    SUSPEND-SUCCESS-LABELS
    SUSPEND-SUCCESS-SPANS
    `(Forced
      ,OWNERS-EMPTY
      (Last ,OWNERS-EMPTY (Answer ,OWNERS-EMPTY ,SIGMA-EMPTY/S)))
    0
    1)
   (delay-trace-case
    'bubble-success
    (delay-rule-case-source (second DELAY-RULE-CASES/S))
    BUBBLE-SUCCESS-LABELS
    BUBBLE-SUCCESS-SPANS
    `(Forced
      ,OWNERS-U0
      (Last
       (Owners
        (Owner (u:1) (label "u1"))
        (Owner (u:2) (label "u2")))
       (Answer ,OWNERS-EMPTY ,SIGMA-EMPTY/S)))
    0
    1)
   (delay-trace-case
    'suspend-failure
    `(More
      (Work
       ,OWNERS-EMPTY
       (suspend (fail (label "body")) (label "suspend"))
       ,SIGMA-EMPTY/S))
    SUSPEND-FAILURE-LABELS
    SUSPEND-FAILURE-SPANS
    `(Forced ,OWNERS-EMPTY (Done ,OWNERS-EMPTY))
    0
    1)
   (delay-trace-case
    'nested-suspend
    `(More
      (Work
       ,OWNERS-EMPTY
       (suspend
        (suspend (succeed (label "body")) (label "inner-suspend"))
        (label "outer-suspend"))
       ,SIGMA-EMPTY/S))
    NESTED-SUSPEND-LABELS
    NESTED-SUSPEND-SPANS
    `(Forced
      ,OWNERS-EMPTY
      (Forced
       ,OWNERS-EMPTY
       (Last ,OWNERS-EMPTY (Answer ,OWNERS-EMPTY ,SIGMA-EMPTY/S))))
    0
    2)
   (delay-trace-case
    'fresh-inside-suspend
    `(More
      (Work
       ,OWNERS-EMPTY
       (suspend
        (∃ (x:q) (succeed (label "body")) (label "fresh-inside"))
        (label "suspend"))
       ,SIGMA-EMPTY/S))
    FRESH-INSIDE-LABELS
    FRESH-INSIDE-SPANS
    `(Forced
      ,OWNERS-EMPTY
      (Last
       (Owners (Owner (u:0) (label "fresh-inside")))
       (Answer ,OWNERS-EMPTY ,SIGMA-EMPTY/S)))
    0
    1)
   (delay-trace-case
    'unused-fresh-outside-delayed-failure
    `(More
      (Work
       ,OWNERS-EMPTY
       (∃ (x:q)
          (suspend (fail (label "body")) (label "suspend"))
          (label "fresh-outside"))
       ,SIGMA-EMPTY/S))
    UNUSED-FRESH-FAILURE-LABELS
    UNUSED-FRESH-FAILURE-SPANS
    `(Forced
      (Owners (Owner (u:0) (label "fresh-outside")))
      (Done ,OWNERS-EMPTY))
    0
    1)))

(define DELAY-TRACES/E
  (list
   (delay-trace-case
    'suspend-success
    `(More
      (Work
       (suspend (succeed (label "body")) (label "suspend"))
       ,SIGMA-EMPTY/E))
    SUSPEND-SUCCESS-LABELS
    SUSPEND-SUCCESS-SPANS
    `(Forced (Last (Answer ,SIGMA-EMPTY/E)))
    0
    1)
   (delay-trace-case
    'bubble-success
    (delay-rule-case-source (second DELAY-RULE-CASES/E))
    BUBBLE-SUCCESS-LABELS
    BUBBLE-SUCCESS-SPANS
    `(Forced (Last (Answer ,SIGMA-U0-U1-U2/E)))
    0
    1)
   (delay-trace-case
    'suspend-failure
    `(More
      (Work
       (suspend (fail (label "body")) (label "suspend"))
       ,SIGMA-EMPTY/E))
    SUSPEND-FAILURE-LABELS
    SUSPEND-FAILURE-SPANS
    '(Forced (Done (Support)))
    0
    1)
   (delay-trace-case
    'nested-suspend
    `(More
      (Work
       (suspend
        (suspend (succeed (label "body")) (label "inner-suspend"))
        (label "outer-suspend"))
       ,SIGMA-EMPTY/E))
    NESTED-SUSPEND-LABELS
    NESTED-SUSPEND-SPANS
    `(Forced (Forced (Last (Answer ,SIGMA-EMPTY/E))))
    0
    2)
   (delay-trace-case
    'fresh-inside-suspend
    `(More
      (Work
       (suspend
        (∃ (x:q) (succeed (label "body")) (label "fresh-inside"))
        (label "suspend"))
       ,SIGMA-EMPTY/E))
    FRESH-INSIDE-LABELS
    FRESH-INSIDE-SPANS
    `(Forced (Last (Answer ,SIGMA-U0/E)))
    0
    1)
   (delay-trace-case
    'unused-fresh-outside-delayed-failure
    `(More
      (Work
       (∃ (x:q)
          (suspend (fail (label "body")) (label "suspend"))
          (label "fresh-outside"))
       ,SIGMA-EMPTY/E))
    UNUSED-FRESH-FAILURE-LABELS
    UNUSED-FRESH-FAILURE-SPANS
    '(Forced (Done (Support u:0)))
    0
    1)))

(define DELAY-TRACES/N
  (list
   (delay-trace-case
    'suspend-success
    `(More
      (Work
       (suspend (succeed (label "body")) (label "suspend"))
       ,SIGMA-0/N))
    SUSPEND-SUCCESS-LABELS
    SUSPEND-SUCCESS-SPANS
    `(Forced (Last (Answer ,SIGMA-0/N)))
    0
    1)
   (delay-trace-case
    'bubble-success
    (delay-rule-case-source (second DELAY-RULE-CASES/N))
    BUBBLE-SUCCESS-LABELS
    BUBBLE-SUCCESS-SPANS
    `(Forced (Last (Answer ,SIGMA-3/N)))
    0
    1)
   (delay-trace-case
    'suspend-failure
    `(More
      (Work
       (suspend (fail (label "body")) (label "suspend"))
       ,SIGMA-0/N))
    SUSPEND-FAILURE-LABELS
    SUSPEND-FAILURE-SPANS
    '(Forced (Done 0))
    0
    1)
   (delay-trace-case
    'nested-suspend
    `(More
      (Work
       (suspend
        (suspend (succeed (label "body")) (label "inner-suspend"))
        (label "outer-suspend"))
       ,SIGMA-0/N))
    NESTED-SUSPEND-LABELS
    NESTED-SUSPEND-SPANS
    `(Forced (Forced (Last (Answer ,SIGMA-0/N))))
    0
    2)
   (delay-trace-case
    'fresh-inside-suspend
    `(More
      (Work
       (suspend
        (∃ (x:q) (succeed (label "body")) (label "fresh-inside"))
        (label "suspend"))
       ,SIGMA-0/N))
    FRESH-INSIDE-LABELS
    FRESH-INSIDE-SPANS
    `(Forced (Last (Answer ,SIGMA-1/N)))
    0
    1)
   (delay-trace-case
    'unused-fresh-outside-delayed-failure
    `(More
      (Work
       (∃ (x:q)
          (suspend (fail (label "body")) (label "suspend"))
          (label "fresh-outside"))
       ,SIGMA-0/N))
    UNUSED-FRESH-FAILURE-LABELS
    UNUSED-FRESH-FAILURE-SPANS
    '(Forced (Done 1))
    0
    1)))

;; The sparse witness crosses both Delay wrappers.  Its named support order is
;; u:0, u:2, so the direct N coordinate uses levels 0 and 1 with next = 2.

(define SPARSE-DELAY-WITNESS/S
  `(Forced
    (Owners (Owner (u:0) (label "sparse-0")))
    (More
     (PendingDelay
      (Owners (Owner (u:2) (label "sparse-2")))
      (Work
       ,OWNERS-EMPTY
       (u:2 =? u:0 (label "sparse-goal"))
       (state
        ((u:2 u:0))
        ()
        ((u:2 =? u:0 (label "sparse-trail")))
        (label "sparse-state")))))))

(define SPARSE-DELAY-WITNESS/E
  '(Forced
    (More
     (PendingDelay
      (Work
       (u:2 =? u:0 (label "sparse-goal"))
       (state
        (Support u:0 u:2)
        ((u:2 u:0))
        ()
        ((u:2 =? u:0 (label "sparse-trail")))
        (label "sparse-state")))))))

(define SPARSE-DELAY-WITNESS/N
  '(Forced
    (More
     (PendingDelay
      (Work
       (1 =? 0 (label "sparse-goal"))
       (state
        2
        ((1 0))
        ()
        ((1 =? 0 (label "sparse-trail")))
        (label "sparse-state")))))))

(define DUPLICATE-BINDER-SOURCE/S
  `(More
    (Work
     ,OWNERS-EMPTY
     (suspend
      (∃ (x:q x:q)
         (succeed (label "duplicate-body"))
         (label "duplicate"))
      (label "suspend"))
     ,SIGMA-EMPTY/S)))

(define DUPLICATE-BINDER-SOURCE/E
  `(More
    (Work
     (suspend
      (∃ (x:q x:q)
         (succeed (label "duplicate-body"))
         (label "duplicate"))
      (label "suspend"))
     ,SIGMA-EMPTY/E)))

(define DUPLICATE-BINDER-SOURCE/N
  `(More
    (Work
     (suspend
      (∃ (x:q x:q)
         (succeed (label "duplicate-body"))
         (label "duplicate"))
      (label "suspend"))
     ,SIGMA-0/N)))

;; Grammar negatives all fail the full source-frontier category.  WF negatives
;; remain grammatical and isolate semantic scope/support failures.

(define GRAMMAR-NEGATIVES/S
  (list
   (delay-negative-case
    'pending-used-as-frontier
    '(PendingDelay (Owners) (Dead (Owners))))
   (delay-negative-case
    'forced-used-as-work
    '(More (Forced (Owners) (Done (Owners)))))
   (delay-negative-case
    'forced-wraps-work
    `(Forced
      ,OWNERS-EMPTY
      (Work ,OWNERS-EMPTY (succeed (label "body")) ,SIGMA-EMPTY/S)))
   (delay-negative-case
    'ownerless-pending-shape
    '(More (PendingDelay (Dead (Owners)))))))

(define GRAMMAR-NEGATIVES/E
  (list
   (delay-negative-case
    'pending-used-as-frontier
    '(PendingDelay (Dead (Support))))
   (delay-negative-case
    'forced-used-as-work
    '(More (Forced (Done (Support)))))
   (delay-negative-case
    'forced-wraps-work
    `(Forced (Work (succeed (label "body")) ,SIGMA-EMPTY/E)))
   (delay-negative-case
    'copied-support-on-pending
    '(More (PendingDelay (Support u:0) (Dead (Support u:0)))))))

(define GRAMMAR-NEGATIVES/N
  (list
   (delay-negative-case
    'pending-used-as-frontier
    '(PendingDelay (Dead 0)))
   (delay-negative-case
    'forced-used-as-work
    '(More (Forced (Done 0))))
   (delay-negative-case
    'forced-wraps-work
    `(Forced (Work (succeed (label "body")) ,SIGMA-0/N)))
   (delay-negative-case
    'copied-next-on-pending
    '(More (PendingDelay 1 (Dead 1))))))

(define WF-NEGATIVES/S
  (list
   (delay-negative-case
    'unallocated-runtime-under-delay-wrappers
    `(Forced
      ,OWNERS-EMPTY
      (More
       (PendingDelay
        ,OWNERS-EMPTY
        (Work
         ,OWNERS-EMPTY
         (suspend
          (u:9 =? (nat 0) (label "unbound"))
          (label "suspend"))
         ,SIGMA-EMPTY/S)))))
   (delay-negative-case
    'duplicate-owner-across-wrappers
    `(Forced
      ,OWNERS-U0
      (More
       (PendingDelay
        ,OWNERS-U0
        (Work
         ,OWNERS-EMPTY
         (succeed (label "body"))
         ,SIGMA-EMPTY/S)))))
   (delay-negative-case
    'cyclic-substitution-under-delay-wrappers
    `(Forced
      ,OWNERS-U0
      (More
       (PendingDelay
        ,OWNERS-EMPTY
        (Work
         ,OWNERS-EMPTY
         (succeed (label "body"))
         (state ((u:0 u:0)) () () ,STATE-TAG))))))))

(define WF-NEGATIVES/E
  (list
   (delay-negative-case
    'unallocated-runtime-under-delay-wrappers
    `(Forced
      (More
       (PendingDelay
        (Work
         (suspend
          (u:9 =? (nat 0) (label "unbound"))
          (label "suspend"))
         ,SIGMA-EMPTY/E)))))
   (delay-negative-case
    'cyclic-substitution-under-delay-wrappers
    `(Forced
      (More
       (PendingDelay
        (Work
         (succeed (label "body"))
         (state (Support u:0) ((u:0 u:0)) () () ,STATE-TAG))))))))

(define WF-NEGATIVES/N
  (list
   (delay-negative-case
    'unallocated-runtime-under-delay-wrappers
    `(Forced
      (More
       (PendingDelay
        (Work
         (suspend
          (9 =? (nat 0) (label "unbound"))
          (label "suspend"))
         ,SIGMA-0/N)))))
   (delay-negative-case
    'cyclic-substitution-under-delay-wrappers
    `(Forced
      (More
       (PendingDelay
        (Work
         (succeed (label "body"))
         (state 1 ((0 0)) () () ,STATE-TAG))))))))

(define DELAY-CORPUS/S
  (delay-row-corpus
   'S
   CORE-CORPUS/S
   (extend-rule-sources CORE-CORPUS/S DELAY-RULE-CASES/S)
   DELAY-RULE-CASES/S
   DELAY-TRACES/S
   SPARSE-DELAY-WITNESS/S
   DUPLICATE-BINDER-SOURCE/S
   GRAMMAR-NEGATIVES/S
   WF-NEGATIVES/S))

(define DELAY-CORPUS/E
  (delay-row-corpus
   'E
   CORE-CORPUS/E
   (extend-rule-sources CORE-CORPUS/E DELAY-RULE-CASES/E)
   DELAY-RULE-CASES/E
   DELAY-TRACES/E
   SPARSE-DELAY-WITNESS/E
   DUPLICATE-BINDER-SOURCE/E
   GRAMMAR-NEGATIVES/E
   WF-NEGATIVES/E))

(define DELAY-CORPUS/N
  (delay-row-corpus
   'N
   CORE-CORPUS/N
   (extend-rule-sources CORE-CORPUS/N DELAY-RULE-CASES/N)
   DELAY-RULE-CASES/N
   DELAY-TRACES/N
   SPARSE-DELAY-WITNESS/N
   DUPLICATE-BINDER-SOURCE/N
   GRAMMAR-NEGATIVES/N
   WF-NEGATIVES/N))
