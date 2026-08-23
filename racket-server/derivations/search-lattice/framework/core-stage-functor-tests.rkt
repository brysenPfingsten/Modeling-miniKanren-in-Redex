#lang racket

(require rackunit
         rackunit/text-ui
         racket/list
         racket/match
         redex/reduction-semantics
         "./core-stage-functor-base-fixture.rkt"
         "./core-stage-functor-identity-fixture.rkt"
         "./core-stage-functor-probe-fixture.rkt"
         "./core-stage-functor-sequential-fixture.rkt"
         (prefix-in oracle: "./core-stage-functor-oracle-fixture.rkt")
         (submod "./core-stage-schema.rkt" test-support))

(provide CORE-STAGE-FUNCTOR-TESTS)

;; Identity copies the compile-time row, including its direct artifacts,
;; diagnostics, source language, and compression metadata.
(assert-selected-staged-row-metadata
 selected-functor/identity-row
 #:same-as selected-functor/base-row)

;; The second result row records the effective source/stage artifacts and the
;; exact dependency defaults.  Its metadata accumulates one compression
;; boundary batch for each nonempty feature extension.
(assert-selected-staged-row-metadata
 selected-functor/probe-row
 #:source-language selected-functor-probe-source-lang
 #:D
 (D-artifacts
  #:language selected-functor-probe-D-lang
  #:plug-D selected-functor-probe-plug-D
  #:plug-C selected-functor-probe-plug-C
  #:contract-label selected-functor-probe-contract-label
  #:decompose selected-functor-probe-decompose
  #:contract selected-functor-probe-contract
  #:step selected-functor-probe-D-step)
 #:Z
 (Z-artifacts
  #:language selected-functor-probe-Z-lang
  #:refocus-phase selected-functor-probe-refocus-phase
  #:refocus-work-direct selected-functor-probe-Z-refocus-work
  #:refocus-direct selected-functor-probe-Z-refocus
  #:step-direct selected-functor-probe-Z-step)
 #:M
 (M-artifacts
  #:language selected-functor-probe-M-lang
  #:machineize selected-functor-probe-machineize
  #:refocus-work-direct selected-functor-probe-M-refocus-work
  #:refocus-direct selected-functor-probe-M-refocus
  #:step-direct selected-functor-probe-M-step)
 #:B
 (B-artifacts
  #:language selected-functor-probe-B-lang
  #:compress selected-functor-probe-compress
  #:span-labels selected-functor-probe-span-labels
  #:produce-settled selected-functor-probe-produce-settled
  #:produce-dead selected-functor-probe-produce-dead
  #:advance-settled selected-functor-probe-advance-settled
  #:advance-dead selected-functor-probe-advance-dead
  #:base-singleton selected-functor-probe-singleton
  #:step-direct selected-functor-probe-B-step)
 #:Big
 (Big-artifacts
  #:language selected-functor-probe-Big-lang
  #:dispatch-one selected-functor-probe-big-dispatch-one
  #:dispatch selected-functor-probe-big-dispatch
  #:run selected-functor-probe-big-run
  #:settled selected-functor-probe-big-settled
  #:dead selected-functor-probe-big-dead
  #:final selected-functor-probe-big-final
  #:evaluate selected-functor-probe-big-evaluate)
 #:Z-diagnostics
 (Z-diagnostics
  #:D->Z selected-functor-probe-D->Z
  #:Z->D selected-functor-probe-Z->D
  #:readback selected-functor-probe-readback-Z
  #:refocus-spec selected-functor-probe-refocus/spec
  #:step-spec selected-functor-probe-Z-step/spec)
 #:M-diagnostics
 (M-diagnostics
  #:encode-ZM selected-functor-probe-encode-ZM
  #:decode-MZ selected-functor-probe-decode-MZ
  #:D->M selected-functor-probe-D->M
  #:M->D selected-functor-probe-M->D
  #:readback selected-functor-probe-readback-M
  #:corresponds selected-functor-probe-ZM-corresponds
  #:step-spec selected-functor-probe-M-step/spec
  #:square selected-functor-probe-ZM-square)
 #:B-diagnostics
 (B-diagnostics
  #:encode-MB selected-functor-probe-encode-MB
  #:decode-BM selected-functor-probe-decode-BM
  #:readback selected-functor-probe-readback-B
  #:corresponds selected-functor-probe-MB-corresponds
  #:replay selected-functor-probe-replay/M
  #:step-spec selected-functor-probe-B-step/spec
  #:square selected-functor-probe-MB-square)
 #:Big-diagnostics
 (Big-diagnostics
  #:readback selected-functor-probe-readback-Big
  #:spec-language selected-functor-probe-Big-spec-lang
  #:initialize selected-functor-probe-initialize-B
  #:close selected-functor-probe-close-B
  #:flatten selected-functor-probe-flatten-BTrace
  #:promote selected-functor-probe-promote
  #:evaluate-spec selected-functor-probe-big-evaluate/spec
  #:unfold-square selected-functor-probe-B-Big-unfold-square
  #:closure-square selected-functor-probe-B-Big-closure-square
  #:root-square selected-functor-probe-B-Big-root-square)
 #:D-parameters
 ([query-evidence selected-functor-probe-query-evidence/D])
 #:Z-parameters
 ([query-evidence selected-functor-probe-query-evidence/Z])
 #:M-parameters
 ([query-evidence selected-functor-probe-query-evidence/M])
 #:B-parameters
 ([query-evidence selected-functor-probe-query-evidence/B])
 #:Big-parameters
 ([query-evidence selected-functor-probe-query-evidence/Big])
 #:Z-diagnostic-parameters
 ([query-evidence selected-functor-probe-query-evidence/Z])
 #:M-diagnostic-parameters
 ([query-evidence selected-functor-probe-query-evidence/M])
 #:B-diagnostic-parameters
 ([query-evidence selected-functor-probe-query-evidence/B])
 #:Big-diagnostic-parameters
 ([query-evidence selected-functor-probe-query-evidence/Big-spec])
 #:feature-singletons
 (query pop-box-value pop-box-crash probe)
 #:compression-labels
 (sentinel-settled sentinel-dead
  pop-wrap-value finish-value pop-wrap-crash finish-failure
  echo tick fail allocate query pop-box-value pop-box-crash probe)
 #:compression-boundaries
 ((query pop-box-value pop-box-crash) (probe)))

(define (canonical-top-terms derivations stage-tag)
  (sort
   (for/list ([proof (in-list derivations)])
     (match (derivation-term proof)
       [(cons _ arguments)
        (cons stage-tag arguments)]))
   string<?
   #:key ~s))

(define (histogram values)
  (define counts
    (for/fold ([counts (hash)]) ([value (in-list values)])
      (hash-update counts value add1 0)))
  (sort
   (for/list ([(value count) (in-dict counts)])
     (list value count))
   string<?
   #:key ~s))

(define (top-name-histogram derivations)
  (histogram (map derivation-name derivations)))

(define (derivation-names proof [names '()])
  (for/fold ([names (cons (derivation-name proof) names)])
            ([subproof (in-list (derivation-subs proof))])
    (derivation-names subproof names)))

(define (evidence-name-histogram derivations)
  (histogram
   (filter
    (lambda (name)
      (member name '("query-evidence-left" "query-evidence-right")))
    (append-map derivation-names derivations))))

(define (check-top-proof-multiset selected oracle stage-tag)
  (check-equal? (canonical-top-terms selected stage-tag)
                (canonical-top-terms oracle stage-tag)))

(define (selected-D-proofs carrier)
  (build-derivations
   (selected-functor-probe-D-step ,carrier RuleName D)))

(define (base-D-proofs carrier)
  (build-derivations
   (selected-functor-base-D-step ,carrier RuleName D)))

(define (query-D-proofs carrier)
  (build-derivations
   (selected-foreign-query-D-step ,carrier RuleName D)))

(define (oracle-D-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-D-step ,carrier RuleName D)))

(define (selected-Z-proofs carrier)
  (build-derivations
   (selected-functor-probe-Z-step ,carrier RuleName Z)))

(define (base-Z-proofs carrier)
  (build-derivations
   (selected-functor-base-Z-step ,carrier RuleName Z)))

(define (query-Z-proofs carrier)
  (build-derivations
   (selected-foreign-query-Z-step ,carrier RuleName Z)))

(define (oracle-Z-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-Z-step ,carrier RuleName Z)))

(define (selected-M-proofs carrier)
  (build-derivations
   (selected-functor-probe-M-step ,carrier RuleName M)))

(define (base-M-proofs carrier)
  (build-derivations
   (selected-functor-base-M-step ,carrier RuleName M)))

(define (query-M-proofs carrier)
  (build-derivations
   (selected-foreign-query-M-step ,carrier RuleName M)))

(define (oracle-M-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-M-step ,carrier RuleName M)))

(define (selected-B-proofs carrier)
  (build-derivations
   (selected-functor-probe-B-step ,carrier TransitionSpan B)))

(define (base-B-proofs carrier)
  (build-derivations
   (selected-functor-base-B-step ,carrier TransitionSpan B)))

(define (query-B-proofs carrier)
  (build-derivations
   (selected-foreign-query-B-step ,carrier TransitionSpan B)))

(define (oracle-B-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-B-step
    ,carrier TransitionSpan B)))

(define (selected-Big-proofs source)
  (build-derivations
   (selected-functor-probe-big-evaluate ,source Big)))

(define (base-Big-proofs source)
  (build-derivations
   (selected-functor-base-big-evaluate ,source Big)))

(define (query-Big-proofs source)
  (build-derivations
   (selected-foreign-query-big-evaluate ,source Big)))

(define (oracle-Big-proofs source)
  (build-derivations
   (oracle:selected-functor-oracle-big-evaluate ,source Big)))

(define (selected-Z-spec-proofs carrier)
  (build-derivations
   (selected-functor-probe-Z-step/spec ,carrier RuleName Z)))

(define (oracle-Z-spec-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-Z-step/spec ,carrier RuleName Z)))

(define (selected-M-spec-proofs carrier)
  (build-derivations
   (selected-functor-probe-M-step/spec ,carrier RuleName M)))

(define (oracle-M-spec-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-M-step/spec ,carrier RuleName M)))

(define (selected-B-spec-proofs carrier)
  (build-derivations
   (selected-functor-probe-B-step/spec ,carrier TransitionSpan B)))

(define (oracle-B-spec-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-B-step/spec
    ,carrier TransitionSpan B)))

(define (selected-Big-spec-proofs source)
  (build-derivations
   (selected-functor-probe-big-evaluate/spec ,source BTrace Big)))

(define (oracle-Big-spec-proofs source)
  (build-derivations
   (oracle:selected-functor-oracle-big-evaluate/spec
    ,source BTrace Big)))

(define (selected-ZM-square-proofs carrier)
  (build-derivations
   (selected-functor-probe-ZM-square
    ,carrier RuleName Z_1 M_0 M_1)))

(define (oracle-ZM-square-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-ZM-square
    ,carrier RuleName Z_1 M_0 M_1)))

(define (selected-MB-square-proofs carrier)
  (build-derivations
   (selected-functor-probe-MB-square
    ,carrier TransitionSpan B_1 M_0 M_1)))

(define (oracle-MB-square-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-MB-square
    ,carrier TransitionSpan B_1 M_0 M_1)))

(define (selected-replay-proofs carrier)
  (build-derivations
   (selected-functor-probe-replay/M
    ,carrier TransitionSpan M)))

(define (oracle-replay-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-replay/M
    ,carrier TransitionSpan M)))

(define (selected-promote-proofs carrier)
  (build-derivations
   (selected-functor-probe-promote ,carrier Big)))

(define (oracle-promote-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-promote ,carrier Big)))

(define (selected-unfold-square-proofs carrier)
  (build-derivations
   (selected-functor-probe-B-Big-unfold-square
    ,carrier TransitionSpan B_1 Big)))

(define (oracle-unfold-square-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-B-Big-unfold-square
    ,carrier TransitionSpan B_1 Big)))

(define (selected-closure-square-proofs carrier)
  (build-derivations
   (selected-functor-probe-B-Big-closure-square
    ,carrier BTrace Big)))

(define (oracle-closure-square-proofs carrier)
  (build-derivations
   (oracle:selected-functor-oracle-B-Big-closure-square
    ,carrier BTrace Big)))

(define (selected-root-square-proofs source)
  (build-derivations
   (selected-functor-probe-B-Big-root-square
    ,source BTrace Big)))

(define (oracle-root-square-proofs source)
  (build-derivations
   (oracle:selected-functor-oracle-B-Big-root-square
    ,source BTrace Big)))

(define (proof-final-results derivations)
  (sort
   (for/list ([proof (in-list derivations)])
     (last (derivation-term proof)))
   string<?
   #:key ~s))

(define (tagged-successors relation source)
  (sort (apply-reduction-relation/tag-with-names relation source)
        string<?
        #:key ~s))

(define probe-context (term (Root (Box hole))))
(define query-input "cross-module")
(define rejected-input "rejected")

(define D-query
  (term (DecWork (Query ,query-input) ,probe-context)))
(define Z-query
  (term (ZWork (Query ,query-input) ,probe-context)))
(define M-query
  (term (MWork (Query ,query-input) ,probe-context)))
(define B-query
  (term (BRun (Query ,query-input) ,probe-context)))

(define success-source
  (term (Root (Box (Probe ,query-input)))))
(define failure-source
  (term (Root (Box (Fail 9)))))
(define rejected-source
  (term (Root (Box (Probe ,rejected-input)))))

(define expected-success-trace
  (term ((transition-span probe)
         (transition-span query)
         (transition-span tick)
         (transition-span pop-box-value)
         (transition-span finish-value))))

(define expected-failure-trace
  (term ((transition-span fail)
         (transition-span pop-box-crash)
         (transition-span finish-failure))))

(define-test-suite CORE-STAGE-FUNCTOR-TESTS
  (test-case
   "source composition preserves success, failure, and rejection"
   (for ([source
          (in-list
           (list success-source
                 failure-source
                 rejected-source
                 (term (Root (Wrap (Echo ,query-input))))))])
     (check-equal?
      (tagged-successors selected-functor-probe-R source)
      (tagged-successors oracle:selected-functor-oracle-R source)))
   (check-false
    (member "sentinel-settled"
            (map car
                 (tagged-successors
                  selected-functor-base-R
                  (term (Root (Tick 3)))))))
   (check-false
    (member "sentinel-dead"
            (map car
                 (tagged-successors
                 selected-functor-base-R
                  (term (Root (Fail 3))))))))

  (test-case
   "each staged feature preserves the earlier row on inherited carriers"
   (for
       ([case
         (in-list
          (list
           (list 'D base-D-proofs query-D-proofs selected-D-proofs
                 (term (DecWork (Echo 4) (Root (Wrap hole)))))
           (list 'D base-D-proofs query-D-proofs selected-D-proofs
                 (term (DecAllocate (Allocate 4)
                                    (Root (Wrap hole)))))
           (list 'Z base-Z-proofs query-Z-proofs selected-Z-proofs
                 (term (ZWork (Echo 4) (Root (Wrap hole)))))
           (list 'Z base-Z-proofs query-Z-proofs selected-Z-proofs
                 (term (ZAllocate (Allocate 4)
                                  (Root (Wrap hole)))))
           (list 'M base-M-proofs query-M-proofs selected-M-proofs
                 (term (MWork (Echo 4) (Root (Wrap hole)))))
           (list 'M base-M-proofs query-M-proofs selected-M-proofs
                 (term (MAllocate (Allocate 4)
                                  (Root (Wrap hole)))))
           (list 'B base-B-proofs query-B-proofs selected-B-proofs
                 (term (BRun (Echo 4) (Root (Wrap hole)))))
           (list 'B base-B-proofs query-B-proofs selected-B-proofs
                 (term (BRun (Allocate 4) (Root (Wrap hole)))))
           (list 'Big base-Big-proofs query-Big-proofs selected-Big-proofs
                 (term (Root (Wrap (Echo 4)))))
           (list 'Big base-Big-proofs query-Big-proofs selected-Big-proofs
                 (term (Root (Wrap (Allocate 4)))))))])
     (match-define
       (list stage base-builder query-builder probe-builder carrier)
       case)
     (define base-proofs (base-builder carrier))
     (define query-proofs (query-builder carrier))
     (define probe-proofs (probe-builder carrier))
     (check-top-proof-multiset base-proofs query-proofs stage)
     (check-top-proof-multiset query-proofs probe-proofs stage))
   (for ([stage (in-list '(D Z M B Big))]
         [query-proofs
          (in-list
           (list (query-D-proofs D-query)
                 (query-Z-proofs Z-query)
                 (query-M-proofs M-query)
                 (query-B-proofs B-query)
                 (query-Big-proofs
                  (term (Root (Box (Query ,query-input)))))))]
         [probe-proofs
          (in-list
           (list (selected-D-proofs D-query)
                 (selected-Z-proofs Z-query)
                 (selected-M-proofs M-query)
                 (selected-B-proofs B-query)
                 (selected-Big-proofs
                  (term (Root (Box (Query ,query-input)))))))])
     (check-top-proof-multiset query-proofs probe-proofs stage)))

  (test-case
   "stage transformation maps commute on the joint focused carrier"
   (define selected-decompositions
     (build-derivations
      (selected-functor-probe-decompose ,success-source D)))
   (define oracle-decompositions
     (build-derivations
      (oracle:selected-functor-oracle-decompose ,success-source D)))
   (check-top-proof-multiset
    selected-decompositions oracle-decompositions 'decompose)
   (define D-carrier
     (term (DecWork (Probe ,query-input) ,probe-context)))
   (define Z-carrier
     (term (ZWork (Probe ,query-input) ,probe-context)))
   (define M-carrier
     (term (MWork (Probe ,query-input) ,probe-context)))
   (check-equal?
    (term (selected-functor-probe-refocus-phase ,D-carrier))
    (term (oracle:selected-functor-oracle-D->Z ,D-carrier)))
   (check-equal?
    (term (selected-functor-probe-machineize ,Z-carrier))
    (term (oracle:selected-functor-oracle-encode-ZM ,Z-carrier)))
   (check-equal?
    (term (selected-functor-probe-compress ,M-carrier))
    (term (oracle:selected-functor-oracle-encode-MB ,M-carrier))))

  (test-case
   "Stage(Delta2 after Delta1) matches the frozen whole instance"
   (for
       ([case
         (in-list
          (list
           (list 'D selected-D-proofs oracle-D-proofs
                 (term (DecWork (Probe ,query-input) ,probe-context)))
           (list 'D selected-D-proofs oracle-D-proofs D-query)
           (list 'D selected-D-proofs oracle-D-proofs
                 (term (DecWork (Echo ,query-input) ,probe-context)))
           (list 'D selected-D-proofs oracle-D-proofs
                 (term (DecAllocate (Allocate 4) ,probe-context)))
           (list 'D selected-D-proofs oracle-D-proofs
                 (term (DecWork (Query ,rejected-input) ,probe-context)))
           (list 'Z selected-Z-proofs oracle-Z-proofs
                 (term (ZWork (Probe ,query-input) ,probe-context)))
           (list 'Z selected-Z-proofs oracle-Z-proofs Z-query)
           (list 'Z selected-Z-proofs oracle-Z-proofs
                 (term (ZWork (Echo ,query-input) ,probe-context)))
           (list 'Z selected-Z-proofs oracle-Z-proofs
                 (term (ZAllocate (Allocate 4) ,probe-context)))
           (list 'Z selected-Z-proofs oracle-Z-proofs
                 (term (ZWork (Query ,rejected-input) ,probe-context)))
           (list 'M selected-M-proofs oracle-M-proofs
                 (term (MWork (Probe ,query-input) ,probe-context)))
           (list 'M selected-M-proofs oracle-M-proofs M-query)
           (list 'M selected-M-proofs oracle-M-proofs
                 (term (MWork (Echo ,query-input) ,probe-context)))
           (list 'M selected-M-proofs oracle-M-proofs
                 (term (MAllocate (Allocate 4) ,probe-context)))
           (list 'M selected-M-proofs oracle-M-proofs
                 (term (MWork (Query ,rejected-input) ,probe-context)))
           (list 'B selected-B-proofs oracle-B-proofs
                 (term (BRun (Probe ,query-input) ,probe-context)))
           (list 'B selected-B-proofs oracle-B-proofs B-query)
           (list 'B selected-B-proofs oracle-B-proofs
                 (term (BRun (Echo ,query-input) ,probe-context)))
           (list 'B selected-B-proofs oracle-B-proofs
                 (term (BRun (Allocate 4) ,probe-context)))
           (list 'B selected-B-proofs oracle-B-proofs
                 (term (BRun (Query ,rejected-input) ,probe-context)))
           (list 'Big selected-Big-proofs oracle-Big-proofs success-source)
           (list 'Big selected-Big-proofs oracle-Big-proofs failure-source)
           (list 'Big selected-Big-proofs oracle-Big-proofs rejected-source)
           (list 'Big selected-Big-proofs oracle-Big-proofs
                 (term (Root (Box (Allocate 4)))))
           (list 'Big selected-Big-proofs oracle-Big-proofs
                 (term (Root (Wrap (Echo ,query-input)))))))])
     (match-define (list stage selected oracle carrier) case)
     (check-top-proof-multiset
      (selected carrier) (oracle carrier) stage)))

  (test-case
   "raw proof multiplicity retains both lifted Query proofs"
   (for ([selected
          (in-list
           (list (selected-D-proofs D-query)
                 (selected-Z-proofs Z-query)
                 (selected-M-proofs M-query)
                 (selected-B-proofs B-query)
                 (selected-Big-proofs success-source)))]
         [oracle
          (in-list
           (list (oracle-D-proofs D-query)
                 (oracle-Z-proofs Z-query)
                 (oracle-M-proofs M-query)
                 (oracle-B-proofs B-query)
                 (oracle-Big-proofs success-source)))])
     (check-equal? (length selected) 2)
     (check-equal? (length oracle) 2)
     (check-equal?
      (evidence-name-histogram selected)
      '(("query-evidence-left" 1) ("query-evidence-right" 1)))
     (check-equal?
      (evidence-name-histogram oracle)
      '(("query-evidence-left" 1) ("query-evidence-right" 1))))
   (for ([selected
          (in-list
           (list
            (selected-D-proofs
             (term (DecWork (Echo ,query-input) ,probe-context)))
            (selected-Z-proofs
             (term (ZWork (Echo ,query-input) ,probe-context)))
            (selected-M-proofs
             (term (MWork (Echo ,query-input) ,probe-context)))
            (selected-B-proofs
             (term (BRun (Echo ,query-input) ,probe-context)))
            (selected-Big-proofs
             (term (Root (Box (Echo ,query-input)))))))]
         [oracle
          (in-list
           (list
            (oracle-D-proofs
             (term (DecWork (Echo ,query-input) ,probe-context)))
            (oracle-Z-proofs
             (term (ZWork (Echo ,query-input) ,probe-context)))
            (oracle-M-proofs
             (term (MWork (Echo ,query-input) ,probe-context)))
            (oracle-B-proofs
             (term (BRun (Echo ,query-input) ,probe-context)))
            (oracle-Big-proofs
             (term (Root (Box (Echo ,query-input)))))))])
     (check-equal? (length selected) 2)
     (check-equal? (length oracle) 2)
     (check-equal?
      (evidence-name-histogram selected)
      '(("query-evidence-left" 1) ("query-evidence-right" 1)))
     (check-equal?
      (evidence-name-histogram oracle)
      '(("query-evidence-left" 1) ("query-evidence-right" 1))))
   (for ([selected
          (in-list
           (list
            (selected-D-proofs
             (term (DecWork (Probe ,query-input) ,probe-context)))
            (selected-Z-proofs
             (term (ZWork (Probe ,query-input) ,probe-context)))
            (selected-M-proofs
             (term (MWork (Probe ,query-input) ,probe-context)))
            (selected-B-proofs
             (term (BRun (Probe ,query-input) ,probe-context)))))]
         [oracle
          (in-list
           (list
            (oracle-D-proofs
             (term (DecWork (Probe ,query-input) ,probe-context)))
            (oracle-Z-proofs
             (term (ZWork (Probe ,query-input) ,probe-context)))
            (oracle-M-proofs
             (term (MWork (Probe ,query-input) ,probe-context)))
            (oracle-B-proofs
             (term (BRun (Probe ,query-input) ,probe-context)))))])
     (check-equal? (length selected) 1)
     (check-equal? (length oracle) 1))
   ;; Names are recorded separately: selected Z/M feature clauses carry their
   ;; semantic names, while generic selected wrappers and the frozen whole-row
   ;; wrappers are unnamed.  The judgment terms above retain every label.
   (check-equal? (top-name-histogram (selected-D-proofs D-query))
                 '((#f 2)))
   (check-equal? (top-name-histogram (oracle-D-proofs D-query))
                 '((#f 2)))
   (check-equal? (top-name-histogram (selected-Z-proofs Z-query))
                 '(("query" 2)))
   (check-equal? (top-name-histogram (oracle-Z-proofs Z-query))
                 '((#f 2)))
   (check-equal? (top-name-histogram (selected-M-proofs M-query))
                 '(("query" 2)))
   (check-equal? (top-name-histogram (oracle-M-proofs M-query))
                 '((#f 2)))
   (check-equal? (top-name-histogram (selected-B-proofs B-query))
                 '((#f 2)))
   (check-equal? (top-name-histogram (oracle-B-proofs B-query))
                 '((#f 2)))
   (check-equal? (top-name-histogram (selected-Big-proofs success-source))
                 '((#f 2)))
   (check-equal? (top-name-histogram (oracle-Big-proofs success-source))
                 '((#f 2))))

  (test-case
   "direct and specification systems retain complete proof multisets"
   (for ([stage (in-list '(Z M B))]
         [selected-direct
          (in-list
           (list (selected-Z-proofs Z-query)
                 (selected-M-proofs M-query)
                 (selected-B-proofs B-query)))]
         [selected-spec
          (in-list
           (list (selected-Z-spec-proofs Z-query)
                 (selected-M-spec-proofs M-query)
                 (selected-B-spec-proofs B-query)))]
         [oracle-direct
          (in-list
           (list (oracle-Z-proofs Z-query)
                 (oracle-M-proofs M-query)
                 (oracle-B-proofs B-query)))]
         [oracle-spec
          (in-list
           (list (oracle-Z-spec-proofs Z-query)
                 (oracle-M-spec-proofs M-query)
                 (oracle-B-spec-proofs B-query)))])
     (check-top-proof-multiset selected-direct selected-spec stage)
     (check-top-proof-multiset oracle-direct oracle-spec stage)
     (check-top-proof-multiset selected-direct oracle-direct stage))
   (check-equal?
    (proof-final-results (selected-Big-proofs success-source))
    (proof-final-results (selected-Big-spec-proofs success-source)))
   (check-equal?
    (proof-final-results (oracle-Big-proofs success-source))
    (proof-final-results (oracle-Big-spec-proofs success-source))))

  (test-case
   "all executable labels remain singleton and sentinels are rejected"
   (check-equal?
    (judgment-holds
     (selected-functor-probe-B-step
      (BRun (Tick 7) (Root (Box hole))) TransitionSpan B)
     (TransitionSpan B))
    (term (((transition-span tick)
            (BSettled (Value 8) (Root (Box hole)))))))
   (check-equal?
    (judgment-holds
     (selected-functor-probe-B-step
      (BSettled (Value 8) (Root (Box hole))) TransitionSpan B)
     (TransitionSpan B))
    (term (((transition-span pop-box-value)
            (BSettled (Value 8) (Root hole))))))
   (for ([selected
          (in-list
           (list
            (build-derivations
             (selected-functor-probe-D-step
              (DecWork (Tick 3) (Root hole)) sentinel-settled D))
            (build-derivations
             (selected-functor-probe-Z-step
              (ZWork (Tick 3) (Root hole)) sentinel-settled Z))
            (build-derivations
             (selected-functor-probe-M-step
              (MWork (Tick 3) (Root hole)) sentinel-settled M))
            (build-derivations
             (selected-functor-probe-B-step
              (BRun (Tick 3) (Root hole))
              (transition-span sentinel-settled) B))))]
         [oracle
          (in-list
           (list
            (build-derivations
             (oracle:selected-functor-oracle-D-step
              (DecWork (Tick 3) (Root hole)) sentinel-settled D))
            (build-derivations
             (oracle:selected-functor-oracle-Z-step
              (ZWork (Tick 3) (Root hole)) sentinel-settled Z))
            (build-derivations
             (oracle:selected-functor-oracle-M-step
              (MWork (Tick 3) (Root hole)) sentinel-settled M))
            (build-derivations
             (oracle:selected-functor-oracle-B-step
              (BRun (Tick 3) (Root hole))
              (transition-span sentinel-settled) B))))])
     (check-equal? selected '())
     (check-equal? oracle '()))
   (for ([selected
          (in-list
           (list
            (build-derivations
             (selected-functor-probe-D-step
              (DecWork (Fail 3) (Root hole)) sentinel-dead D))
            (build-derivations
             (selected-functor-probe-Z-step
              (ZWork (Fail 3) (Root hole)) sentinel-dead Z))
            (build-derivations
             (selected-functor-probe-M-step
              (MWork (Fail 3) (Root hole)) sentinel-dead M))
            (build-derivations
             (selected-functor-probe-B-step
              (BRun (Fail 3) (Root hole))
              (transition-span sentinel-dead) B))))]
         [oracle
          (in-list
           (list
            (build-derivations
             (oracle:selected-functor-oracle-D-step
              (DecWork (Fail 3) (Root hole)) sentinel-dead D))
            (build-derivations
             (oracle:selected-functor-oracle-Z-step
              (ZWork (Fail 3) (Root hole)) sentinel-dead Z))
            (build-derivations
             (oracle:selected-functor-oracle-M-step
              (MWork (Fail 3) (Root hole)) sentinel-dead M))
            (build-derivations
             (oracle:selected-functor-oracle-B-step
              (BRun (Fail 3) (Root hole))
              (transition-span sentinel-dead) B))))])
     (check-equal? selected '())
     (check-equal? oracle '())))

  (test-case
   "codecs and phase squares are secondary diagnostics"
   (define D-carrier
     (term (DecWork (Probe ,query-input) ,probe-context)))
   (define Z-carrier
     (term (selected-functor-probe-D->Z ,D-carrier)))
   (define M-carrier
     (term (selected-functor-probe-encode-ZM ,Z-carrier)))
   (define B-carrier
     (term (selected-functor-probe-encode-MB ,M-carrier)))
   (check-top-proof-multiset
    (selected-ZM-square-proofs Z-carrier)
    (oracle-ZM-square-proofs Z-carrier)
    'ZM-square)
   (check-top-proof-multiset
    (selected-MB-square-proofs B-carrier)
    (oracle-MB-square-proofs B-carrier)
    'MB-square)
   (check-top-proof-multiset
    (selected-promote-proofs B-carrier)
    (oracle-promote-proofs B-carrier)
    'promote)
   (check-top-proof-multiset
    (selected-unfold-square-proofs B-carrier)
    (oracle-unfold-square-proofs B-carrier)
    'unfold-square)
   (check-top-proof-multiset
    (selected-closure-square-proofs B-carrier)
    (oracle-closure-square-proofs B-carrier)
    'closure-square)
   (check-top-proof-multiset
    (selected-root-square-proofs success-source)
    (oracle-root-square-proofs success-source)
    'root-square)
   (check-equal? (term (selected-functor-probe-Z->D ,Z-carrier))
                 D-carrier)
   (check-equal? (term (selected-functor-probe-decode-MZ ,M-carrier))
                 Z-carrier)
   (check-equal? (term (selected-functor-probe-decode-BM ,B-carrier))
                 M-carrier)
   (check-equal? (term (selected-functor-probe-refocus-phase ,D-carrier))
                 Z-carrier)
   (check-equal? (term (selected-functor-probe-machineize ,Z-carrier))
                 M-carrier)
   (check-equal? (term (selected-functor-probe-compress ,M-carrier))
                 B-carrier)
   (check-equal? (term (selected-functor-probe-readback-Z ,Z-carrier))
                 success-source)
   (check-equal? (term (selected-functor-probe-readback-M ,M-carrier))
                 success-source)
   (check-equal? (term (selected-functor-probe-readback-B ,B-carrier))
                 success-source)
   (check-equal?
    (length
     (build-derivations
      (selected-functor-probe-ZM-square
       ,Z-carrier RuleName Z_1 M_0 M_1)))
    1)
   (check-equal?
    (length
     (build-derivations
      (selected-functor-probe-MB-square
       ,B-carrier TransitionSpan B_1 M_0 M_1)))
    1)
   (check-equal?
    (length
     (build-derivations
      (selected-functor-probe-B-Big-root-square
       ,success-source BTrace Big)))
    4)
   (check-equal?
    (length
     (build-derivations
      (selected-functor-probe-B-Big-unfold-square
       ,B-carrier TransitionSpan B_1 Big)))
    4)
   (check-equal?
    (length
     (build-derivations
      (selected-functor-probe-B-Big-closure-square
       ,B-carrier BTrace Big)))
    4)
   (define oracle-Z-carrier
     (term (oracle:selected-functor-oracle-D->Z ,D-carrier)))
   (define oracle-M-carrier
     (term (oracle:selected-functor-oracle-encode-ZM
            ,oracle-Z-carrier)))
   (define oracle-B-carrier
     (term (oracle:selected-functor-oracle-encode-MB
            ,oracle-M-carrier)))
   (check-equal?
    (term (oracle:selected-functor-oracle-Z->D ,oracle-Z-carrier))
    D-carrier)
   (check-equal?
    (term (oracle:selected-functor-oracle-decode-MZ ,oracle-M-carrier))
    oracle-Z-carrier)
   (check-equal?
    (term (oracle:selected-functor-oracle-decode-BM ,oracle-B-carrier))
    oracle-M-carrier)
   (check-equal?
    (term (oracle:selected-functor-oracle-readback-Z ,oracle-Z-carrier))
    success-source)
   (check-equal?
    (term (oracle:selected-functor-oracle-readback-M ,oracle-M-carrier))
    success-source)
   (check-equal?
    (term (oracle:selected-functor-oracle-readback-B ,oracle-B-carrier))
    success-source)
   (check-equal?
    (length
     (build-derivations
      (oracle:selected-functor-oracle-ZM-square
       ,oracle-Z-carrier RuleName Z_1 M_0 M_1)))
    1)
   (check-equal?
    (length
     (build-derivations
      (oracle:selected-functor-oracle-MB-square
       ,oracle-B-carrier TransitionSpan B_1 M_0 M_1)))
    1)
   (check-equal?
    (length
     (build-derivations
      (oracle:selected-functor-oracle-B-Big-root-square
       ,success-source BTrace Big)))
    4)
   (check-equal?
    (length
     (build-derivations
      (oracle:selected-functor-oracle-B-Big-unfold-square
       ,oracle-B-carrier TransitionSpan B_1 Big)))
    4)
   (check-equal?
    (length
     (build-derivations
      (oracle:selected-functor-oracle-B-Big-closure-square
       ,oracle-B-carrier BTrace Big)))
    4))

  (test-case
   "replay and finite closure preserve exact traces"
   (check-top-proof-multiset
    (selected-Big-spec-proofs success-source)
    (oracle-Big-spec-proofs success-source)
    'Big-spec)
   (check-top-proof-multiset
    (selected-Big-spec-proofs failure-source)
    (oracle-Big-spec-proofs failure-source)
    'Big-spec)
   (check-equal?
    (judgment-holds
     (selected-functor-probe-big-evaluate ,success-source Big)
     Big)
    (term ((BigFinal (Halted 8)))))
   (check-equal?
    (judgment-holds
     (oracle:selected-functor-oracle-big-evaluate
      ,success-source Big)
     Big)
    (term ((BigFinal (Halted 8)))))
   (check-equal?
    (judgment-holds
     (selected-functor-probe-big-evaluate ,failure-source Big)
     Big)
    (term ((BigFinal (Aborted 9)))))
   (check-equal?
    (judgment-holds
     (oracle:selected-functor-oracle-big-evaluate
      ,failure-source Big)
     Big)
    (term ((BigFinal (Aborted 9)))))
   (check-equal?
    (judgment-holds
     (selected-functor-probe-big-evaluate/spec
      ,success-source BTrace Big)
     (BTrace Big))
    (list (list expected-success-trace
                (term (BigFinal (Halted 8))))))
   (check-equal?
    (judgment-holds
     (oracle:selected-functor-oracle-big-evaluate/spec
      ,success-source BTrace Big)
     (BTrace Big))
    (list (list expected-success-trace
                (term (BigFinal (Halted 8))))))
   (check-equal?
    (judgment-holds
     (selected-functor-probe-big-evaluate/spec
      ,failure-source BTrace Big)
     (BTrace Big))
    (list (list expected-failure-trace
                (term (BigFinal (Aborted 9))))))
   (check-equal?
    (judgment-holds
     (oracle:selected-functor-oracle-big-evaluate/spec
      ,failure-source BTrace Big)
     (BTrace Big))
    (list (list expected-failure-trace
                (term (BigFinal (Aborted 9))))))
   (check-equal?
    (selected-Big-spec-proofs rejected-source)
    '())
   (check-equal?
    (oracle-Big-spec-proofs rejected-source)
    '())
   (check-equal?
    (selected-Big-proofs rejected-source)
    '())
   (check-equal?
    (oracle-Big-proofs rejected-source)
    '())
   (check-equal?
    (term (selected-functor-probe-flatten-BTrace
           ,expected-success-trace))
    (term (probe query tick pop-box-value finish-value)))
   (check-equal?
    (term (oracle:selected-functor-oracle-flatten-BTrace
           ,expected-success-trace))
    (term (probe query tick pop-box-value finish-value)))
   (check-equal?
    (term (selected-functor-probe-readback-Big
           (BigFinal (Halted 8))))
    (term (Halted 8)))
   (check-equal?
    (term (oracle:selected-functor-oracle-readback-Big
           (BigFinal (Halted 8))))
    (term (Halted 8)))
   (define replay-source
     (term (MWork (Query ,query-input) ,probe-context)))
   (check-top-proof-multiset
    (selected-replay-proofs replay-source)
    (oracle-replay-proofs replay-source)
    'replay)
   (check-equal?
    (judgment-holds
     (selected-functor-probe-replay/M
      ,replay-source TransitionSpan M)
     (TransitionSpan M))
    (term (((transition-span query)
            (MWork (Tick 7) ,probe-context)))))
   (check-equal?
    (judgment-holds
     (oracle:selected-functor-oracle-replay/M
      ,replay-source TransitionSpan M)
     (TransitionSpan M))
    (term (((transition-span query)
            (MWork (Tick 7) ,probe-context)))))))

(module+ test
  (run-tests CORE-STAGE-FUNCTOR-TESTS))
