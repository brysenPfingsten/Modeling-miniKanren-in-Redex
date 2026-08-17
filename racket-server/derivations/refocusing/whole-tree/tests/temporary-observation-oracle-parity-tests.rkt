#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in corpus: "../corpus/observation-cases.rkt")
         (prefix-in toy-b:
                    "../reference/marked/toy/compressed.rkt")
         (prefix-in toy-l:
                    "../reference/marked/toy/labels.rkt")
         (prefix-in toy-o:
                    "../reference/marked/toy/observations.rkt")
         (prefix-in toy-s:
                    "../reference/marked/toy/source.rkt")
         (prefix-in pilot-b:
                    "../../whole-tree-pipeline-pilot/compressed.rkt")
         (prefix-in pilot:
                    "../../whole-tree-pipeline-pilot/source.rkt")
         (prefix-in spike:
                    "../../whole-tree-spike/main.rkt"))

(provide temporary-observation-oracle-parity-tests)

;; This suite is intentionally outside the marked reference.  It transfers
;; durable observations into neutral corpus data while the broad spike and the
;; pipeline pilot are still available as temporary independent oracles.

(define (unique who results)
  (match results
    [(list result) result]
    [_ (error who "expected one result, received ~e" results)]))

(define (toy-source-successors frontier)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names
          toy-s:source-red/toy
          frontier))])
    (match-define (list name next) named)
    (list (term (toy-l:redex-name->label/toy ,(~a name))) next)))

(define (toy-source-trace frontier
                          [remaining 256]
                          [reverse-labels '()]
                          [reverse-states (list frontier)]
                          [reverse-edges '()])
  (match (toy-source-successors frontier)
    ['()
     (values (reverse reverse-labels)
             (reverse reverse-states)
             (reverse reverse-edges))]
    [(list (list label next))
     (unless (positive? remaining)
       (error 'toy-source-trace "step cap reached at ~e" frontier))
     (toy-source-trace
      next
      (sub1 remaining)
      (cons label reverse-labels)
      (cons next reverse-states)
      (cons `(Edge ,frontier ,label ,next) reverse-edges))]
    [other
     (error 'toy-source-trace
            "expected a deterministic source path, received ~e"
            other)]))

(define (toy-compressed-span-lengths frontier
                                     [remaining 256]
                                     [reverse-lengths '()])
  (define initial
    (unique
     'toy-compressed-span-lengths
     (judgment-holds
      (toy-b:initial-compressed/direct/toy ,frontier B)
      B)))
  (define (loop state remaining reverse-lengths)
    (match
        (judgment-holds
         (toy-b:compressed-step/direct/toy ,state Span B_next)
         (Span B_next))
      ['() (reverse reverse-lengths)]
      [(list (list `(transition-span ,labels ...) next))
       (unless (positive? remaining)
         (error 'toy-compressed-span-lengths
                "step cap reached at ~e"
                state))
       (loop next
             (sub1 remaining)
             (cons (length labels) reverse-lengths))]
      [other
       (error 'toy-compressed-span-lengths
              "expected a deterministic compressed path, received ~e"
              other)]))
  (loop initial remaining reverse-lengths))

(define (pilot-step->label step)
  (match-define (list name owner) step)
  (define symbolic-name (string->symbol name))
  (if (member symbolic-name '(work-succeed work-fail work-put))
      `(kernel ,symbolic-name ,owner)
      `(,symbolic-name ,owner)))

(define (legacy-prefix-events frontier-events)
  (filter-map
   (lambda (event)
     (match event
       [`(frontier-fresh ,intro ,tag)
        `(FrontierFreshEvent ,intro ,tag)]
       [`(emit ,answer) `(EmitEvent ,answer)]
       ['forced 'ForcedEvent]
       ['more #f]
       ['done #f]
       [`(last ,_answer) #f]))
   frontier-events))

(define (legacy-forced-events frontier-events)
  (filter (lambda (event) (equal? event 'ForcedEvent))
          (legacy-prefix-events frontier-events)))

(define (legacy-residual residual)
  (match residual
    ['Done 'Done]
    [`(Last ,_answer) residual]
    [_ `(More ,residual)]))

(define (pilot-scoped-answers->terms answers)
  (for/list ([answer (in-list answers)])
    `(ScopedAnswer
      ,(pilot:scoped-answer-state answer)
      ,(for/list ([owner
                   (in-list (pilot:scoped-answer-owners answer))])
         `(Owner ,(pilot:scope-owner-intro owner)
                 ,(pilot:scope-owner-tag owner))))))

(define (check-canonical-observations
         frontier
         expected-prefix-events
         expected-answer-payloads
         expected-answer-states
         expected-scoped-answers
         expected-forced-events
         expected-residual)
  (check-equal?
   (term (toy-o:frontier-prefix-events/toy ,frontier))
   expected-prefix-events)
  (check-equal?
   (term (toy-o:answer-payloads/toy ,frontier))
   expected-answer-payloads)
  (check-equal?
   (term (toy-o:answer-states/toy ,frontier))
   expected-answer-states)
  (check-equal?
   (term (toy-o:scoped-answers/toy ,frontier))
   expected-scoped-answers)
  (check-equal?
   (term (toy-o:forced-events/toy ,frontier))
   expected-forced-events)
  (check-equal?
   (term (toy-o:residual/toy ,frontier))
   expected-residual))

(define (check-pilot-observations
         frontier
         expected-prefix-events
         expected-answer-payloads
         expected-answer-states
         expected-scoped-answers
         expected-forced-events
         expected-residual)
  (define old-events (pilot:frontier-events frontier))
  (check-equal? (legacy-prefix-events old-events)
                expected-prefix-events)
  (check-equal? (pilot:answer-payloads frontier)
                expected-answer-payloads)
  (check-equal? (pilot:extensional-answers frontier)
                expected-answer-states)
  (check-equal?
   (pilot-scoped-answers->terms (pilot:scoped-answers frontier))
   expected-scoped-answers)
  (check-equal? (legacy-forced-events old-events)
                expected-forced-events)
  (check-equal? (legacy-residual (pilot:residual-tail frontier))
                expected-residual))

(define temporary-observation-oracle-parity-tests
  (test-suite
   "temporary whole-tree observation oracle parity"

   (test-case
    "direct frontier cases preserve Last/Emit, force order, and residuals"
    (for ([candidate (in-list corpus:frontier-observation-cases)])
      (define frontier
        (corpus:frontier-observation-case-frontier candidate))
      (define prefix-events
        (corpus:frontier-observation-case-prefix-events candidate))
      (define answer-payloads
        (corpus:frontier-observation-case-answer-payloads candidate))
      (define answer-states
        (corpus:frontier-observation-case-answer-states candidate))
      (define scoped-answers
        (corpus:frontier-observation-case-scoped-answers candidate))
      (define forced-events
        (corpus:frontier-observation-case-forced-events candidate))
      (define residual
        (corpus:frontier-observation-case-residual candidate))
      (check-canonical-observations
       frontier
       prefix-events
       answer-payloads
       answer-states
       scoped-answers
       forced-events
       residual)
      (check-pilot-observations
       frontier
       prefix-events
       answer-payloads
       answer-states
       scoped-answers
       forced-events
       residual)
      ;; The older broad spike lacks scoped observations, but independently
      ;; agrees on the remaining public projections.
      (check-equal?
       (legacy-prefix-events (spike:frontier-events frontier))
       prefix-events)
      (check-equal? (spike:answer-payloads frontier) answer-payloads)
      (check-equal? (spike:extensional-answers frontier) answer-states)
      (check-equal? (legacy-residual (spike:residual-tail frontier))
                    residual)))

   (test-case
    "Last and Emit remain observably distinct despite equal answers"
    (define last-case
      (corpus:frontier-observation-case-by-name 'last-answer))
    (define emit-case
      (corpus:frontier-observation-case-by-name 'emit-then-done))
    (check-equal?
     (corpus:frontier-observation-case-answer-states last-case)
     (corpus:frontier-observation-case-answer-states emit-case))
    (check-equal?
     (corpus:frontier-observation-case-scoped-answers last-case)
     (corpus:frontier-observation-case-scoped-answers emit-case))
    (check-not-equal?
     (corpus:frontier-observation-case-prefix-events last-case)
     (corpus:frontier-observation-case-prefix-events emit-case))
    (check-not-equal?
     (corpus:frontier-observation-case-residual last-case)
     (corpus:frontier-observation-case-residual emit-case)))

   (test-case
    "selected traces reproduce observations, allocations, and metrics"
    (for ([candidate (in-list corpus:trace-observation-cases)])
      (define goal (corpus:trace-observation-case-goal candidate))
      (define root (term (toy-s:initial-tree/toy ,goal)))
      (define-values (labels states edges) (toy-source-trace root))
      (define final (last states))
      (define expected-labels
        (corpus:trace-observation-case-source-labels candidate))
      (define expected-span-lengths
        (corpus:trace-observation-case-compressed-span-lengths candidate))
      (check-equal? labels expected-labels)
      (check-equal? (length labels)
                    (corpus:trace-observation-case-source-edge-count
                     candidate))
      (check-equal? final
                    (corpus:trace-observation-case-final-frontier
                     candidate))
      (check-equal?
       (term (toy-o:rule-cost/toy ,labels))
       (corpus:trace-observation-case-rule-cost candidate))
      (check-equal?
       (term (toy-o:force-count/toy ,labels))
       (corpus:trace-observation-case-force-count candidate))
      (check-equal?
       (term (toy-o:allocation-events/toy ,edges))
       (corpus:trace-observation-case-allocation-events candidate))
      (check-equal? (toy-compressed-span-lengths root)
                    expected-span-lengths)
      (check-equal?
       (length expected-span-lengths)
       (corpus:trace-observation-case-compressed-edge-count candidate))
      (check-canonical-observations
       final
       (corpus:trace-observation-case-prefix-events candidate)
       (corpus:trace-observation-case-answer-payloads candidate)
       (corpus:trace-observation-case-answer-states candidate)
       (corpus:trace-observation-case-scoped-answers candidate)
       (corpus:trace-observation-case-forced-events candidate)
       (corpus:trace-observation-case-residual candidate))

      ;; The frozen pilot must still produce the identical marked path and
      ;; compressed partition while it remains a temporary oracle.
      (define-values
        (pilot-steps pilot-final pilot-status pilot-states)
        (pilot:source-trace (pilot:initial-tree goal)))
      (check-equal? pilot-status 'value)
      (check-equal? (map pilot-step->label pilot-steps) labels)
      (check-equal? pilot-states states)
      (check-equal? pilot-final final)
      (check-pilot-observations
       pilot-final
       (corpus:trace-observation-case-prefix-events candidate)
       (corpus:trace-observation-case-answer-payloads candidate)
       (corpus:trace-observation-case-answer-states candidate)
       (corpus:trace-observation-case-scoped-answers candidate)
       (corpus:trace-observation-case-forced-events candidate)
       (corpus:trace-observation-case-residual candidate))
      (define-values
        (pilot-spans _pilot-compressed-final pilot-compressed-status
                     _pilot-compressed-states)
        (pilot-b:compressed-trace (pilot-b:initial-compressed root)))
      (check-equal? pilot-compressed-status 'value)
      (check-equal?
       (map (lambda (span)
              (length (pilot-b:transition-span-marks span)))
            pilot-spans)
       expected-span-lengths)))

   (test-case
    "allocation events retain dynamic multiplicity and live-name reuse"
    (for ([candidate (in-list corpus:allocation-observation-cases)])
      (define goal
        (corpus:allocation-observation-case-goal candidate))
      (define root (term (toy-s:initial-tree/toy ,goal)))
      (define-values (labels states edges) (toy-source-trace root))
      (check-equal?
       (term (toy-o:allocation-events/toy ,edges))
       (corpus:allocation-observation-case-allocation-events candidate))
      (define-values
        (pilot-steps pilot-final pilot-status pilot-states)
        (pilot:source-trace (pilot:initial-tree goal)))
      (check-equal? pilot-status 'value)
      (check-equal? (map pilot-step->label pilot-steps) labels)
      (check-equal? pilot-states states)
      (check-equal? pilot-final (last states))))

   (test-case
    "committed event and answer observations grow by prefix"
    (for ([candidate (in-list corpus:trace-observation-cases)])
      (define goal (corpus:trace-observation-case-goal candidate))
      (define root (term (toy-s:initial-tree/toy ,goal)))
      (define-values (_labels states _edges) (toy-source-trace root))
      (for ([before (in-list states)]
            [after (in-list (rest states))])
        (define before-events
          (term (toy-o:frontier-prefix-events/toy ,before)))
        (define after-events
          (term (toy-o:frontier-prefix-events/toy ,after)))
        (define before-answers
          (term (toy-o:answer-payloads/toy ,before)))
        (define after-answers
          (term (toy-o:answer-payloads/toy ,after)))
        (define before-scoped
          (term (toy-o:scoped-answers/toy ,before)))
        (define after-scoped
          (term (toy-o:scoped-answers/toy ,after)))
        (check-true
         (judgment-holds
          (toy-o:observation-prefix/toy
           ,before-events
           ,after-events)))
        (check-true
         (judgment-holds
          (toy-o:observation-prefix/toy
           ,before-answers
           ,after-answers)))
        (check-true
         (judgment-holds
          (toy-o:observation-prefix/toy
           ,before-scoped
           ,after-scoped))))))))

(module+ test
  (run-tests temporary-observation-oracle-parity-tests))
