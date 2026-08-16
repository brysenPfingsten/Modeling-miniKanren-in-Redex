#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         (except-in redex/reduction-semantics plug)
         "./corpus.rkt"
         "./languages.rkt"
         "./main.rkt")

(provide whole-tree-spike-tests)

(define (scenario-result name [hoist #f] [scheduler #f])
  (define selected
    (or (scenario-by-name name)
        (error 'scenario-result "unknown scenario: ~a" name)))
  (define system
    (make-semantics (scenario-index selected)
                    #:hoist (or hoist (scenario-hoist selected))
                    #:scheduler (or scheduler (scenario-scheduler selected))))
  (define-values (steps final status trees)
    (source-trace system (scenario-initial-tree selected)))
  (values system steps final status trees))

(define (scenario-final name)
  (define-values (_system _steps final status _trees)
    (scenario-result name))
  (check-equal? status 'value name)
  final)

(define (list-prefix? prefix whole)
  (and (<= (length prefix) (length whole))
       (equal? prefix (take whole (length prefix)))))

(define (states-from-first-emit trees)
  (match trees
    ['() '()]
    [(cons `(Emit ,_answer ,_rest) _remaining) trees]
    [(cons _first rest) (states-from-first-emit rest)]))

(define (check-monotone-answers trees)
  (for ([before (in-list trees)]
        [after (in-list (rest trees))])
    (check-true (list-prefix? (extensional-answers before)
                              (extensional-answers after)))))

(define (check-machine-agreement system tree
                                 [machine (tree->machine system tree)]
                                 [limit 128])
  (check-equal? (machine->tree machine) tree)
  (match* ((source-step system tree) (machine-step machine))
    [(#f #f) (void)]
    [((transition source-name source-owner source-next)
      (transition machine-name machine-owner machine-next))
     (check-true (positive? limit))
     (check-equal? machine-name source-name)
     (check-equal? machine-owner source-owner)
     (check-equal? (machine->tree machine-next) source-next)
     (check-machine-agreement system
                              source-next
                              machine-next
                              (sub1 limit))]
    [(source-result machine-result)
     (fail-check
      (format "source/machine step mismatch: ~e versus ~e"
              source-result
              machine-result))]))

(define (check-embedded-trace parent-system child-system initial)
  (define-values (_steps _final status trees)
    (source-trace parent-system initial))
  (check-equal? status 'value)
  (for ([tree (in-list trees)])
    (check-equal? (source-step child-system tree)
                  (source-step parent-system tree))))

(define whole-tree-spike-tests
  (test-suite
   "whole-tree source/refocusing spike"

   (test-case
    "every feature node carries an executable presentation"
    (for ([candidate (in-list (list core-presentation
                                    delay-presentation
                                    disj-presentation
                                    search-presentation))])
      (check-true (procedure? (presentation-goal-language candidate)))
      (check-true (procedure? (presentation-tree-language candidate)))
      (check-true (procedure? (presentation-value-language candidate)))
      (check-true (procedure? (presentation-context-language candidate)))
      (check-true (procedure? (presentation-well-formed candidate)))
      (check-true (procedure? (presentation-reduction candidate)))
      (check-true (procedure? (presentation-observations candidate))))
    (check-false (assoc "rail-enter-right"
                        (presentation-rule-owners disj-presentation)))
    (check-equal? (assoc "finish-success"
                         (presentation-rule-owners core-presentation))
                  '("finish-success" . core))
    (check-false (assoc "commit-choice-answer"
                        (presentation-rule-owners core-presentation)))
    (check-equal? (assoc "commit-choice-answer"
                         (presentation-rule-owners disj-presentation))
                  '("commit-choice-answer" . disj))
    (check-equal? (assoc "rail-enter-right"
                         (presentation-rule-owners search-presentation))
                  '("rail-enter-right" . search-join)))

   (test-case
    "Emit and emitted-answer ownership begin at disjunction"
    (define ordinary-answer
      '(Answer (state (sym "answer"))))
    (define emitted-value
      `(Emit ,ordinary-answer Done))
    (define emitted-running-tree
      `(Emit ,ordinary-answer
             (More (Work (succeed (label "ok")) (state unit)))))
    (define emit-context
      `((emit-frame ,ordinary-answer)))
    (define answer-owned-last
      '(Last (AnswerFresh (u:0)
                          (Answer (state u:0))
                          (label "branch-fresh"))))
    (for ([index (in-list '(core delay))])
      (check-false (tree-in-language? index emitted-running-tree))
      (check-false (value-in-language? index emitted-value))
      (check-false (context-in-language? index emit-context))
      (check-false (value-in-language? index answer-owned-last)))
    (for ([index (in-list '(disj search))])
      (check-true (tree-in-language? index emitted-running-tree))
      (check-true (value-in-language? index emitted-value))
      (check-true (context-in-language? index emit-context))
      (check-true (value-in-language? index answer-owned-last))))

   (test-case
    "core terminals and disjunction answer promotion have exact forms"
    (define answer-unit
      '(Answer (state unit)))
    (define answer-left
      '(Answer (state (sym "left"))))
    (define answer-right
      '(Answer (state (sym "right"))))
    (check-equal? (scenario-final "simple success")
                  `(Last ,answer-unit))
    (check-equal? (scenario-final "simple failure")
                  'Done)
    (check-equal? (scenario-final "two disjunction answers")
                  `(Emit ,answer-left (Last ,answer-right)))
    (check-equal? (scenario-final "successful left failed right")
                  `(Emit ,answer-left Done))
    (check-equal? (scenario-final "failed left branch")
                  `(Last ,answer-right))
    (check-equal? (scenario-final "both disjunction branches fail")
                  'Done)
    (define direct-last
      `(Last ,answer-left))
    (define emitted-then-exhausted
      `(Emit ,answer-left Done))
    (check-not-equal? direct-last emitted-then-exhausted)
    (check-equal? (answer-payloads 'Done) '())
    (check-equal? (answer-payloads direct-last)
                  (list answer-left))
    (check-equal? (answer-payloads
                   `(Emit ,answer-left (Last ,answer-right)))
                  (list answer-left answer-right))
    (check-equal? (answer-payloads direct-last)
                  (answer-payloads emitted-then-exhausted))
    (check-equal? (tree-observation-answers (observe-tree direct-last))
                  (tree-observation-answers
                   (observe-tree emitted-then-exhausted)))
    (check-equal? (extensional-answers direct-last)
                  (extensional-answers emitted-then-exhausted))
    (check-equal? (frontier-events direct-last)
                  `((last ,answer-left)))
    (check-equal? (frontier-events emitted-then-exhausted)
                  `((emit ,answer-left) done))
    (check-equal? (residual-tail direct-last) direct-last)
    (check-equal? (residual-tail emitted-then-exhausted) 'Done))

   (test-case
    "an Emit node is an immutable committed prefix"
    (define-values (system _steps _final status trees)
      (scenario-result "two disjunction answers"))
    (check-equal? status 'value)
    (define emitted-states
      (states-from-first-emit trees))
    (check-false (empty? emitted-states))
    (define first-answer
      (match (first emitted-states)
        [`(Emit ,answer ,_rest) answer]))
    (for ([tree (in-list emitted-states)])
      (check-equal?
       (match tree
         [`(Emit ,answer ,_rest) answer]
         [_ #f])
       first-answer))
    (define exhausted
      (scenario-final "successful left failed right"))
    (check-match exhausted `(Emit ,_answer Done))
    (check-false (source-step system exhausted)))

   (test-case
    "the grammar enforces the completed/WIP region split"
    (define legal
      '(Emit (AnswerFresh (u:0)
                          (Answer (state (sym "cat")))
                          (label "owned"))
             (Forced
              (FrontierFresh (u:1)
                           (More
                            (PendingDelay
                             (Work (succeed (label "ok"))
                                   (state unit))))
                           (label "frontier")))))
    (check-true (well-formed-tree? 'search legal))
    (check-false
     (tree-in-language?
      'search
      '(Emit (Forced (Emit (Answer (state unit)) Done)) Done)))
    (check-false
     (tree-in-language?
      'search
      '(More (PendingDelay (Forced Done)))))
    (check-false
     (well-formed-tree?
      'search
      '(FrontierFresh (u:0 u:0)
                    Done
                    (label "duplicate"))))
    (check-equal? (residual-tail legal)
                  '(PendingDelay
                    (Work (succeed (label "ok")) (state unit))))
    (check-equal? (frontier-events legal)
                  '((emit
                     (AnswerFresh (u:0)
                                  (Answer (state (sym "cat")))
                                  (label "owned")))
                    forced
                    (frontier-fresh (u:1) (label "frontier"))
                    more)))

   (test-case
    "feature languages form the lower additive diamond"
    (define core-tree
      '(More (Work (succeed (label "ok")) (state unit))))
    (define delay-tree
      '(More
        (PendingDelay
         (Work (succeed (label "ok")) (state unit)))))
    (define disj-tree
      '(More
        (DisjL (Work (succeed (label "left")) (state unit))
               (Work (fail (label "right")) (state unit)))))
    (define join-tree
      '(More
        (DisjR (Work (succeed (label "left")) (state unit))
               (Work (succeed (label "right")) (state unit)))))
    (for ([index (in-list '(core delay disj search))])
      (check-true (tree-in-language? index core-tree)))
    (check-true (tree-in-language? 'delay delay-tree))
    (check-true (tree-in-language? 'search delay-tree))
    (check-false (tree-in-language? 'disj delay-tree))
    (check-true (tree-in-language? 'disj disj-tree))
    (check-true (tree-in-language? 'search disj-tree))
    (check-false (tree-in-language? 'delay disj-tree))
    (check-true (tree-in-language? 'search join-tree))
    (check-false (tree-in-language? 'disj join-tree)))

   (test-case
    "parent reductions embed unchanged at child nodes"
    (define core-initial
      (scenario-initial-tree (scenario-by-name "conjunction handoff")))
    (define delay-initial
      (scenario-initial-tree (scenario-by-name "top delay")))
    (define disj-initial
      (scenario-initial-tree (scenario-by-name "two disjunction answers")))
    (define core-system
      (make-semantics 'core))
    (for ([child (in-list (list (make-semantics 'delay)
                                (make-semantics 'disj #:hoist 'late)
                                (make-semantics 'search
                                                #:hoist 'late
                                                #:scheduler 'dfs)))])
      (check-embedded-trace core-system child core-initial))
    (check-embedded-trace
     (make-semantics 'delay)
     (make-semantics 'search #:hoist 'late #:scheduler 'dfs)
     delay-initial)
    (check-embedded-trace
     (make-semantics 'disj #:hoist 'late)
     (make-semantics 'search #:hoist 'late #:scheduler 'dfs)
     disj-initial))

   (test-case
    "all corpus programs terminate with their expected answer sequence"
    (for ([selected (in-list scenarios)])
      (define system
        (scenario-semantics selected))
      (define-values (steps final status _trees)
        (source-trace system
                      (scenario-initial-tree selected)))
      (check-equal? status 'value (scenario-name selected))
      (check-equal? (extensional-answers final)
                    (scenario-expected-answers selected)
                    (scenario-name selected))
      (for ([step (in-list steps)])
        (match-define (list name owner) step)
        (check-equal?
         (assoc name
                (presentation-rule-owners
                 (semantics-presentation system)))
         (cons name owner)
         (scenario-name selected)))))

   (test-case
    "frontier and answer-owned freshening remain structurally different"
    (define frontier-success-final
      (scenario-final "frontier fresh success"))
    (define-values (_frontier-system _frontier-steps frontier-final
                                    frontier-status _frontier-trees)
      (scenario-result "frontier fresh answers"))
    (define frontier-failure-final
      (scenario-final "frontier fresh answer then failure"))
    (define-values (_local-system _local-steps local-final
                                  local-status _local-trees)
      (scenario-result "branch-local fresh answer"))
    (check-equal? frontier-status 'value)
    (check-equal? local-status 'value)
    (check-match
     frontier-success-final
     `(FrontierFresh (u:0)
                   (Last (Answer (state u:0)))
                   (label "fresh")))
    (check-match
     frontier-final
     `(FrontierFresh (u:0)
                   (Emit (Answer (state u:0))
                         (Last (Answer (state u:0))))
                   (label "fresh")))
    (check-match
     frontier-failure-final
     `(FrontierFresh (u:0)
                   (Emit (Answer (state u:0)) Done)
                   (label "fresh")))
    (check-match
     local-final
     `(Emit (AnswerFresh (u:0)
                         (Answer (state u:0))
                         (label "branch-fresh"))
            (Last (Answer (state (sym "right"))))))
    (define-values (_subtree-system _subtree-steps subtree-final
                                   subtree-status _subtree-trees)
      (scenario-result "branch-local fresh subtree"))
    (check-equal? subtree-status 'value)
    (check-match
     subtree-final
     `(Emit (AnswerFresh (u:0)
                         (Answer (state u:0))
                         (label "branch-fresh"))
            (Emit (AnswerFresh (u:0)
                               (Answer (state u:0))
                               (label "branch-fresh"))
                  (Last (Answer (state (sym "outer-right"))))))))

   (test-case
    "fresh contraction allocates logical variables exactly once"
    (define frontier
      (scenario-by-name "frontier fresh answers"))
    (define system
      (scenario-semantics frontier))
    (define first-step
      (source-step system (scenario-initial-tree frontier)))
    (check-equal? (transition-name first-step) "allocate-fresh")
    (check-equal?
     (transition-next first-step)
     '(More
       (WorkFresh
        (u:0)
        (Work
         (disj (put u:0 (label "left"))
               (put u:0 (label "right"))
               (label "split"))
         (state unit))
        (label "fresh"))))
    (define-values (_subtree-system subtree-steps _subtree-final
                                   subtree-status subtree-trees)
      (scenario-result "branch-local fresh subtree"))
    (check-equal? subtree-status 'value)
    (check-equal?
     (count (lambda (step)
              (equal? step '("allocate-fresh" core)))
            subtree-steps)
     1)
    (check-true
     (for/or ([tree (in-list subtree-trees)])
       (match tree
         [`(More
            (DisjL
             (DisjL (WorkFresh (,u-left) ,_left-work ,left-tag)
                    (WorkFresh (,u-right) ,_right-work ,right-tag))
             ,_outside))
          (and (equal? u-left u-right)
               (equal? left-tag right-tag)
               (equal? u-left 'u:0)
               (equal? left-tag '(label "branch-fresh")))]
         [_ #f])))
    (define-values (_nested-system _nested-steps nested-final
                                  nested-status _nested-trees)
      (scenario-result "nested lexical fresh allocation"))
    (check-equal? nested-status 'value)
    (check-equal?
     nested-final
     '(FrontierFresh
       (u:0 u:1)
       (FrontierFresh
        (u:2)
        (Last (Answer (state (u:0 : u:2))))
        (label "inner-fresh"))
       (label "outer-fresh"))))

   (test-case
    "forced-delay evidence can occur between answer commits"
    (define-values (_system steps final status trees)
      (scenario-result "answer then delayed answer"))
    (check-equal? status 'value)
    (check-not-false (member '("force-delay" delay) steps))
    (check-equal?
     final
     '(Emit (Answer (state (sym "now")))
            (Forced
             (Last (Answer (state (sym "later")))))))
    (check-equal? (extensional-answers final)
                  '((state (sym "now"))
                    (state (sym "later"))))
    (check-monotone-answers trees))

   (test-case
    "rail interleaving uses a join-owned right-active constructor"
    (define selected
      (scenario-by-name "delayed left rail"))
    (define initial
      (scenario-initial-tree selected))
    (define rail-system
      (scenario-semantics selected))
    (define dfs-system
      (make-semantics 'search #:hoist 'late #:scheduler 'dfs))
    (define-values (rail-steps rail-final rail-status rail-trees)
      (source-trace rail-system initial))
    (define-values (dfs-steps dfs-final dfs-status _dfs-trees)
      (source-trace dfs-system initial))
    (check-equal? rail-status 'value)
    (check-equal? dfs-status 'value)
    (check-not-false
     (member '("rail-enter-right" search-join) rail-steps))
    (check-not-false
     (member '("dfs-carry-delay-left" search-join) dfs-steps))
    (check-true
     (for/or ([tree (in-list rail-trees)])
       (match tree
         [`(Forced (More (DisjR ,_left ,_right))) #t]
         [_ #f])))
    (check-equal? (extensional-answers rail-final)
                  '((state (sym "now"))
                    (state (sym "later"))))
    (check-equal? (extensional-answers dfs-final)
                  '((state (sym "later"))
                    (state (sym "now"))))
    (define-values (_turn-system turn-steps _turn-final turn-status
                                _turn-trees)
      (scenario-result "two delayed rail turns"))
    (check-equal? turn-status 'value)
    (check-not-false
     (member '("rail-enter-right" search-join) turn-steps))
    (check-not-false
     (member '("rail-return-left" search-join) turn-steps))
    (define-values (_failure-system failure-steps _failure-final
                                   failure-status _failure-trees)
      (scenario-result "rail right failure"))
    (check-equal? failure-status 'value)
    (check-not-false
     (member '("skip-right-failure" search-join) failure-steps)))

   (test-case
    "early and late are policies over one carrier"
    (define selected
      (scenario-by-name "early-late witness"))
    (define initial
      (scenario-initial-tree selected))
    (define early-system
      (make-semantics 'search #:hoist 'early #:scheduler 'rail))
    (define late-system
      (make-semantics 'search #:hoist 'late #:scheduler 'rail))
    (define after-conj
      (transition-next (source-step early-system initial)))
    (define exposed-choice
      (transition-next (source-step early-system after-conj)))
    (check-equal? exposed-choice
                  (transition-next (source-step late-system after-conj)))
    (define early-machine
      (tree->machine early-system exposed-choice))
    (define late-machine
      (tree->machine late-system exposed-choice))
    (check-match (refocused-machine-focus early-machine)
                 `(Conj (DisjL ,_left ,_right) ,_goal))
    (check-match (refocused-machine-focus late-machine)
                 `(Work ,_goal ,_state))
    (check-true
     (for/or ([frame (in-list (refocused-machine-context late-machine))])
       (match frame
         [`(conj-frame ,_goal) #t]
         [_ #f])))
    (check-equal? (transition-name (machine-step early-machine))
                  "early-distribute-choice")
    (check-equal? (transition-name (machine-step late-machine))
                  "work-put")
    (define-values (_early-steps early-final early-status _early-trees)
      (source-trace early-system initial))
    (define-values (_late-steps late-final late-status _late-trees)
      (source-trace late-system initial))
    (check-equal? early-status 'value)
    (check-equal? late-status 'value)
    (check-equal? (extensional-answers early-final)
                  (extensional-answers late-final)))

   (test-case
    "decomposition plugs back every source trace state"
    (for ([selected (in-list scenarios)])
      (define system
        (scenario-semantics selected))
      (define-values (_steps _final _status trees)
        (source-trace system (scenario-initial-tree selected)))
      (for ([tree (in-list trees)])
        (match-define (decomposition _sort focus context)
          (decompose system tree))
        (check-equal? (plug focus context)
                      tree
                      (scenario-name selected))
        (check-true
         ((presentation-context-language
           (semantics-presentation system))
          context)
         (scenario-name selected)))))

   (test-case
    "refocusing agrees step-for-step and adds no observation register"
    (for ([selected (in-list scenarios)])
      (define system
        (scenario-semantics selected))
      (define initial
        (scenario-initial-tree selected))
      (define machine
        (tree->machine system initial))
      ;; struct tag plus exactly four fields: semantics, sort, focus, context.
      (check-equal? (vector-length (struct->vector machine)) 5)
      (check-machine-agreement system initial machine))
    (define-values (system _steps _final _status trees)
      (scenario-result "two disjunction answers"))
    (define after-first-answer
      (findf (lambda (tree)
               (match tree
                 [`(Emit ,_answer (More ,_work)) #t]
                 [_ #f]))
             trees))
    (check-not-false after-first-answer)
    (define context
      (refocused-machine-context
       (tree->machine system after-first-answer)))
    (check-match context
                 `(,_work-frames ...
                   more-frame
                   (emit-frame ,_answer))))

   (test-case
    "the exported Redex relations expose the directed tree equality"
    (define core-initial
      (scenario-initial-tree (scenario-by-name "simple success")))
    (define delay-initial
      (scenario-initial-tree (scenario-by-name "top delay")))
    (define disj-initial
      (scenario-initial-tree (scenario-by-name "early-late witness")))
    (define search-initial
      (scenario-initial-tree (scenario-by-name "delayed left rail")))
    (define checks
      (list
       (list core-red (make-semantics 'core) core-initial)
       (list delay-red (make-semantics 'delay) delay-initial)
       (list disj-early-red
             (make-semantics 'disj #:hoist 'early)
             disj-initial)
       (list disj-late-red
             (make-semantics 'disj #:hoist 'late)
             disj-initial)
       (list search-early-dfs-red
             (make-semantics 'search #:hoist 'early #:scheduler 'dfs)
             search-initial)
       (list search-late-dfs-red
             (make-semantics 'search #:hoist 'late #:scheduler 'dfs)
             search-initial)
       (list search-early-rail-red
             (make-semantics 'search #:hoist 'early #:scheduler 'rail)
             search-initial)
       (list search-late-rail-red
             (make-semantics 'search #:hoist 'late #:scheduler 'rail)
             search-initial)))
    (for ([check (in-list checks)])
      (match-define (list relation system initial) check)
      (define expected
        (transition-next (source-step system initial)))
      (check-equal? (apply-reduction-relation relation initial)
                    (list expected))))))

(module+ test
  (run-tests whole-tree-spike-tests))
