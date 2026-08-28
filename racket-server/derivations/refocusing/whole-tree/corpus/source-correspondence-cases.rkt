#lang racket

(provide (struct-out source-correspondence-case)
         source-correspondence-cases
         source-correspondence-case-by-name)

;; Constructor-neutral source data for the independent lean reference and the
;; marked-to-lean Q_R tests.  Every term is quoted data: this module deliberately
;; imports no language, relation, kernel, observation, or correspondence code.
(struct source-correspondence-case
  (name
   kernel
   goal
   query
   final-frontier
   source-labels
   source-edge-count
   rule-cost
   force-count
   prefix-events
   answer-payloads
   answer-states
   query-answers
   scoped-answers
   forced-events
   residual
   allocation-events)
  #:transparent)

(define nested-inner-answer
  '(AnswerFresh
    (u:1)
    (Answer (state (u:0 : u:1)))
    (label "branch-fresh")))

(define left-answer
  '(Answer (state (sym "left"))))

(define right-answer
  '(Answer (state (sym "right"))))

(define now-answer
  '(AnswerFresh
    (u:0)
    (Answer (state (sym "now")))
    (label "fresh")))

(define later-answer
  '(Answer (state (sym "later"))))

(define mk-disequality-answer
  '(Answer
    (state ()
           ((u:0 (sym "dog")))
           ()
           (label "s"))))

(define mk-unification-answer
  '(Answer
    (state ((u:0 (sym "cat")))
           ()
           ((u:0 =? (sym "cat") (label "bind")))
           (label "s"))))

(define source-correspondence-cases
  (list
   (source-correspondence-case
    'nested-scope
    'toy
    '(fresh
      (x:outer)
      (disj
       (fresh
        (x:inner)
        (disj
         (put (x:outer : x:inner) (label "inner-left"))
         (put (x:outer : x:inner) (label "inner-right"))
         (label "inner-split"))
        (label "branch-fresh"))
       (put x:outer (label "outer-right"))
       (label "outer-split"))
      (label "outer-fresh"))
    #f
    `(FrontierFresh
      (u:0)
      (Emit
       ,nested-inner-answer
       (Emit
        ,nested-inner-answer
        (Last (Answer (state u:0)))))
      (label "outer-fresh"))
    '((allocate-fresh core)
      (expose-frontier-fresh core)
      (expand-disjunction disj)
      (allocate-fresh core)
      (expand-disjunction disj)
      (kernel work-put core)
      (expose-choice-through-work-fresh disj)
      (reassociate-left-result disj)
      (commit-choice-answer disj)
      (kernel work-put core)
      (commit-choice-answer disj)
      (kernel work-put core)
      (finish-success core))
    13
    13
    0
    `((FrontierFreshEvent (u:0) (label "outer-fresh"))
      (EmitEvent ,nested-inner-answer)
      (EmitEvent ,nested-inner-answer))
    (list nested-inner-answer
          nested-inner-answer
          '(Answer (state u:0)))
    '((state (u:0 : u:1))
      (state (u:0 : u:1))
      (state u:0))
    #f
    '((ScopedAnswer
       (state (u:0 : u:1))
       ((Owner (u:0) (label "outer-fresh"))
        (Owner (u:1) (label "branch-fresh"))))
      (ScopedAnswer
       (state (u:0 : u:1))
       ((Owner (u:0) (label "outer-fresh"))
        (Owner (u:1) (label "branch-fresh"))))
      (ScopedAnswer
       (state u:0)
       ((Owner (u:0) (label "outer-fresh")))))
    '()
    '(Last (Answer (state u:0)))
    '((AllocateEvent (label "outer-fresh") (x:outer) (u:0))
      (AllocateEvent (label "branch-fresh") (x:inner) (u:1))))

   (source-correspondence-case
    'late-hoist
    'toy
    '(conj
      (disj
       (put (sym "left") (label "left"))
       (put (sym "right") (label "right"))
       (label "split"))
      (succeed (label "continue"))
      (label "and"))
    #f
    `(Emit ,left-answer (Last ,right-answer))
    '((expand-conjunction core)
      (expand-disjunction disj)
      (kernel work-put core)
      (late-distribute-settled disj)
      (kernel work-succeed core)
      (commit-choice-answer disj)
      (kernel work-put core)
      (conj-return core)
      (kernel work-succeed core)
      (finish-success core))
    10
    10
    0
    `((EmitEvent ,left-answer))
    (list left-answer right-answer)
    '((state (sym "left"))
      (state (sym "right")))
    #f
    '((ScopedAnswer (state (sym "left")) ())
      (ScopedAnswer (state (sym "right")) ()))
    '()
    `(Last ,right-answer)
    '())

   (source-correspondence-case
    'rail-turn
    'toy
    '(disj
      (suspend
       (put (sym "left") (label "left"))
       (label "left-delay"))
      (suspend
       (put (sym "right") (label "right"))
       (label "right-delay"))
      (label "split"))
    #f
    `(Forced
      (Forced
       (Emit ,left-answer (Last ,right-answer))))
    '((expand-disjunction disj)
      (suspend-goal delay)
      (rail-enter-right search-join)
      (force-delay delay)
      (suspend-goal delay)
      (rail-return-left search-join)
      (force-delay delay)
      (kernel work-put core)
      (commit-choice-answer disj)
      (kernel work-put core)
      (finish-success core))
    11
    11
    2
    `(ForcedEvent
      ForcedEvent
      (EmitEvent ,left-answer))
    (list left-answer right-answer)
    '((state (sym "left"))
      (state (sym "right")))
    #f
    '((ScopedAnswer (state (sym "left")) ())
      (ScopedAnswer (state (sym "right")) ()))
    '(ForcedEvent ForcedEvent)
    `(Last ,right-answer)
    '())

   (source-correspondence-case
    'right-active-fresh
    'toy
    '(conj
      (conj
       (fresh
        (x:q)
        (put x:q (label "seed"))
        (label "fresh"))
       (disj
        (suspend
         (put (sym "later") (label "later"))
         (label "delay"))
        (put (sym "now") (label "now"))
        (label "split"))
       (label "seed-and-choice"))
      (succeed (label "continue"))
      (label "outer-and"))
    #f
    `(Forced
      (Emit
       ,now-answer
       (FrontierFresh
        (u:0)
        (Last ,later-answer)
        (label "fresh"))))
    '((expand-conjunction core)
      (expand-conjunction core)
      (allocate-fresh core)
      (kernel work-put core)
      (conj-return core)
      (expand-disjunction disj)
      (suspend-goal delay)
      (rail-enter-right search-join)
      (bubble-delay-through-fresh delay)
      (bubble-delay-through-conj delay)
      (force-delay delay)
      (kernel work-put core)
      (expose-choice-through-work-fresh search-join)
      (late-distribute-right-settled search-join)
      (kernel work-succeed core)
      (commit-right-choice-answer search-join)
      (kernel work-put core)
      (conj-return core)
      (expose-frontier-fresh core)
      (kernel work-succeed core)
      (finish-success core))
    21
    21
    1
    `(ForcedEvent
      (EmitEvent ,now-answer)
      (FrontierFreshEvent (u:0) (label "fresh")))
    (list now-answer later-answer)
    '((state (sym "now"))
      (state (sym "later")))
    #f
    '((ScopedAnswer
       (state (sym "now"))
       ((Owner (u:0) (label "fresh"))))
      (ScopedAnswer
       (state (sym "later"))
       ((Owner (u:0) (label "fresh")))))
    '(ForcedEvent)
    `(Last ,later-answer)
    '((AllocateEvent (label "fresh") (x:q) (u:0))))

   (source-correspondence-case
    'mk-unification-delay-disequality
    'mk
    '(fresh
      (x:q)
      (disj
       (conj
        (x:q =? (sym "cat") (label "bind"))
        (suspend
         (succeed (label "resume"))
         (label "delay"))
        (label "and"))
       (x:q != (sym "dog") (label "neq"))
       (label "or"))
      (label "query"))
    '(u:0)
    `(FrontierFresh
      (u:0)
      (Forced
       (Emit
        ,mk-disequality-answer
        (Last ,mk-unification-answer)))
      (label "query"))
    '((allocate-fresh core)
      (expose-frontier-fresh core)
      (expand-disjunction disj)
      (expand-conjunction core)
      (kernel unify-success core)
      (conj-return core)
      (suspend-goal delay)
      (rail-enter-right search-join)
      (force-delay delay)
      (kernel disequality-success core)
      (commit-right-choice-answer search-join)
      (kernel succeed core)
      (finish-success core))
    13
    13
    1
    `((FrontierFreshEvent (u:0) (label "query"))
      ForcedEvent
      (EmitEvent ,mk-disequality-answer))
    (list mk-disequality-answer mk-unification-answer)
    '((state ()
             ((u:0 (sym "dog")))
             ()
             (label "s"))
      (state ((u:0 (sym "cat")))
             ()
             ((u:0 =? (sym "cat") (label "bind")))
             (label "s")))
    '((u:0) ((sym "cat")))
    '((ScopedAnswer
       (state ()
              ((u:0 (sym "dog")))
              ()
              (label "s"))
       ((Owner (u:0) (label "query"))))
      (ScopedAnswer
       (state ((u:0 (sym "cat")))
              ()
              ((u:0 =? (sym "cat") (label "bind")))
              (label "s"))
       ((Owner (u:0) (label "query")))))
    '(ForcedEvent)
    `(Last ,mk-unification-answer)
    '((AllocateEvent (label "query") (x:q) (u:0))))))

(define (source-correspondence-case-by-name name)
  (for/first ([candidate (in-list source-correspondence-cases)]
              #:when (equal? name
                             (source-correspondence-case-name candidate)))
    candidate))
