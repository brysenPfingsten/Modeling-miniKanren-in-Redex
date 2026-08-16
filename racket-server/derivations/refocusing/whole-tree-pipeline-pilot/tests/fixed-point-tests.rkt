#lang racket

(require racket/list
         racket/runtime-path
         rackunit
         rackunit/text-ui
         "../compressed.rkt"
         "../corpus.rkt"
         "../fixed-point.rkt"
         "../language.rkt"
         (prefix-in source: "../source.rkt"))

(provide fixed-point-tests)

(define witness-trees
  (list nested-scope-witness-tree
        late-hoist-witness-tree
        rail-turn-witness-tree
        right-active-fresh-witness-tree))

(define outside-work
  '(Work (put (sym "outside") (label "outside")) (state unit)))

(define rule-coverage-trees
  (list
   '(More (Work (fail (label "fail")) (state unit)))
   '(More Dead)
   `(More
     (DisjL
      (Work
       (fresh (x:q)
              (fail (label "local-failure"))
              (label "local-fresh"))
       (state unit))
      ,outside-work))
   '(More (Conj Dead (succeed (label "continue"))))
   `(More (DisjL Dead ,outside-work))
   `(More (DisjR ,outside-work Dead))
   `(More
     (DisjR
      ,outside-work
      (DisjL
       (Returned (state (sym "inside")))
       (Work (put (sym "later") (label "later")) (state unit)))))
   '(More
     (Work
      (suspend (put (sym "later") (label "later"))
               (label "delay"))
      (state unit)))))

(define boundary-priority-trees
  (list
   '(More
     (WorkFresh
      (u:0)
      Dead
      (label "scope")))
   '(More
     (WorkFresh
      (u:0)
      (PendingDelay
       (Work (succeed (label "inside")) (state unit)))
      (label "scope")))
   `(More
     (WorkFresh
      (u:0)
      (DisjL (Returned (state (sym "left"))) ,outside-work)
      (label "scope")))
   `(More
     (WorkFresh
      (u:0)
      (DisjR ,outside-work (Returned (state (sym "right"))))
      (label "scope")))))

(define final-context-trees
  (list
   '(More
     (Work
      (disj (put (sym "answer") (label "answer"))
            (fail (label "failure"))
            (label "choice"))
      (state unit)))
   '(FrontierFresh
     (u:0)
     (More
      (Work
       (fresh (x:q)
              (put x:q (label "answer"))
              (label "inner-fresh"))
       (state unit)))
     (label "outer-fresh"))))

(define all-trees
  (append witness-trees
          rule-coverage-trees
          boundary-priority-trees
          final-context-trees))

(define expected-rule-marks
  '(("allocate-fresh" core)
    ("bubble-delay-through-conj" delay)
    ("bubble-delay-through-fresh" delay)
    ("commit-choice-answer" disj)
    ("commit-right-choice-answer" search-join)
    ("conj-fail" core)
    ("conj-return" core)
    ("erase-dead-fresh" core)
    ("expand-conjunction" core)
    ("expand-disjunction" disj)
    ("expose-choice-through-work-fresh" disj)
    ("expose-choice-through-work-fresh" search-join)
    ("expose-frontier-fresh" core)
    ("finish-failure" core)
    ("finish-success" core)
    ("force-delay" delay)
    ("late-distribute-right-settled" search-join)
    ("late-distribute-settled" disj)
    ("rail-enter-right" search-join)
    ("rail-return-left" search-join)
    ("reassociate-left-result" disj)
    ("reassociate-right-result" search-join)
    ("skip-left-failure" disj)
    ("skip-right-failure" search-join)
    ("suspend-goal" delay)
    ("work-fail" core)
    ("work-put" core)
    ("work-succeed" core)))

(define (erase-compressed-state state)
  (match state
    [(CRun work context)
     (PromotedStuck work context)]
    [(CSettled result context)
     (PromotedStuck result context)]
    [(CDead context)
     (PromotedStuck 'Dead context)]
    [(CDelay work context)
     (PromotedStuck `(PendingDelay ,work) context)]
    [(CFinal terminal context)
     (PromotedFinal terminal context)]))

;; This strict driver is the checkpoint-4 side of the fusion equation.  It is
;; deliberately test-only: the promoted module neither imports nor calls it.
(define (drive-marked-compressed state [limit 256])
  (match state
    [(CFinal _terminal _context)
     (erase-compressed-state state)]
    [_
     (when (zero? limit)
       (error 'drive-marked-compressed "transition limit reached"))
     (match (compressed-step state)
       [#f
        (erase-compressed-state state)]
       [(compressed-transition span next)
        (check-true (pair? (transition-span-marks span)))
        (drive-marked-compressed next (sub1 limit))])]))

(define (promote-compressed-state state)
  (match state
    [(CRun work context)
     (fixed-run work context)]
    [(CSettled result context)
     (fixed-settled result context)]
    [(CDead context)
     (fixed-dead context)]
    [(CDelay work context)
     (fixed-delay work context)]
    [(CFinal terminal context)
     (fixed-final terminal context)]))

(define (reachable-compressed-states tree)
  (define-values (_spans _final _status states)
    (compressed-trace (initial-compressed tree)))
  states)

(define (reachable-rule-marks trees)
  (remove-duplicates
   (append-map
    (lambda (tree)
      (define-values (spans _final _status _states)
        (compressed-trace (initial-compressed tree)))
      (for*/list ([span (in-list spans)]
                  [mark (in-list (transition-span-marks span))])
        (list (rule-mark-name mark)
              (rule-mark-owner mark))))
    trees)))

(define (check-one-step-unfold state)
  (define promoted
    (promote-compressed-state state))
  (match state
    [(CFinal _terminal _context)
     (check-equal? promoted (erase-compressed-state state))]
    [_
     (match (compressed-step state)
       [#f
        (check-equal? promoted (erase-compressed-state state))]
       [(compressed-transition span next)
        (check-true (pair? (transition-span-marks span)))
        (check-equal? promoted
                      (promote-compressed-state next))])]))

(define (compressed-final tree)
  (define-values (_spans final status _states)
    (compressed-trace (initial-compressed tree)))
  (check-equal? status 'value)
  final)

(define (source-final tree)
  (define-values (_steps final status _trees)
    (source:source-trace tree))
  (check-equal? status 'value)
  final)

(define (deep-suspended-goal depth [goal '(succeed (label "bottom"))])
  (if (zero? depth)
      goal
      (deep-suspended-goal
       (sub1 depth)
       `(suspend ,goal (label "deep")))))

(define-runtime-path fixed-point-module "../fixed-point.rkt")

(define fixed-point-tests
  (test-suite
   "whole-tree pipeline pilot: fixed-point promotion"

   (test-case
    "outcomes retain only category-specific final and stuck shapes"
    (check-equal?
     (vector-length (struct->vector (PromotedFinal 'Done 'ff-hole)))
     3)
    (check-equal?
     (vector-length
      (struct->vector
       (PromotedStuck
        '(Returned (state unit))
        '(wf-more ww-hole ff-hole))))
     3)
    (check-equal?
     (fixed-point-readback (PromotedFinal 'Done 'ff-hole))
     'Done)
    (check-equal?
     (fixed-point-readback
      (PromotedStuck
       '(Returned (state unit))
       '(wf-more ww-hole ff-hole)))
     '(More (Returned (state unit)))))

   (test-case
    "direct frontier entry retains prefixes without decomposition"
    (define value
      '(Emit
        (Answer (state (sym "before")))
        (FrontierFresh
         (u:0)
         (Forced Done)
         (label "scope"))))
    (define result
      (fixed-point-evaluate value))
    (check-equal?
     result
     (PromotedFinal
      'Done
      '(ff-forced
        (ff-frontier-fresh
         (u:0)
         (label "scope")
         (ff-emit (Answer (state (sym "before"))) ff-hole)))))
    (check-equal? (fixed-point-readback result) value))

   (test-case
    "direct entry rejects duplicate source names"
    (check-exn
     exn:fail:contract?
     (lambda ()
       (fixed-point-evaluate
        '(More
          (Work
           (fresh (x:q x:q)
                  (succeed (label "body"))
                  (label "duplicate"))
           (state unit))))))
    (check-exn
     exn:fail:contract?
     (lambda ()
       (fixed-point-evaluate
       '(FrontierFresh
          (u:0 u:0)
          Done
          (label "duplicate")))))
    (check-exn
     exn:fail:contract?
     (lambda ()
       (fixed-point-evaluate
        '(More
          (WorkFresh
           (u:0 u:0)
           (Returned (state unit))
           (label "duplicate"))))))
    (check-exn
     exn:fail:contract?
     (lambda ()
       (fixed-point-evaluate
        '(Last
          (AnswerFresh
           (u:0 u:0)
           (Answer (state unit))
           (label "duplicate")))))))

   (test-case
    "five promoted entries equal the strict marked compressed driver"
    (for ([tree (in-list all-trees)])
      (for ([state (in-list (reachable-compressed-states tree))])
        (check-equal? (promote-compressed-state state)
                      (drive-marked-compressed state)))))

   (test-case
    "every reachable state satisfies the one-step unfold fusion law"
    (for ([tree (in-list all-trees)])
      (for ([state (in-list (reachable-compressed-states tree))])
        (check-one-step-unfold state))))

   (test-case
    "the rule corpus reaches every promoted entry function"
    (define states
      (append-map reachable-compressed-states all-trees))
    (define marks
      (reachable-rule-marks all-trees))
    (check-true (ormap CRun? states))
    (check-true (ormap CSettled? states))
    (check-true (ormap CDead? states))
    (check-true (ormap CDelay? states))
    (check-true (ormap CFinal? states))
    (check-equal? (length marks)
                  (length expected-rule-marks)
                  "unexpected rule/owner mark in coverage corpus")
    (for ([expected (in-list expected-rule-marks)])
      (check-not-false
       (member expected marks)
       (format "missing rule mark ~e" expected))))

   (test-case
    "More priority and final frontier contexts survive fusion"
    (for ([tree (in-list boundary-priority-trees)])
      (define initial
        (initial-compressed tree))
      (match (compressed-step initial)
        [(compressed-transition span _next)
         (check-equal?
          (list (rule-mark-name (first (transition-span-marks span)))
                (rule-mark-owner (first (transition-span-marks span))))
          '("expose-frontier-fresh" core))])
      (check-equal?
       (fixed-point-evaluate tree)
       (drive-marked-compressed initial)))
    (for ([tree (in-list final-context-trees)])
      (define promoted
        (fixed-point-evaluate tree))
      (check-match promoted
                   (PromotedFinal _terminal
                                  (not 'ff-hole)))
      (check-equal? (fixed-point-readback promoted)
                    (compressed-readback (compressed-final tree))))
    (check-not-false
     (member
      '(frontier-fresh (u:1) (label "inner-fresh"))
      (source:frontier-events
       (fixed-point-readback
        (fixed-point-evaluate (second final-context-trees)))))))

   (test-case
    "fixed evaluation agrees on final readback and source observation"
    (for ([tree (in-list all-trees)])
      (define promoted
        (fixed-point-evaluate tree))
      (define compressed
        (compressed-final tree))
      (define source
        (source-final tree))
      (check-true (PromotedFinal? promoted))
      (check-equal? (fixed-point-readback promoted)
                    (compressed-readback compressed))
      (check-equal? (fixed-point-readback promoted) source)
      (check-equal?
       (source:observe-source (fixed-point-readback promoted))
       (source:observe-source source))))

   (test-case
    "the promoted recursive path contains no prior-stage machine"
    (define module-text
      (file->string fixed-point-module))
    (check-false
     (regexp-match? #rx"(source|refocused|compressed)[.]rkt\""
                    module-text))
    (check-false
     (regexp-match?
      #rx"[(](source-step|source-trace|decompose|contract|refocus[^ ]*|machine-step|machine-trace|initial-compressed|compressed-step|compressed-trace)"
      module-text))
    (for ([forbidden
           (in-list
            '("CRun" "CSettled" "CDead" "CDelay" "CFinal"
              "rule-mark" "transition-span" "compressed-transition"
              "symbolic-path" "DecWork" "DecFrontier"
              "ContractWork" "ContractFrontier"))])
      (check-false
       (regexp-match? (regexp (regexp-quote forbidden)) module-text)
       forbidden))
    (check-equal?
     (length (regexp-match* #rx"[(]struct[ ]+Promoted" module-text))
     2))

   (test-case
    "deep finite delay execution uses proper tail calls"
    (define result
      (fixed-run
       `(Work ,(deep-suspended-goal 10000) (state unit))
       '(wf-more ww-hole ff-hole)))
    (check-equal?
     result
     (PromotedFinal
      '(Last (Answer (state unit)))
      (for/fold ([context 'ff-hole])
                ([_index (in-range 10000)])
        `(ff-forced ,context)))))))

(module+ test
  (run-tests fixed-point-tests))
