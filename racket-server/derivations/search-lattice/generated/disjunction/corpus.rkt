#lang racket

(provide CORE-RULE-NAMES
         DISJUNCTION-OWNED-RULE-NAMES
         DISJUNCTION-RULE-NAMES
         DISJUNCTION-B-SINGLETON-RULE-NAMES
         (struct-out disjunction-rule-case)
         (struct-out disjunction-trace-case)
         (struct-out disjunction-row-corpus)
         disjunction-row-source-ref
         disjunction-row-state-ref
         DISJUNCTION-CORPUS/S
         DISJUNCTION-CORPUS/E
         DISJUNCTION-CORPUS/N)

;; This corpus is deliberately plain data.  It imports neither a generated
;; artifact nor an oracle.  In particular, the E and N coordinates below are
;; literal witnesses rather than results computed by a representation map.

(define CORE-RULE-NAMES
  '(allocate-fresh
    conj-fail
    conj-return
    disequality-fail
    disequality-success
    expand-conjunction
    fail
    finish-failure
    finish-success
    succeed
    unify-fail
    unify-success
    unify-violates-disequality))

(define DISJUNCTION-OWNED-RULE-NAMES
  '(expand-disjunction
    skip-left-failure
    reassociate-left-result
    commit-choice-answer
    resume-left-choice-success))

(define DISJUNCTION-RULE-NAMES
  (sort (append CORE-RULE-NAMES DISJUNCTION-OWNED-RULE-NAMES) symbol<?))

;; Disjunction adds no producer or follower category.  Every feature-owned
;; label is a singleton B transition, including when it immediately follows a
;; settled/dead core transition.  Existing core-to-core pairs may still fuse.
(define DISJUNCTION-B-SINGLETON-RULE-NAMES
  '(expand-disjunction
    skip-left-failure
    reassociate-left-result
    commit-choice-answer
    resume-left-choice-success))

(struct disjunction-rule-case (label source target) #:transparent)

(struct disjunction-trace-case
  (name
   source
   labels
   spans
   terminal
   answers
   shared-outer
   sibling-allocations)
  #:transparent)

(struct disjunction-row-corpus
  (name
   core-rule-sources
   rule-sources
   owned-rule-cases
   finite-traces
   row-states
   complete-state-copy)
  #:transparent)

(define (disjunction-row-source-ref corpus rule-name)
  (match (assoc rule-name (disjunction-row-corpus-rule-sources corpus))
    [(list _ source) source]
    [#f
     (error 'disjunction-row-source-ref
            "row ~a has no representative for ~a"
            (disjunction-row-corpus-name corpus)
            rule-name)]))

(define (disjunction-row-state-ref corpus state-name)
  (match (assoc state-name (disjunction-row-corpus-row-states corpus))
    [(list _ state) state]
    [#f
     (error 'disjunction-row-state-ref
            "row ~a has no state named ~a"
            (disjunction-row-corpus-name corpus)
            state-name)]))

(define (extend-rule-sources core-sources owned-cases)
  (append
   core-sources
   (for/list ([owned-case (in-list owned-cases)])
     (list (disjunction-rule-case-label owned-case)
           (disjunction-rule-case-source owned-case)))))

(define CORE-STATE-TAG '(label "stage-state"))
(define STATE-TAG '(label "disjunction-state"))

(define OWNERS-EMPTY '(Owners))
(define OWNERS-U0 '(Owners (Owner (u:0) (label "outer"))))
(define OWNERS-U1 '(Owners (Owner (u:1) (label "inner"))))
(define OWNERS-U2 '(Owners (Owner (u:2) (label "answer"))))
(define OWNERS-U3 '(Owners (Owner (u:3) (label "residual"))))
(define OWNERS-U4 '(Owners (Owner (u:4) (label "right"))))
(define OWNERS-U0-U1
  '(Owners
    (Owner (u:0) (label "outer"))
    (Owner (u:1) (label "inner"))))
(define OWNERS-U0-U3
  '(Owners
    (Owner (u:0) (label "outer"))
    (Owner (u:3) (label "residual"))))
(define OWNERS-U1-U2
  '(Owners
    (Owner (u:1) (label "inner"))
    (Owner (u:2) (label "answer"))))
(define OWNERS-U1-U3
  '(Owners
    (Owner (u:1) (label "inner"))
    (Owner (u:3) (label "residual"))))
(define OWNERS-LEFT-U1
  '(Owners (Owner (u:1) (label "left-fresh"))))
(define OWNERS-RIGHT-U1
  '(Owners (Owner (u:1) (label "right-fresh"))))

;; --------------------------------------------------------------------------
;; The inherited thirteen representatives are copied literally so this module
;; remains independent of every generated core module.

(define CORE-SIGMA/S `(state () () () ,CORE-STATE-TAG))
(define CORE-OWNERS-U0 '(Owners (Owner (u:0) (label "u0"))))
(define CORE-OWNERS-U1 '(Owners (Owner (u:1) (label "u1"))))

(define CORE-RULE-SOURCES/S
  (list
   (list
    'expand-conjunction
    `(More
      (Work ,CORE-OWNERS-U0
            ((succeed (label "left"))
             ∧
             (u:0 =? u:0 (label "right"))
             (label "and"))
            ,CORE-SIGMA/S)))
   (list
    'succeed
    `(More (Work ,CORE-OWNERS-U0 (succeed (label "yes")) ,CORE-SIGMA/S)))
   (list
    'fail
    `(More (Work ,CORE-OWNERS-U0 (fail (label "no")) ,CORE-SIGMA/S)))
   (list
    'conj-return
    `(More
      (Conj ,CORE-OWNERS-U0
            (Returned ,CORE-OWNERS-U1 ,CORE-SIGMA/S)
            (u:0 =? u:0 (label "continue")))))
   (list
    'conj-fail
    `(More
      (Conj ,CORE-OWNERS-U0
            (Dead ,CORE-OWNERS-U1)
            (u:0 =? u:0 (label "unreachable")))))
   (list
    'unify-success
    `(More
      (Work ,CORE-OWNERS-U0
            (u:0 =? (nat 7) (label "bind"))
            ,CORE-SIGMA/S)))
   (list
    'unify-violates-disequality
    `(More
      (Work ,CORE-OWNERS-U0
            (u:0 =? (nat 7) (label "violate"))
            (state ()
                   ((u:0 (nat 7)))
                   ()
                   ,CORE-STATE-TAG))))
   (list
    'unify-fail
    `(More
      (Work ,OWNERS-EMPTY
            ((nat 0) =? (nat 1) (label "unify-fail"))
            ,CORE-SIGMA/S)))
   (list
    'disequality-success
    `(More
      (Work ,CORE-OWNERS-U0
            (u:0 != (nat 7) (label "exclude"))
            ,CORE-SIGMA/S)))
   (list
    'disequality-fail
    `(More
      (Work ,OWNERS-EMPTY
            ((nat 0) != (nat 0) (label "same-data"))
            ,CORE-SIGMA/S)))
   (list
    'finish-success
    `(More (Returned ,CORE-OWNERS-U0 ,CORE-SIGMA/S)))
   (list 'finish-failure `(More (Dead ,CORE-OWNERS-U0)))
   (list
    'allocate-fresh
    `(More
      (Conj
       ,CORE-OWNERS-U0
       (Work
        (Owners (Owner (u:2) (label "u2")))
        (∃ (x:new)
           (x:new =? u:0 (label "fresh-body"))
           (label "allocate-u1"))
        ,CORE-SIGMA/S)
       (u:0 != (nat 9) (label "future")))))))

(define CORE-SIGMA/E `(state (Support) () () () ,CORE-STATE-TAG))
(define CORE-SIGMA-U0/E
  `(state (Support u:0) () () () ,CORE-STATE-TAG))

(define CORE-RULE-SOURCES/E
  (list
   (list
    'expand-conjunction
    `(More
      (Work ((succeed (label "left"))
             ∧
             (u:0 =? u:0 (label "right"))
             (label "and"))
            ,CORE-SIGMA-U0/E)))
   (list
    'succeed
    `(More (Work (succeed (label "yes")) ,CORE-SIGMA-U0/E)))
   (list 'fail `(More (Work (fail (label "no")) ,CORE-SIGMA-U0/E)))
   (list
    'conj-return
    `(More
      (Conj
       (Returned (state (Support u:0 u:1) () () () ,CORE-STATE-TAG))
       (u:0 =? u:0 (label "continue")))))
   (list
    'conj-fail
    '(More
      (Conj (Dead (Support u:0 u:1))
            (u:0 =? u:0 (label "unreachable")))))
   (list
    'unify-success
    `(More
      (Work (u:0 =? (nat 7) (label "bind")) ,CORE-SIGMA-U0/E)))
   (list
    'unify-violates-disequality
    `(More
      (Work
       (u:0 =? (nat 7) (label "violate"))
       (state (Support u:0) () ((u:0 (nat 7))) () ,CORE-STATE-TAG))))
   (list
    'unify-fail
    `(More
      (Work ((nat 0) =? (nat 1) (label "unify-fail")) ,CORE-SIGMA/E)))
   (list
    'disequality-success
    `(More
      (Work (u:0 != (nat 7) (label "exclude")) ,CORE-SIGMA-U0/E)))
   (list
    'disequality-fail
    `(More
      (Work ((nat 0) != (nat 0) (label "same-data")) ,CORE-SIGMA/E)))
   (list 'finish-success `(More (Returned ,CORE-SIGMA-U0/E)))
   (list 'finish-failure '(More (Dead (Support u:0))))
   (list
    'allocate-fresh
    `(More
      (Conj
       (Work
        (∃ (x:new)
           (x:new =? u:0 (label "fresh-body"))
           (label "allocate-u1"))
        (state (Support u:0 u:2) () () () ,CORE-STATE-TAG))
       (u:0 != (nat 9) (label "future")))))))

(define CORE-SIGMA/N `(state 0 () () () ,CORE-STATE-TAG))
(define CORE-SIGMA-1/N `(state 1 () () () ,CORE-STATE-TAG))

(define CORE-RULE-SOURCES/N
  (list
   (list
    'expand-conjunction
    `(More
      (Work ((succeed (label "left"))
             ∧
             (0 =? 0 (label "right"))
             (label "and"))
            ,CORE-SIGMA-1/N)))
   (list 'succeed `(More (Work (succeed (label "yes")) ,CORE-SIGMA-1/N)))
   (list 'fail `(More (Work (fail (label "no")) ,CORE-SIGMA-1/N)))
   (list
    'conj-return
    `(More
      (Conj (Returned (state 2 () () () ,CORE-STATE-TAG))
            (0 =? 0 (label "continue")))))
   (list
    'conj-fail
    '(More (Conj (Dead 2) (0 =? 0 (label "unreachable")))))
   (list
    'unify-success
    `(More (Work (0 =? (nat 7) (label "bind")) ,CORE-SIGMA-1/N)))
   (list
    'unify-violates-disequality
    `(More
      (Work
       (0 =? (nat 7) (label "violate"))
       (state 1 () ((0 (nat 7))) () ,CORE-STATE-TAG))))
   (list
    'unify-fail
    `(More
      (Work ((nat 0) =? (nat 1) (label "unify-fail")) ,CORE-SIGMA/N)))
   (list
    'disequality-success
    `(More (Work (0 != (nat 7) (label "exclude")) ,CORE-SIGMA-1/N)))
   (list
    'disequality-fail
    `(More
      (Work ((nat 0) != (nat 0) (label "same-data")) ,CORE-SIGMA/N)))
   (list 'finish-success `(More (Returned ,CORE-SIGMA-1/N)))
   (list 'finish-failure '(More (Dead 1)))
   (list
    'allocate-fresh
    `(More
      (Conj
       (Work
        (∃ (x:new)
           (x:new =? 0 (label "fresh-body"))
           (label "allocate-u1"))
        (state 2 () () () ,CORE-STATE-TAG))
       (0 != (nat 9) (label "future")))))))

;; --------------------------------------------------------------------------
;; Row-local states.  The shared state makes every component observable when
;; expand-disjunction copies the complete world into both siblings.

(define SIGMA-EMPTY/S `(state () () () ,STATE-TAG))
(define SIGMA-SHARED/S
  `(state ((u:0 (sym "shared")))
          ((u:0 (sym "blocked")))
          ((u:0 =? (sym "shared") (label "outer-binding")))
          ,STATE-TAG))
(define SIGMA-TWO-LEFT/S
  `(state ((u:1 (sym "shared")) (u:0 (sym "shared")))
          ((u:0 (sym "blocked")))
          ((u:0 =? (sym "shared") (label "outer-binding"))
           (u:1 =? u:0 (label "left-uses-shared")))
          ,STATE-TAG))
(define SIGMA-TWO-RIGHT/S
  `(state ((u:1 (sym "shared")) (u:0 (sym "shared")))
          ((u:0 (sym "blocked")))
          ((u:0 =? (sym "shared") (label "outer-binding"))
           (u:1 =? u:0 (label "right-uses-shared")))
          ,STATE-TAG))
(define SIGMA-OUTER-LEFT/S
  `(state ((u:0 (sym "shared")))
          ((u:0 (sym "blocked")))
          ((u:0 =? (sym "shared") (label "outer-binding"))
           (u:0 =? (sym "shared") (label "left-reads-shared")))
          ,STATE-TAG))
(define SIGMA-OUTER-RIGHT/S
  `(state ((u:0 (sym "shared")))
          ((u:0 (sym "different"))
           (u:0 (sym "blocked")))
          ((u:0 =? (sym "shared") (label "outer-binding")))
          ,STATE-TAG))

(define SIGMA-EMPTY/E `(state (Support) () () () ,STATE-TAG))
(define SIGMA-U0/E `(state (Support u:0) () () () ,STATE-TAG))
(define SIGMA-U0-U2/E
  `(state (Support u:0 u:2) () () () ,STATE-TAG))
(define SIGMA-U0-U3/E
  `(state (Support u:0 u:3) () () () ,STATE-TAG))
(define SIGMA-U0-U1-U2/E
  `(state (Support u:0 u:1 u:2) () () () ,STATE-TAG))
(define SIGMA-U0-U1-U3/E
  `(state (Support u:0 u:1 u:3) () () () ,STATE-TAG))
(define SIGMA-SHARED/E
  `(state (Support u:0)
          ((u:0 (sym "shared")))
          ((u:0 (sym "blocked")))
          ((u:0 =? (sym "shared") (label "outer-binding")))
          ,STATE-TAG))
(define SIGMA-TWO-LEFT/E
  `(state (Support u:0 u:1)
          ((u:1 (sym "shared")) (u:0 (sym "shared")))
          ((u:0 (sym "blocked")))
          ((u:0 =? (sym "shared") (label "outer-binding"))
           (u:1 =? u:0 (label "left-uses-shared")))
          ,STATE-TAG))
(define SIGMA-TWO-RIGHT/E
  `(state (Support u:0 u:1)
          ((u:1 (sym "shared")) (u:0 (sym "shared")))
          ((u:0 (sym "blocked")))
          ((u:0 =? (sym "shared") (label "outer-binding"))
           (u:1 =? u:0 (label "right-uses-shared")))
          ,STATE-TAG))
(define SIGMA-OUTER-LEFT/E
  `(state (Support u:0)
          ((u:0 (sym "shared")))
          ((u:0 (sym "blocked")))
          ((u:0 =? (sym "shared") (label "outer-binding"))
           (u:0 =? (sym "shared") (label "left-reads-shared")))
          ,STATE-TAG))
(define SIGMA-OUTER-RIGHT/E
  `(state (Support u:0)
          ((u:0 (sym "shared")))
          ((u:0 (sym "different"))
           (u:0 (sym "blocked")))
          ((u:0 =? (sym "shared") (label "outer-binding")))
          ,STATE-TAG))

(define SIGMA-0/N `(state 0 () () () ,STATE-TAG))
(define SIGMA-1/N `(state 1 () () () ,STATE-TAG))
(define SIGMA-2/N `(state 2 () () () ,STATE-TAG))
(define SIGMA-3/N `(state 3 () () () ,STATE-TAG))
(define SIGMA-SHARED/N
  `(state 1
          ((0 (sym "shared")))
          ((0 (sym "blocked")))
          ((0 =? (sym "shared") (label "outer-binding")))
          ,STATE-TAG))
(define SIGMA-TWO-LEFT/N
  `(state 2
          ((1 (sym "shared")) (0 (sym "shared")))
          ((0 (sym "blocked")))
          ((0 =? (sym "shared") (label "outer-binding"))
           (1 =? 0 (label "left-uses-shared")))
          ,STATE-TAG))
(define SIGMA-TWO-RIGHT/N
  `(state 2
          ((1 (sym "shared")) (0 (sym "shared")))
          ((0 (sym "blocked")))
          ((0 =? (sym "shared") (label "outer-binding"))
           (1 =? 0 (label "right-uses-shared")))
          ,STATE-TAG))
(define SIGMA-OUTER-LEFT/N
  `(state 1
          ((0 (sym "shared")))
          ((0 (sym "blocked")))
          ((0 =? (sym "shared") (label "outer-binding"))
           (0 =? (sym "shared") (label "left-reads-shared")))
          ,STATE-TAG))
(define SIGMA-OUTER-RIGHT/N
  `(state 1
          ((0 (sym "shared")))
          ((0 (sym "different"))
           (0 (sym "blocked")))
          ((0 =? (sym "shared") (label "outer-binding")))
          ,STATE-TAG))

(define ROW-STATES/S
  (list (list 'empty SIGMA-EMPTY/S)
        (list 'shared SIGMA-SHARED/S)
        (list 'two-answer-left SIGMA-TWO-LEFT/S)
        (list 'two-answer-right SIGMA-TWO-RIGHT/S)
        (list 'outer-shared-left SIGMA-OUTER-LEFT/S)
        (list 'outer-shared-right SIGMA-OUTER-RIGHT/S)))

(define ROW-STATES/E
  (list (list 'empty SIGMA-EMPTY/E)
        (list 'shared SIGMA-SHARED/E)
        (list 'two-answer-left SIGMA-TWO-LEFT/E)
        (list 'two-answer-right SIGMA-TWO-RIGHT/E)
        (list 'outer-shared-left SIGMA-OUTER-LEFT/E)
        (list 'outer-shared-right SIGMA-OUTER-RIGHT/E)))

(define ROW-STATES/N
  (list (list 'empty SIGMA-0/N)
        (list 'shared SIGMA-SHARED/N)
        (list 'two-answer-left SIGMA-TWO-LEFT/N)
        (list 'two-answer-right SIGMA-TWO-RIGHT/N)
        (list 'outer-shared-left SIGMA-OUTER-LEFT/N)
        (list 'outer-shared-right SIGMA-OUTER-RIGHT/N)))

;; --------------------------------------------------------------------------
;; Five direct Disjunction equations in each representation.

(define DISJUNCTION-RULE-CASES/S
  (list
   (disjunction-rule-case
    'expand-disjunction
    `(More
      (Work
       ,OWNERS-U0
       ((succeed (label "copy-left"))
        ∨
        (fail (label "copy-right"))
        (label "copy-complete-state"))
       ,SIGMA-SHARED/S))
    `(More
      (DisjL
       ,OWNERS-U0
       (Work ,OWNERS-EMPTY (succeed (label "copy-left")) ,SIGMA-SHARED/S)
       (Work ,OWNERS-EMPTY (fail (label "copy-right")) ,SIGMA-SHARED/S))))
   (disjunction-rule-case
    'skip-left-failure
    `(More
      (DisjL
       ,OWNERS-U0
       (Dead ,OWNERS-U4)
       (Work ,OWNERS-U3 (succeed (label "survivor")) ,SIGMA-EMPTY/S)))
    `(More
      (Work ,OWNERS-U0-U3 (succeed (label "survivor")) ,SIGMA-EMPTY/S)))
   (disjunction-rule-case
    'reassociate-left-result
    `(More
      (DisjL
       ,OWNERS-U0
       (DisjL
        ,OWNERS-U1
        (Returned ,OWNERS-U2 ,SIGMA-EMPTY/S)
        (Work ,OWNERS-U3 (succeed (label "residual")) ,SIGMA-EMPTY/S))
       (Dead ,OWNERS-U4)))
    `(More
      (DisjL
       ,OWNERS-U0
       (Returned ,OWNERS-U1-U2 ,SIGMA-EMPTY/S)
       (DisjL
        ,OWNERS-EMPTY
        (Work ,OWNERS-U1-U3 (succeed (label "residual")) ,SIGMA-EMPTY/S)
        (Dead ,OWNERS-U4)))))
   (disjunction-rule-case
    'commit-choice-answer
    `(More
      (DisjL
       ,OWNERS-U0
       (Returned ,OWNERS-U2 ,SIGMA-EMPTY/S)
       (Dead ,OWNERS-U4)))
    `(Emit
      ,OWNERS-U0
      (Answer ,OWNERS-U2 ,SIGMA-EMPTY/S)
      (More (Dead ,OWNERS-U4))))
   (disjunction-rule-case
    'resume-left-choice-success
    `(More
      (Conj
       ,OWNERS-U0
       (DisjL
        ,OWNERS-U1
        (Returned ,OWNERS-U2 ,SIGMA-EMPTY/S)
        (Dead ,OWNERS-U4))
       (succeed (label "continuation"))))
    `(More
      (DisjL
       ,OWNERS-U0-U1
       (Work ,OWNERS-U2 (succeed (label "continuation")) ,SIGMA-EMPTY/S)
       (Conj ,OWNERS-EMPTY
             (Dead ,OWNERS-U4)
             (succeed (label "continuation"))))))))

(define DISJUNCTION-RULE-CASES/E
  (list
   (disjunction-rule-case
    'expand-disjunction
    `(More
      (Work
       ((succeed (label "copy-left"))
        ∨
        (fail (label "copy-right"))
        (label "copy-complete-state"))
       ,SIGMA-SHARED/E))
    `(More
      (DisjL
       (Work (succeed (label "copy-left")) ,SIGMA-SHARED/E)
       (Work (fail (label "copy-right")) ,SIGMA-SHARED/E))))
   (disjunction-rule-case
    'skip-left-failure
    `(More
      (DisjL
       (Dead (Support u:0 u:4))
       (Work (succeed (label "survivor")) ,SIGMA-U0-U3/E)))
    `(More (Work (succeed (label "survivor")) ,SIGMA-U0-U3/E)))
   (disjunction-rule-case
    'reassociate-left-result
    `(More
      (DisjL
       (DisjL
        (Returned ,SIGMA-U0-U1-U2/E)
        (Work (succeed (label "residual")) ,SIGMA-U0-U1-U3/E))
       (Dead (Support u:0 u:4))))
    `(More
      (DisjL
       (Returned ,SIGMA-U0-U1-U2/E)
       (DisjL
        (Work (succeed (label "residual")) ,SIGMA-U0-U1-U3/E)
        (Dead (Support u:0 u:4))))))
   (disjunction-rule-case
    'commit-choice-answer
    `(More
      (DisjL
       (Returned ,SIGMA-U0-U2/E)
       (Dead (Support u:0 u:4))))
    `(Emit
      (Answer ,SIGMA-U0-U2/E)
      (More (Dead (Support u:0 u:4)))))
   (disjunction-rule-case
    'resume-left-choice-success
    `(More
      (Conj
       (DisjL
        (Returned ,SIGMA-U0-U1-U2/E)
        (Dead (Support u:0 u:1 u:4)))
       (succeed (label "continuation"))))
    `(More
      (DisjL
       (Work (succeed (label "continuation")) ,SIGMA-U0-U1-U2/E)
       (Conj
        (Dead (Support u:0 u:1 u:4))
        (succeed (label "continuation"))))))))

(define DISJUNCTION-RULE-CASES/N
  (list
   (disjunction-rule-case
    'expand-disjunction
    `(More
      (Work
       ((succeed (label "copy-left"))
        ∨
        (fail (label "copy-right"))
        (label "copy-complete-state"))
       ,SIGMA-SHARED/N))
    `(More
      (DisjL
       (Work (succeed (label "copy-left")) ,SIGMA-SHARED/N)
       (Work (fail (label "copy-right")) ,SIGMA-SHARED/N))))
   (disjunction-rule-case
    'skip-left-failure
    `(More
      (DisjL
       (Dead 2)
       (Work (succeed (label "survivor")) ,SIGMA-2/N)))
    `(More (Work (succeed (label "survivor")) ,SIGMA-2/N)))
   (disjunction-rule-case
    'reassociate-left-result
    `(More
      (DisjL
       (DisjL
        (Returned ,SIGMA-3/N)
        (Work (succeed (label "residual")) ,SIGMA-3/N))
       (Dead 2)))
    `(More
      (DisjL
       (Returned ,SIGMA-3/N)
       (DisjL
        (Work (succeed (label "residual")) ,SIGMA-3/N)
        (Dead 2)))))
   (disjunction-rule-case
    'commit-choice-answer
    `(More (DisjL (Returned ,SIGMA-2/N) (Dead 2)))
    `(Emit (Answer ,SIGMA-2/N) (More (Dead 2))))
   (disjunction-rule-case
    'resume-left-choice-success
    `(More
      (Conj
       (DisjL (Returned ,SIGMA-3/N) (Dead 3))
       (succeed (label "continuation"))))
    `(More
      (DisjL
       (Work (succeed (label "continuation")) ,SIGMA-3/N)
       (Conj (Dead 3) (succeed (label "continuation"))))))))

;; --------------------------------------------------------------------------
;; Five bounded trace families.  No span crosses a core/Disjunction feature
;; boundary; every occurrence of a Disjunction-owned label is one-label wide.

(define LEFT-FAILURE-LABELS
  '(expand-disjunction
    fail
    skip-left-failure
    succeed
    finish-success))
(define LEFT-FAILURE-SPANS
  '((transition-span expand-disjunction)
    (transition-span fail)
    (transition-span skip-left-failure)
    (transition-span succeed finish-success)))

(define TWO-ANSWERS-LABELS
  '(expand-disjunction
    allocate-fresh
    unify-success
    commit-choice-answer
    allocate-fresh
    unify-success
    finish-success))
(define TWO-ANSWERS-SPANS
  '((transition-span expand-disjunction)
    (transition-span allocate-fresh)
    (transition-span unify-success)
    (transition-span commit-choice-answer)
    (transition-span allocate-fresh)
    (transition-span unify-success finish-success)))

(define NESTED-REASSOCIATION-LABELS
  '(expand-disjunction
    expand-disjunction
    succeed
    reassociate-left-result
    commit-choice-answer
    fail
    skip-left-failure
    fail
    finish-failure))
(define NESTED-REASSOCIATION-SPANS
  '((transition-span expand-disjunction)
    (transition-span expand-disjunction)
    (transition-span succeed)
    (transition-span reassociate-left-result)
    (transition-span commit-choice-answer)
    (transition-span fail)
    (transition-span skip-left-failure)
    (transition-span fail finish-failure)))

(define CONJUNCTION-RESUME-LABELS
  '(expand-conjunction
    expand-disjunction
    succeed
    resume-left-choice-success
    succeed
    commit-choice-answer
    fail
    conj-fail
    finish-failure))
(define CONJUNCTION-RESUME-SPANS
  '((transition-span expand-conjunction)
    (transition-span expand-disjunction)
    (transition-span succeed)
    (transition-span resume-left-choice-success)
    (transition-span succeed)
    (transition-span commit-choice-answer)
    (transition-span fail conj-fail)
    (transition-span finish-failure)))

(define OUTER-SHARED-LABELS
  '(expand-disjunction
    unify-success
    commit-choice-answer
    disequality-success
    finish-success))
(define OUTER-SHARED-SPANS
  '((transition-span expand-disjunction)
    (transition-span unify-success)
    (transition-span commit-choice-answer)
    (transition-span disequality-success finish-success)))

(define TWO-ANSWERS-GOAL/S
  '((∃ (x:left)
       (x:left =? u:0 (label "left-uses-shared"))
       (label "left-fresh"))
    ∨
    (∃ (x:right)
       (x:right =? u:0 (label "right-uses-shared"))
       (label "right-fresh"))
    (label "two-answers")))
(define TWO-ANSWERS-GOAL/E
  '((∃ (x:left)
       (x:left =? u:0 (label "left-uses-shared"))
       (label "left-fresh"))
    ∨
    (∃ (x:right)
       (x:right =? u:0 (label "right-uses-shared"))
       (label "right-fresh"))
    (label "two-answers")))
(define TWO-ANSWERS-GOAL/N
  '((∃ (x:left)
       (x:left =? 0 (label "left-uses-shared"))
       (label "left-fresh"))
    ∨
    (∃ (x:right)
       (x:right =? 0 (label "right-uses-shared"))
       (label "right-fresh"))
    (label "two-answers")))

(define DISJUNCTION-TRACES/S
  (list
   (disjunction-trace-case
    'left-failure
    `(More
      (Work
       ,OWNERS-U0
       ((fail (label "left"))
        ∨
        (succeed (label "right"))
        (label "left-failure"))
       ,SIGMA-SHARED/S))
    LEFT-FAILURE-LABELS
    LEFT-FAILURE-SPANS
    `(Last ,OWNERS-U0 (Answer ,OWNERS-EMPTY ,SIGMA-SHARED/S))
    (list `(Answer ,OWNERS-EMPTY ,SIGMA-SHARED/S))
    'u:0
    '())
   (disjunction-trace-case
    'two-answers-sibling-allocation-reuse
    `(More (Work ,OWNERS-U0 ,TWO-ANSWERS-GOAL/S ,SIGMA-SHARED/S))
    TWO-ANSWERS-LABELS
    TWO-ANSWERS-SPANS
    `(Emit
      ,OWNERS-U0
      (Answer ,OWNERS-LEFT-U1 ,SIGMA-TWO-LEFT/S)
      (Last
       ,OWNERS-RIGHT-U1
       (Answer ,OWNERS-EMPTY ,SIGMA-TWO-RIGHT/S)))
    (list `(Answer ,OWNERS-LEFT-U1 ,SIGMA-TWO-LEFT/S)
          `(Answer ,OWNERS-EMPTY ,SIGMA-TWO-RIGHT/S))
    'u:0
    '(u:1 u:1))
   (disjunction-trace-case
    'nested-left-reassociation
    `(More
      (Work
       ,OWNERS-U0
       (((succeed (label "inner-answer"))
         ∨
         (fail (label "inner-residual"))
         (label "inner-choice"))
        ∨
        (fail (label "outer-residual"))
        (label "outer-choice"))
       ,SIGMA-EMPTY/S))
    NESTED-REASSOCIATION-LABELS
    NESTED-REASSOCIATION-SPANS
    `(Emit
      ,OWNERS-U0
      (Answer ,OWNERS-EMPTY ,SIGMA-EMPTY/S)
      (Done ,OWNERS-EMPTY))
    (list `(Answer ,OWNERS-EMPTY ,SIGMA-EMPTY/S))
    #f
    '())
   (disjunction-trace-case
    'conjunction-resume
    `(More
      (Work
       ,OWNERS-U0
       (((succeed (label "choice-answer"))
         ∨
         (fail (label "choice-residual"))
         (label "choice"))
        ∧
        (succeed (label "continuation"))
        (label "conjunction"))
       ,SIGMA-EMPTY/S))
    CONJUNCTION-RESUME-LABELS
    CONJUNCTION-RESUME-SPANS
    `(Emit
      ,OWNERS-U0
      (Answer ,OWNERS-EMPTY ,SIGMA-EMPTY/S)
      (Done ,OWNERS-EMPTY))
    (list `(Answer ,OWNERS-EMPTY ,SIGMA-EMPTY/S))
    #f
    '())
   (disjunction-trace-case
    'outer-shared-variable
    `(More
      (Work
       ,OWNERS-U0
       ((u:0 =? (sym "shared") (label "left-reads-shared"))
        ∨
        (u:0 != (sym "different") (label "right-reads-shared"))
        (label "shared-choice"))
       ,SIGMA-SHARED/S))
    OUTER-SHARED-LABELS
    OUTER-SHARED-SPANS
    `(Emit
      ,OWNERS-U0
      (Answer ,OWNERS-EMPTY ,SIGMA-OUTER-LEFT/S)
      (Last ,OWNERS-EMPTY (Answer ,OWNERS-EMPTY ,SIGMA-OUTER-RIGHT/S)))
    (list `(Answer ,OWNERS-EMPTY ,SIGMA-OUTER-LEFT/S)
          `(Answer ,OWNERS-EMPTY ,SIGMA-OUTER-RIGHT/S))
    'u:0
    '())))

(define DISJUNCTION-TRACES/E
  (list
   (disjunction-trace-case
    'left-failure
    `(More
      (Work
       ((fail (label "left"))
        ∨
        (succeed (label "right"))
        (label "left-failure"))
       ,SIGMA-SHARED/E))
    LEFT-FAILURE-LABELS
    LEFT-FAILURE-SPANS
    `(Last (Answer ,SIGMA-SHARED/E))
    (list `(Answer ,SIGMA-SHARED/E))
    'u:0
    '())
   (disjunction-trace-case
    'two-answers-sibling-allocation-reuse
    `(More (Work ,TWO-ANSWERS-GOAL/E ,SIGMA-SHARED/E))
    TWO-ANSWERS-LABELS
    TWO-ANSWERS-SPANS
    `(Emit
      (Answer ,SIGMA-TWO-LEFT/E)
      (Last (Answer ,SIGMA-TWO-RIGHT/E)))
    (list `(Answer ,SIGMA-TWO-LEFT/E)
          `(Answer ,SIGMA-TWO-RIGHT/E))
    'u:0
    '(u:1 u:1))
   (disjunction-trace-case
    'nested-left-reassociation
    `(More
      (Work
       (((succeed (label "inner-answer"))
         ∨
         (fail (label "inner-residual"))
         (label "inner-choice"))
        ∨
        (fail (label "outer-residual"))
        (label "outer-choice"))
       ,SIGMA-U0/E))
    NESTED-REASSOCIATION-LABELS
    NESTED-REASSOCIATION-SPANS
    `(Emit (Answer ,SIGMA-U0/E) (Done (Support u:0)))
    (list `(Answer ,SIGMA-U0/E))
    #f
    '())
   (disjunction-trace-case
    'conjunction-resume
    `(More
      (Work
       (((succeed (label "choice-answer"))
         ∨
         (fail (label "choice-residual"))
         (label "choice"))
        ∧
        (succeed (label "continuation"))
        (label "conjunction"))
       ,SIGMA-U0/E))
    CONJUNCTION-RESUME-LABELS
    CONJUNCTION-RESUME-SPANS
    `(Emit (Answer ,SIGMA-U0/E) (Done (Support u:0)))
    (list `(Answer ,SIGMA-U0/E))
    #f
    '())
   (disjunction-trace-case
    'outer-shared-variable
    `(More
      (Work
       ((u:0 =? (sym "shared") (label "left-reads-shared"))
        ∨
        (u:0 != (sym "different") (label "right-reads-shared"))
        (label "shared-choice"))
       ,SIGMA-SHARED/E))
    OUTER-SHARED-LABELS
    OUTER-SHARED-SPANS
    `(Emit
      (Answer ,SIGMA-OUTER-LEFT/E)
      (Last (Answer ,SIGMA-OUTER-RIGHT/E)))
    (list `(Answer ,SIGMA-OUTER-LEFT/E)
          `(Answer ,SIGMA-OUTER-RIGHT/E))
    'u:0
    '())))

(define DISJUNCTION-TRACES/N
  (list
   (disjunction-trace-case
    'left-failure
    `(More
      (Work
       ((fail (label "left"))
        ∨
        (succeed (label "right"))
        (label "left-failure"))
       ,SIGMA-SHARED/N))
    LEFT-FAILURE-LABELS
    LEFT-FAILURE-SPANS
    `(Last (Answer ,SIGMA-SHARED/N))
    (list `(Answer ,SIGMA-SHARED/N))
    0
    '())
   (disjunction-trace-case
    'two-answers-sibling-allocation-reuse
    `(More (Work ,TWO-ANSWERS-GOAL/N ,SIGMA-SHARED/N))
    TWO-ANSWERS-LABELS
    TWO-ANSWERS-SPANS
    `(Emit
      (Answer ,SIGMA-TWO-LEFT/N)
      (Last (Answer ,SIGMA-TWO-RIGHT/N)))
    (list `(Answer ,SIGMA-TWO-LEFT/N)
          `(Answer ,SIGMA-TWO-RIGHT/N))
    0
    '(1 1))
   (disjunction-trace-case
    'nested-left-reassociation
    `(More
      (Work
       (((succeed (label "inner-answer"))
         ∨
         (fail (label "inner-residual"))
         (label "inner-choice"))
        ∨
        (fail (label "outer-residual"))
        (label "outer-choice"))
       ,SIGMA-1/N))
    NESTED-REASSOCIATION-LABELS
    NESTED-REASSOCIATION-SPANS
    `(Emit (Answer ,SIGMA-1/N) (Done 1))
    (list `(Answer ,SIGMA-1/N))
    #f
    '())
   (disjunction-trace-case
    'conjunction-resume
    `(More
      (Work
       (((succeed (label "choice-answer"))
         ∨
         (fail (label "choice-residual"))
         (label "choice"))
        ∧
        (succeed (label "continuation"))
        (label "conjunction"))
       ,SIGMA-1/N))
    CONJUNCTION-RESUME-LABELS
    CONJUNCTION-RESUME-SPANS
    `(Emit (Answer ,SIGMA-1/N) (Done 1))
    (list `(Answer ,SIGMA-1/N))
    #f
    '())
   (disjunction-trace-case
    'outer-shared-variable
    `(More
      (Work
       ((0 =? (sym "shared") (label "left-reads-shared"))
        ∨
        (0 != (sym "different") (label "right-reads-shared"))
        (label "shared-choice"))
       ,SIGMA-SHARED/N))
    OUTER-SHARED-LABELS
    OUTER-SHARED-SPANS
    `(Emit
      (Answer ,SIGMA-OUTER-LEFT/N)
      (Last (Answer ,SIGMA-OUTER-RIGHT/N)))
    (list `(Answer ,SIGMA-OUTER-LEFT/N)
          `(Answer ,SIGMA-OUTER-RIGHT/N))
    0
    '())))

(define DISJUNCTION-CORPUS/S
  (disjunction-row-corpus
   'S
   CORE-RULE-SOURCES/S
   (extend-rule-sources CORE-RULE-SOURCES/S DISJUNCTION-RULE-CASES/S)
   DISJUNCTION-RULE-CASES/S
   DISJUNCTION-TRACES/S
   ROW-STATES/S
   (first DISJUNCTION-RULE-CASES/S)))

(define DISJUNCTION-CORPUS/E
  (disjunction-row-corpus
   'E
   CORE-RULE-SOURCES/E
   (extend-rule-sources CORE-RULE-SOURCES/E DISJUNCTION-RULE-CASES/E)
   DISJUNCTION-RULE-CASES/E
   DISJUNCTION-TRACES/E
   ROW-STATES/E
   (first DISJUNCTION-RULE-CASES/E)))

(define DISJUNCTION-CORPUS/N
  (disjunction-row-corpus
   'N
   CORE-RULE-SOURCES/N
   (extend-rule-sources CORE-RULE-SOURCES/N DISJUNCTION-RULE-CASES/N)
   DISJUNCTION-RULE-CASES/N
   DISJUNCTION-TRACES/N
   ROW-STATES/N
   (first DISJUNCTION-RULE-CASES/N)))
