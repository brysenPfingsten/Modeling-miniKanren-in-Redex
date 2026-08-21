#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in source-red:
                    "../../../src/search-lattice/reduction-relations/core-red.rkt")
         (prefix-in s:
                    "../core/s/decomposition.rkt")
         (prefix-in z:
                    "../core/s/refocused.rkt")
         (prefix-in m:
                    "../core/s/machine.rkt")
         (prefix-in m-spec:
                    "../core/s/machine-spec.rkt")
         (prefix-in b:
                    "../core/s/compressed.rkt")
         (prefix-in b-spec:
                    "../core/s/compression-spec.rkt")
         (prefix-in big:
                    "../core/s/fixed-point.rkt")
         (prefix-in big-spec:
                    "../core/s/fixed-point-spec.rkt"))

(provide CORE-S-HORIZONTAL)

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

(define PRODUCER-RULE-NAMES
  '(succeed
    fail
    unify-success
    unify-violates-disequality
    unify-fail
    disequality-success
    disequality-fail))

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

;; One witness per production label.  This suite deliberately owns its corpus:
;; the horizontal column is compared with R[S], but it does not import a
;; production test suite or a semantic clause table.
(define RULE-REPRESENTATIVES
  (list
   (list
    'expand-conjunction
    (term
     (More
      (Work (Owners)
            ((succeed (label "left"))
             ∧
             (fail (label "right"))
             (label "conjunction"))
            ,sigma-empty))))
   (list
    'succeed
    (term (More (Work ,owner-u0 (succeed (label "yes")) ,sigma-empty))))
   (list
    'fail
    (term (More (Work ,owner-u0 (fail (label "no")) ,sigma-empty))))
   (list
    'conj-return
    (term
     (More
      (Conj ,owner-u0
            (Returned ,owner-u1 ,sigma-empty)
            (u:0 =? u:0 (label "continue"))))))
   (list
    'conj-fail
    (term
     (More
      (Conj ,owner-u0
            (Dead ,owner-u1)
            (succeed (label "unreachable"))))))
   (list
    'unify-success
    (term
     (More
      (Work ,owner-u0
            (u:0 =? (nat 0) (label "unify"))
            ,sigma-empty))))
   (list
    'unify-violates-disequality
    (term
     (More
      (Work
       ,owner-u0
       (u:0 =? (nat 0) (label "violates"))
       (state ()
              ((u:0 (nat 0)))
              ()
              (label "violates-state"))))))
   (list
    'unify-fail
    (term
     (More
      (Work (Owners)
            ((nat 0) =? (nat 1) (label "unify-fail"))
            ,sigma-empty))))
   (list
    'disequality-success
    (term
     (More
      (Work (Owners)
            ((nat 0) != (nat 1) (label "disequality-ok"))
            ,sigma-empty))))
   (list
    'disequality-fail
    (term
     (More
      (Work (Owners)
            ((nat 0) != (nat 0) (label "disequality-fail"))
            ,sigma-empty))))
   (list
    'finish-success
    (term (More (Returned ,owner-u0 ,sigma-empty))))
   (list
    'finish-failure
    (term (More (Dead ,owner-u0))))
   (list 'allocate-fresh allocation-source)))

(define CODEC-CASES
  (list
   (term (ZFinal (Done ,owner-u0)))
   (term
    (ZWork
     (Work ,owner-u0 (succeed (label "codec-work")) ,sigma-empty)
     (More hole)))
   (term
    (ZFrontier
     (More (Returned ,owner-u0 ,sigma-empty))
     hole))
   (term
    (ZAllocate
     (Work
      ,owner-u0
      (∃ (x:q) (succeed (label "codec-body")) (label "codec-fresh"))
     ,sigma-empty)
     (More hole)))))

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

(define DUPLICATE-BINDER-SOURCE
  (term
   (More
    (Work
     (Owners)
     (∃ (x:q x:q)
        (succeed (label "duplicate-binder-body"))
        (label "duplicate-binder"))
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
     (error who "expected exactly one raw proof/result, got ~e" results)]))

(define (decompose/s frontier)
  (only-result
   'decompose/s
   (judgment-holds (s:decompose/s ,frontier D) D)))

(define (source->z/s source)
  (term (z:D->Z/s ,(decompose/s source))))

(define (source->m/s source)
  (term (m:encode-ZM/s ,(source->z/s source))))

(define (source->b/s source)
  (term (b:encode-MB/s ,(source->m/s source))))

(define (span-labels/s transition-span)
  (term (b:transition-span-labels/s ,transition-span)))

(define (machine-trace/s machine [fuel 24] [reversed-labels '()])
  (when (zero? fuel)
    (error 'machine-trace/s "trace exceeded its explicit step bound"))
  (define direct-results
    (judgment-holds
     (m:machine-step/direct/s ,machine RuleName M_next)
     (RuleName M_next)))
  (define spec-results
    (judgment-holds
     (m-spec:machine-step/spec/s ,machine RuleName M_next)
     (RuleName M_next)))
  (check-equal? direct-results spec-results)
  (match direct-results
    ['()
     (values (reverse reversed-labels) machine)]
    [(list (list rule-name machine-next))
     (check-equal?
      (length
       (build-derivations
        (m:machine-step/direct/s ,machine RuleName M_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (m-spec:machine-step/spec/s ,machine RuleName M_next)))
      1)
     (machine-trace/s
      machine-next
      (sub1 fuel)
      (cons rule-name reversed-labels))]
    [_
     (error 'machine-trace/s
            "expected a deterministic exact-machine step, got ~e"
            direct-results)]))

(define (compressed-trace/s compressed [fuel 24] [reversed-spans '()])
  (when (zero? fuel)
    (error 'compressed-trace/s "trace exceeded its explicit step bound"))
  (define direct-results
    (judgment-holds
     (b:compressed-step/direct/s ,compressed TransitionSpan B_next)
     (TransitionSpan B_next)))
  (define spec-results
    (judgment-holds
     (b-spec:compressed-step/spec/s ,compressed TransitionSpan B_next)
     (TransitionSpan B_next)))
  (check-equal? direct-results spec-results)
  (match direct-results
    ['()
     (values (reverse reversed-spans) compressed)]
    [(list (list transition-span compressed-next))
     (define labels (span-labels/s transition-span))
     (define machine (term (b:decode-BM/s ,compressed)))
     (define machine-next (term (b:decode-BM/s ,compressed-next)))

     (check-true (<= 1 (length labels) 2))
     (check-equal?
      (length
       (build-derivations
        (b:compressed-step/direct/s
         ,compressed
         TransitionSpan
         B_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (b-spec:compressed-step/spec/s
         ,compressed
         TransitionSpan
         B_next)))
      1)
     (check-equal?
      (judgment-holds
       (b-spec:replay-transition-span/M/s
        ,machine
        TransitionSpan
        M_next)
       (TransitionSpan M_next))
      (list (list transition-span machine-next)))
     (check-equal?
      (length
       (build-derivations
        (b-spec:replay-transition-span/M/s
         ,machine
         TransitionSpan
         M_next)))
      1)

     (compressed-trace/s
      compressed-next
      (sub1 fuel)
      (cons transition-span reversed-spans))]
    [_
     (error 'compressed-trace/s
            "expected a deterministic compressed step, got ~e"
            direct-results)]))

(define (compressed-path/s compressed [fuel 24])
  (when (zero? fuel)
    (error 'compressed-path/s "path exceeded its explicit step bound"))
  (match
      (judgment-holds
       (b:compressed-step/direct/s
        ,compressed
        TransitionSpan
        B_next)
       (TransitionSpan B_next))
    ['() (list compressed)]
    [(list (list _transition-span compressed-next))
     (cons compressed
           (compressed-path/s compressed-next (sub1 fuel)))]
    [results
     (error 'compressed-path/s
            "expected a deterministic compressed step, got ~e"
            results)]))

(define/provide-test-suite CORE-S-HORIZONTAL
  (test-case "Z[S] and M[S] have four exact codec/readback cases"
    (check-equal? (length CODEC-CASES) 4)
    (for ([z-state (in-list CODEC-CASES)])
      (define machine (term (m:encode-ZM/s ,z-state)))
      (define decomposition (term (z:Z->D/s ,z-state)))

      (check-true (redex-match? m:core-s-machine-lang M machine))
      (check-equal? (term (m:decode-MZ/s ,machine)) z-state)
      (check-equal? (term (m:D->M/s ,decomposition)) machine)
      (check-equal? (term (m:M->D/s ,machine)) decomposition)
      (check-equal? (term (m:readback-M/s ,machine))
                    (term (z:readback-Z/s ,z-state)))))

  (test-case "duplicate fresh binders cannot enter any S horizontal carrier"
    (define duplicate-work (second DUPLICATE-BINDER-SOURCE))
    (define duplicate-allocation
      (list 'DecAllocate duplicate-work (term (More hole))))
    (define duplicate-refocused
      (list 'ZAllocate duplicate-work (term (More hole))))
    (define duplicate-machine
      (list 'MAllocate duplicate-work (term (More hole))))
    (define duplicate-compressed
      (list 'BRun duplicate-work (term (More hole))))

    (check-false
     (redex-match? s:core-s-decomposition-lang F DUPLICATE-BINDER-SOURCE))
    (check-false
     (redex-match? s:core-s-decomposition-lang D duplicate-allocation))
    (check-false
     (redex-match? z:core-s-refocused-lang Z duplicate-refocused))
    (check-false
     (redex-match? m:core-s-machine-lang M duplicate-machine))
    (check-false
     (redex-match? b:core-s-compressed-lang B duplicate-compressed))
    (check-false
     (redex-match? big:core-s-big-lang F DUPLICATE-BINDER-SOURCE)))

  (test-case "all 13 M[S] direct/spec successors are raw singleton labeled proofs"
    (define encountered-names
      (for/list ([representative (in-list RULE-REPRESENTATIVES)])
        (match-define (list expected-name source) representative)
        (define z-state (source->z/s source))
        (define machine (term (m:encode-ZM/s ,z-state)))
        (define direct-results
          (judgment-holds
           (m:machine-step/direct/s ,machine RuleName M_next)
           (RuleName M_next)))
        (define spec-results
          (judgment-holds
           (m-spec:machine-step/spec/s ,machine RuleName M_next)
           (RuleName M_next)))
        (define square-results
          (judgment-holds
           (m-spec:ZM-step-square/s
            ,z-state
            RuleName
            Z_next
            M_0
            M_1)
           (RuleName Z_next M_0 M_1)))

        (check-equal?
         (length
          (build-derivations
           (m:machine-step/direct/s ,machine RuleName M_next)))
         1)
        (check-equal?
         (length
          (build-derivations
           (m-spec:machine-step/spec/s ,machine RuleName M_next)))
         1)
        (check-equal?
         (length
          (build-derivations
           (m-spec:ZM-step-square/s
            ,z-state
            RuleName
            Z_next
            M_0
            M_1)))
         1)
        (check-equal? direct-results spec-results)
        (check-equal? (length square-results) 1)

        (match-define (list actual-name machine-next)
          (only-result 'machine-step/direct/s direct-results))
        (match-define
          (list source-name source-target)
          (only-result
           'core-red
          (apply-reduction-relation/tag-with-names
           source-red:core-red
           source)))
        (check-equal? actual-name expected-name)
        (check-equal? (normalize-rule-name source-name) expected-name)
        (check-equal? (term (m:readback-M/s ,machine-next)) source-target)
        actual-name))

    (check-equal? (sort encountered-names symbol<?) CORE-RULE-NAMES))

  (test-case "M[S] runs one complete finite labeled trace"
    (define-values (labels terminal-machine)
      (machine-trace/s (source->m/s FINITE-SOURCE)))
    (check-equal? labels GOLDEN-M-LABELS)
    (check-equal? (term (m:readback-M/s ,terminal-machine))
                  GOLDEN-TERMINAL))

  (test-case "all 13 exact control points enter nonempty one/two-label B[S] spans"
    (define encountered-first-labels
      (for/list ([representative (in-list RULE-REPRESENTATIVES)])
        (match-define (list expected-name source) representative)
        (define machine (source->m/s source))
        (define compressed (term (b:encode-MB/s ,machine)))
        (define direct-results
          (judgment-holds
           (b:compressed-step/direct/s
            ,compressed
            TransitionSpan
            B_next)
           (TransitionSpan B_next)))
        (define spec-results
          (judgment-holds
           (b-spec:compressed-step/spec/s
            ,compressed
            TransitionSpan
            B_next)
           (TransitionSpan B_next)))
        (define square-results
          (judgment-holds
           (b-spec:MB-step-square/s
            ,compressed
            TransitionSpan
            B_next
            M_0
            M_1)
           (TransitionSpan B_next M_0 M_1)))

        (check-equal?
         (length
          (build-derivations
           (b:compressed-step/direct/s
            ,compressed
            TransitionSpan
            B_next)))
         1)
        (check-equal?
         (length
          (build-derivations
           (b-spec:compressed-step/spec/s
            ,compressed
            TransitionSpan
            B_next)))
         1)
        (check-equal?
         (length
          (build-derivations
           (b-spec:MB-step-square/s
            ,compressed
            TransitionSpan
            B_next
            M_0
            M_1)))
         1)
        (check-equal? direct-results spec-results)
        (check-equal? (length square-results) 1)

        (match-define (list transition-span compressed-next)
          (only-result 'compressed-step/direct/s direct-results))
        (define labels (span-labels/s transition-span))
        (define machine-next (term (b:decode-BM/s ,compressed-next)))
        (check-equal? (length labels)
                      (if (member expected-name PRODUCER-RULE-NAMES)
                          2
                          1))
        (check-equal? (first labels) expected-name)
        (check-equal?
         (judgment-holds
          (b-spec:replay-transition-span/M/s
           ,machine
           TransitionSpan
           M_next)
          (TransitionSpan M_next))
         (list (list transition-span machine-next)))
        expected-name))

    (check-equal? (sort encountered-first-labels symbol<?) CORE-RULE-NAMES))

  (test-case "nine exact labels partition into six canonical B[S] spans"
    (define machine (source->m/s FINITE-SOURCE))
    (define compressed (term (b:encode-MB/s ,machine)))
    (define-values (machine-labels terminal-machine)
      (machine-trace/s machine))
    (define-values (spans terminal-compressed)
      (compressed-trace/s compressed))
    (define flattened-labels
      (append-map span-labels/s spans))

    (check-equal? machine-labels GOLDEN-M-LABELS)
    (check-equal? spans GOLDEN-B-SPANS)
    (check-equal? (length machine-labels) 9)
    (check-equal? (length spans) 6)
    (check-equal? flattened-labels machine-labels)
    (check-equal? (term (m:readback-M/s ,terminal-machine))
                  GOLDEN-TERMINAL)
    (check-equal? (term (b:readback-B/s ,terminal-compressed))
                  GOLDEN-TERMINAL)
    (check-equal? (term (b:decode-BM/s ,terminal-compressed))
                  terminal-machine))

  (test-case "all 13 root inputs have singleton direct/spec Big[S] outcomes"
    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (match-define (list _expected-first-label source) representative)
      (define direct-results
        (judgment-holds
         (big:big-evaluate/direct/s ,source Big)
         Big))
      (define spec-results
        (judgment-holds
         (big-spec:big-evaluate/spec/s ,source BTrace Big)
         (BTrace Big)))
      (define root-square-results
        (judgment-holds
         (big-spec:B-Big-root-square/s ,source BTrace Big)
         (BTrace Big)))

      (check-equal?
       (length
        (build-derivations
         (big:big-evaluate/direct/s ,source Big)))
       1)
      (check-equal?
       (length
        (build-derivations
         (big-spec:big-evaluate/spec/s ,source BTrace Big)))
       1)
      (check-equal?
       (length
        (build-derivations
         (big-spec:B-Big-root-square/s ,source BTrace Big)))
       1)
      (check-equal? spec-results root-square-results)

      (define direct-big
        (only-result 'big-evaluate/direct/s direct-results))
      (match-define (list _trace spec-big)
        (only-result 'big-evaluate/spec/s spec-results))
      (check-equal? direct-big spec-big)))

  (test-case "all four B control entries promote through their direct Big[S] entries"
    (define success-big
      (term
       (BigFinal
        (Last
         (Owners)
         (Answer (Owners) ,sigma-empty)))))
    (define entry-cases
      (list
       (list
        (term
         (BRun
          (Work (Owners) (succeed (label "run")) ,sigma-empty)
          (More hole)))
        success-big)
       (list
        (term
         (BSettled
          (Returned (Owners) ,sigma-empty)
          (More hole)))
        success-big)
       (list
        (term (BDead ,owner-u0 (More hole)))
        (term (BigFinal (Done ,owner-u0))))
       (list
        (term (BFinal (Done ,owner-u0)))
        (term (BigFinal (Done ,owner-u0))))))

    (for ([entry-case (in-list entry-cases)])
      (match-define (list compressed expected-big) entry-case)
      (check-equal?
       (length
        (build-derivations
         (big-spec:promote-B/direct/s ,compressed Big)))
       1)
      (check-equal?
       (judgment-holds
        (big-spec:promote-B/direct/s ,compressed Big)
        Big)
       (list expected-big))))

  (test-case "Big[S] is the singleton fixed point of every golden B[S] suffix"
    (define compressed-root (source->b/s FINITE-SOURCE))
    (define compressed-path (compressed-path/s compressed-root))
    (define direct-results
      (judgment-holds
       (big:big-evaluate/direct/s ,FINITE-SOURCE Big)
       Big))
    (define spec-results
      (judgment-holds
       (big-spec:big-evaluate/spec/s
        ,FINITE-SOURCE
        BTrace
        Big)
       (BTrace Big)))
    (define root-square-results
      (judgment-holds
       (big-spec:B-Big-root-square/s
        ,FINITE-SOURCE
        BTrace
        Big)
       (BTrace Big)))

    (check-equal? (length compressed-path)
                  (add1 (length GOLDEN-B-SPANS)))
    (check-equal?
     (length
      (build-derivations
       (big:big-evaluate/direct/s ,FINITE-SOURCE Big)))
     1)
    (check-equal?
     (length
      (build-derivations
       (big-spec:big-evaluate/spec/s
        ,FINITE-SOURCE
        BTrace
        Big)))
     1)
    (check-equal?
     (length
      (build-derivations
       (big-spec:B-Big-root-square/s
        ,FINITE-SOURCE
        BTrace
        Big)))
     1)
    (check-equal? direct-results (list GOLDEN-BIG))
    (check-equal? spec-results
                  (list (list GOLDEN-B-SPANS GOLDEN-BIG)))
    (check-equal? root-square-results spec-results)
    (check-equal?
     (term (big-spec:flatten-BTrace/s ,GOLDEN-B-SPANS))
     GOLDEN-M-LABELS)
    (check-equal? (term (big:readback-Big/s ,GOLDEN-BIG))
                  GOLDEN-TERMINAL)

    (for ([compressed (in-list compressed-path)]
          [index (in-naturals)])
      (define expected-trace (drop GOLDEN-B-SPANS index))
      (define closure-results
        (judgment-holds
         (big-spec:B-Big-closure-square/s
          ,compressed
          BTrace
          Big)
         (BTrace Big)))

      (check-equal?
       (length
        (build-derivations
         (big-spec:promote-B/direct/s ,compressed Big)))
       1)
      (check-equal?
       (length
        (build-derivations
         (big-spec:close-B/spec/s ,compressed BTrace T)))
       1)
      (check-equal?
       (length
        (build-derivations
         (big-spec:B-Big-closure-square/s
          ,compressed
          BTrace
          Big)))
       1)
      (check-equal? closure-results
                    (list (list expected-trace GOLDEN-BIG)))

      (when (< index (length GOLDEN-B-SPANS))
        (define expected-span (list-ref GOLDEN-B-SPANS index))
        (define expected-next (list-ref compressed-path (add1 index)))
        (define unfold-results
          (judgment-holds
           (big-spec:B-Big-unfold-square/s
            ,compressed
            TransitionSpan
            B_next
            Big)
           (TransitionSpan B_next Big)))

        (check-equal?
         (length
          (build-derivations
           (big-spec:B-Big-unfold-square/s
            ,compressed
            TransitionSpan
            B_next
            Big)))
         1)
        (check-equal?
         unfold-results
         (list (list expected-span expected-next GOLDEN-BIG)))))))

(module+ test
  (run-tests CORE-S-HORIZONTAL))
