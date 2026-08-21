#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in source-lang:
                    "../../../../../src/search-lattice/languages/core-lang.rkt")
         (prefix-in source-red:
                    "../../../../../src/search-lattice/reduction-relations/core-red.rkt")
         (prefix-in reference:
                    "../../../core/s/decomposition.rkt")
         (prefix-in reference-z:
                    "../../../core/s/refocused.rkt")
         (prefix-in reference-m:
                    "../../../core/s/machine.rkt")
         (prefix-in reference-m-spec:
                    "../../../core/s/machine-spec.rkt")
         (prefix-in reference-b:
                    "../../../core/s/compressed.rkt")
         (prefix-in reference-b-spec:
                    "../../../core/s/compression-spec.rkt")
         (prefix-in reference-big:
                    "../../../core/s/fixed-point.rkt")
         (prefix-in reference-big-spec:
                    "../../../core/s/fixed-point-spec.rkt")
         "./column.rkt")

(provide GENERATED-CORE-S-COLUMN)

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

(define owner-u0
  (term (Owners (Owner (u:0) (label "owner-u0")))))

(define owner-u1
  (term (Owners (Owner (u:1) (label "owner-u1")))))

(define owner-u2
  (term (Owners (Owner (u:2) (label "owner-u2")))))

(define allocation-source
  (term
   (More
    (Conj
     ,owner-u0
     (Work
      ,owner-u2
      (∃ (x:q)
         (x:q =? u:0 (label "fresh-body"))
         (label "fresh-u1"))
      ,sigma-empty)
     (u:0 != (nat 7) (label "future-goal"))))))

(define allocation-target
  (term
   (More
    (Conj
     ,owner-u0
     (Work
      (Owners
       (Owner (u:2) (label "owner-u2"))
       (Owner (u:1) (label "fresh-u1")))
      (u:1 =? u:0 (label "fresh-body"))
      ,sigma-empty)
     (u:0 != (nat 7) (label "future-goal"))))))

;; This corpus belongs to the comparison, not to the generated descriptor.
;; It therefore remains an independent observation of all production labels.
(define RULE-REPRESENTATIVES
  (list
   (list
    'expand-conjunction
    (term
     (More
      (Work
       (Owners)
       ((succeed (label "left"))
        ∧
        (fail (label "right"))
        (label "conjunction"))
       ,sigma-empty))))
   (list
    'succeed
    (term
     (More
      (Work ,owner-u0 (succeed (label "yes")) ,sigma-empty))))
   (list
    'fail
    (term
     (More
      (Work ,owner-u0 (fail (label "no")) ,sigma-empty))))
   (list
    'conj-return
    (term
     (More
      (Conj
       ,owner-u0
       (Returned ,owner-u1 ,sigma-empty)
       (u:0 =? u:0 (label "continue"))))))
   (list
    'conj-fail
    (term
     (More
      (Conj
       ,owner-u0
       (Dead ,owner-u1)
       (succeed (label "unreachable"))))))
   (list
    'allocate-fresh
    allocation-source)
   (list
    'unify-success
    (term
     (More
      (Work
       ,owner-u0
       (u:0 =? (nat 0) (label "unify"))
       ,sigma-empty))))
   (list
    'unify-violates-disequality
    (term
     (More
      (Work
       ,owner-u0
       (u:0 =? (nat 0) (label "violates"))
       (state
        ()
        ((u:0 (nat 0)))
        ()
        (label "violates-state"))))))
   (list
    'unify-fail
    (term
     (More
      (Work
       (Owners)
       ((nat 0) =? (nat 1) (label "unify-fail"))
       ,sigma-empty))))
   (list
    'disequality-success
    (term
     (More
      (Work
       (Owners)
       ((nat 0) != (nat 1) (label "disequality-ok"))
       ,sigma-empty))))
   (list
    'disequality-fail
    (term
     (More
      (Work
       (Owners)
       ((nat 0) != (nat 0) (label "disequality-fail"))
       ,sigma-empty))))
   (list
    'finish-success
    (term (More (Returned ,owner-u0 ,sigma-empty))))
   (list
    'finish-failure
    (term (More (Dead ,owner-u0))))))

(define TERMINAL-REPRESENTATIVES
  (list
   (term (Done ,owner-u0))
   (term (Last ,owner-u0 (Answer ,owner-u1 ,sigma-empty)))))

(define DUPLICATE-BINDER-SOURCE
  (term
   (More
    (Work
     (Owners)
     (∃ (x:q x:q)
        (succeed (label "duplicate-body"))
        (label "duplicate"))
     ,sigma-empty))))

(define FINITE-SOURCE
  (term
   (More
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
     ,sigma-empty))))

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

(define PRODUCER-RULE-NAMES
  '(disequality-fail
    disequality-success
    fail
    succeed
    unify-fail
    unify-success
    unify-violates-disequality))

(define SINGLETON-RULE-NAMES
  '(allocate-fresh
    conj-fail
    conj-return
    expand-conjunction
    finish-failure
    finish-success))

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
    (Owners (Owner (u:0 u:1) (label "allocate-two")))
    (Answer
     (Owners)
     (state
      ((u:0 (sym "cat")))
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
     (error who "expected one raw result, received ~e" results)]))

(define (derivation-output derivation)
  (last (derivation-term derivation)))

(define (generated-machine-trace machine
                                 [fuel 24]
                                 [reversed-labels '()])
  (when (zero? fuel)
    (error 'generated-machine-trace
           "trace exceeded its explicit step bound"))
  (define results
    (judgment-holds
     (generated-machine-step/direct/s
      ,machine
      RuleName
      M_next)
     (RuleName M_next)))
  (match results
    ['()
     (values (reverse reversed-labels) machine)]
    [(list (list rule-name machine-next))
     (check-equal?
      (length
       (build-derivations
        (generated-machine-step/direct/s
         ,machine
         RuleName
         M_next)))
      1)
     (generated-machine-trace
      machine-next
      (sub1 fuel)
      (cons rule-name reversed-labels))]
    [_
     (error 'generated-machine-trace
            "expected one or zero direct successors, received ~e"
            results)]))

(define (reference-machine-trace machine
                                 [fuel 24]
                                 [reversed-labels '()])
  (when (zero? fuel)
    (error 'reference-machine-trace
           "trace exceeded its explicit step bound"))
  (define results
    (judgment-holds
     (reference-m:machine-step/direct/s
      ,machine
      RuleName
      M_next)
     (RuleName M_next)))
  (match results
    ['()
     (values (reverse reversed-labels) machine)]
    [(list (list rule-name machine-next))
     (check-equal?
      (length
       (build-derivations
        (reference-m:machine-step/direct/s
         ,machine
         RuleName
         M_next)))
      1)
     (reference-machine-trace
      machine-next
      (sub1 fuel)
      (cons rule-name reversed-labels))]
    [_
     (error 'reference-machine-trace
            "expected one or zero direct successors, received ~e"
            results)]))

(define (generated-span-labels transition-span)
  (term (generated-transition-span-labels/s ,transition-span)))

(define (generated-compressed-trace compressed
                                    [fuel 24]
                                    [reversed-spans '()])
  (when (zero? fuel)
    (error 'generated-compressed-trace
           "trace exceeded its explicit step bound"))
  (define results
    (judgment-holds
     (generated-compressed-step/direct/s
      ,compressed
      TransitionSpan
      B_next)
     (TransitionSpan B_next)))
  (match results
    ['()
     (values (reverse reversed-spans) compressed)]
    [(list (list transition-span compressed-next))
     (check-equal?
      (length
       (build-derivations
        (generated-compressed-step/direct/s
         ,compressed
         TransitionSpan
         B_next)))
      1)
     (generated-compressed-trace
      compressed-next
      (sub1 fuel)
      (cons transition-span reversed-spans))]
    [_
     (error 'generated-compressed-trace
            "expected one or zero direct successors, received ~e"
            results)]))

(define (reference-compressed-trace compressed
                                    [fuel 24]
                                    [reversed-spans '()])
  (when (zero? fuel)
    (error 'reference-compressed-trace
           "trace exceeded its explicit step bound"))
  (define results
    (judgment-holds
     (reference-b:compressed-step/direct/s
      ,compressed
      TransitionSpan
      B_next)
     (TransitionSpan B_next)))
  (match results
    ['()
     (values (reverse reversed-spans) compressed)]
    [(list (list transition-span compressed-next))
     (check-equal?
      (length
       (build-derivations
        (reference-b:compressed-step/direct/s
         ,compressed
         TransitionSpan
         B_next)))
      1)
     (reference-compressed-trace
      compressed-next
      (sub1 fuel)
      (cons transition-span reversed-spans))]
    [_
     (error 'reference-compressed-trace
            "expected one or zero direct successors, received ~e"
            results)]))

(define (generated-compressed-path compressed [fuel 24])
  (when (zero? fuel)
    (error 'generated-compressed-path
           "path exceeded its explicit step bound"))
  (match
      (judgment-holds
       (generated-compressed-step/direct/s
        ,compressed
        TransitionSpan
        B_next)
       (TransitionSpan B_next))
    ['() (list compressed)]
    [(list (list _transition-span compressed-next))
     (cons compressed
           (generated-compressed-path compressed-next (sub1 fuel)))]
    [results
     (error 'generated-compressed-path
            "expected one or zero direct successors, received ~e"
            results)]))

(define/provide-test-suite GENERATED-CORE-S-COLUMN
  (test-case "the generated RuleName grammar has exactly the 13 production labels"
    (define production-rule-names
      (sort
       (map normalize-rule-name
            (reduction-relation->rule-names source-red:core-red))
       symbol<?))

    (check-equal? production-rule-names CORE-RULE-NAMES)
    (check-equal? (length production-rule-names) 13)
    (check-equal? (length production-rule-names)
                  (length (remove-duplicates production-rule-names)))

    (for ([rule-name (in-list CORE-RULE-NAMES)])
      (check-true
       (redex-match?
        generated-core-s-decomposition-lang
        RuleName
        rule-name))
      (check-true
       (redex-match?
        reference:core-s-decomposition-lang
        RuleName
        rule-name)))

    (check-false
     (redex-match?
      generated-core-s-decomposition-lang
      RuleName
      'not-a-core-rule))
    (check-false
     (redex-match?
      reference:core-s-decomposition-lang
      RuleName
      'not-a-core-rule)))

  (test-case "all 13 generated D equations equal production and handwritten D"
    (define encountered-rule-names
      (for/list ([representative (in-list RULE-REPRESENTATIVES)])
        (match-define (list expected-rule-name source) representative)
        (define production-steps
          (apply-reduction-relation/tag-with-names
           source-red:core-red
           source))
        (define reference-decompositions
          (build-derivations (reference:decompose/s ,source D)))
        (define generated-decompositions
          (build-derivations (generated-decompose/s ,source D)))

        (check-equal? (length production-steps) 1)
        (check-equal? (length reference-decompositions) 1)
        (check-equal? (length generated-decompositions) 1)

        (match-define (list production-name production-target)
          (only-result 'production-step production-steps))
        (define reference-D
          (derivation-output (first reference-decompositions)))
        (define generated-D
          (derivation-output (first generated-decompositions)))

        (check-equal? generated-D reference-D)
        (check-equal?
         (term (generated-plug-D/s ,generated-D))
         source)
        (check-true
         (redex-match?
          generated-core-s-decomposition-lang
          D
          generated-D))
        (check-true
         (redex-match?
          reference:core-s-decomposition-lang
          D
          generated-D))

        (define reference-contracta
          (build-derivations (reference:contract/s ,reference-D C)))
        (define generated-contracta
          (build-derivations (generated-contract/s ,generated-D C)))

        (check-equal? (length reference-contracta) 1)
        (check-equal? (length generated-contracta) 1)

        (define reference-C
          (derivation-output (first reference-contracta)))
        (define generated-C
          (derivation-output (first generated-contracta)))

        (check-equal? generated-C reference-C)
        (check-true
         (redex-match?
          generated-core-s-decomposition-lang
          C
          generated-C))
        (check-equal?
         (term (generated-contract-label/s ,generated-C))
         expected-rule-name)
        (check-equal?
         (term (reference:contract-label/s ,reference-C))
         expected-rule-name)

        (define reference-step-proofs
          (build-derivations
           (reference:decomposed-step/direct/s
            ,reference-D
            RuleName
            D_next)))
        (define generated-step-proofs
          (build-derivations
           (generated-decomposed-step/s
            ,generated-D
            RuleName
            D_next)))
        (define reference-step-results
          (judgment-holds
           (reference:decomposed-step/direct/s
            ,reference-D
            RuleName
            D_next)
           (RuleName D_next)))
        (define generated-step-results
          (judgment-holds
           (generated-decomposed-step/s
            ,generated-D
            RuleName
            D_next)
           (RuleName D_next)))

        (check-equal? (length reference-step-proofs) 1)
        (check-equal? (length generated-step-proofs) 1)
        (check-equal? generated-step-results reference-step-results)

        (match-define (list generated-name generated-next-D)
          (only-result 'generated-D-step generated-step-results))
        (check-equal? (normalize-rule-name production-name)
                      expected-rule-name)
        (check-equal? generated-name expected-rule-name)
        (check-equal?
         (term (generated-plug-D/s ,generated-next-D))
         production-target)
        generated-name))

    (check-equal? (sort encountered-rule-names symbol<?)
                  CORE-RULE-NAMES))

  (test-case "generated D uniquely decomposes and plugs both terminal forms"
    (for ([terminal (in-list TERMINAL-REPRESENTATIVES)])
      (define reference-proofs
        (build-derivations (reference:decompose/s ,terminal D)))
      (define generated-proofs
        (build-derivations (generated-decompose/s ,terminal D)))

      (check-equal? (length reference-proofs) 1)
      (check-equal? (length generated-proofs) 1)

      (define reference-D
        (derivation-output (first reference-proofs)))
      (define generated-D
        (derivation-output (first generated-proofs)))

      (check-equal? generated-D reference-D)
      (check-equal? (term (generated-plug-D/s ,generated-D)) terminal)
      (check-equal?
       (length
        (build-derivations
         (generated-decomposed-step/s
          ,generated-D
          RuleName
          D_next)))
       0)))

  (test-case "sparse S allocation preserves the exact u:1 identity"
    (define source-D
      (only-result
       'generated-allocation-decomposition
       (judgment-holds
        (generated-decompose/s ,allocation-source D)
        D)))
    (define contractum
      (only-result
       'generated-allocation-contractum
       (judgment-holds
        (generated-contract/s ,source-D C)
        C)))
    (define step-result
      (only-result
       'generated-allocation-step
       (judgment-holds
        (generated-decomposed-step/s
         ,source-D
         RuleName
         D_next)
        (RuleName D_next))))

    (check-equal? (term (generated-plug-C/s ,contractum))
                  allocation-target)
    (check-equal? (first step-result) 'allocate-fresh)
    (check-equal?
     (term (generated-plug-D/s ,(second step-result)))
     allocation-target))

  (test-case "generated Z codecs cover all four decomposition summands"
    (define decomposition-cases
      (list
       (term (Final (Done ,owner-u0)))
       (term
        (DecWork
         (Work ,owner-u0 (succeed (label "codec-work")) ,sigma-empty)
         (More hole)))
       (term
        (DecFrontier
         (More (Returned ,owner-u0 ,sigma-empty))
         hole))
       (term
        (DecAllocate
         (Work
          ,owner-u0
          (∃ (x:q)
             (succeed (label "codec-body"))
             (label "codec-fresh"))
          ,sigma-empty)
         (More hole)))))

    (for ([decomposition (in-list decomposition-cases)])
      (define generated-Z
        (term (generated-D->Z/s ,decomposition)))
      (define reference-Z
        (term (reference-z:D->Z/s ,decomposition)))
      (define generated-M
        (term (generated-encode-ZM/s ,generated-Z)))
      (define reference-M
        (term (reference-m:encode-ZM/s ,reference-Z)))

      (check-equal? generated-Z reference-Z)
      (check-equal? generated-M reference-M)
      (check-true
       (redex-match? generated-core-s-refocused-lang Z generated-Z))
      (check-true
       (redex-match? generated-core-s-machine-lang M generated-M))
      (check-equal? (term (generated-Z->D/s ,generated-Z))
                    decomposition)
      (check-equal? (term (generated-M->D/s ,generated-M))
                    decomposition)
      (check-equal? (term (generated-decode-MZ/s ,generated-M))
                    generated-Z)
      (check-equal? (term (generated-D->M/s ,decomposition))
                    generated-M)
      (check-equal? (term (generated-readback-Z/s ,generated-Z))
                    (term (generated-plug-D/s ,decomposition)))
      (check-equal? (term (generated-readback-M/s ,generated-M))
                    (term (generated-readback-Z/s ,generated-Z)))))

  (test-case "all 13 generated Z steps equal slow Z and handwritten Z"
    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (match-define (list expected-rule-name source) representative)
      (match-define (list _production-name production-target)
        (only-result
         'production-Z-step
         (apply-reduction-relation/tag-with-names
          source-red:core-red
          source)))
      (define decomposition
        (only-result
         'generated-Z-decomposition
         (judgment-holds (generated-decompose/s ,source D) D)))
      (define generated-Z
        (term (generated-D->Z/s ,decomposition)))
      (define reference-Z
        (term (reference-z:D->Z/s ,decomposition)))

      (check-equal? generated-Z reference-Z)

      (define generated-direct-proofs
        (build-derivations
         (generated-refocused-step/direct/s
          ,generated-Z
          RuleName
          Z_next)))
      (define generated-spec-proofs
        (build-derivations
         (generated-refocused-step/spec/s
          ,generated-Z
          RuleName
          Z_next)))
      (define reference-direct-proofs
        (build-derivations
         (reference-z:refocused-step/direct/s
          ,reference-Z
          RuleName
          Z_next)))
      (define reference-spec-proofs
        (build-derivations
         (reference-z:refocused-step/spec/s
          ,reference-Z
          RuleName
          Z_next)))

      (check-equal? (length generated-direct-proofs) 1)
      (check-equal? (length generated-spec-proofs) 1)
      (check-equal? (length reference-direct-proofs) 1)
      (check-equal? (length reference-spec-proofs) 1)

      (define generated-direct-results
        (judgment-holds
         (generated-refocused-step/direct/s
          ,generated-Z
          RuleName
          Z_next)
         (RuleName Z_next)))
      (define generated-spec-results
        (judgment-holds
         (generated-refocused-step/spec/s
          ,generated-Z
          RuleName
          Z_next)
         (RuleName Z_next)))
      (define reference-direct-results
        (judgment-holds
         (reference-z:refocused-step/direct/s
          ,reference-Z
          RuleName
          Z_next)
         (RuleName Z_next)))
      (define reference-spec-results
        (judgment-holds
         (reference-z:refocused-step/spec/s
          ,reference-Z
          RuleName
          Z_next)
         (RuleName Z_next)))

      (check-equal? generated-direct-results generated-spec-results)
      (check-equal? generated-direct-results reference-direct-results)
      (check-equal? generated-direct-results reference-spec-results)

      (match-define (list actual-rule-name generated-next-Z)
        (only-result 'generated-Z-step generated-direct-results))
      (check-equal? actual-rule-name expected-rule-name)
      (check-equal?
       (term (generated-readback-Z/s ,generated-next-Z))
       production-target)))

  (test-case "all 13 generated M steps commute with Z and handwritten M"
    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (match-define (list expected-rule-name source) representative)
      (match-define (list _production-name production-target)
        (only-result
         'production-M-step
         (apply-reduction-relation/tag-with-names
          source-red:core-red
          source)))
      (define decomposition
        (only-result
         'generated-M-decomposition
         (judgment-holds (generated-decompose/s ,source D) D)))
      (define generated-Z
        (term (generated-D->Z/s ,decomposition)))
      (define reference-Z
        (term (reference-z:D->Z/s ,decomposition)))
      (define generated-M
        (term (generated-encode-ZM/s ,generated-Z)))
      (define reference-M
        (term (reference-m:encode-ZM/s ,reference-Z)))

      (check-equal? generated-M reference-M)

      (define generated-direct-proofs
        (build-derivations
         (generated-machine-step/direct/s
          ,generated-M
          RuleName
          M_next)))
      (define generated-spec-proofs
        (build-derivations
         (generated-machine-step/spec/s
          ,generated-M
          RuleName
          M_next)))
      (define generated-square-proofs
        (build-derivations
         (generated-ZM-step-square/s
          ,generated-Z
          RuleName
          Z_next
          M_0
          M_1)))
      (define generated-correspondence-proofs
        (build-derivations
         (generated-ZM-corresponds/s ,generated-Z M_0)))
      (define reference-direct-proofs
        (build-derivations
         (reference-m:machine-step/direct/s
          ,reference-M
          RuleName
          M_next)))
      (define reference-spec-proofs
        (build-derivations
         (reference-m-spec:machine-step/spec/s
          ,reference-M
          RuleName
          M_next)))
      (define reference-square-proofs
        (build-derivations
         (reference-m-spec:ZM-step-square/s
          ,reference-Z
          RuleName
          Z_next
          M_0
          M_1)))

      (for ([proofs
             (in-list
              (list generated-direct-proofs
                    generated-spec-proofs
                    generated-square-proofs
                    generated-correspondence-proofs
                    reference-direct-proofs
                    reference-spec-proofs
                    reference-square-proofs))])
        (check-equal? (length proofs) 1))

      (define generated-direct-results
        (judgment-holds
         (generated-machine-step/direct/s
          ,generated-M
          RuleName
          M_next)
         (RuleName M_next)))
      (define generated-spec-results
        (judgment-holds
         (generated-machine-step/spec/s
          ,generated-M
          RuleName
          M_next)
         (RuleName M_next)))
      (define reference-direct-results
        (judgment-holds
         (reference-m:machine-step/direct/s
          ,reference-M
          RuleName
          M_next)
         (RuleName M_next)))
      (define reference-spec-results
        (judgment-holds
         (reference-m-spec:machine-step/spec/s
          ,reference-M
          RuleName
          M_next)
         (RuleName M_next)))

      (check-equal? generated-direct-results generated-spec-results)
      (check-equal? generated-direct-results reference-direct-results)
      (check-equal? generated-direct-results reference-spec-results)

      (match-define (list actual-rule-name generated-next-M)
        (only-result 'generated-M-step generated-direct-results))
      (check-equal? actual-rule-name expected-rule-name)
      (check-equal?
       (term (generated-readback-M/s ,generated-next-M))
       production-target)))

  (test-case "generated and handwritten M have the same complete golden trace"
    (define source-D
      (only-result
       'golden-M-decomposition
       (judgment-holds (generated-decompose/s ,FINITE-SOURCE D) D)))
    (define generated-source-M
      (term
       (generated-encode-ZM/s
        (generated-D->Z/s ,source-D))))
    (define reference-source-M
      (term
       (reference-m:encode-ZM/s
        (reference-z:D->Z/s ,source-D))))
    (define-values (generated-labels generated-terminal-M)
      (generated-machine-trace generated-source-M))
    (define-values (reference-labels reference-terminal-M)
      (reference-machine-trace reference-source-M))

    (check-equal? generated-source-M reference-source-M)
    (check-equal? generated-labels GOLDEN-M-LABELS)
    (check-equal? generated-labels reference-labels)
    (check-equal? generated-terminal-M reference-terminal-M)
    (check-equal?
     (term (generated-readback-M/s ,generated-terminal-M))
     GOLDEN-TERMINAL)
    (check-equal?
     (term (reference-m:readback-M/s ,reference-terminal-M))
     GOLDEN-TERMINAL))

  (test-case "all 13 B entries implement exactly seven fused and six singleton spans"
    (define observed-span-lengths
      (for/list ([representative (in-list RULE-REPRESENTATIVES)])
        (match-define (list expected-rule-name source) representative)
        (define source-D
          (only-result
           'generated-B-decomposition
           (judgment-holds (generated-decompose/s ,source D) D)))
        (define generated-M
          (term (generated-D->M/s ,source-D)))
        (define reference-M
          (term (reference-m:D->M/s ,source-D)))
        (define generated-B
          (term (generated-encode-MB/s ,generated-M)))
        (define reference-B
          (term (reference-b:encode-MB/s ,reference-M)))

        (check-equal? generated-M reference-M)
        (check-equal? generated-B reference-B)
        (check-equal? (term (generated-decode-BM/s ,generated-B))
                      generated-M)
        (check-equal? (term (generated-readback-B/s ,generated-B))
                      source)
        (check-true
         (redex-match? generated-core-s-compressed-lang B generated-B))

        (define generated-direct-proofs
          (build-derivations
           (generated-compressed-step/direct/s
            ,generated-B
            TransitionSpan
            B_next)))
        (define generated-spec-proofs
          (build-derivations
           (generated-compressed-step/spec/s
            ,generated-B
            TransitionSpan
            B_next)))
        (define generated-square-proofs
          (build-derivations
           (generated-MB-step-square/s
            ,generated-B
            TransitionSpan
            B_next
            M_0
            M_1)))
        (define generated-correspondence-proofs
          (build-derivations
           (generated-MB-corresponds/s ,generated-M B_0)))
        (define reference-direct-proofs
          (build-derivations
           (reference-b:compressed-step/direct/s
            ,reference-B
            TransitionSpan
            B_next)))
        (define reference-spec-proofs
          (build-derivations
           (reference-b-spec:compressed-step/spec/s
            ,reference-B
            TransitionSpan
            B_next)))
        (define reference-square-proofs
          (build-derivations
           (reference-b-spec:MB-step-square/s
            ,reference-B
            TransitionSpan
            B_next
            M_0
            M_1)))

        (for ([proofs
               (in-list
                (list generated-direct-proofs
                      generated-spec-proofs
                      generated-square-proofs
                      generated-correspondence-proofs
                      reference-direct-proofs
                      reference-spec-proofs
                      reference-square-proofs))])
          (check-equal? (length proofs) 1))

        (define generated-direct-results
          (judgment-holds
           (generated-compressed-step/direct/s
            ,generated-B
            TransitionSpan
            B_next)
           (TransitionSpan B_next)))
        (define generated-spec-results
          (judgment-holds
           (generated-compressed-step/spec/s
            ,generated-B
            TransitionSpan
            B_next)
           (TransitionSpan B_next)))
        (define reference-direct-results
          (judgment-holds
           (reference-b:compressed-step/direct/s
            ,reference-B
            TransitionSpan
            B_next)
           (TransitionSpan B_next)))
        (define reference-spec-results
          (judgment-holds
           (reference-b-spec:compressed-step/spec/s
            ,reference-B
            TransitionSpan
            B_next)
           (TransitionSpan B_next)))

        (check-equal? generated-direct-results generated-spec-results)
        (check-equal? generated-direct-results reference-direct-results)
        (check-equal? generated-direct-results reference-spec-results)

        (match-define (list transition-span generated-next-B)
          (only-result 'generated-B-step generated-direct-results))
        (define labels (generated-span-labels transition-span))
        (define generated-next-M
          (term (generated-decode-BM/s ,generated-next-B)))
        (define generated-replay-proofs
          (build-derivations
           (generated-replay-transition-span/M/s
            ,generated-M
            TransitionSpan
            M_next)))
        (define reference-replay-proofs
          (build-derivations
           (reference-b-spec:replay-transition-span/M/s
            ,reference-M
            TransitionSpan
            M_next)))

        (check-equal? (length generated-replay-proofs) 1)
        (check-equal? (length reference-replay-proofs) 1)
        (check-equal?
         (judgment-holds
          (generated-replay-transition-span/M/s
           ,generated-M
           TransitionSpan
           M_next)
          (TransitionSpan M_next))
         (list (list transition-span generated-next-M)))
        (check-equal? (first labels) expected-rule-name)
        (check-true (<= 1 (length labels) 2))
        (list expected-rule-name (length labels))))

    (define observed-producers
      (sort
       (for/list ([observation (in-list observed-span-lengths)]
                  #:when (= (second observation) 2))
         (first observation))
       symbol<?))
    (define observed-singletons
      (sort
       (for/list ([observation (in-list observed-span-lengths)]
                  #:when (= (second observation) 1))
         (first observation))
       symbol<?))

    (check-equal? observed-producers PRODUCER-RULE-NAMES)
    (check-equal? observed-singletons SINGLETON-RULE-NAMES)
    (check-equal? (length observed-producers) 7)
    (check-equal? (length observed-singletons) 6))

  (test-case "generated and handwritten B partition the golden trace identically"
    (define source-D
      (only-result
       'golden-B-decomposition
       (judgment-holds (generated-decompose/s ,FINITE-SOURCE D) D)))
    (define generated-source-B
      (term
       (generated-encode-MB/s
        (generated-D->M/s ,source-D))))
    (define reference-source-B
      (term
       (reference-b:encode-MB/s
        (reference-m:D->M/s ,source-D))))
    (define-values (generated-spans generated-terminal-B)
      (generated-compressed-trace generated-source-B))
    (define-values (reference-spans reference-terminal-B)
      (reference-compressed-trace reference-source-B))
    (define flattened-labels
      (append-map generated-span-labels generated-spans))

    (check-equal? generated-source-B reference-source-B)
    (check-equal? generated-spans GOLDEN-B-SPANS)
    (check-equal? generated-spans reference-spans)
    (check-equal? (length generated-spans) 6)
    (check-equal? flattened-labels GOLDEN-M-LABELS)
    (check-equal? generated-terminal-B reference-terminal-B)
    (check-equal?
     (term (generated-readback-B/s ,generated-terminal-B))
     GOLDEN-TERMINAL)
    (check-equal?
     (term (generated-flatten-BTrace/s ,generated-spans))
     GOLDEN-M-LABELS))

  (test-case "all 13 root witnesses have one generated and handwritten Big result"
    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (match-define (list _expected-first-label source) representative)
      (define generated-direct-proofs
        (build-derivations
         (generated-big-evaluate/direct/s ,source Big)))
      (define generated-spec-proofs
        (build-derivations
         (generated-big-evaluate/spec/s ,source BTrace Big)))
      (define generated-root-square-proofs
        (build-derivations
         (generated-B-Big-root-square/s ,source BTrace Big)))
      (define reference-direct-proofs
        (build-derivations
         (reference-big:big-evaluate/direct/s ,source Big)))
      (define reference-spec-proofs
        (build-derivations
         (reference-big-spec:big-evaluate/spec/s ,source BTrace Big)))
      (define reference-root-square-proofs
        (build-derivations
         (reference-big-spec:B-Big-root-square/s
          ,source
          BTrace
          Big)))

      (for ([proofs
             (in-list
              (list generated-direct-proofs
                    generated-spec-proofs
                    generated-root-square-proofs
                    reference-direct-proofs
                    reference-spec-proofs
                    reference-root-square-proofs))])
        (check-equal? (length proofs) 1))

      (define generated-direct-results
        (judgment-holds
         (generated-big-evaluate/direct/s ,source Big)
         Big))
      (define generated-spec-results
        (judgment-holds
         (generated-big-evaluate/spec/s ,source BTrace Big)
         (BTrace Big)))
      (define generated-root-square-results
        (judgment-holds
         (generated-B-Big-root-square/s ,source BTrace Big)
         (BTrace Big)))
      (define reference-direct-results
        (judgment-holds
         (reference-big:big-evaluate/direct/s ,source Big)
         Big))
      (define reference-spec-results
        (judgment-holds
         (reference-big-spec:big-evaluate/spec/s ,source BTrace Big)
         (BTrace Big)))
      (define reference-root-square-results
        (judgment-holds
         (reference-big-spec:B-Big-root-square/s
          ,source
          BTrace
          Big)
         (BTrace Big)))

      (check-equal? generated-direct-results reference-direct-results)
      (check-equal? generated-spec-results reference-spec-results)
      (check-equal? generated-root-square-results generated-spec-results)
      (check-equal? generated-root-square-results
                    reference-root-square-results)

      (define generated-Big
        (only-result 'generated-Big-root generated-direct-results))
      (match-define (list _trace generated-spec-Big)
        (only-result 'generated-Big-spec generated-spec-results))
      (check-equal? generated-Big generated-spec-Big)
      (check-true
       (redex-match? generated-core-s-big-lang Big generated-Big))))

  (test-case "all four canonical controls enter generated Big directly"
    (define success-Big
      (term
       (BigFinal
        (Last
         (Owners)
         (Answer (Owners) ,sigma-empty)))))
    (define done-Big
      (term (BigFinal (Done ,owner-u0))))

    (check-equal?
     (judgment-holds
      (generated-big-run/direct/s
       (Work (Owners) (succeed (label "run")) ,sigma-empty)
       (More hole)
       Big)
      Big)
     (list success-Big))
    (check-equal?
     (judgment-holds
      (generated-big-settled/direct/s
       (Returned (Owners) ,sigma-empty)
       (More hole)
       Big)
      Big)
     (list success-Big))
    (check-equal?
     (judgment-holds
      (generated-big-dead/direct/s
       ,owner-u0
       (More hole)
       Big)
      Big)
     (list done-Big))
    (check-equal?
     (judgment-holds
      (generated-big-final/direct/s
       (Done ,owner-u0)
       Big)
      Big)
     (list done-Big))

    (check-equal?
     (length
      (build-derivations
       (generated-big-run/direct/s
        (Work (Owners) (succeed (label "run")) ,sigma-empty)
        (More hole)
        Big)))
     1)
    (check-equal?
     (length
      (build-derivations
       (generated-big-settled/direct/s
        (Returned (Owners) ,sigma-empty)
        (More hole)
        Big)))
     1)
    (check-equal?
     (length
      (build-derivations
       (generated-big-dead/direct/s ,owner-u0 (More hole) Big)))
     1)
    (check-equal?
     (length
      (build-derivations
       (generated-big-final/direct/s (Done ,owner-u0) Big)))
     1)

    (define compressed-entry-cases
      (list
       (list
        (term
         (BRun
          (Work (Owners) (succeed (label "run")) ,sigma-empty)
          (More hole)))
        success-Big)
       (list
        (term
         (BSettled
          (Returned (Owners) ,sigma-empty)
          (More hole)))
        success-Big)
       (list (term (BDead ,owner-u0 (More hole))) done-Big)
       (list (term (BFinal (Done ,owner-u0))) done-Big)))

    (for ([entry-case (in-list compressed-entry-cases)])
      (match-define (list compressed expected-Big) entry-case)
      (check-equal?
       (length
        (build-derivations
         (generated-promote-B/direct/s ,compressed Big)))
       1)
      (check-equal?
       (judgment-holds
        (generated-promote-B/direct/s ,compressed Big)
        Big)
       (list expected-Big))
      (check-equal?
       (judgment-holds
       (reference-big-spec:promote-B/direct/s ,compressed Big)
        Big)
       (list expected-Big))))

  (test-case "every reachable generated B suffix has the same Big fixed point"
    (define source-D
      (only-result
       'suffix-B-decomposition
       (judgment-holds (generated-decompose/s ,FINITE-SOURCE D) D)))
    (define compressed-root
      (term
       (generated-encode-MB/s
        (generated-D->M/s ,source-D))))
    (define compressed-path
      (generated-compressed-path compressed-root))
    (define generated-direct-results
      (judgment-holds
       (generated-big-evaluate/direct/s ,FINITE-SOURCE Big)
       Big))
    (define generated-spec-results
      (judgment-holds
       (generated-big-evaluate/spec/s ,FINITE-SOURCE BTrace Big)
       (BTrace Big)))
    (define generated-root-square-results
      (judgment-holds
       (generated-B-Big-root-square/s
        ,FINITE-SOURCE
        BTrace
        Big)
       (BTrace Big)))
    (define reference-root-square-results
      (judgment-holds
       (reference-big-spec:B-Big-root-square/s
        ,FINITE-SOURCE
        BTrace
        Big)
       (BTrace Big)))

    (check-equal? (length compressed-path)
                  (add1 (length GOLDEN-B-SPANS)))
    (check-equal? generated-direct-results (list GOLDEN-BIG))
    (check-equal? generated-spec-results
                  (list (list GOLDEN-B-SPANS GOLDEN-BIG)))
    (check-equal? generated-root-square-results generated-spec-results)
    (check-equal? generated-root-square-results
                  reference-root-square-results)
    (check-equal?
     (term (generated-readback-Big/s ,GOLDEN-BIG))
     GOLDEN-TERMINAL)

    (for ([compressed (in-list compressed-path)]
          [index (in-naturals)])
      (define expected-trace (drop GOLDEN-B-SPANS index))
      (define generated-closure-results
        (judgment-holds
         (generated-B-Big-closure-square/s
          ,compressed
          BTrace
          Big)
         (BTrace Big)))
      (define reference-closure-results
        (judgment-holds
         (reference-big-spec:B-Big-closure-square/s
          ,compressed
          BTrace
          Big)
         (BTrace Big)))

      (check-equal?
       (length
        (build-derivations
         (generated-promote-B/direct/s ,compressed Big)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated-close-B/spec/s ,compressed BTrace T)))
       1)
      (check-equal?
       (length
        (build-derivations
         (generated-B-Big-closure-square/s
          ,compressed
          BTrace
          Big)))
       1)
      (check-equal? generated-closure-results
                    (list (list expected-trace GOLDEN-BIG)))
      (check-equal? generated-closure-results reference-closure-results)

      (when (< index (length GOLDEN-B-SPANS))
        (define expected-span (list-ref GOLDEN-B-SPANS index))
        (define expected-next (list-ref compressed-path (add1 index)))
        (define generated-unfold-results
          (judgment-holds
           (generated-B-Big-unfold-square/s
            ,compressed
            TransitionSpan
            B_next
            Big)
           (TransitionSpan B_next Big)))
        (define reference-unfold-results
          (judgment-holds
           (reference-big-spec:B-Big-unfold-square/s
            ,compressed
            TransitionSpan
            B_next
            Big)
           (TransitionSpan B_next Big)))

        (check-equal?
         (length
          (build-derivations
           (generated-B-Big-unfold-square/s
            ,compressed
            TransitionSpan
            B_next
            Big)))
         1)
        (check-equal?
         generated-unfold-results
         (list (list expected-span expected-next GOLDEN-BIG)))
        (check-equal? generated-unfold-results reference-unfold-results))))

  (test-case "sparse allocation remains singleton in B and exact through Big"
    (define source-D
      (only-result
       'sparse-B-decomposition
       (judgment-holds (generated-decompose/s ,allocation-source D) D)))
    (define source-B
      (term
       (generated-encode-MB/s
        (generated-D->M/s ,source-D))))
    (define generated-B-results
      (judgment-holds
       (generated-compressed-step/direct/s
        ,source-B
        TransitionSpan
        B_next)
       (TransitionSpan B_next)))
    (define reference-B-results
      (judgment-holds
       (reference-b:compressed-step/direct/s
        ,source-B
        TransitionSpan
        B_next)
       (TransitionSpan B_next)))

    (check-equal? (length generated-B-results) 1)
    (check-equal? generated-B-results reference-B-results)
    (match-define (list transition-span next-B)
      (only-result 'sparse-B-step generated-B-results))
    (check-equal? transition-span '(transition-span allocate-fresh))
    (check-equal? (term (generated-readback-B/s ,next-B))
                  allocation-target)

    (define generated-Big-proofs
      (build-derivations
       (generated-big-evaluate/direct/s ,allocation-source Big)))
    (define reference-Big-proofs
      (build-derivations
       (reference-big:big-evaluate/direct/s ,allocation-source Big)))
    (define generated-Big-results
      (judgment-holds
       (generated-big-evaluate/direct/s ,allocation-source Big)
       Big))
    (define reference-Big-results
      (judgment-holds
       (reference-big:big-evaluate/direct/s ,allocation-source Big)
       Big))

    (check-equal? (length generated-Big-proofs) 1)
    (check-equal? (length reference-Big-proofs) 1)
    (check-equal? generated-Big-results reference-Big-results))

  (test-case "duplicate binders inhabit neither handwritten nor generated D"
    (define duplicate-work (second DUPLICATE-BINDER-SOURCE))
    (define duplicate-D
      (list 'DecAllocate duplicate-work (term (More hole))))
    (define duplicate-Z
      (list 'ZAllocate duplicate-work (term (More hole))))
    (define duplicate-M
      (list 'MAllocate duplicate-work (term (More hole))))
    (define duplicate-B
      (list 'BRun duplicate-work (term (More hole))))

    (check-false
     (redex-match? source-lang:core-lang F DUPLICATE-BINDER-SOURCE))
    (check-false
     (redex-match?
      reference:core-s-decomposition-lang
      F
      DUPLICATE-BINDER-SOURCE))
    (check-false
     (redex-match?
      generated-core-s-decomposition-lang
      F
      DUPLICATE-BINDER-SOURCE))
    (check-false
     (redex-match?
      reference:core-s-decomposition-lang
      D
      duplicate-D))
    (check-false
     (redex-match?
      generated-core-s-decomposition-lang
      D
      duplicate-D))
    (check-false
     (redex-match?
      reference-z:core-s-refocused-lang
      Z
      duplicate-Z))
    (check-false
     (redex-match?
      generated-core-s-refocused-lang
      Z
      duplicate-Z))
    (check-false
     (redex-match?
      reference-m:core-s-machine-lang
      M
      duplicate-M))
    (check-false
     (redex-match?
      generated-core-s-machine-lang
      M
      duplicate-M))
    (check-false
     (redex-match?
      reference-b:core-s-compressed-lang
      B
      duplicate-B))
    (check-false
     (redex-match?
      generated-core-s-compressed-lang
      B
      duplicate-B))
    (check-false
     (redex-match?
      reference-big:core-s-big-lang
      F
      DUPLICATE-BINDER-SOURCE))
    (check-false
     (redex-match?
      generated-core-s-big-lang
      F
      DUPLICATE-BINDER-SOURCE))))

(module+ test
  (run-tests GENERATED-CORE-S-COLUMN))
