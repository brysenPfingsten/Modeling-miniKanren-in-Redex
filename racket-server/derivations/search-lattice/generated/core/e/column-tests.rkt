#lang racket

(require racket/runtime-path
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in e-lang:
                    "../../../core/e/language.rkt")
         (prefix-in source:
                    "../../../core/e/source.rkt")
         (prefix-in reference:
                    "../../../core/e/decomposition.rkt")
         (prefix-in generated:
                    "./column.rkt"))

(provide GENERATED-CORE-E-COLUMN)

(define-runtime-path generated-column-file "./column.rkt")

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

(define sigma-empty
  (term (state () () () (label "state"))))

(define support-empty (term (Support)))
(define support-u0 (term (Support u:0)))
(define support-u0-u1 (term (Support u:0 u:1)))

(define allocation-source
  (term
   (More
    (Conj
     (Support u:0)
     (Work
      (Support u:0 u:2)
      (∃ (x:q)
         (x:q =? u:0 (label "fresh-body"))
         (label "fresh-u1"))
      ,sigma-empty)
     (u:0 != (nat 7) (label "future-goal"))))))

(define allocation-target
  (term
   (More
    (Conj
     (Support u:0)
     (Work
      (Support u:0 u:2 u:1)
      (u:1 =? u:0 (label "fresh-body"))
      ,sigma-empty)
     (u:0 != (nat 7) (label "future-goal"))))))

;; The generated-vs-reference suite owns this corpus.  Neither generated
;; semantics nor either oracle supplies the expected labels or witnesses.
(define RULE-REPRESENTATIVES
  (list
   (list
    'expand-conjunction
    (term
     (More
      (Work
       ,support-empty
       ((succeed (label "left"))
        ∧
        (fail (label "right"))
        (label "conjunction"))
       ,sigma-empty))))
   (list
    'succeed
    (term
     (More
      (Work ,support-u0 (succeed (label "yes")) ,sigma-empty))))
   (list
    'fail
    (term
     (More
      (Work ,support-u0 (fail (label "no")) ,sigma-empty))))
   (list
    'conj-return
    (term
     (More
      (Conj
       ,support-u0
       (Returned ,support-u0-u1 ,sigma-empty)
       (u:0 =? u:0 (label "continue"))))))
   (list
    'conj-fail
    (term
     (More
      (Conj
       ,support-u0
       (Dead ,support-u0-u1)
       (succeed (label "unreachable"))))))
   (list
    'unify-success
    (term
     (More
      (Work
       ,support-u0
       (u:0 =? (nat 0) (label "unify"))
       ,sigma-empty))))
   (list
    'unify-violates-disequality
    (term
     (More
      (Work
       ,support-u0
       (u:0 =? (nat 0) (label "violates"))
       (state ()
              ((u:0 (nat 0)))
              ()
              (label "violates-state"))))))
   (list
    'unify-fail
    (term
     (More
      (Work
       ,support-empty
       ((nat 0) =? (nat 1) (label "unify-fail"))
       ,sigma-empty))))
   (list
    'disequality-success
    (term
     (More
      (Work
       ,support-empty
       ((nat 0) != (nat 1) (label "disequality-ok"))
       ,sigma-empty))))
   (list
    'disequality-fail
    (term
     (More
      (Work
       ,support-empty
       ((nat 0) != (nat 0) (label "disequality-fail"))
       ,sigma-empty))))
   (list
    'finish-success
    (term (More (Returned ,support-u0 ,sigma-empty))))
   (list
    'finish-failure
    (term (More (Dead ,support-u0))))
   (list 'allocate-fresh allocation-source)))

(define TERMINAL-REPRESENTATIVES
  (list
   (term (Done ,support-u0))
   (term
    (Last
     ,support-u0
     (Answer ,support-u0-u1 ,sigma-empty)))))

(define FINITE-SOURCE
  (term
   (More
    (Work
     (Support)
     (∃ (x:q x:r)
        (((x:q =? (sym "cat") (label "bind-x"))
          ∧
          (x:r != (sym "dog") (label "exclude-dog"))
          (label "inner-conjunction"))
         ∧
         (succeed (label "done"))
         (label "outer-conjunction"))
        (label "allocate-two"))
     ,sigma-empty))))

(define GOLDEN-LABELS
  '(allocate-fresh
    expand-conjunction
    expand-conjunction
    unify-success
    conj-return
    disequality-success
    conj-return
    succeed
    finish-success))

(define SETTLED-PRODUCER-RULE-NAMES
  '(succeed
    unify-success
    disequality-success))

(define DEAD-PRODUCER-RULE-NAMES
  '(fail
    unify-violates-disequality
    unify-fail
    disequality-fail))

(define GOLDEN-B-SPANS
  '((transition-span allocate-fresh)
    (transition-span expand-conjunction)
    (transition-span expand-conjunction)
    (transition-span unify-success conj-return)
    (transition-span disequality-success conj-return)
    (transition-span succeed finish-success)))

(define GOLDEN-TERMINAL
  (term
   (Last
    (Support u:0 u:1)
    (Answer
     (Support u:0 u:1)
     (state ((u:0 (sym "cat")))
            ((u:1 (sym "dog")))
            ((u:0 =? (sym "cat") (label "bind-x")))
            (label "state"))))))

(define GOLDEN-BIG
  (term (BigFinal ,GOLDEN-TERMINAL)))

(define (normalize-rule-name name)
  (string->symbol (~a name)))

(define (only-result who results)
  (match results
    [(list result) result]
    [_
     (error who "expected exactly one result, got ~e" results)]))

(define (decompose-both frontier)
  (define generated-results
    (judgment-holds
     (generated:decompose/generated-e ,frontier D)
     D))
  (define reference-results
    (judgment-holds
     (reference:decompose/e ,frontier D)
     D))
  (check-equal?
   (length
    (build-derivations
     (generated:decompose/generated-e ,frontier D)))
   1)
  (check-equal?
   (length
    (build-derivations
     (reference:decompose/e ,frontier D)))
   1)
  (check-equal? generated-results reference-results)
  (only-result 'decompose-both generated-results))

(define (trace-both frontier [fuel 24] [reversed-labels '()])
  (when (zero? fuel)
    (error 'trace-both "trace exceeded its explicit step bound"))
  (define decomposition (decompose-both frontier))
  (define source-results
    (apply-reduction-relation/tag-with-names source:core-e-red frontier))
  (define generated-results
    (judgment-holds
     (generated:decomposed-step/generated-e
      ,decomposition
      RuleName
      D_next)
     (RuleName D_next)))
  (define reference-results
    (judgment-holds
     (reference:decomposed-step/e
      ,decomposition
      RuleName
      D_next)
     (RuleName D_next)))
  (check-equal? generated-results reference-results)
  (match source-results
    ['()
     (check-equal? generated-results '())
     (values (reverse reversed-labels) frontier)]
    [(list (list source-name source-next))
     (check-equal?
      (length
       (build-derivations
        (generated:decomposed-step/generated-e
         ,decomposition
         RuleName
         D_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (reference:decomposed-step/e
         ,decomposition
         RuleName
         D_next)))
      1)
     (match-define
       (list generated-name generated-next)
       (only-result 'trace-both generated-results))
     (check-equal? generated-name (normalize-rule-name source-name))
     (check-equal?
      (term (generated:plug-D/generated-e ,generated-next))
      source-next)
     (trace-both
      source-next
      (sub1 fuel)
      (cons generated-name reversed-labels))]
    [_
     (error 'trace-both
            "R[E] produced a non-singleton step set: ~e"
            source-results)]))

(define (source->z frontier)
  (term
   (generated:D->Z/generated-e
    ,(decompose-both frontier))))

(define (source->m frontier)
  (term
   (generated:encode-ZM/generated-e
    ,(source->z frontier))))

(define (source->b frontier)
  (term
   (generated:encode-MB/generated-e
    ,(source->m frontier))))

(define (span-labels transition-span)
  (term
   (generated:transition-span-labels/generated-e
    ,transition-span)))

(define (zm-trace refocused machine [fuel 24] [reversed-labels '()])
  (when (zero? fuel)
    (error 'zm-trace "trace exceeded its explicit step bound"))
  (check-equal?
   (term (generated:readback-Z/generated-e ,refocused))
   (term (generated:readback-M/generated-e ,machine)))
  (define z-direct
    (judgment-holds
     (generated:refocused-step/direct/generated-e
      ,refocused
      RuleName
      Z_next)
     (RuleName Z_next)))
  (define z-spec
    (judgment-holds
     (generated:refocused-step/spec/generated-e
      ,refocused
      RuleName
      Z_next)
     (RuleName Z_next)))
  (define m-direct
    (judgment-holds
     (generated:machine-step/direct/generated-e
      ,machine
      RuleName
      M_next)
     (RuleName M_next)))
  (define m-spec
    (judgment-holds
     (generated:machine-step/spec/generated-e
      ,machine
      RuleName
      M_next)
     (RuleName M_next)))
  (check-equal? z-direct z-spec)
  (check-equal? m-direct m-spec)
  (match z-direct
    ['()
     (check-equal? m-direct '())
     (values
      (reverse reversed-labels)
      (term (generated:readback-Z/generated-e ,refocused)))]
    [(list (list label refocused-next))
     (match-define
       (list machine-label machine-next)
       (only-result 'zm-trace/m m-direct))
     (check-equal? machine-label label)
     (check-equal?
      machine-next
      (term (generated:encode-ZM/generated-e ,refocused-next)))
     (check-equal?
      (length
       (build-derivations
        (generated:refocused-step/direct/generated-e
         ,refocused
         RuleName
         Z_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (generated:refocused-step/spec/generated-e
         ,refocused
         RuleName
         Z_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (generated:machine-step/direct/generated-e
         ,machine
         RuleName
         M_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (generated:machine-step/spec/generated-e
         ,machine
         RuleName
         M_next)))
      1)
     (zm-trace
      refocused-next
      machine-next
      (sub1 fuel)
      (cons label reversed-labels))]
    [_
     (error 'zm-trace
            "Z[E] produced a non-singleton step set: ~e"
            z-direct)]))

(define (compressed-trace compressed [fuel 24] [reversed-spans '()])
  (when (zero? fuel)
    (error 'compressed-trace "trace exceeded its explicit step bound"))
  (define direct-results
    (judgment-holds
     (generated:compressed-step/direct/generated-e
      ,compressed
      TransitionSpan
      B_next)
     (TransitionSpan B_next)))
  (define spec-results
    (judgment-holds
     (generated:compressed-step/spec/generated-e
      ,compressed
      TransitionSpan
      B_next)
     (TransitionSpan B_next)))
  (check-equal? direct-results spec-results)
  (match direct-results
    ['()
     (values (reverse reversed-spans) compressed)]
    [(list (list transition-span compressed-next))
     (define machine
       (term (generated:decode-BM/generated-e ,compressed)))
     (define machine-next
       (term (generated:decode-BM/generated-e ,compressed-next)))
     (check-equal?
      (judgment-holds
       (generated:replay-transition-span/M/generated-e
        ,machine
        TransitionSpan
        M_next)
       (TransitionSpan M_next))
      (list (list transition-span machine-next)))
     (check-equal?
      (length
       (build-derivations
        (generated:compressed-step/direct/generated-e
         ,compressed
         TransitionSpan
         B_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (generated:compressed-step/spec/generated-e
         ,compressed
         TransitionSpan
         B_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (generated:replay-transition-span/M/generated-e
         ,machine
         TransitionSpan
         M_next)))
      1)
     (compressed-trace
      compressed-next
      (sub1 fuel)
      (cons transition-span reversed-spans))]
    [_
     (error 'compressed-trace
            "B[E] produced a non-singleton step set: ~e"
            direct-results)]))

(define (compressed-path compressed [fuel 24])
  (when (zero? fuel)
    (error 'compressed-path "path exceeded its explicit step bound"))
  (match
      (judgment-holds
       (generated:compressed-step/direct/generated-e
        ,compressed
        TransitionSpan
        B_next)
       (TransitionSpan B_next))
    ['() (list compressed)]
    [(list (list _transition-span compressed-next))
     (cons compressed
           (compressed-path compressed-next (sub1 fuel)))]
    [results
     (error 'compressed-path
            "B[E] produced a non-singleton step set: ~e"
            results)]))

(define/provide-test-suite GENERATED-CORE-E-COLUMN
  (test-case "generated D[E] matches R[E] and handwritten D[E] on all 13 rules"
    (define source-rule-names
      (sort
       (map normalize-rule-name
            (reduction-relation->rule-names source:core-e-red))
       symbol<?))
    (check-equal? source-rule-names CORE-RULE-NAMES)

    (define encountered
      (for/list ([representative (in-list RULE-REPRESENTATIVES)])
        (match-define (list expected-name frontier) representative)
        (define decomposition (decompose-both frontier))
        (define generated-contracts
          (judgment-holds
           (generated:contract/generated-e ,decomposition C)
           C))
        (define reference-contracts
          (judgment-holds
           (reference:contract/e ,decomposition C)
           C))
        (define generated-steps
          (judgment-holds
           (generated:decomposed-step/generated-e
            ,decomposition
            RuleName
            D_next)
           (RuleName D_next)))
        (define reference-steps
          (judgment-holds
           (reference:decomposed-step/e
            ,decomposition
            RuleName
            D_next)
           (RuleName D_next)))
        (match-define
          (list source-name source-target)
          (only-result
           'source-step
           (apply-reduction-relation/tag-with-names
            source:core-e-red
            frontier)))

        (check-true
         (redex-match?
          generated:generated-core-e-decomposition-lang
          F
          frontier))
        (check-equal?
         (redex-match?
          generated:generated-core-e-decomposition-lang
          D
          decomposition)
         (redex-match?
          reference:core-e-decomposition-lang
          D
          decomposition))
        (check-equal?
         (length
          (build-derivations
           (generated:contract/generated-e ,decomposition C)))
         1)
        (check-equal?
         (length
          (build-derivations
           (reference:contract/e ,decomposition C)))
         1)
        (check-equal?
         (length
          (build-derivations
           (generated:decomposed-step/generated-e
            ,decomposition
            RuleName
            D_next)))
         1)
        (check-equal?
         (length
          (build-derivations
           (reference:decomposed-step/e
            ,decomposition
            RuleName
            D_next)))
         1)
        (check-equal? generated-contracts reference-contracts)
        (check-equal? generated-steps reference-steps)

        (define contractum
          (only-result 'generated-contract generated-contracts))
        (match-define
          (list actual-name next-decomposition)
          (only-result 'generated-step generated-steps))
        (check-equal? actual-name expected-name)
        (check-equal? (normalize-rule-name source-name) expected-name)
        (check-equal?
         (term (generated:contract-label/generated-e ,contractum))
         expected-name)
        (check-equal?
         (term (generated:plug-D/generated-e ,next-decomposition))
         source-target)
        actual-name))

    (check-equal? (sort encountered symbol<?) CORE-RULE-NAMES))

  (test-case "generated D[E] has the same terminal grammar and raw decomposition"
    (for ([terminal (in-list TERMINAL-REPRESENTATIVES)])
      (define decomposition (decompose-both terminal))
      (check-equal? decomposition (term (Final ,terminal)))
      (check-equal?
       (term (generated:plug-D/generated-e ,decomposition))
       terminal)
      (check-equal?
       (judgment-holds
        (generated:decomposed-step/generated-e
         ,decomposition
         RuleName
         D_next)
        (RuleName D_next))
       '())))

  (test-case "generated Z[E] directly refocuses every contractum like plug/decompose"
    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (match-define (list _expected-name frontier) representative)
      (define decomposition (decompose-both frontier))
      (define contractum
        (only-result
         'refocus-contract
         (judgment-holds
          (generated:contract/generated-e ,decomposition C)
          C)))
      (define direct-results
        (judgment-holds
         (generated:refocus/direct/generated-e ,contractum Z)
         Z))
      (define spec-results
        (judgment-holds
         (generated:refocus/spec/generated-e ,contractum Z)
         Z))
      (check-equal? direct-results spec-results)
      (check-equal?
       (length
        (build-derivations
         (generated:refocus/direct/generated-e ,contractum Z)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated:refocus/spec/generated-e ,contractum Z)))
       1)))

  (test-case "generated Z[E] codecs/readback and all 13 direct/spec steps agree"
    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (match-define (list expected-name frontier) representative)
      (define decomposition (decompose-both frontier))
      (define refocused
        (term (generated:D->Z/generated-e ,decomposition)))
      (define direct-results
        (judgment-holds
         (generated:refocused-step/direct/generated-e
          ,refocused
          RuleName
          Z_next)
         (RuleName Z_next)))
      (define spec-results
        (judgment-holds
         (generated:refocused-step/spec/generated-e
          ,refocused
          RuleName
          Z_next)
         (RuleName Z_next)))
      (define reference-step
        (only-result
         'reference-step/Z
         (judgment-holds
          (reference:decomposed-step/e
           ,decomposition
           RuleName
           D_next)
          (RuleName D_next))))

      (check-true
       (redex-match?
        generated:generated-core-e-refocused-lang
        Z
        refocused))
      (check-equal?
       (term (generated:Z->D/generated-e ,refocused))
       decomposition)
      (check-equal?
       (term (generated:readback-Z/generated-e ,refocused))
       frontier)
      (check-equal?
       (length
        (build-derivations
         (generated:refocused-step/direct/generated-e
          ,refocused
          RuleName
          Z_next)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated:refocused-step/spec/generated-e
          ,refocused
          RuleName
          Z_next)))
       1)
      (check-equal? direct-results spec-results)

      (match-define
        (list actual-name refocused-next)
        (only-result 'generated-Z-step direct-results))
      (check-equal? actual-name expected-name)
      (check-equal?
       (term (generated:Z->D/generated-e ,refocused-next))
       (second reference-step)))

    (for ([terminal (in-list TERMINAL-REPRESENTATIVES)])
      (define decomposition (decompose-both terminal))
      (define refocused
        (term (generated:D->Z/generated-e ,decomposition)))
      (check-equal?
       (term (generated:Z->D/generated-e ,refocused))
       decomposition)
      (check-equal?
       (term (generated:readback-Z/generated-e ,refocused))
       terminal)
      (check-equal?
       (judgment-holds
        (generated:refocused-step/direct/generated-e
         ,refocused
         RuleName
         Z_next)
        (RuleName Z_next))
       '())))

  (test-case "generated Z[E] and M[E] are an exact four-case isomorphism"
    (define decompositions
      (append
       (for/list ([representative (in-list RULE-REPRESENTATIVES)])
         (decompose-both (second representative)))
       (for/list ([terminal (in-list TERMINAL-REPRESENTATIVES)])
         (decompose-both terminal))))
    (for ([decomposition (in-list decompositions)])
      (define refocused
        (term (generated:D->Z/generated-e ,decomposition)))
      (define machine
        (term (generated:encode-ZM/generated-e ,refocused)))
      (check-true
       (redex-match?
        generated:generated-core-e-machine-lang
        M
        machine))
      (check-equal?
       (term (generated:decode-MZ/generated-e ,machine))
       refocused)
      (check-equal?
       (term (generated:D->M/generated-e ,decomposition))
       machine)
      (check-equal?
       (term (generated:M->D/generated-e ,machine))
       decomposition)
      (check-equal?
       (term (generated:readback-M/generated-e ,machine))
       (term (generated:readback-Z/generated-e ,refocused)))))

  (test-case "all 13 specialized M[E] steps agree with transported Z[E]"
    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (match-define (list expected-name frontier) representative)
      (define refocused (source->z frontier))
      (define machine
        (term (generated:encode-ZM/generated-e ,refocused)))
      (define direct-results
        (judgment-holds
         (generated:machine-step/direct/generated-e
          ,machine
          RuleName
          M_next)
         (RuleName M_next)))
      (define spec-results
        (judgment-holds
         (generated:machine-step/spec/generated-e
          ,machine
          RuleName
          M_next)
         (RuleName M_next)))
      (define square-results
        (judgment-holds
         (generated:ZM-step-square/generated-e
          ,refocused
          RuleName
          Z_next
          M_0
          M_1)
         (RuleName Z_next M_0 M_1)))
      (check-equal?
       (length
        (build-derivations
         (generated:ZM-corresponds/generated-e ,refocused M)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated:machine-step/direct/generated-e
          ,machine
          RuleName
          M_next)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated:machine-step/spec/generated-e
          ,machine
          RuleName
          M_next)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated:ZM-step-square/generated-e
          ,refocused
          RuleName
          Z_next
          M_0
          M_1)))
       1)
      (check-equal? direct-results spec-results)
      (check-equal? (length square-results) 1)
      (match-define
        (list actual-name machine-next)
        (only-result 'generated-M-step direct-results))
      (check-equal? actual-name expected-name)
      (check-equal?
       (term (generated:readback-M/generated-e ,machine-next))
       (second
        (only-result
         'source-M-step
         (apply-reduction-relation/tag-with-names
          source:core-e-red
          frontier))))))

  (test-case "canonical M[E]/B[E] codecs cover every control and preserve readback"
    (define machines
      (append
       (for/list ([representative (in-list RULE-REPRESENTATIVES)])
         (source->m (second representative)))
       (for/list ([terminal (in-list TERMINAL-REPRESENTATIVES)])
         (source->m terminal))))
    (for ([machine (in-list machines)])
      (define compressed
        (term (generated:encode-MB/generated-e ,machine)))
      (check-true
       (redex-match?
        generated:generated-core-e-compressed-lang
        B
        compressed))
      (check-equal?
       (term (generated:decode-BM/generated-e ,compressed))
       machine)
      (check-equal?
       (term (generated:readback-B/generated-e ,compressed))
       (term (generated:readback-M/generated-e ,machine)))
      (check-equal?
       (length
        (build-derivations
         (generated:MB-corresponds/generated-e ,machine B)))
       1)))

  (test-case "all 13 B[E] entries obey the exact one/two-label replay policy"
    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (match-define (list expected-first-label frontier) representative)
      (define machine (source->m frontier))
      (define compressed
        (term (generated:encode-MB/generated-e ,machine)))
      (define direct-results
        (judgment-holds
         (generated:compressed-step/direct/generated-e
          ,compressed
          TransitionSpan
          B_next)
         (TransitionSpan B_next)))
      (define spec-results
        (judgment-holds
         (generated:compressed-step/spec/generated-e
          ,compressed
          TransitionSpan
          B_next)
         (TransitionSpan B_next)))
      (define square-results
        (judgment-holds
         (generated:MB-step-square/generated-e
          ,compressed
          TransitionSpan
          B_next
          M_0
          M_1)
         (TransitionSpan B_next M_0 M_1)))
      (check-equal?
       (length
        (build-derivations
         (generated:compressed-step/direct/generated-e
          ,compressed
          TransitionSpan
          B_next)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated:compressed-step/spec/generated-e
          ,compressed
          TransitionSpan
          B_next)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated:MB-step-square/generated-e
          ,compressed
          TransitionSpan
          B_next
          M_0
          M_1)))
       1)
      (check-equal? direct-results spec-results)
      (check-equal? (length square-results) 1)

      (match-define
        (list transition-span compressed-next)
        (only-result 'generated-B-step direct-results))
      (define labels (span-labels transition-span))
      (define expected-labels
        (cond
          [(member expected-first-label SETTLED-PRODUCER-RULE-NAMES)
           (list expected-first-label 'finish-success)]
          [(member expected-first-label DEAD-PRODUCER-RULE-NAMES)
           (list expected-first-label 'finish-failure)]
          [else
           (list expected-first-label)]))
      (check-equal? labels expected-labels)
      (check-true (<= 1 (length labels) 2))

      (define replay-results
        (judgment-holds
         (generated:replay-transition-span/M/generated-e
          ,machine
          TransitionSpan
          M_next)
         (TransitionSpan M_next)))
      (check-equal?
       (length
        (build-derivations
         (generated:replay-transition-span/M/generated-e
          ,machine
          TransitionSpan
          M_next)))
       1)
      (check-equal?
       replay-results
       (list
        (list
         transition-span
         (term
          (generated:decode-BM/generated-e
           ,compressed-next)))))))

  (test-case "generated allocation reads cumulative local Support and preserves sparse names"
    (define decomposition (decompose-both allocation-source))
    (check-equal?
     decomposition
     (term
      (DecAllocate
       (Work
        (Support u:0 u:2)
        (∃ (x:q)
           (x:q =? u:0 (label "fresh-body"))
           (label "fresh-u1"))
        ,sigma-empty)
       (More
        (Conj
         (Support u:0)
         hole
         (u:0 != (nat 7) (label "future-goal")))))))

    (define generated-step
      (only-result
       'generated-allocation
       (judgment-holds
        (generated:decomposed-step/generated-e
         ,decomposition
         RuleName
         D_next)
        (RuleName D_next))))
    (check-equal? (first generated-step) 'allocate-fresh)
    (check-equal?
     (term
      (generated:plug-D/generated-e ,(second generated-step)))
     allocation-target)
    (check-equal?
     (only-result
      'source-allocation
      (apply-reduction-relation/tag-with-names
       source:core-e-red
       allocation-source))
     (list "allocate-fresh" allocation-target)))

  (test-case "the cumulative-Support golden trace compresses exactly from M[E] to B[E]"
    (define machine (source->m FINITE-SOURCE))
    (define compressed
      (term (generated:encode-MB/generated-e ,machine)))
    (define-values (machine-labels machine-terminal)
      (zm-trace
       (source->z FINITE-SOURCE)
       machine))
    (define-values (spans compressed-terminal)
      (compressed-trace compressed))
    (check-equal? machine-labels GOLDEN-LABELS)
    (check-equal? spans GOLDEN-B-SPANS)
    (check-equal? (append-map span-labels spans) machine-labels)
    (check-equal? machine-terminal GOLDEN-TERMINAL)
    (check-equal?
     (term (generated:readback-B/generated-e ,compressed-terminal))
     GOLDEN-TERMINAL)
    (check-equal?
     (term
      (generated:readback-M/generated-e
       (generated:decode-BM/generated-e ,compressed-terminal)))
     GOLDEN-TERMINAL))

  (test-case "one finite program has the exact R[E]/D[E] trace and terminal"
    (define-values (labels terminal)
      (trace-both FINITE-SOURCE))
    (check-equal? labels GOLDEN-LABELS)
    (check-equal? terminal GOLDEN-TERMINAL))

  (test-case "the same finite program terminates identically through Z[E] and M[E]"
    (define refocused (source->z FINITE-SOURCE))
    (define machine
      (term (generated:encode-ZM/generated-e ,refocused)))
    (define-values (labels terminal)
      (zm-trace refocused machine))
    (check-equal? labels GOLDEN-LABELS)
    (check-equal? terminal GOLDEN-TERMINAL))

  (test-case "all 13 root inputs have singleton direct/spec Big[E] results"
    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (define frontier (second representative))
      (define direct-results
        (judgment-holds
         (generated:big-evaluate/direct/generated-e ,frontier Big)
         Big))
      (define spec-results
        (judgment-holds
         (generated:big-evaluate/spec/generated-e
          ,frontier
          BTrace
          Big)
         (BTrace Big)))
      (define root-square-results
        (judgment-holds
         (generated:B-Big-root-square/generated-e
          ,frontier
          BTrace
          Big)
         (BTrace Big)))
      (check-equal?
       (length
        (build-derivations
         (generated:big-evaluate/direct/generated-e
          ,frontier
          Big)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated:big-evaluate/spec/generated-e
          ,frontier
          BTrace
          Big)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated:B-Big-root-square/generated-e
          ,frontier
          BTrace
          Big)))
       1)
      (check-equal? spec-results root-square-results)
      (define direct-big
        (only-result 'generated-Big/direct direct-results))
      (match-define
        (list _trace spec-big)
        (only-result 'generated-Big/spec spec-results))
      (check-equal? direct-big spec-big)))

  (test-case "all four canonical B[E] controls use their direct Big[E] entries"
    (define success-big
      (term
       (BigFinal
        (Last
         (Support u:0)
         (Answer (Support u:0) ,sigma-empty)))))
    (define entry-cases
      (list
       (list
        (term
         (BRun
          (Work
           (Support u:0)
           (succeed (label "run"))
           ,sigma-empty)
          (More hole)))
        success-big)
       (list
        (term
         (BSettled
          (Returned (Support u:0) ,sigma-empty)
          (More hole)))
        success-big)
       (list
        (term (BDead (Support u:0) (More hole)))
        (term (BigFinal (Done (Support u:0)))))
       (list
        (term (BFinal (Done (Support u:0))))
        (term (BigFinal (Done (Support u:0)))))))
    (for ([entry-case (in-list entry-cases)]
          [entry-kind (in-list '(run settled dead final))])
      (match-define (list compressed expected-big) entry-case)
      (check-equal?
       (length
        (build-derivations
         (generated:promote-B/direct/generated-e ,compressed Big)))
       1)
      (check-equal?
       (judgment-holds
        (generated:promote-B/direct/generated-e ,compressed Big)
        Big)
       (list expected-big))
      (match entry-kind
        ['run
         (check-equal?
          (length
           (build-derivations
            (generated:big-run/direct/generated-e
             (Work
              (Support u:0)
              (succeed (label "run"))
              ,sigma-empty)
             (More hole)
             Big)))
          1)
         (check-equal?
          (judgment-holds
           (generated:big-run/direct/generated-e
            (Work
             (Support u:0)
             (succeed (label "run"))
             ,sigma-empty)
            (More hole)
            Big)
           Big)
          (list expected-big))]
        ['settled
         (check-equal?
          (length
           (build-derivations
            (generated:big-settled/direct/generated-e
             (Returned (Support u:0) ,sigma-empty)
             (More hole)
             Big)))
          1)
         (check-equal?
          (judgment-holds
           (generated:big-settled/direct/generated-e
            (Returned (Support u:0) ,sigma-empty)
            (More hole)
            Big)
           Big)
          (list expected-big))]
        ['dead
         (check-equal?
          (length
           (build-derivations
            (generated:big-dead/direct/generated-e
             (Support u:0)
             (More hole)
             Big)))
          1)
         (check-equal?
          (judgment-holds
           (generated:big-dead/direct/generated-e
            (Support u:0)
            (More hole)
            Big)
           Big)
          (list expected-big))]
        ['final
         (check-equal?
          (length
           (build-derivations
            (generated:big-final/direct/generated-e
             (Done (Support u:0))
             Big)))
          1)
         (check-equal?
          (judgment-holds
           (generated:big-final/direct/generated-e
            (Done (Support u:0))
            Big)
           Big)
          (list expected-big))])))

  (test-case "Big[E] is the exact fixed point of every golden B[E] suffix"
    (define compressed-root (source->b FINITE-SOURCE))
    (define path (compressed-path compressed-root))
    (define direct-results
      (judgment-holds
       (generated:big-evaluate/direct/generated-e ,FINITE-SOURCE Big)
       Big))
    (define spec-results
      (judgment-holds
       (generated:big-evaluate/spec/generated-e
        ,FINITE-SOURCE
        BTrace
        Big)
       (BTrace Big)))
    (define root-square-results
      (judgment-holds
       (generated:B-Big-root-square/generated-e
        ,FINITE-SOURCE
        BTrace
        Big)
       (BTrace Big)))
    (check-equal? direct-results (list GOLDEN-BIG))
    (check-equal?
     spec-results
     (list (list GOLDEN-B-SPANS GOLDEN-BIG)))
    (check-equal? root-square-results spec-results)
    (check-equal? (length path) (add1 (length GOLDEN-B-SPANS)))
    (check-equal?
     (term
      (generated:flatten-BTrace/generated-e ,GOLDEN-B-SPANS))
     GOLDEN-LABELS)
    (check-equal?
     (term (generated:readback-Big/generated-e ,GOLDEN-BIG))
     GOLDEN-TERMINAL)

    (for ([compressed (in-list path)]
          [index (in-naturals)])
      (define expected-trace (drop GOLDEN-B-SPANS index))
      (define closure-results
        (judgment-holds
         (generated:B-Big-closure-square/generated-e
          ,compressed
          BTrace
          Big)
         (BTrace Big)))
      (check-equal?
       (length
        (build-derivations
         (generated:promote-B/direct/generated-e ,compressed Big)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated:close-B/spec/generated-e
          ,compressed
          BTrace
          T)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated:B-Big-closure-square/generated-e
          ,compressed
          BTrace
          Big)))
       1)
      (check-equal?
       closure-results
       (list (list expected-trace GOLDEN-BIG)))

      (when (< index (length GOLDEN-B-SPANS))
        (define expected-span (list-ref GOLDEN-B-SPANS index))
        (define expected-next (list-ref path (add1 index)))
        (define unfold-results
          (judgment-holds
           (generated:B-Big-unfold-square/generated-e
            ,compressed
            TransitionSpan
            B_next
            Big)
           (TransitionSpan B_next Big)))
        (check-equal?
         (length
          (build-derivations
           (generated:B-Big-unfold-square/generated-e
            ,compressed
            TransitionSpan
            B_next
            Big)))
         1)
        (check-equal?
         unfold-results
         (list
          (list expected-span expected-next GOLDEN-BIG))))))

  (test-case "generated E has no Owners carrier or S/Q implementation dependency"
    (define owners-frontier
      (term
       (More
        (Work
         (Owners)
         (succeed (label "not-E"))
         ,sigma-empty))))
    (define owners-D
      (term
       (DecWork
        (Work
         (Owners)
         (succeed (label "not-E"))
         ,sigma-empty)
        (More hole))))
    (define owners-Z
      (term
       (ZWork
        (Work
         (Owners)
         (succeed (label "not-E"))
         ,sigma-empty)
        (More hole))))
    (define owners-M
      (term
       (MWork
        (Work
         (Owners)
         (succeed (label "not-E"))
         ,sigma-empty)
        (More hole))))
    (define owners-B
      (term
       (BRun
        (Work
         (Owners)
         (succeed (label "not-E"))
         ,sigma-empty)
        (More hole))))
    (check-false
     (redex-match?
      generated:generated-core-e-decomposition-lang
      F
      owners-frontier))
    (check-false
     (redex-match?
      generated:generated-core-e-decomposition-lang
      D
      owners-D))
    (check-false
     (redex-match?
      generated:generated-core-e-refocused-lang
      Z
      owners-Z))
    (check-false
     (redex-match?
      generated:generated-core-e-machine-lang
      M
      owners-M))
    (check-false
     (redex-match?
      generated:generated-core-e-compressed-lang
      B
      owners-B))
    (check-false
     (redex-match?
      generated:generated-core-e-big-lang
      F
      owners-frontier))
    (define contents (file->string generated-column-file))
    (for ([forbidden
           (in-list
            '("Owners"
              "s-to-e"
              "Q-SE"
              "core/s/"
              "source.rkt"
              "decomposition.rkt"))])
      (check-false
       (regexp-match? (regexp (regexp-quote forbidden)) contents))))

  (test-case "duplicate fresh binders cannot enter generated E"
    (define malformed
      (term
       (More
        (Work
         (Support)
         (∃ (x:q x:q)
            (succeed (label "body"))
            (label "duplicate"))
         ,sigma-empty))))
    (check-false
     (redex-match?
      generated:generated-core-e-decomposition-lang
      F
      malformed))))

(module+ test
  (run-tests GENERATED-CORE-E-COLUMN))
