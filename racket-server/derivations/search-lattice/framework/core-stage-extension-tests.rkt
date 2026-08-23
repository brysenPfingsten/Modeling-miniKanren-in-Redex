#lang racket

(require rackunit
         rackunit/text-ui
         racket/file
         racket/runtime-path
         redex/reduction-semantics
         "./core-stage-extension-base-fixture.rkt"
         "./core-stage-extension-query-fixture.rkt"
         "./core-stage-extension-applied-fixture.rkt"
         "./core-stage-extension-premerged-oracle-fixture.rkt"
         "./core-stage-schema.rkt")

(provide CORE-STAGE-EXTENSION-TESTS)

(define-runtime-path base-fixture-path
  "core-stage-extension-base-fixture.rkt")
(define-runtime-path query-fixture-path
  "core-stage-extension-query-fixture.rkt")
(define-runtime-path applied-fixture-path
  "core-stage-extension-applied-fixture.rkt")

;; An all-singleton policy is the no-fusion edge of the generic compression
;; renderer.  Its producer classes are intentionally empty.
(define-selected-compression-policy
  selected-foreign/all-singleton-compression
  #:settled-producers ()
  #:dead-producers ()
  #:settled-followers (pop-wrap-value finish-value)
  #:dead-followers (pop-wrap-crash finish-failure)
  #:singletons
  (echo tick fail allocate
   pop-wrap-value pop-wrap-crash
   finish-value finish-failure)
  #:retained-observation rule-labels
  #:maximum-span 2)

(define-selected-compressed-stage selected-foreign/all-singleton-B
  #:from selected-foreign/base-M
  #:policy selected-foreign/all-singleton-compression
  #:language selected-foreign-all-singleton-B-lang
  #:compress selected-foreign-all-singleton-compress
  #:encode-MB selected-foreign-all-singleton-encode-MB
  #:decode-BM selected-foreign-all-singleton-decode-BM
  #:readback selected-foreign-all-singleton-readback-B
  #:span-labels selected-foreign-all-singleton-span-labels
  #:produce-settled selected-foreign-all-singleton-produce-settled
  #:produce-dead selected-foreign-all-singleton-produce-dead
  #:advance-settled selected-foreign-all-singleton-advance-settled
  #:advance-dead selected-foreign-all-singleton-advance-dead
  #:step-direct selected-foreign-all-singleton-B-step
  #:corresponds selected-foreign-all-singleton-MB-corresponds
  #:replay selected-foreign-all-singleton-replay/M
  #:step-spec selected-foreign-all-singleton-B-step/spec
  #:square selected-foreign-all-singleton-MB-square)

(define-selected-fixed-point-stage selected-foreign/all-singleton-Big
  #:from selected-foreign/all-singleton-B
  #:language selected-foreign-all-singleton-Big-lang
  #:readback selected-foreign-all-singleton-readback-Big
  #:dispatch selected-foreign-all-singleton-big-dispatch
  #:run selected-foreign-all-singleton-big-run
  #:settled selected-foreign-all-singleton-big-settled
  #:dead selected-foreign-all-singleton-big-dead
  #:final selected-foreign-all-singleton-big-final
  #:evaluate selected-foreign-all-singleton-big-evaluate
  #:spec-language selected-foreign-all-singleton-Big-spec-lang
  #:initialize selected-foreign-all-singleton-initialize-B
  #:close selected-foreign-all-singleton-close-B
  #:flatten selected-foreign-all-singleton-flatten-BTrace
  #:promote selected-foreign-all-singleton-promote
  #:evaluate-spec selected-foreign-all-singleton-big-evaluate/spec
  #:unfold-square selected-foreign-all-singleton-B-Big-unfold-square
  #:closure-square selected-foreign-all-singleton-B-Big-closure-square
  #:root-square selected-foreign-all-singleton-B-Big-root-square)

(define base-fixture-text (file->string base-fixture-path))
(define query-fixture-text (file->string query-fixture-path))
(define applied-fixture-text (file->string applied-fixture-path))

(define (tagged-successors relation source)
  (apply-reduction-relation/tag-with-names relation source))

(define (applied-B-steps carrier)
  (judgment-holds
   (selected-foreign-query-B-step ,carrier TransitionSpan B)
   (TransitionSpan B)))

(define (oracle-B-steps carrier)
  (judgment-holds
   (selected-foreign-premerged-oracle-B-step
    ,carrier TransitionSpan B)
   (TransitionSpan B)))

(define (applied-B-proof-count carrier)
  (length
   (build-derivations
    (selected-foreign-query-B-step ,carrier TransitionSpan B))))

(define (oracle-B-proof-count carrier)
  (length
   (build-derivations
    (selected-foreign-premerged-oracle-B-step
     ,carrier TransitionSpan B))))

(define (applied-Big source)
  (judgment-holds
   (selected-foreign-query-big-evaluate ,source Big)
   Big))

(define (oracle-Big source)
  (judgment-holds
   (selected-foreign-premerged-oracle-big-evaluate ,source Big)
   Big))

(define (applied-Big-proof-count source)
  (length
   (build-derivations
    (selected-foreign-query-big-evaluate ,source Big))))

(define (oracle-Big-proof-count source)
  (length
   (build-derivations
    (selected-foreign-premerged-oracle-big-evaluate ,source Big))))

(define-test-suite CORE-STAGE-EXTENSION-TESTS
  (test-case "the base is feature-clean and application is post-generation"
    (check-false
     (regexp-match? #rx"[(](Query|Box|Seal)" base-fixture-text))
    (check-false
     (redex-match?
      selected-foreign-base-lang Task
      (term (Query "cross-module"))))
    (check-false
     (redex-match?
      selected-foreign-base-lang Task
      (term (Box (Tick 0)))))
    (check-false
     (redex-match?
      selected-foreign-base-lang Task
      (term (Seal (Tick 0)))))
    (check-true
     (regexp-match? #rx"apply-selected-stage-extension"
                    applied-fixture-text))
    (for ([forbidden
           (in-list
            (list #rx"define-selected-core-instance"
                  #rx"define-generated-core-stage-instance"
                  #rx"define-derivation-instance"
                  #rx"#:environment"
                  #rx"stage-generators[.]rkt"))])
      (check-false (regexp-match? forbidden applied-fixture-text))
      (check-false (regexp-match? forbidden query-fixture-text)))
    ;; The feature declaration extends the evidence dependency once per
    ;; target language; it never copies an inherited semantic rule.
    (check-false
     (regexp-match? #rx"#:from[ ]+[(]run[ ]+[(]Echo"
                    query-fixture-text))
    (check-false
     (regexp-match? #rx"----------------[ ]+\"echo\""
                    query-fixture-text)))

  (test-case "the foreign feature consumes retained runtime/state views"
    (check-true
     (redex-match?
      selected-foreign-query-D-lang
      FeatureViewWitness
      (term (feature-view 3 4)))))

  (test-case "J_R is an embedding of every bounded base representative"
    (for ([source
           (in-list
            (list (term (Root (Echo 4)))
                  (term (Root (Allocate 4)))
                  (term (Root (Wrap (Tick 4))))
                  (term (Root (Wrap (Crashed 4))))))])
      (check-equal?
       (tagged-successors selected-foreign-query-R source)
       (tagged-successors selected-foreign-base-R source))))

  (test-case
      "J_D o decompose_base = decompose_ext o J_R"
    (define base-source (term (Root (Echo 4))))
    (check-equal?
     (judgment-holds
      (selected-foreign-query-decompose ,base-source D)
      D)
     (judgment-holds
      (selected-foreign-base-decompose ,base-source D)
      D))
    (check-equal?
     (length
      (build-derivations
       (selected-foreign-query-decompose ,base-source D)))
     (length
      (build-derivations
       (selected-foreign-base-decompose ,base-source D))))
    (check-equal?
     (length
      (build-derivations
       (selected-foreign-query-decompose ,base-source D)))
     1))

  (test-case
      "J_Z o refocus_base = refocus_ext o J_D"
    (define base-D
      (term (DecWork (Echo 4) (Root hole))))
    (check-equal?
     (term (selected-foreign-query-refocus-phase ,base-D))
     (term (selected-foreign-base-refocus-phase ,base-D))))

  (test-case
      "J_M o machineize_base = machineize_ext o J_Z"
    (define base-Z
      (term (ZWork (Echo 4) (Root hole))))
    (check-equal?
     (term (selected-foreign-query-machineize ,base-Z))
     (term (selected-foreign-base-machineize ,base-Z))))

  (test-case
      "J_B o compress_base = compress_ext o J_M"
    (define base-M
      (term (MWork (Echo 4) (Root hole))))
    (check-equal?
     (term (selected-foreign-query-compress ,base-M))
     (term (selected-foreign-base-compress ,base-M))))

  (test-case
      "J_Big o big_base = big_ext o J_B"
    (define base-B
      (term (BRun (Echo 4) (Root hole))))
    (check-equal?
     (judgment-holds
      (selected-foreign-query-promote ,base-B Big)
      Big)
     (judgment-holds
      (selected-foreign-base-promote ,base-B Big)
      Big))
    (check-equal?
     (length
      (build-derivations
       (selected-foreign-query-promote ,base-B Big)))
     (length
      (build-derivations
       (selected-foreign-base-promote ,base-B Big))))
    (check-equal?
     (length
      (build-derivations
       (selected-foreign-query-promote ,base-B Big)))
     2))

  (test-case "feature R observations equal the bounded premerged oracle"
    (for ([source
           (in-list
            (list
             (term (Root (Box (Query "cross-module"))))
             (term (Root (Box (Echo "cross-module"))))
             (term (Root (Box (Fail 9))))))])
      (check-equal?
       (tagged-successors selected-foreign-query-R source)
       (tagged-successors selected-foreign-premerged-oracle-R source)))
    (check-equal?
     (tagged-successors
      selected-foreign-query-R
      (term (Root (Query "rejected"))))
     '()))

  (test-case "feature D equals the oracle and retains two proofs"
    (define query-D
      (term
       (DecWork
        (Query "cross-module")
        (Root (Box hole)))))
    (define echo-D
      (term
       (DecWork
        (Echo "cross-module")
        (Root (Box hole)))))
    (for ([carrier (in-list (list query-D echo-D))])
      (check-equal?
       (judgment-holds
        (selected-foreign-query-D-step
         ,carrier RuleName D)
        (RuleName D))
       (judgment-holds
        (selected-foreign-premerged-oracle-D-step
         ,carrier RuleName D)
        (RuleName D)))
      (check-equal?
       (length
        (build-derivations
         (selected-foreign-query-D-step
          ,carrier RuleName D)))
       2)
      (check-equal?
       (length
        (build-derivations
         (selected-foreign-premerged-oracle-D-step
          ,carrier RuleName D)))
       2)))

  (test-case "feature Z equals the oracle and retains two proofs"
    (for ([carrier
           (in-list
            (list
             (term
              (ZWork
               (Query "cross-module")
               (Root (Box hole))))
             (term
              (ZWork
               (Echo "cross-module")
               (Root (Box hole))))))])
      (check-equal?
       (judgment-holds
        (selected-foreign-query-Z-step
         ,carrier RuleName Z)
        (RuleName Z))
       (judgment-holds
        (selected-foreign-premerged-oracle-Z-step
         ,carrier RuleName Z)
        (RuleName Z)))
      (check-equal?
       (length
        (build-derivations
         (selected-foreign-query-Z-step
          ,carrier RuleName Z)))
       2)
      (check-equal?
       (length
        (build-derivations
         (selected-foreign-premerged-oracle-Z-step
          ,carrier RuleName Z)))
       2)))

  (test-case "feature M equals the oracle and retains two proofs"
    (for ([carrier
           (in-list
            (list
             (term
              (MWork
               (Query "cross-module")
               (Root (Box hole))))
             (term
              (MWork
               (Echo "cross-module")
               (Root (Box hole))))))])
      (check-equal?
       (judgment-holds
        (selected-foreign-query-M-step
         ,carrier RuleName M)
        (RuleName M))
       (judgment-holds
        (selected-foreign-premerged-oracle-M-step
         ,carrier RuleName M)
        (RuleName M)))
      (check-equal?
       (length
        (build-derivations
         (selected-foreign-query-M-step
          ,carrier RuleName M)))
       2)
      (check-equal?
       (length
        (build-derivations
         (selected-foreign-premerged-oracle-M-step
          ,carrier RuleName M)))
       2)))

  (test-case "feature Query and inherited Echo are singleton B proofs"
    (for ([carrier
           (in-list
            (list
             (term
              (BRun
               (Query "cross-module")
               (Root (Box hole))))
             (term
              (BRun
               (Echo "cross-module")
               (Root (Box hole))))))])
      (check-equal? (applied-B-steps carrier)
                    (oracle-B-steps carrier))
      (check-equal? (applied-B-proof-count carrier) 2)
      (check-equal? (oracle-B-proof-count carrier) 2)
      (check-equal?
       (length
        (first (first (applied-B-steps carrier))))
       2)))

  (test-case "B forbids cross-feature fusion and preserves base fusion"
    (define tick/box
      (term (BRun (Tick 7) (Root (Box hole)))))
    (define settled/box
      (term
       (BSettled (Value 8) (Root (Box hole)))))
    (define tick/wrap
      (term (BRun (Tick 7) (Root (Wrap hole)))))
    (define tick/root
      (term (BRun (Tick 7) (Root hole))))
    (define tick/seal
      (term (BRun (Tick 7) (Root (Seal hole)))))
    (check-equal? (applied-B-steps tick/box)
                  (oracle-B-steps tick/box))
    (check-equal? (applied-B-proof-count tick/box) 1)
    (check-equal? (oracle-B-proof-count tick/box) 1)
    (check-equal?
     (applied-B-steps tick/box)
     (list
      (list
       (term (transition-span tick))
       (term
        (BSettled (Value 8) (Root (Box hole)))))))
    (check-equal? (applied-B-steps settled/box)
                  (oracle-B-steps settled/box))
    (check-equal? (applied-B-proof-count settled/box) 1)
    (check-equal? (oracle-B-proof-count settled/box) 1)
    (check-equal?
     (applied-B-steps settled/box)
     (list
      (list
       (term (transition-span pop-box-value))
       (term (BSettled (Value 8) (Root hole))))))
    (check-false
     (for/or ([result (in-list (applied-B-steps tick/box))])
       (equal?
        (first result)
        (term (transition-span tick pop-box-value)))))
    (check-equal? (applied-B-steps tick/wrap)
                  (oracle-B-steps tick/wrap))
    (check-equal? (applied-B-proof-count tick/wrap) 1)
    (check-equal? (oracle-B-proof-count tick/wrap) 1)
    (check-equal?
     (first (first (applied-B-steps tick/wrap)))
     (term (transition-span tick pop-wrap-value)))
    (check-equal? (applied-B-steps tick/root)
                  (oracle-B-steps tick/root))
    (check-equal? (applied-B-proof-count tick/root) 1)
    (check-equal? (oracle-B-proof-count tick/root) 1)
    (check-equal?
     (first (first (applied-B-steps tick/root)))
     (term (transition-span tick finish-value)))
    ;; Seal is a feature-owned grammar-only negative witness.  With neither a
    ;; legal base follower nor a feature singleton continuation, the guarded
    ;; fallback must not invent a transition.
    (check-equal? (applied-B-steps tick/seal) '())
    (check-equal? (oracle-B-steps tick/seal) '())
    (check-equal? (applied-B-proof-count tick/seal) 0)
    (check-equal? (oracle-B-proof-count tick/seal) 0))

  (test-case "B lifts allocation and applies the dead boundary symmetrically"
    (define allocate/box
      (term (BRun (Allocate 4) (Root (Box hole)))))
    (define fail/box
      (term (BRun (Fail 9) (Root (Box hole)))))
    (define dead/box
      (term (BDead 9 (Root (Box hole)))))
    (define fail/seal
      (term (BRun (Fail 9) (Root (Seal hole)))))
    (check-equal?
     (applied-B-steps allocate/box)
     (list
      (list
       (term (transition-span allocate))
       (term (BRun (Tick 4) (Root (Box hole)))))))
    (check-equal? (applied-B-steps allocate/box)
                  (oracle-B-steps allocate/box))
    (check-equal? (applied-B-proof-count allocate/box) 1)
    (check-equal? (oracle-B-proof-count allocate/box) 1)
    (check-equal? (applied-B-steps fail/box)
                  (oracle-B-steps fail/box))
    (check-equal? (applied-B-proof-count fail/box) 1)
    (check-equal? (oracle-B-proof-count fail/box) 1)
    (check-equal?
     (applied-B-steps fail/box)
     (list
      (list
       (term (transition-span fail))
       (term (BDead 9 (Root (Box hole)))))))
    (check-equal? (applied-B-steps dead/box)
                  (oracle-B-steps dead/box))
    (check-equal? (applied-B-proof-count dead/box) 1)
    (check-equal? (oracle-B-proof-count dead/box) 1)
    (check-equal?
     (applied-B-steps dead/box)
     (list
      (list
       (term (transition-span pop-box-crash))
       (term (BDead 9 (Root hole))))))
    (check-equal? (applied-B-steps fail/seal) '())
    (check-equal? (oracle-B-steps fail/seal) '())
    (check-equal? (applied-B-proof-count fail/seal) 0)
    (check-equal? (oracle-B-proof-count fail/seal) 0))

  (test-case "an all-singleton policy has no producer categories or fusion"
    (define carrier
      (term (BRun (Tick 7) (Root (Wrap hole)))))
    (define expected-step
      (list
       (list
        (term (transition-span tick))
        (term (BSettled (Value 8) (Root (Wrap hole)))))))
    (define direct-steps
      (judgment-holds
       (selected-foreign-all-singleton-B-step
        ,carrier TransitionSpan B)
       (TransitionSpan B)))
    (define spec-steps
      (judgment-holds
       (selected-foreign-all-singleton-B-step/spec
        ,carrier TransitionSpan B)
       (TransitionSpan B)))
    (check-equal? direct-steps expected-step)
    (check-equal? spec-steps expected-step)
    (check-equal?
     (length
      (build-derivations
       (selected-foreign-all-singleton-replay/M
        (MWork (Tick 7) (Root (Wrap hole)))
        TransitionSpan
        M)))
     1)
    (define source (term (Root (Wrap (Tick 7)))))
    (check-equal?
     (judgment-holds
      (selected-foreign-all-singleton-big-evaluate ,source Big)
      Big)
     (list (term (BigFinal (Halted 8)))))
    (check-equal?
     (judgment-holds
      (selected-foreign-all-singleton-big-evaluate/spec
       ,source BTrace Big)
      (BTrace Big))
     (list
      (list
       (term
        ((transition-span tick)
         (transition-span pop-wrap-value)
         (transition-span finish-value)))
       (term (BigFinal (Halted 8))))))
    (check-equal?
     (length
      (build-derivations
       (selected-foreign-all-singleton-B-Big-root-square
        ,source BTrace Big)))
     1))

  (test-case "Big recognizes feature recursion and preserves proof evidence"
    (for ([source
           (in-list
            (list
             (term (Root (Box (Query "cross-module"))))
             (term (Root (Box (Echo "cross-module"))))
             (term
              (Root
               (Box (Box (Query "cross-module")))))))])
      (check-equal? (applied-Big source)
                    (oracle-Big source))
      (check-equal?
       (applied-Big source)
       (list (term (BigFinal (Halted 8)))))
      (check-equal? (applied-Big-proof-count source) 2)
      (check-equal? (oracle-Big-proof-count source) 2))
    (define failed-source
      (term (Root (Box (Fail 9)))))
    (check-equal? (applied-Big failed-source)
                  (oracle-Big failed-source))
    (check-equal?
     (applied-Big failed-source)
     (list (term (BigFinal (Aborted 9)))))
    (check-equal? (applied-Big-proof-count failed-source) 1)
    (check-equal? (oracle-Big-proof-count failed-source) 1)
    (check-equal?
     (applied-Big
      (term (Root (Query "rejected"))))
     '())))

(module+ test
  (run-tests CORE-STAGE-EXTENSION-TESTS))
