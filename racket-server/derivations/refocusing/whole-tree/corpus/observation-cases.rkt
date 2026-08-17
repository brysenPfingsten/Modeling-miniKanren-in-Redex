#lang racket

(provide (struct-out frontier-observation-case)
         (struct-out trace-observation-case)
         (struct-out allocation-observation-case)
         frontier-observation-cases
         trace-observation-cases
         allocation-observation-cases
         frontier-observation-case-by-name
         trace-observation-case-by-name
         allocation-observation-case-by-name)

;; Constructor-neutral observation data shared by temporary references and the
;; eventual modular family.  Every Redex term below is quoted data; this module
;; deliberately imports no language, relation, kernel, or observation code.

(struct frontier-observation-case
  (name
   frontier
   prefix-events
   answer-payloads
   answer-states
   scoped-answers
   forced-events
   residual)
  #:transparent)

(struct trace-observation-case
  (name
   goal
   final-frontier
   source-labels
   source-edge-count
   rule-cost
   force-count
   compressed-span-lengths
   compressed-edge-count
   prefix-events
   answer-payloads
   answer-states
   scoped-answers
   forced-events
   residual
   allocation-events)
  #:transparent)

(struct allocation-observation-case
  (name goal allocation-events)
  #:transparent)

(define left-answer
  '(Answer (state (sym "left"))))

(define right-answer
  '(Answer (state (sym "right"))))

(define inner-answer
  '(AnswerFresh
    (u:1)
    (Answer (state (u:0 : u:1)))
    (label "branch-fresh")))

(define now-answer
  '(AnswerFresh
    (u:0)
    (Answer (state (sym "now")))
    (label "fresh")))

(define later-answer
  '(Answer (state (sym "later"))))

;; The first two cases have the same answer observation but deliberately retain
;; the Last/Emit and residual-tail distinctions.  The third case records that
;; already committed answers do not acquire the ownership of a later residual
;; FrontierFresh, and that force evidence stays ordered in the prefix.
(define frontier-observation-cases
  (list
   (frontier-observation-case
    'last-answer
    `(Last ,left-answer)
    '()
    (list left-answer)
    '((state (sym "left")))
    '((ScopedAnswer (state (sym "left")) ()))
    '()
    `(Last ,left-answer))
   (frontier-observation-case
    'emit-then-done
    `(Emit ,left-answer Done)
    `((EmitEvent ,left-answer))
    (list left-answer)
    '((state (sym "left")))
    '((ScopedAnswer (state (sym "left")) ()))
    '()
    'Done)
   (frontier-observation-case
    'committed-answer-with-forced-scoped-residual
    '(Emit
      (AnswerFresh
       (u:0)
       (Answer (state (sym "cat")))
       (label "owned"))
      (Forced
       (FrontierFresh
        (u:1)
        (More
         (PendingDelay
          (Work (succeed (label "ok")) (state unit))))
        (label "frontier"))))
    '((EmitEvent
       (AnswerFresh
        (u:0)
        (Answer (state (sym "cat")))
        (label "owned")))
      ForcedEvent
      (FrontierFreshEvent (u:1) (label "frontier")))
    '((AnswerFresh
       (u:0)
       (Answer (state (sym "cat")))
       (label "owned")))
    '((state (sym "cat")))
    '((ScopedAnswer
       (state (sym "cat"))
       ((Owner (u:0) (label "owned")))))
    '(ForcedEvent)
    '(More
      (PendingDelay
       (Work (succeed (label "ok")) (state unit)))))))

(define trace-observation-cases
  (list
   (trace-observation-case
    'nested-scope
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
    `(FrontierFresh
      (u:0)
      (Emit ,inner-answer
            (Emit ,inner-answer
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
    '(2 1 1 1 2 1 1 2 2)
    9
    `((FrontierFreshEvent (u:0) (label "outer-fresh"))
      (EmitEvent ,inner-answer)
      (EmitEvent ,inner-answer))
    (list inner-answer inner-answer '(Answer (state u:0)))
    '((state (u:0 : u:1))
      (state (u:0 : u:1))
      (state u:0))
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

   (trace-observation-case
    'late-hoist
    '(conj
      (disj
       (put (sym "left") (label "left"))
       (put (sym "right") (label "right"))
       (label "split"))
      (succeed (label "continue"))
      (label "and"))
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
    '(1 1 2 2 2 2)
    6
    `((EmitEvent ,left-answer))
    (list left-answer right-answer)
    '((state (sym "left"))
      (state (sym "right")))
    '((ScopedAnswer (state (sym "left")) ())
      (ScopedAnswer (state (sym "right")) ()))
    '()
    `(Last ,right-answer)
    '())

   (trace-observation-case
    'rail-turn
    '(disj
      (suspend
       (put (sym "left") (label "left"))
       (label "left-delay"))
      (suspend
       (put (sym "right") (label "right"))
       (label "right-delay"))
      (label "split"))
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
    '(1 2 1 2 1 2 2)
    7
    `(ForcedEvent
      ForcedEvent
      (EmitEvent ,left-answer))
    (list left-answer right-answer)
    '((state (sym "left"))
      (state (sym "right")))
    '((ScopedAnswer (state (sym "left")) ())
      (ScopedAnswer (state (sym "right")) ()))
    '(ForcedEvent ForcedEvent)
    `(Last ,right-answer)
    '())

   (trace-observation-case
    'right-active-fresh
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
    '(1 1 1 2 1 2 1 1 1 2 1 2 3 2)
    14
    `(ForcedEvent
      (EmitEvent ,now-answer)
      (FrontierFreshEvent (u:0) (label "fresh")))
    (list now-answer later-answer)
    '((state (sym "now"))
      (state (sym "later")))
    '((ScopedAnswer
       (state (sym "now"))
       ((Owner (u:0) (label "fresh"))))
      (ScopedAnswer
       (state (sym "later"))
       ((Owner (u:0) (label "fresh")))))
    '(ForcedEvent)
    `(Last ,later-answer)
    '((AllocateEvent (label "fresh") (x:q) (u:0))))))

;; Allocation events describe dynamic allocation edges, not globally unique
;; source binders or permanent trace IDs.  These focused cases prevent three
;; tempting but false inferences: distribution can duplicate a syntactic
;; continuation binder, an empty fresh still takes an allocation edge with no
;; marker, and an erased failed scope lets a later branch reuse its name.
(define allocation-observation-cases
  (list
   (allocation-observation-case
    'distributed-continuation-allocates-twice
    '(conj
      (disj
       (succeed (label "left"))
       (succeed (label "right"))
       (label "split"))
      (fresh
       (x:q)
       (put x:q (label "answer"))
       (label "branch-fresh"))
      (label "and"))
    '((AllocateEvent (label "branch-fresh") (x:q) (u:0))
      (AllocateEvent (label "branch-fresh") (x:q) (u:1))))
   (allocation-observation-case
    'empty-fresh-has-empty-introduction
    '(fresh
      ()
      (put (sym "answer") (label "answer"))
      (label "empty-fresh"))
    '((AllocateEvent (label "empty-fresh") () ())))
   (allocation-observation-case
    'erased-failed-scope-permits-name-reuse
    '(disj
      (fresh
       (x:failed)
       (fail (label "fail"))
       (label "failed-fresh"))
      (fresh
       (x:live)
       (put x:live (label "answer"))
       (label "live-fresh"))
      (label "split"))
    '((AllocateEvent (label "failed-fresh") (x:failed) (u:0))
      (AllocateEvent (label "live-fresh") (x:live) (u:0))))))

(define (frontier-observation-case-by-name name)
  (for/first ([candidate (in-list frontier-observation-cases)]
              #:when (equal? name
                             (frontier-observation-case-name candidate)))
    candidate))

(define (trace-observation-case-by-name name)
  (for/first ([candidate (in-list trace-observation-cases)]
              #:when (equal? name
                             (trace-observation-case-name candidate)))
    candidate))

(define (allocation-observation-case-by-name name)
  (for/first ([candidate (in-list allocation-observation-cases)]
              #:when (equal? name
                             (allocation-observation-case-name candidate)))
    candidate))
