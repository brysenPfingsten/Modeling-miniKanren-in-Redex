#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in mk-b: "../mk/compressed.rkt")
         (prefix-in mk-big: "../mk/big-step.rkt")
         (prefix-in mk-big-lang: "../mk/big-step-language.rkt")
         (prefix-in mk-d: "../mk/decomposition.rkt")
         (prefix-in mk-l: "../mk/labels.rkt")
         (prefix-in mk-m: "../mk/machine.rkt")
         (prefix-in mk-o: "../mk/observations.rkt")
         (prefix-in mk-s: "../mk/source.rkt")
         (prefix-in mk-z: "../mk/refocused.rkt")
         (prefix-in toy-b: "../toy/compressed.rkt")
         (prefix-in toy-big: "../toy/big-step.rkt")
         (prefix-in toy-big-lang: "../toy/big-step-language.rkt")
         (prefix-in toy-d: "../toy/decomposition.rkt")
         (prefix-in toy-l: "../toy/labels.rkt")
         (prefix-in toy-m: "../toy/machine.rkt")
         (prefix-in toy-o: "../toy/observations.rkt")
         (prefix-in toy-s: "../toy/source.rkt")
         (prefix-in toy-z: "../toy/refocused.rkt"))

(provide observation-tests)

(define toy-goal
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
    (label "outer-fresh")))

(define mk-goal
  '(fresh
    (x:q)
    (disj
     (conj
      (x:q =? (sym "cat") (label "bind"))
      (suspend (succeed (label "resume")) (label "delay"))
      (label "and"))
     (x:q != (sym "dog") (label "neq"))
     (label "or"))
    (label "query")))

(define (unique who results)
  (match results
    [(list result) result]
    [_ (error who "expected one result, received ~e" results)]))

(define (named-successors relation decode frontier)
  (for/list ([named
              (in-list
               (apply-reduction-relation/tag-with-names
                relation
                frontier))])
    (match-define (list name next) named)
    (list (decode (~a name)) next)))

(define (toy-source-successors frontier)
  (named-successors
   toy-s:source-red/toy
   (lambda (name)
     (term (toy-l:redex-name->label/toy ,name)))
   frontier))

(define (mk-source-successors frontier)
  (named-successors
   mk-s:source-red/mk
   (lambda (name)
     (term (mk-l:redex-name->label/mk ,name)))
   frontier))

(define (source-trace successors frontier [limit 256]
                      [reverse-labels '()]
                      [reverse-states (list frontier)])
  (match (successors frontier)
    ['() (values (reverse reverse-labels)
                 (reverse reverse-states))]
    [(list (list label next))
     (unless (positive? limit)
       (error 'source-trace "step cap reached at ~e" frontier))
     (source-trace successors
                   next
                   (sub1 limit)
                   (cons label reverse-labels)
                   (cons next reverse-states))]
    [other
     (error 'source-trace "expected deterministic source, received ~e" other)]))

(define (trace-edges labels states)
  (for/list ([label (in-list labels)]
             [before (in-list states)]
             [after (in-list (rest states))])
    `(Edge ,before ,label ,after)))

(define (toy-observation frontier)
  (list (term (toy-o:frontier-prefix-events/toy ,frontier))
        (term (toy-o:answer-states/toy ,frontier))
        (term (toy-o:scoped-answers/toy ,frontier))
        (term (toy-o:forced-events/toy ,frontier))
        (term (toy-o:residual/toy ,frontier))))

(define (mk-observation frontier)
  (list (term (mk-o:frontier-prefix-events/mk ,frontier))
        (term (mk-o:query-answers/mk ,frontier (u:0)))
        (term (mk-o:scoped-answers/mk ,frontier))
        (term (mk-o:forced-events/mk ,frontier))
        (term (mk-o:residual/mk ,frontier))))

(define (toy-prefix? before after)
  (judgment-holds
   (toy-o:observation-prefix/toy ,before ,after)))

(define (mk-prefix? before after)
  (judgment-holds
   (mk-o:observation-prefix/mk ,before ,after)))

(define (toy-frontier-delta before after)
  (judgment-holds
   (toy-o:frontier-delta/toy
    ,before
    ,after
    (FrontierEvent_delta ...))
   (FrontierEvent_delta ...)))

(define (mk-frontier-delta before after)
  (judgment-holds
   (mk-o:frontier-delta/mk
    ,before
    ,after
    (FrontierEvent_delta ...))
   (FrontierEvent_delta ...)))

(define (toy-allocation-events edges)
  (term (toy-o:allocation-events/toy ,edges)))

(define (mk-allocation-events edges)
  (term (mk-o:allocation-events/mk ,edges)))

(define (toy-trace-labels edges)
  (term (toy-o:trace-labels/toy ,edges)))

(define (mk-trace-labels edges)
  (term (mk-o:trace-labels/mk ,edges)))

(define (toy-allocation-edge-results before label after)
  (judgment-holds
   (toy-o:allocation-edge/toy
    ,before
    ,label
    ,after
    AllocationEvent)
   AllocationEvent))

(define (mk-allocation-edge-results before label after)
  (judgment-holds
   (mk-o:allocation-edge/mk
    ,before
    ,label
    ,after
    AllocationEvent)
   AllocationEvent))

(define (toy-allocation-edge-derivations before label after)
  (build-derivations
   (toy-o:allocation-edge/toy
    ,before
    ,label
    ,after
    AllocationEvent)))

(define (mk-allocation-edge-derivations before label after)
  (build-derivations
   (mk-o:allocation-edge/mk
    ,before
    ,label
    ,after
    AllocationEvent)))

(define (expected-frontier-delta label delta)
  (match label
    [`(expose-frontier-fresh core)
     (match delta
       [`((FrontierFreshEvent ,_intro ,_tag)) #t]
       [_ #f])]
    [(or `(commit-choice-answer disj)
         `(commit-right-choice-answer search-join))
     (match delta
       [`((EmitEvent ,_answer)) #t]
       [_ #f])]
    [`(force-delay delay)
     (equal? delta '(ForcedEvent))]
    [_ (null? delta)]))

(define (answer-producing-label? label)
  (match label
    [(or `(commit-choice-answer disj)
         `(commit-right-choice-answer search-join)
         `(finish-success core))
     #t]
    [_ #f]))

(define (check-trace-laws labels states observation prefix? frontier-delta
                          trace-labels rule-cost force-count
                          allocation-edge-results
                          allocation-edge-derivations
                          allocation-events)
  (define initial-forces
    (length (fourth (observation (first states)))))
  (define edges (trace-edges labels states))
  (define projected-labels (trace-labels edges))
  (check-equal? projected-labels labels)
  (for ([label (in-list labels)]
        [before (in-list states)]
        [after (in-list (rest states))])
    (define before-observation (observation before))
    (define after-observation (observation after))
    (define before-events (first before-observation))
    (define after-events (first after-observation))
    (define before-answers (second before-observation))
    (define after-answers (second after-observation))
    (define before-scoped (third before-observation))
    (define after-scoped (third after-observation))
    (define before-forces (fourth before-observation))
    (define after-forces (fourth after-observation))
    (check-true (prefix? before-events after-events) (format "events: ~e" label))
    (check-true (prefix? before-answers after-answers) (format "answers: ~e" label))
    (check-true (prefix? before-scoped after-scoped) (format "scopes: ~e" label))
    (check-equal? (length after-answers)
                  (+ (length before-answers)
                     (if (answer-producing-label? label) 1 0))
                  (format "answer delta: ~e" label))
    (check-equal? (length after-forces)
                  (+ (length before-forces)
                     (if (equal? label '(force-delay delay)) 1 0))
                  (format "force delta: ~e" label))
    (define delta (unique 'frontier-delta (frontier-delta before after)))
    (check-true (expected-frontier-delta label delta)
                (format "frontier delta ~e: ~e" label delta))
    (define allocation-results
      (allocation-edge-results before label after))
    (define expected-allocation-count
      (if (equal? label '(allocate-fresh core)) 1 0))
    (check-equal? (length allocation-results)
                  expected-allocation-count
                  (format "allocation result: ~e" label))
    ;; Count proof trees, rather than deduplicated results, so a duplicated
    ;; allocation derivation cannot hide behind an equal event payload.
    (check-equal? (length (allocation-edge-derivations before label after))
                  expected-allocation-count
                  (format "allocation derivation: ~e" label))
    (check-equal?
     (allocation-events (list `(Edge ,before ,label ,after)))
     allocation-results
     (format "allocation trace projection: ~e" label)))
  (check-equal? (rule-cost projected-labels) (length labels))
  (check-equal? (force-count projected-labels)
                (- (length (fourth (observation (last states))))
                   initial-forces))
  (check-equal? (length (allocation-events edges))
                (count (lambda (label)
                         (equal? label '(allocate-fresh core)))
                       labels)))

(define (one-step-observation-laws?
         before
         label
         after
         observation
         raw-answers
         prefix?
         frontier-delta
         trace-labels
         allocation-edge-results
         allocation-edge-derivations
         allocation-events)
  (define before-observation (observation before))
  (define after-observation (observation after))
  (define before-events (first before-observation))
  (define after-events (first after-observation))
  (define before-answers (second before-observation))
  (define after-answers (second after-observation))
  (define before-scoped (third before-observation))
  (define after-scoped (third after-observation))
  (define before-forces (fourth before-observation))
  (define after-forces (fourth after-observation))
  (define raw-before (raw-answers before))
  (define raw-after (raw-answers after))
  (define deltas (frontier-delta before after))
  (define allocation-results
    (allocation-edge-results before label after))
  (define expected-allocation-count
    (if (equal? label '(allocate-fresh core)) 1 0))
  (define edge `(Edge ,before ,label ,after))
  (and (prefix? before-events after-events)
       (prefix? before-answers after-answers)
       (prefix? raw-before raw-after)
       (prefix? before-scoped after-scoped)
       (prefix? before-forces after-forces)
       (= (length after-answers)
          (+ (length before-answers)
             (if (answer-producing-label? label) 1 0)))
       (= (length raw-after)
          (+ (length raw-before)
             (if (answer-producing-label? label) 1 0)))
       (= (length after-forces)
          (+ (length before-forces)
             (if (equal? label '(force-delay delay)) 1 0)))
       (match deltas
         [(list delta) (expected-frontier-delta label delta)]
         [_ #f])
       (equal? (trace-labels (list edge)) (list label))
       (= (length allocation-results) expected-allocation-count)
       (= (length (allocation-edge-derivations before label after))
          expected-allocation-count)
       (equal? (allocation-events (list edge)) allocation-results)))

(define (toy-answer-states frontier)
  (term (toy-o:answer-states/toy ,frontier)))

(define (mk-answer-states frontier)
  (term (mk-o:answer-states/mk ,frontier)))

(define (toy-rule-cost labels)
  (term (toy-o:rule-cost/toy ,labels)))

(define (toy-force-count labels)
  (term (toy-o:force-count/toy ,labels)))

(define (mk-rule-cost labels)
  (term (mk-o:rule-cost/mk ,labels)))

(define (mk-force-count labels)
  (term (mk-o:force-count/mk ,labels)))

(define (toy-readbacks frontier)
  (define decomposition
    (unique 'toy-decomposition
            (judgment-holds (toy-d:decompose/toy ,frontier D) D)))
  (define refocused (term (toy-z:D->Z/toy ,decomposition)))
  (define machine (term (toy-m:D->M/toy ,decomposition)))
  (define compressed
    (unique
     'toy-compressed
     (judgment-holds
      (toy-b:initial-compressed/direct/toy ,frontier B)
      B)))
  (list (term (toy-d:plug-D/toy ,decomposition))
        (term (toy-z:readback-Z/toy ,refocused))
        (term (toy-m:readback-M/toy ,machine))
        (term (toy-b:compressed-readback/toy ,compressed))))

(define (mk-readbacks frontier)
  (define decomposition
    (unique 'mk-decomposition
            (judgment-holds (mk-d:decompose/mk ,frontier D) D)))
  (define refocused (term (mk-z:D->Z/mk ,decomposition)))
  (define machine (term (mk-m:D->M/mk ,decomposition)))
  (define compressed
    (unique
     'mk-compressed
     (judgment-holds
      (mk-b:initial-compressed/direct/mk ,frontier B)
      B)))
  (list (term (mk-d:plug-D/mk ,decomposition))
        (term (mk-z:readback-Z/mk ,refocused))
        (term (mk-m:readback-M/mk ,machine))
        (term (mk-b:compressed-readback/mk ,compressed))))

(define observation-tests
  (test-suite
   "marked Phase-2 observations"

   (test-case
    "frontier factorization is a raw unique grammatical fact"
    (redex-check
     toy-o:pk-toy-observation-lang
     F
     (= 1
        (length
         (build-derivations
          (toy-o:frontier-split/toy F FF FTail))))
     #:attempts 2000)
    (redex-check
     mk-o:pk-mk-observation-lang
     F
     (= 1
        (length
         (build-derivations
          (mk-o:frontier-split/mk F FF FTail))))
     #:attempts 2000))

   (test-case
    "the frontier split reconstructs every generated frontier"
    (redex-check
     toy-o:pk-toy-observation-lang
     F
     (match (judgment-holds
             (toy-o:frontier-split/toy F FF FTail)
             (FF FTail))
       [(list (list prefix tail))
        (equal? (term F)
                (term (toy-o:restore-frontier/toy ,prefix ,tail)))]
       [_ #f])
     #:attempts 2000)
    (redex-check
     mk-o:pk-mk-observation-lang
     F
     (match (judgment-holds
             (mk-o:frontier-split/mk F FF FTail)
             (FF FTail))
       [(list (list prefix tail))
        (equal? (term F)
                (term (mk-o:restore-frontier/mk ,prefix ,tail)))]
       [_ #f])
     #:attempts 2000))

   (test-case
    "frontier, answers, ownership, force, and residual remain separate"
    (define final
      '(FrontierFresh
        (u:0)
        (Forced
         (Emit
          (AnswerFresh
           (u:1)
           (Answer (state (u:0 : u:1)))
           (label "branch"))
          (Last (Answer (state u:0)))))
        (label "outer")))
    (check-equal?
     (term (toy-o:frontier-prefix-events/toy ,final))
     '((FrontierFreshEvent (u:0) (label "outer"))
       ForcedEvent
       (EmitEvent
        (AnswerFresh
         (u:1)
         (Answer (state (u:0 : u:1)))
         (label "branch")))))
    (check-equal?
     (term (toy-o:answer-states/toy ,final))
     '((state (u:0 : u:1)) (state u:0)))
    (check-equal?
     (term (toy-o:scoped-answers/toy ,final))
     '((ScopedAnswer
        (state (u:0 : u:1))
        ((Owner (u:0) (label "outer"))
         (Owner (u:1) (label "branch"))))
       (ScopedAnswer
        (state u:0)
        ((Owner (u:0) (label "outer"))))))
    (check-equal? (term (toy-o:forced-events/toy ,final))
                  '(ForcedEvent))
    (check-equal? (term (toy-o:residual/toy ,final))
                  '(Last (Answer (state u:0)))))

   (test-case
    "toy trace satisfies exact monotonicity, delta, force, cost, and allocation laws"
    (define root (term (toy-s:initial-tree/toy ,toy-goal)))
    (define-values (labels states)
      (source-trace toy-source-successors root))
    (check-trace-laws labels
                      states
                      toy-observation
                      toy-prefix?
                      toy-frontier-delta
                      toy-trace-labels
                      toy-rule-cost
                      toy-force-count
                      toy-allocation-edge-results
                      toy-allocation-edge-derivations
                      toy-allocation-events)
    (check-equal? (toy-rule-cost labels) 13)
    (check-equal?
     (toy-allocation-events (trace-edges labels states))
     '((AllocateEvent (label "outer-fresh") (x:outer) (u:0))
       (AllocateEvent (label "branch-fresh") (x:inner) (u:1)))))

   (test-case
    "miniKanren trace satisfies the same intrinsic observation laws"
    (define root (term (mk-s:initial-tree/mk ,mk-goal)))
    (define-values (labels states)
      (source-trace mk-source-successors root))
    (check-trace-laws labels
                      states
                      mk-observation
                      mk-prefix?
                      mk-frontier-delta
                      mk-trace-labels
                      mk-rule-cost
                      mk-force-count
                      mk-allocation-edge-results
                      mk-allocation-edge-derivations
                      mk-allocation-events)
    (check-equal? (mk-rule-cost labels) 13)
    (check-equal? (mk-force-count labels) 1)
    (check-equal?
     (mk-allocation-events (trace-edges labels states))
     '((AllocateEvent (label "query") (x:q) (u:0))))
    (check-equal?
     (term (mk-o:query-answers/mk ,(last states) (u:0)))
     '((u:0) ((sym "cat"))))
    (check-not-equal?
     (term (mk-o:answer-states/mk ,(last states)))
     (term (mk-o:query-answers/mk ,(last states) (u:0)))))

   (test-case
    "generated source edges preserve every intrinsic observation law"
    (redex-check
     toy-o:pk-toy-observation-lang
     F
     (for/and ([successor (in-list (toy-source-successors (term F)))])
       (match-define (list label after) successor)
       (one-step-observation-laws?
        (term F)
        label
        after
        toy-observation
        toy-answer-states
        toy-prefix?
        toy-frontier-delta
        toy-trace-labels
        toy-allocation-edge-results
        toy-allocation-edge-derivations
        toy-allocation-events))
     #:attempts 2000)
    (redex-check
     mk-o:pk-mk-observation-lang
     F
     (for/and ([successor (in-list (mk-source-successors (term F)))])
       (match-define (list label after) successor)
       (one-step-observation-laws?
        (term F)
        label
        after
        mk-observation
        mk-answer-states
        mk-prefix?
        mk-frontier-delta
        mk-trace-labels
        mk-allocation-edge-results
        mk-allocation-edge-derivations
        mk-allocation-events))
     #:attempts 2000))

   (test-case
    "miniKanren query observations preserve empty, subset, and requested order"
    (define owned-answer
      '(FrontierFresh
        (u:0 u:1)
        (Last
         (Answer
          (state ((u:0 (sym "zero"))
                  (u:1 (sym "one")))
                 ()
                 ()
                 (label "state"))))
        (label "owner")))
    (check-equal?
     (term (mk-o:query-answers/mk ,owned-answer ()))
     '(()))
    (check-equal?
     (term (mk-o:query-answers/mk ,owned-answer (u:1)))
     '(((sym "one"))))
    (check-equal?
     (term (mk-o:query-answers/mk ,owned-answer (u:1 u:0)))
     '(((sym "one") (sym "zero"))))
    (check-equal?
     (term (mk-o:scoped-answers/mk ,owned-answer))
     '((ScopedAnswer
        (state ((u:0 (sym "zero"))
                (u:1 (sym "one")))
               ()
               ()
               (label "state"))
        ((Owner (u:0 u:1) (label "owner")))))))

   (test-case
    "allocation events are dynamic and names are fresh only against live support"
    (define empty-root
      (term
       (toy-s:initial-tree/toy
        (fresh ()
               (succeed (label "body"))
               (label "empty-fresh")))))
    (define-values (empty-labels empty-states)
      (source-trace toy-source-successors empty-root))
    (check-equal?
     (toy-allocation-events (trace-edges empty-labels empty-states))
     '((AllocateEvent (label "empty-fresh") () ())))

    ;; The first u:0 marker is erased after its branch fails.  Allocation in
    ;; the surviving branch may therefore reuse u:0: freshness is relative to
    ;; live whole-frontier support, not permanent trace history.
    (define reuse-root
      (term
       (toy-s:initial-tree/toy
        (disj
         (fresh (x:first)
                (fail (label "first-fail"))
                (label "first-fresh"))
         (fresh (x:second)
                (put x:second (label "second-answer"))
                (label "second-fresh"))
         (label "split")))))
    (define-values (reuse-labels reuse-states)
      (source-trace toy-source-successors reuse-root))
    (check-equal?
     (toy-allocation-events (trace-edges reuse-labels reuse-states))
     '((AllocateEvent (label "first-fresh") (x:first) (u:0))
       (AllocateEvent (label "second-fresh") (x:second) (u:0))))

    ;; Trace is intentionally permissive observation syntax.  A forged edge
    ;; with a non-fresh opening must nevertheless fail the allocation
    ;; judgment's repeated source premises and produce no event.
    (define forged-edge
      '(Edge
        (More
         (Work
          (fresh (x:first)
                 (fail (label "first-fail"))
                 (label "first-fresh"))
          (state unit)))
        (allocate-fresh core)
        (More
         (WorkFresh
          (u:9)
          (Work (fail (label "first-fail")) (state unit))
          (label "first-fresh")))))
    (check-equal?
     (term (toy-o:allocation-events/toy (,forged-edge)))
     '()))

   (test-case
    "local fresh-choice exposure copies but never allocates"
    (define before
      '(More
        (DisjL
         (WorkFresh
          (u:0)
          (DisjL
           (Returned (state u:0))
           (Work (put u:0 (label "inner-right")) (state unit)))
          (label "branch"))
         (Work (put (sym "outside") (label "outside")) (state unit)))))
    (define edge (unique 'local-exposure (toy-source-successors before)))
    (match-define (list label after) edge)
    ;; Membership in source-red/toy is established before the observation
    ;; projection is queried; allocation-edge is not an alternative stepper.
    (check-not-false
     (member (list label after) (toy-source-successors before)))
    (check-equal? label '(expose-choice-through-work-fresh disj))
    (check-match
     after
     `(More
       (DisjL
        (DisjL
         (WorkFresh (u:0) ,_left (label "branch"))
         (WorkFresh (u:0) ,_right (label "branch")))
        ,_outside)))
    (check-equal?
     (judgment-holds
      (toy-o:allocation-edge/toy
       ,before
       ,label
       ,after
       AllocationEvent)
      AllocationEvent)
     '()))

   (test-case
   "all exact-stage readbacks carry the same public observations"
    (define toy-root (term (toy-s:initial-tree/toy ,toy-goal)))
    (define mk-root (term (mk-s:initial-tree/mk ,mk-goal)))
    (define-values (_toy-labels toy-states)
      (source-trace toy-source-successors toy-root))
    (for ([state (in-list toy-states)])
      (for ([readback (in-list (toy-readbacks state))])
        (check-equal? (toy-observation readback)
                      (toy-observation state))))
    (define toy-outcome
      (unique
       'toy-big-step
       (judgment-holds
        (toy-big:big-step/direct/toy ,toy-root O)
        O)))
    (define toy-final
      (term (toy-big-lang:big-step-readback/toy ,toy-outcome)))
    (check-equal? (toy-observation toy-final)
                  (toy-observation (last toy-states)))
    (define-values (_mk-labels mk-states)
      (source-trace mk-source-successors mk-root))
    (for ([state (in-list mk-states)])
      (for ([readback (in-list (mk-readbacks state))])
        (check-equal? (mk-observation readback)
                      (mk-observation state))))
    (define mk-outcome
      (unique
       'mk-big-step
       (judgment-holds
        (mk-big:big-step/direct/mk ,mk-root O)
        O)))
    (define mk-final
      (term (mk-big-lang:big-step-readback/mk ,mk-outcome)))
    (check-equal? (mk-observation mk-final)
                  (mk-observation (last mk-states))))))

(module+ test
  (run-tests observation-tests))
