#lang racket

(provide CORE-RULE-NAMES
         PRODUCER-RULE-NAMES
         GOLDEN-M-LABELS
         GOLDEN-B-SPANS
         (struct-out failure-case)
         (struct-out row-corpus)
         row-source-ref
         CORE-CORPUS/S
         CORE-CORPUS/E
         CORE-CORPUS/N
         SPARSE-VERTICAL-WITNESS/S
         SPARSE-VERTICAL-WITNESS/E
         SPARSE-VERTICAL-WITNESS/N)

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

(define PRODUCER-RULE-NAMES
  '(succeed
    fail
    unify-success
    unify-violates-disequality
    unify-fail
    disequality-success
    disequality-fail))

(define GOLDEN-M-LABELS
  '(allocate-fresh
    expand-conjunction
    expand-conjunction
    unify-success
    conj-return
    disequality-success
    conj-return
    succeed
    finish-success))

(define GOLDEN-B-SPANS
  '((transition-span allocate-fresh)
    (transition-span expand-conjunction)
    (transition-span expand-conjunction)
    (transition-span unify-success conj-return)
    (transition-span disequality-success conj-return)
    (transition-span succeed finish-success)))

(struct failure-case (name source labels terminal) #:transparent)
(struct row-corpus (name rule-sources finite-source golden-terminal failures)
  #:transparent)

(define (row-source-ref corpus rule-name)
  (match (assoc rule-name (row-corpus-rule-sources corpus))
    [(list _ source) source]
    [#f
     (error 'row-source-ref
            "row ~a has no representative for ~a"
            (row-corpus-name corpus)
            rule-name)]))

(define TAG-STATE '(label "stage-state"))

(define SIGMA/S `(state () () () ,TAG-STATE))
(define OWNERS-0 '(Owners))
(define OWNERS-U0 '(Owners (Owner (u:0) (label "u0"))))
(define OWNERS-U1 '(Owners (Owner (u:1) (label "u1"))))

(define RULE-SOURCES/S
  (list
   (list
    'expand-conjunction
    `(More
      (Work ,OWNERS-U0
            ((succeed (label "left"))
             ∧
             (u:0 =? u:0 (label "right"))
             (label "and"))
            ,SIGMA/S)))
   (list
    'succeed
    `(More (Work ,OWNERS-U0 (succeed (label "yes")) ,SIGMA/S)))
   (list
    'fail
    `(More (Work ,OWNERS-U0 (fail (label "no")) ,SIGMA/S)))
   (list
    'conj-return
    `(More
      (Conj ,OWNERS-U0
            (Returned ,OWNERS-U1 ,SIGMA/S)
            (u:0 =? u:0 (label "continue")))))
   (list
    'conj-fail
    `(More
      (Conj ,OWNERS-U0
            (Dead ,OWNERS-U1)
            (u:0 =? u:0 (label "unreachable")))))
   (list
    'unify-success
    `(More
      (Work ,OWNERS-U0
            (u:0 =? (nat 7) (label "bind"))
            ,SIGMA/S)))
   (list
    'unify-violates-disequality
    `(More
      (Work ,OWNERS-U0
            (u:0 =? (nat 7) (label "violate"))
            (state ()
                   ((u:0 (nat 7)))
                   ()
                   ,TAG-STATE))))
   (list
    'unify-fail
    `(More
      (Work ,OWNERS-0
            ((nat 0) =? (nat 1) (label "unify-fail"))
            ,SIGMA/S)))
   (list
    'disequality-success
    `(More
      (Work ,OWNERS-U0
            (u:0 != (nat 7) (label "exclude"))
            ,SIGMA/S)))
   (list
    'disequality-fail
    `(More
      (Work ,OWNERS-0
            ((nat 0) != (nat 0) (label "same-data"))
            ,SIGMA/S)))
   (list
    'finish-success
    `(More (Returned ,OWNERS-U0 ,SIGMA/S)))
   (list 'finish-failure `(More (Dead ,OWNERS-U0)))
   (list
    'allocate-fresh
    `(More
      (Conj
       ,OWNERS-U0
       (Work
        (Owners (Owner (u:2) (label "u2")))
        (∃ (x:new)
           (x:new =? u:0 (label "fresh-body"))
           (label "allocate-u1"))
        ,SIGMA/S)
       (u:0 != (nat 9) (label "future")))))))

(define FINITE-SOURCE/S
  `(More
    (Work
     (Owners)
     (∃ (x:q x:r)
        (((x:q =? (sym "cat") (label "bind-x"))
          ∧
          (x:r != (sym "dog") (label "exclude-dog"))
          (label "inner-conjunction"))
         ∧
         (succeed (label "done"))
         (label "outer-conjunction"))
        (label "allocate-two"))
     ,SIGMA/S)))

(define GOLDEN-TERMINAL/S
  `(Last
    (Owners (Owner (u:0 u:1) (label "allocate-two")))
    (Answer
     (Owners)
     (state ((u:0 (sym "cat")))
            ((u:1 (sym "dog")))
            ((u:0 =? (sym "cat") (label "bind-x")))
            ,TAG-STATE))))

(define FAILURE-LABELS/DEEP
  '(allocate-fresh
    expand-conjunction
    allocate-fresh
    expand-conjunction
    fail
    conj-fail
    conj-fail
    finish-failure))

(define FAILURES/S
  (list
   (failure-case
    'empty-binder
    `(More
      (Work (Owners)
            (∃ () (fail (label "empty-fail")) (label "empty"))
            ,SIGMA/S))
    '(allocate-fresh fail finish-failure)
    '(Done (Owners (Owner () (label "empty")))))
   (failure-case
    'unused-singleton
    `(More
      (Work (Owners)
            (∃ (x:unused)
               (fail (label "unused-fail"))
               (label "one"))
            ,SIGMA/S))
    '(allocate-fresh fail finish-failure)
    '(Done (Owners (Owner (u:0) (label "one")))))
   (failure-case
    'multi-binder
    `(More
      (Work (Owners)
            (∃ (x:a x:b)
               (fail (label "multi-fail"))
               (label "two"))
            ,SIGMA/S))
    '(allocate-fresh fail finish-failure)
    '(Done (Owners (Owner (u:0 u:1) (label "two")))))
   (failure-case
    'deep-two-frame
    `(More
      (Work
       (Owners)
       (∃ (x:outer)
          ((∃ (x:inner)
               ((fail (label "deep-fail"))
                ∧
                (succeed (label "unreached-inner"))
                (label "inner-and"))
               (label "inner"))
            ∧
            (succeed (label "unreached-outer"))
            (label "outer-and"))
          (label "outer"))
       ,SIGMA/S))
    FAILURE-LABELS/DEEP
    '(Done
      (Owners
       (Owner (u:0) (label "outer"))
       (Owner (u:1) (label "inner")))))))

(define SIGMA/E `(state (Support) () () () ,TAG-STATE))
(define SIGMA-U0/E `(state (Support u:0) () () () ,TAG-STATE))

(define RULE-SOURCES/E
  (list
   (list
    'expand-conjunction
    `(More
      (Work ((succeed (label "left"))
             ∧
             (u:0 =? u:0 (label "right"))
             (label "and"))
            ,SIGMA-U0/E)))
   (list 'succeed `(More (Work (succeed (label "yes")) ,SIGMA-U0/E)))
   (list 'fail `(More (Work (fail (label "no")) ,SIGMA-U0/E)))
   (list
    'conj-return
    `(More
      (Conj
       (Returned (state (Support u:0 u:1) () () () ,TAG-STATE))
       (u:0 =? u:0 (label "continue")))))
   (list
    'conj-fail
    '(More
      (Conj (Dead (Support u:0 u:1))
            (u:0 =? u:0 (label "unreachable")))))
   (list
    'unify-success
    `(More
      (Work (u:0 =? (nat 7) (label "bind")) ,SIGMA-U0/E)))
   (list
    'unify-violates-disequality
    `(More
      (Work
       (u:0 =? (nat 7) (label "violate"))
       (state (Support u:0) () ((u:0 (nat 7))) () ,TAG-STATE))))
   (list
    'unify-fail
    `(More
      (Work ((nat 0) =? (nat 1) (label "unify-fail")) ,SIGMA/E)))
   (list
    'disequality-success
    `(More
      (Work (u:0 != (nat 7) (label "exclude")) ,SIGMA-U0/E)))
   (list
    'disequality-fail
    `(More
      (Work ((nat 0) != (nat 0) (label "same-data")) ,SIGMA/E)))
   (list 'finish-success `(More (Returned ,SIGMA-U0/E)))
   (list 'finish-failure '(More (Dead (Support u:0))))
   (list
    'allocate-fresh
    `(More
      (Conj
       (Work
        (∃ (x:new)
           (x:new =? u:0 (label "fresh-body"))
           (label "allocate-u1"))
        (state (Support u:0 u:2) () () () ,TAG-STATE))
       (u:0 != (nat 9) (label "future")))))))

(define FINITE-SOURCE/E
  `(More
    (Work
     (∃ (x:q x:r)
        (((x:q =? (sym "cat") (label "bind-x"))
          ∧
          (x:r != (sym "dog") (label "exclude-dog"))
          (label "inner-conjunction"))
         ∧
         (succeed (label "done"))
         (label "outer-conjunction"))
        (label "allocate-two"))
     ,SIGMA/E)))

(define GOLDEN-TERMINAL/E
  `(Last
    (Answer
     (state (Support u:0 u:1)
            ((u:0 (sym "cat")))
            ((u:1 (sym "dog")))
            ((u:0 =? (sym "cat") (label "bind-x")))
            ,TAG-STATE))))

(define FAILURES/E
  (list
   (failure-case
    'empty-binder
    `(More
      (Work (∃ () (fail (label "empty-fail")) (label "empty"))
            ,SIGMA/E))
    '(allocate-fresh fail finish-failure)
    '(Done (Support)))
   (failure-case
    'unused-singleton
    `(More
      (Work (∃ (x:unused)
                (fail (label "unused-fail"))
                (label "one"))
            ,SIGMA/E))
    '(allocate-fresh fail finish-failure)
    '(Done (Support u:0)))
   (failure-case
    'multi-binder
    `(More
      (Work (∃ (x:a x:b)
                (fail (label "multi-fail"))
                (label "two"))
            ,SIGMA/E))
    '(allocate-fresh fail finish-failure)
    '(Done (Support u:0 u:1)))
   (failure-case
    'deep-two-frame
    `(More
      (Work
       (∃ (x:outer)
          ((∃ (x:inner)
               ((fail (label "deep-fail"))
                ∧
                (succeed (label "unreached-inner"))
                (label "inner-and"))
               (label "inner"))
            ∧
            (succeed (label "unreached-outer"))
            (label "outer-and"))
          (label "outer"))
       ,SIGMA/E))
    FAILURE-LABELS/DEEP
    '(Done (Support u:0 u:1)))))

(define SIGMA/N `(state 0 () () () ,TAG-STATE))
(define SIGMA-1/N `(state 1 () () () ,TAG-STATE))

(define RULE-SOURCES/N
  (list
   (list
    'expand-conjunction
    `(More
      (Work ((succeed (label "left"))
             ∧
             (0 =? 0 (label "right"))
             (label "and"))
            ,SIGMA-1/N)))
   (list 'succeed `(More (Work (succeed (label "yes")) ,SIGMA-1/N)))
   (list 'fail `(More (Work (fail (label "no")) ,SIGMA-1/N)))
   (list
    'conj-return
    `(More
      (Conj (Returned (state 2 () () () ,TAG-STATE))
            (0 =? 0 (label "continue")))))
   (list
    'conj-fail
    '(More (Conj (Dead 2) (0 =? 0 (label "unreachable")))))
   (list
    'unify-success
    `(More (Work (0 =? (nat 7) (label "bind")) ,SIGMA-1/N)))
   (list
    'unify-violates-disequality
    `(More
      (Work
       (0 =? (nat 7) (label "violate"))
       (state 1 () ((0 (nat 7))) () ,TAG-STATE))))
   (list
    'unify-fail
    `(More
      (Work ((nat 0) =? (nat 1) (label "unify-fail")) ,SIGMA/N)))
   (list
    'disequality-success
    `(More (Work (0 != (nat 7) (label "exclude")) ,SIGMA-1/N)))
   (list
    'disequality-fail
    `(More
      (Work ((nat 0) != (nat 0) (label "same-data")) ,SIGMA/N)))
   (list 'finish-success `(More (Returned ,SIGMA-1/N)))
   (list 'finish-failure '(More (Dead 1)))
   (list
    'allocate-fresh
    `(More
      (Conj
       (Work
        (∃ (x:new)
           (x:new =? 0 (label "fresh-body"))
           (label "allocate-u1"))
        (state 2 () () () ,TAG-STATE))
       (0 != (nat 9) (label "future")))))))

(define FINITE-SOURCE/N
  `(More
    (Work
     (∃ (x:q x:r)
        (((x:q =? (sym "cat") (label "bind-x"))
          ∧
          (x:r != (sym "dog") (label "exclude-dog"))
          (label "inner-conjunction"))
         ∧
         (succeed (label "done"))
         (label "outer-conjunction"))
        (label "allocate-two"))
     ,SIGMA/N)))

(define GOLDEN-TERMINAL/N
  `(Last
    (Answer
     (state 2
            ((0 (sym "cat")))
            ((1 (sym "dog")))
            ((0 =? (sym "cat") (label "bind-x")))
            ,TAG-STATE))))

(define FAILURES/N
  (list
   (failure-case
    'empty-binder
    `(More
      (Work (∃ () (fail (label "empty-fail")) (label "empty"))
            ,SIGMA/N))
    '(allocate-fresh fail finish-failure)
    '(Done 0))
   (failure-case
    'unused-singleton
    `(More
      (Work (∃ (x:unused)
                (fail (label "unused-fail"))
                (label "one"))
            ,SIGMA/N))
    '(allocate-fresh fail finish-failure)
    '(Done 1))
   (failure-case
    'multi-binder
    `(More
      (Work (∃ (x:a x:b)
                (fail (label "multi-fail"))
                (label "two"))
            ,SIGMA/N))
    '(allocate-fresh fail finish-failure)
    '(Done 2))
   (failure-case
    'deep-two-frame
    `(More
      (Work
       (∃ (x:outer)
          ((∃ (x:inner)
               ((fail (label "deep-fail"))
                ∧
                (succeed (label "unreached-inner"))
                (label "inner-and"))
               (label "inner"))
            ∧
            (succeed (label "unreached-outer"))
            (label "outer-and"))
          (label "outer"))
       ,SIGMA/N))
    FAILURE-LABELS/DEEP
    '(Done 2))))

(define CORE-CORPUS/S
  (row-corpus 'S RULE-SOURCES/S FINITE-SOURCE/S GOLDEN-TERMINAL/S FAILURES/S))

(define CORE-CORPUS/E
  (row-corpus 'E RULE-SOURCES/E FINITE-SOURCE/E GOLDEN-TERMINAL/E FAILURES/E))

(define CORE-CORPUS/N
  (row-corpus 'N RULE-SOURCES/N FINITE-SOURCE/N GOLDEN-TERMINAL/N FAILURES/N))

;; The ordered support is intentionally sparse as a set of named atoms.  N
;; addresses it positionally: u:0 maps to level 0 and u:2 maps to level 1.
(define SPARSE-VERTICAL-WITNESS/S
  '(More
    (Work
     (Owners
      (Owner (u:0) (label "sparse-0"))
      (Owner (u:2) (label "sparse-2")))
     (u:2 =? u:0 (label "sparse-goal"))
     (state ((u:2 u:0))
            ()
            ((u:2 =? u:0 (label "sparse-trail")))
            (label "sparse-state")))))

(define SPARSE-VERTICAL-WITNESS/E
  '(More
    (Work
     (u:2 =? u:0 (label "sparse-goal"))
     (state (Support u:0 u:2)
            ((u:2 u:0))
            ()
            ((u:2 =? u:0 (label "sparse-trail")))
            (label "sparse-state")))))

(define SPARSE-VERTICAL-WITNESS/N
  '(More
    (Work
     (1 =? 0 (label "sparse-goal"))
     (state 2
            ((1 0))
            ()
            ((1 =? 0 (label "sparse-trail")))
            (label "sparse-state")))))
