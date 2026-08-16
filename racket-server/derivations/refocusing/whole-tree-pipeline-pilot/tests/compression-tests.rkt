#lang racket

(require racket/list
         racket/runtime-path
         rackunit
         rackunit/text-ui
         "../compressed.rkt"
         "../corpus.rkt"
         "../language.rkt"
         (prefix-in derived: "../decomposition.rkt")
         (prefix-in exact: "../refocused.rkt"))

(provide compression-tests)

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

(define all-trees
  (append witness-trees rule-coverage-trees))

;; Quoted strings are used below because source rule names are strings.  These
;; definitions are written one span per list, in exact transition order.
(define nested-partition
  '(( ("allocate-fresh" core) ("expose-frontier-fresh" core))
    ( ("expand-disjunction" disj))
    ( ("allocate-fresh" core))
    ( ("expand-disjunction" disj))
    ( ("work-put" core)
      ("expose-choice-through-work-fresh" disj))
    ( ("reassociate-left-result" disj))
    ( ("commit-choice-answer" disj))
    ( ("work-put" core) ("commit-choice-answer" disj))
    ( ("work-put" core) ("finish-success" core))))

(define rail-partition
  '(( ("expand-disjunction" disj))
    ( ("suspend-goal" delay) ("rail-enter-right" search-join))
    ( ("force-delay" delay))
    ( ("suspend-goal" delay) ("rail-return-left" search-join))
    ( ("force-delay" delay))
    ( ("work-put" core) ("commit-choice-answer" disj))
    ( ("work-put" core) ("finish-success" core))))

(define late-partition
  '(( ("expand-conjunction" core))
    ( ("expand-disjunction" disj))
    ( ("work-put" core) ("late-distribute-settled" disj))
    ( ("work-succeed" core) ("commit-choice-answer" disj))
    ( ("work-put" core) ("conj-return" core))
    ( ("work-succeed" core) ("finish-success" core))))

(define right-partition
  '(( ("expand-conjunction" core))
    ( ("expand-conjunction" core))
    ( ("allocate-fresh" core))
    ( ("work-put" core) ("conj-return" core))
    ( ("expand-disjunction" disj))
    ( ("suspend-goal" delay) ("rail-enter-right" search-join))
    ( ("bubble-delay-through-fresh" delay))
    ( ("bubble-delay-through-conj" delay))
    ( ("force-delay" delay))
    ( ("work-put" core)
      ("expose-choice-through-work-fresh" search-join))
    ( ("late-distribute-right-settled" search-join))
    ( ("work-succeed" core)
      ("commit-right-choice-answer" search-join))
    ( ("work-put" core)
      ("conj-return" core)
      ("expose-frontier-fresh" core))
    ( ("work-succeed" core) ("finish-success" core))))

(define (span->steps span)
  (for/list ([mark (in-list (transition-span-marks span))])
    (list (rule-mark-name mark)
          (rule-mark-owner mark))))

(define (trace-partition tree)
  (define-values (spans _final _status _states)
    (compressed-trace (initial-compressed tree)))
  (map span->steps spans))

(define (flatten-spans spans)
  (append-map span->steps spans))

;; The exact machine is deliberately confined to this test-only replay oracle.
(define (replay-marks state marks [index 0])
  (match marks
    ['() state]
    [(cons expected rest)
     (match (exact:machine-step state)
       [(exact:machine-transition name owner next)
        (check-equal?
         (list name owner)
         (list (rule-mark-name expected)
               (rule-mark-owner expected))
         (format "exact replay mark ~a" index))
        (replay-marks next rest (add1 index))]
       [#f
        (fail-check
         (format "exact replay ended before mark ~a" index))])]))

(define (check-compressed-replay compressed-state exact-state
                                 [limit 256]
                                 [index 0])
  (check-true (positive? limit))
  (check-equal?
   (compressed->refocused compressed-state)
   exact-state
   (format "decode before macro move ~a" index))
  (match (compressed-step compressed-state)
    [#f
     (check-false (exact:machine-step exact-state))]
    [(compressed-transition span next)
     (define replayed
       (replay-marks exact-state (transition-span-marks span)))
     (check-equal?
      (compressed->refocused next)
      replayed
      (format "decode after macro move ~a" index))
     (check-compressed-replay next
                              replayed
                              (sub1 limit)
                              (add1 index))]))

(define (check-state-index state)
  (match state
    [(CRun work context)
     (check-true (work-in-language? work))
     (check-true (derived:wf-context-in-language? context))]
    [(CSettled result context)
     (check-true (work-in-language? result))
     (check-true (derived:wf-context-in-language? context))]
    [(CDead context)
     (check-true (derived:wf-context-in-language? context))]
    [(CDelay work context)
     (check-true (work-in-language? work))
     (check-true (derived:wf-context-in-language? context))]
    [(CFinal terminal context)
     (check-true (frontier-in-language? terminal))
     (check-true (derived:ff-context-in-language? context))]))

(define (all-marks trees)
  (append-map
   (lambda (tree)
     (define-values (spans _final _status _states)
       (compressed-trace (initial-compressed tree)))
     (flatten-spans spans))
   trees))

(define-runtime-path compressed-module "../compressed.rkt")

(define compression-tests
  (test-suite
   "whole-tree pipeline pilot: symbolic transition compression"

   (test-case
    "only the four recursive dispatch modes and final mode remain"
    (check-match
     (initial-compressed nested-scope-witness-tree)
     (CRun _work `(wf-more ww-hole ff-hole)))
    (check-equal? (vector-length
                   (struct->vector
                    (CRun '(Returned (state unit))
                          '(wf-more ww-hole ff-hole))))
                  3)
    (check-equal? (vector-length
                   (struct->vector
                    (CSettled '(Returned (state unit))
                              '(wf-more ww-hole ff-hole))))
                  3)
    (check-equal? (vector-length
                   (struct->vector
                    (CDead '(wf-more ww-hole ff-hole))))
                  2)
    (check-equal? (vector-length
                   (struct->vector
                    (CDelay '(Work (succeed (label "ok")) (state unit))
                            '(wf-more ww-hole ff-hole))))
                  3)
    (check-equal? (vector-length
                   (struct->vector (CFinal 'Done 'ff-hole)))
                  3))

   (test-case
    "transition spans are nonempty ordered rule marks"
    (check-exn exn:fail:contract?
               (lambda () (transition-span '())))
    (check-exn exn:fail:contract?
               (lambda () (transition-span '(not-a-mark))))
    (check-equal?
     (transition-span-marks
      (transition-span
       (list (rule-mark "first" 'core)
             (rule-mark "second" 'delay))))
     (list (rule-mark "first" 'core)
           (rule-mark "second" 'delay))))

   (test-case
    "initial entry rejects duplicate source names"
    (check-exn
     exn:fail:contract?
     (lambda ()
       (initial-compressed
        '(More
          (Work
           (fresh (x:q x:q)
                  (succeed (label "body"))
                  (label "duplicate"))
           (state unit))))))
    (check-exn
     exn:fail:contract?
     (lambda ()
       (initial-compressed
        '(FrontierFresh
          (u:0 u:0)
          Done
          (label "duplicate"))))))

   (test-case
    "every compressed move and marker identity replay exactly"
    (for ([tree (in-list all-trees)])
      (check-compressed-replay
       (initial-compressed tree)
       (exact:initial-machine tree))))

   (test-case
    "every reachable constructor retains its grammatical context index"
    (for ([tree (in-list all-trees)])
      (define-values (_spans _final _status states)
        (compressed-trace (initial-compressed tree)))
      (for ([state (in-list states)])
        (check-state-index state))))

   (test-case
    "concatenated spans partition complete exact traces"
    (for ([tree (in-list all-trees)])
      (define-values (spans compressed-final compressed-status _states)
        (compressed-trace (initial-compressed tree)))
      (define-values (exact-steps exact-final exact-status _machines)
        (exact:machine-trace (exact:initial-machine tree)))
      (check-equal? (flatten-spans spans) exact-steps)
      (check-equal? compressed-status exact-status)
      (check-equal? (compressed->refocused compressed-final) exact-final)))

   (test-case
    "witness traces have the derived golden span partitions"
    (check-equal? (trace-partition nested-scope-witness-tree)
                  nested-partition)
    (check-equal? (trace-partition rail-turn-witness-tree)
                  rail-partition)
    (check-equal? (trace-partition late-hoist-witness-tree)
                  late-partition)
    (check-equal? (trace-partition right-active-fresh-witness-tree)
                  right-partition))

   (test-case
    "fresh and rail names retain their frozen owners"
    (define marks
      (all-marks witness-trees))
    (for ([expected
           (in-list
            '(("allocate-fresh" core)
              ("expose-frontier-fresh" core)
              ("expose-choice-through-work-fresh" disj)
              ("expose-choice-through-work-fresh" search-join)
              ("rail-enter-right" search-join)
              ("rail-return-left" search-join)
              ("force-delay" delay)))])
      (check-not-false (member expected marks)))
    (check-true
     (for/or ([partition
               (in-list (list nested-partition
                              rail-partition
                              late-partition
                              right-partition))])
       (>= (count (lambda (span) (> (length span) 1)) partition)
           2))))

   (test-case
    "failure, local fresh failure, and top delay keep derived pairings"
    (check-equal?
     (first
      (trace-partition
       '(More (Work (fail (label "fail")) (state unit)))))
     '(("work-fail" core) ("finish-failure" core)))
    (check-not-false
     (member
      '(("work-fail" core) ("erase-dead-fresh" core))
      (trace-partition (third rule-coverage-trees))))
    (check-equal?
     (first
      (trace-partition
       '(More
         (Work
          (suspend (put (sym "later") (label "later"))
                   (label "delay"))
          (state unit)))))
     '(("suspend-goal" delay) ("force-delay" delay))))

   (test-case
    "direct clauses have no source or exact-step fallback"
    (define module-text
      (file->string compressed-module))
    (check-false (regexp-match? #rx"source[.]rkt\"" module-text))
    (check-false
     (regexp-match?
      #rx"[(](source-step|contract|refocus-contract|machine-step)"
      module-text))
    (check-false (regexp-match? #rx"[(]exact:machine-step" module-text)))))

(module+ test
  (run-tests compression-tests))
