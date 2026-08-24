#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in selected-parameter: "./core-redex-parameter.rkt")
         "./core-stage-empty-frame-fixture.rkt"
         "./core-stage-schema.rkt"
         "./core-stage-schema-consumer-fixture.rkt")

(provide CORE-STAGE-SCHEMA-TESTS)

(define EMPTY-STATE
  (term (box 0 () () () (label "state"))))

;; This deliberately puts the only consumer rule at L0.  Reaching the L2-only
;; dependency case requires both recursive base reconstruction and registration
;; of the L2 dependency with every ancestor's exact-language table.
(define-language selected-parameter-L0
  [E 0]
  [N natural])

(selected-parameter:define-judgment-form* selected-parameter-L0
  #:mode (selected-parameter-dependency0 I O)
  #:contract (selected-parameter-dependency0 E N)
  [----
   (selected-parameter-dependency0 0 10)])

(selected-parameter:define-judgment-form* selected-parameter-L0
  #:parameters
  ([current-dependency selected-parameter-dependency0])
  #:mode (selected-parameter-consumer0 I O)
  #:contract (selected-parameter-consumer0 E N)
  [(current-dependency E N)
   ----
   (selected-parameter-consumer0 E N)])

(define-extended-language selected-parameter-L1
  selected-parameter-L0
  [E .... 1])

(selected-parameter:define-extended-judgment-form*
 selected-parameter-dependency0
 selected-parameter-L1
 #:mode (selected-parameter-dependency1 I O)
 [----
  (selected-parameter-dependency1 1 11)])

(selected-parameter:define-extended-judgment-form*
 selected-parameter-consumer0
 selected-parameter-L1
 #:mode (selected-parameter-consumer1 I O)
 #:parameters
 ([current-dependency selected-parameter-dependency1]))

(define-extended-language selected-parameter-L2
  selected-parameter-L1
  [E .... 2])

(selected-parameter:define-extended-judgment-form*
 selected-parameter-dependency1
 selected-parameter-L2
 #:mode (selected-parameter-dependency2 I O)
 [----
  (selected-parameter-dependency2 2 12)])

(selected-parameter:define-extended-judgment-form*
 selected-parameter-consumer1
 selected-parameter-L2
 #:mode (selected-parameter-consumer2 I O)
 #:parameters
 ([current-dependency selected-parameter-dependency2]))

(define (adversarial-extension-syntax
         D-forms Z-step-direct Z-D->Z
         [Z-parameters #'()]
         [Z-diagnostic-parameters #'()])
  #`(let ()
      (define-selected-stage-extension adversarial-extension
        #:source-language output-source-language
        #:feature-singletons ()
        #:D
        [#:parameters ()
         #:artifacts
         (D-artifacts
          #:language primary-output
          #:plug-D primary-output
          #:plug-C primary-output
          #:contract-label primary-output
          #:decompose primary-output
          #:contract primary-output
          #:step primary-output)
         #:forms #,D-forms]
        #:Z
        [#:parameters #,Z-parameters
         #:artifacts
         (Z-artifacts
          #:language primary-output
          #:refocus-phase primary-output
          #:refocus-work-direct primary-output
          #:refocus-frontier-direct primary-output
          #:refocus-direct primary-output
          #:step-direct #,Z-step-direct)
         #:forms ()
         #:diagnostic-parameters #,Z-diagnostic-parameters
         #:diagnostics
         (Z-diagnostics
          #:D->Z #,Z-D->Z
          #:Z->D diagnostic-output
          #:readback diagnostic-output
          #:refocus-spec diagnostic-output
          #:step-spec diagnostic-output)
         #:diagnostic-forms ()]
        #:M
        [#:parameters ()
         #:artifacts
         (M-artifacts
          #:language primary-output
          #:machineize primary-output
          #:refocus-work-direct primary-output
          #:refocus-frontier-direct primary-output
          #:refocus-direct primary-output
          #:step-direct primary-output)
         #:forms ()
         #:diagnostic-parameters ()
         #:diagnostics
         (M-diagnostics
          #:encode-ZM diagnostic-output
          #:decode-MZ diagnostic-output
          #:D->M diagnostic-output
          #:M->D diagnostic-output
          #:readback diagnostic-output
          #:corresponds diagnostic-output
          #:step-spec diagnostic-output
          #:square diagnostic-output)
         #:diagnostic-forms ()]
        #:B
        [#:parameters ()
         #:artifacts
         (B-artifacts
          #:language primary-output
          #:compress primary-output
          #:refocus-frontier-direct primary-output
          #:span-labels primary-output
          #:produce-settled primary-output
          #:produce-dead primary-output
          #:advance-settled primary-output
          #:advance-dead primary-output
          #:base-singleton primary-output
          #:step-direct primary-output)
         #:forms ()
         #:diagnostic-parameters ()
         #:diagnostics
         (B-diagnostics
          #:encode-MB diagnostic-output
          #:decode-BM diagnostic-output
          #:readback diagnostic-output
          #:corresponds diagnostic-output
          #:replay diagnostic-output
          #:step-spec diagnostic-output
          #:square diagnostic-output)
         #:diagnostic-forms ()]
        #:Big
        [#:parameters ()
         #:artifacts
         (Big-artifacts
          #:language primary-output
          #:dispatch-one primary-output
          #:dispatch primary-output
          #:refocus-frontier-direct primary-output
          #:control-one primary-output
          #:control primary-output
          #:frontier primary-output
          #:run primary-output
          #:settled primary-output
          #:dead primary-output
          #:final primary-output
          #:evaluate primary-output
          #:promotion-language primary-output
          #:promote primary-output)
         #:forms ()
         #:diagnostic-parameters ()
         #:diagnostics
         (Big-diagnostics
          #:readback diagnostic-output
          #:spec-language diagnostic-output
          #:initialize diagnostic-output
          #:close diagnostic-output
          #:flatten diagnostic-output
          #:evaluate-spec diagnostic-output
          #:unfold-square diagnostic-output
          #:closure-square diagnostic-output
          #:root-square diagnostic-output)
         #:diagnostic-forms ()])))

(define-test-suite CORE-STAGE-SCHEMA-TESTS
  (test-case "selected dependency lifting is transitive across three languages"
    (check-equal?
     (judgment-holds (selected-parameter-consumer2 2 N) N)
     '(12))
    (check-equal?
     (length
      (build-derivations
       (selected-parameter-consumer2 2 N)))
     1))

  (test-case "a foreign interface generates an ordinary D artifact"
    (check-true
     (redex-match?
      foreign-core-D-lang
      D
      (term
       (DecWork
        (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
        (More hole)))))
    (check-equal?
     (judgment-holds
      (foreign-core-decompose
       (More (Work 0 (succeed (label "yes")) ,EMPTY-STATE))
       D)
      D)
     (list
      (term
       (DecWork
        (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
        (More hole))))))

  (test-case "private rule helpers survive an adversarial module boundary"
    (define allocation-D
      (term
       (DecAllocate
        (Work
         0
         (∃ (x:a)
            (x:a =? (nat 7) (label "body"))
            (label "fresh"))
         ,EMPTY-STATE)
        (More hole))))
    (check-equal?
     (judgment-holds
      (foreign-core-contract ,allocation-D C)
      C)
     (list
      (term
       (ContractWork
        allocate-fresh
        (Work
         1
         (0 =? (nat 7) (label "body"))
         (box 1 () () () (label "state")))
        (More hole)))))

    ;; These premises use the generated private walk/unify/store helpers, not
    ;; merely the fixture's explicitly declared allocation helpers.
    (define unify-D
      (term
       (DecWork
        (Work
         1
         (0 =? (nat 9) (label "bind"))
         (box 1 () () () (label "state-1")))
        (More hole))))
    (check-equal?
     (judgment-holds (foreign-core-contract ,unify-D C) C)
     (list
      (term
       (ContractWork
        unify-success
        (Returned
         1
         (box
          1
          ((0 (nat 9)))
          ()
          ((0 =? (nat 9) (label "bind")))
          (label "state-1")))
        (More hole)))))

    (define focused
      (term (Work 0 (succeed (label "focused")) ,EMPTY-STATE)))
    (define focus (term (More hole)))
    (check-equal?
     (foreign-interface-focus-roundtrip focused focus)
     (list focused focus))
    (check-equal?
     (foreign-interface-Q (term (More ,focused)))
     (term (More ,focused))))

  (test-case "selected phase arrows and Z/M steppers are native"
    (define source-D
      (term
       (DecWork
        (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
        (More hole))))
    (define source-Z
      (term (foreign-core-refocus-phase ,source-D)))
    (define source-M
      (term (foreign-core-machineize ,source-Z)))
    (define source-B
      (term (foreign-core-compress ,source-M)))
    (check-equal?
     source-Z
     (term
      (ZWork
       (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
       (More hole))))
    (check-equal?
     source-M
     (term
      (MWork
       (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
       (More hole))))
    (check-equal?
     source-B
     (term
      (BRun
       (Work 0 (succeed (label "yes")) ,EMPTY-STATE)
       (More hole))))
    (check-equal?
     (judgment-holds
      (foreign-core-Z-step/direct ,source-Z RuleName Z)
      (RuleName Z))
     (list
      (list
       'succeed
       (term (ZFrontier (More (Returned 0 ,EMPTY-STATE)) hole)))))
    (check-equal?
     (judgment-holds
      (foreign-core-M-step/direct ,source-M RuleName M)
      (RuleName M))
     (list
      (list
       'succeed
       (term (MFrontier (More (Returned 0 ,EMPTY-STATE)) hole)))))
    (check-equal?
     (judgment-holds
      (foreign-core-B-step/direct ,source-B TransitionSpan B)
      (TransitionSpan B))
     (list
      (list
       (term (transition-span succeed finish-success))
       (term (BFinal (Last 0 (Answer 0 ,EMPTY-STATE)))))))
    (check-equal?
     (judgment-holds
      (foreign-core-promote ,source-B Big)
      Big)
     (list
      (term (BigFinal (Last 0 (Answer 0 ,EMPTY-STATE))))))
    (check-true
     (foreign-core-D-square?
      (term
       (More
        (Work 0 (succeed (label "yes")) ,EMPTY-STATE)))))
    (check-true (foreign-core-Z-square? source-D))
    (check-true (foreign-core-M-square? source-Z))
    (check-true (foreign-core-B-square? source-M))
    (check-true (foreign-core-Big-square? source-B)))

  (test-case "every declared selected view is materialized in generated grammars"
    (check-true
     (redex-match? empty-frame-D-lang SourceRuntimeVariable (term 3)))
    (check-true
     (redex-match? empty-frame-D-lang SourceState (term (state 3))))
    (check-true
     (redex-match? empty-frame-D-lang SourceReturnedView
                   (term (returned 3))))
    (check-true
     (redex-match? empty-frame-D-lang SourceFailureView (term (failed 3))))
    (check-true
     (redex-match? empty-frame-D-lang SourceTerminalSuccess
                   (term (halted 3))))
    (check-true
     (redex-match? empty-frame-D-lang SourceTerminalFailure
                   (term (aborted 3))))
    (check-true
     (redex-match? empty-frame-Z-lang Settled (term (returned 3))))
    (check-true
     (redex-match? empty-frame-M-lang DeadW (term (failed 3))))
    (check-true
     (redex-match? empty-frame-B-lang T (term (halted 3))))
    (check-true
     (redex-match? empty-frame-Big-lang T (term (aborted 3)))))

  (test-case "a frame-free selected row renders all five stages"
    (define source-D (term (DecWork (tick 3) (root hole))))
    (define source-Z (term (empty-frame-refocus-phase ,source-D)))
    (define source-M (term (empty-frame-machineize ,source-Z)))
    (define source-B (term (empty-frame-compress ,source-M)))
    (check-equal? source-Z (term (ZWork (tick 3) (root hole))))
    (check-equal? source-M (term (MWork (tick 3) (root hole))))
    (check-equal? source-B (term (BRun (tick 3) (root hole))))
    (check-equal?
     (judgment-holds
      (empty-frame-B-step ,source-B TransitionSpan B)
      (TransitionSpan B))
     (list
      (list
       (term (transition-span tick finish-success))
       (term (BFinal (halted 4))))))
    (check-equal?
     (judgment-holds
      (empty-frame-big-evaluate (root (tick 3)) Big)
      Big)
     (list (term (BigFinal (halted 4))))))

  (test-case "Big renders frontier-to-frontier instance IR through control"
    (check-equal?
     (judgment-holds
      (empty-frame-big-dispatch/control-one
       (BigFrontierControl (flip 3) hole)
       ControlNext)
      ControlNext)
     (list
      (term
       (BigControlContinue
        (BigFrontierControl (rail 4) hole))))))

  (test-case "direct extension forms cannot consume output diagnostics"
    (check-exn
     #rx"direct stage forms cannot consume diagnostic artifacts"
     (lambda ()
       (expand
        (adversarial-extension-syntax
         #'((void forbidden-output-diagnostic))
         #'primary-output
         #'forbidden-output-diagnostic)))))

  (test-case "direct extension forms cannot consume BASE diagnostic artifacts"
    (check-exn
     #rx"direct stage forms cannot consume diagnostic artifacts"
     (lambda ()
       (expand
        (adversarial-extension-syntax
         #'((void BASE-Z-READBACK))
         #'primary-output
         #'forbidden-output-diagnostic)))))

  (test-case "direct extension forms cannot consume BASE diagnostic parameters"
    (check-exn
     #rx"direct stage forms cannot consume diagnostic artifacts"
     (lambda ()
       (expand
        (adversarial-extension-syntax
         #'((void BASE-Z-DIAGNOSTIC-PARAMETER-query-evidence))
         #'primary-output
         #'forbidden-output-diagnostic)))))

  (test-case
      "primary artifacts cannot alias diagnostic-only parameter defaults"
    (check-exn
     #rx"primary artifact and diagnostic-only parameter default identifiers must be disjoint"
     (lambda ()
       (expand
        (adversarial-extension-syntax
         #'()
         #'diagnostic-parameter-output
         #'forbidden-output-diagnostic
         #'()
         #'([diagnostic-dependency diagnostic-parameter-output]))))))

  (test-case "primary and diagnostic output records are disjoint"
    (check-exn
     #rx"primary and diagnostic artifact identifiers must be disjoint"
     (lambda ()
       (expand
        (adversarial-extension-syntax
         #'()
         #'forbidden-output-diagnostic
         #'forbidden-output-diagnostic))))))

(module+ test
  (run-tests CORE-STAGE-SCHEMA-TESTS))
