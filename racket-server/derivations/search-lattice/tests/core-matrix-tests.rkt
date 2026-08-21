#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in source-lang:
                    "../../../src/search-lattice/languages/core-lang.rkt")
         (prefix-in source-red:
                    "../../../src/search-lattice/reduction-relations/core-red.rkt")
         (prefix-in source-wf:
                    "../../../src/search-lattice/wf/core-wf.rkt")
         (prefix-in s:
                    "../core/s/decomposition.rkt")
         (prefix-in s-spec:
                    "../core/s/source-spec.rkt")
         (prefix-in z:
                    "../core/s/refocused.rkt")
         (prefix-in e-lang:
                    "../core/e/language.rkt")
         (prefix-in e-red:
                    "../core/e/source.rkt")
         (prefix-in e-wf:
                    "../core/e/wf.rkt")
         (prefix-in e-d:
                    "../core/e/decomposition.rkt")
         (prefix-in q:
                    "../core/s-to-e.rkt"))

(provide CORE-MATRIX-SEED)

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
      (Owners (Owner (u:2) (label "owner-u2"))
              (Owner (u:1) (label "fresh-u1")))
      (u:1 =? u:0 (label "fresh-body"))
      ,sigma-empty)
     (u:0 != (nat 7) (label "future-goal"))))))

;; Each representative owns one source rule and is deliberately kept local to
;; this derivation artifact.  The derived column does not import a production
;; test suite or a shared semantic-clause table.
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

(define TERMINAL-REPRESENTATIVES
  (list
   (term (Done ,owner-u0))
   (term (Last ,owner-u0 (Answer ,owner-u1 ,sigma-empty)))))

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

(define (matrix-trace s-frontier
                      e-frontier
                      d/s
                      z/s
                      d/e
                      [reversed-labels '()]
                      [fuel 24])
  (when (zero? fuel)
    (error 'matrix-trace "trace exceeded its explicit step bound"))
  (define source-steps
    (apply-reduction-relation/tag-with-names
     source-red:core-red
     s-frontier))
  (match source-steps
    ['()
     (check-equal?
      (apply-reduction-relation/tag-with-names e-red:core-e-red e-frontier)
      '())
     (check-equal?
      (judgment-holds
       (s:decomposed-step/direct/s ,d/s RuleName D_next)
       (RuleName D_next))
      '())
     (check-equal?
      (judgment-holds
       (z:refocused-step/direct/s ,z/s RuleName Z_next)
       (RuleName Z_next))
      '())
     (check-equal?
      (judgment-holds
       (e-d:decomposed-step/e ,d/e RuleName D_next)
       (RuleName D_next))
      '())
     (values (reverse reversed-labels) s-frontier e-frontier)]
    [(list (list source-name s-next))
     (match-define
       (list e-name e-next)
       (only-result
        'matrix-trace/e
        (apply-reduction-relation/tag-with-names
         e-red:core-e-red
         e-frontier)))
     (define d/s-spec
       (only-result
        'matrix-trace/D-spec
        (judgment-holds
         (s-spec:source-step/spec/s ,d/s RuleName D_next)
         (RuleName D_next))))
     (define d/s-direct
       (only-result
        'matrix-trace/D-direct
        (judgment-holds
         (s:decomposed-step/direct/s ,d/s RuleName D_next)
         (RuleName D_next))))
     (define z/s-spec
       (only-result
        'matrix-trace/Z-spec
        (judgment-holds
         (z:refocused-step/spec/s ,z/s RuleName Z_next)
         (RuleName Z_next))))
     (define z/s-direct
       (only-result
        'matrix-trace/Z-direct
        (judgment-holds
         (z:refocused-step/direct/s ,z/s RuleName Z_next)
         (RuleName Z_next))))
     (define d/e-direct
       (only-result
        'matrix-trace/D-E
        (judgment-holds
         (e-d:decomposed-step/e ,d/e RuleName D_next)
         (RuleName D_next))))
     (define label (normalize-rule-name source-name))

     (check-equal?
      (length
       (build-derivations
        (s-spec:source-step/spec/s ,d/s RuleName D_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (s:decomposed-step/direct/s ,d/s RuleName D_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (z:refocused-step/spec/s ,z/s RuleName Z_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (z:refocused-step/direct/s ,z/s RuleName Z_next)))
      1)
     (check-equal?
      (length
       (build-derivations
        (e-d:decomposed-step/e ,d/e RuleName D_next)))
      1)
     (check-equal? (normalize-rule-name e-name) label)
     (check-equal? d/s-direct d/s-spec)
     (check-equal? z/s-direct z/s-spec)
     (check-equal? (first d/s-direct) label)
     (check-equal? (first z/s-direct) label)
     (check-equal? (first d/e-direct) label)
     (check-equal? (term (s:plug-D/s ,(second d/s-direct))) s-next)
     (check-equal? (term (z:readback-Z/s ,(second z/s-direct))) s-next)
     (check-equal? (term (e-d:plug-D/e ,(second d/e-direct))) e-next)
     (check-equal? e-next (term (q:Q-SE/F ,s-next)))
     (check-equal?
      (term (q:Q-SE/D ,(second d/s-direct)))
      (second d/e-direct))
     (check-equal?
      (term (z:Z->D/s ,(second z/s-direct)))
      (second d/s-direct))

     (matrix-trace
      s-next
      e-next
      (second d/s-direct)
      (second z/s-direct)
      (second d/e-direct)
      (cons label reversed-labels)
      (sub1 fuel))]
    [_
     (error 'matrix-trace
            "R[S] produced a non-singleton raw proof set: ~e"
            source-steps)]))

(define/provide-test-suite CORE-MATRIX-SEED
  (test-case "R[S] and direct D[S] expose the same 13 live rule names"
    (define static-rule-names
      (map normalize-rule-name
           (reduction-relation->rule-names source-red:core-red)))
    (check-equal? (length static-rule-names)
                  (length CORE-RULE-NAMES))
    (check-equal? (sort static-rule-names symbol<?)
                  CORE-RULE-NAMES)

    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (match-define (list expected-name source) representative)
      (match-define
        (list source-name source-target)
        (only-result
         'source-step
         (apply-reduction-relation/tag-with-names
          source-red:core-red
          source)))
      (define decomposition (decompose/s source))
      (define specification-proof
        (only-result
         'source-step/spec/s
         (judgment-holds
          (s-spec:source-step/spec/s ,decomposition RuleName D_next)
          (RuleName D_next))))
      (define direct-proof
        (only-result
         'decomposed-step/direct/s
         (judgment-holds
          (s:decomposed-step/direct/s ,decomposition RuleName D_next)
          (RuleName D_next))))
      (define contractum
        (only-result
         'contract/s
         (judgment-holds (s:contract/s ,decomposition C) C)))

      (check-equal?
       (length
        (build-derivations
         (s-spec:source-step/spec/s ,decomposition RuleName D_next)))
       1)
      (check-equal?
       (length
        (build-derivations
         (s:decomposed-step/direct/s ,decomposition RuleName D_next)))
       1)
      (check-equal?
       (length (build-derivations (s:contract/s ,decomposition C)))
       1)
      (check-equal? (normalize-rule-name source-name) expected-name)
      (check-equal? (first specification-proof) expected-name)
      (check-equal? direct-proof specification-proof)
      (check-equal? (term (s:contract-label/s ,contractum)) expected-name)
      (check-equal?
       (term (s:plug-D/s ,(second specification-proof)))
       source-target)))

  (test-case "D[S] uniquely decomposes and plugs every redex and terminal"
    (for ([frontier
           (in-list
            (append (map second RULE-REPRESENTATIVES)
                    TERMINAL-REPRESENTATIVES))])
      (define decomposition (decompose/s frontier))
      (check-equal?
       (length (build-derivations (s:decompose/s ,frontier D)))
       1)
      (check-equal? (term (s:plug-D/s ,decomposition)) frontier)))

  (test-case "Z[S] codecs and direct refocusing agree with the slow specification"
    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (match-define (list expected-name source) representative)
      (define decomposition (decompose/s source))
      (define refocused (term (z:D->Z/s ,decomposition)))
      (match-define
        (list _source-name source-target)
        (only-result
         'source-step/Z
         (apply-reduction-relation/tag-with-names
          source-red:core-red
          source)))
      (define specification-proof
        (only-result
         'refocused-step/spec/s
         (judgment-holds
          (z:refocused-step/spec/s ,refocused RuleName Z_next)
          (RuleName Z_next))))
      (define direct-proof
        (only-result
         'refocused-step/direct/s
         (judgment-holds
          (z:refocused-step/direct/s ,refocused RuleName Z_next)
          (RuleName Z_next))))

      (check-equal? (term (z:Z->D/s ,refocused)) decomposition)
      (check-equal? (term (z:readback-Z/s ,refocused)) source)
      (check-equal?
       (length
        (build-derivations
         (z:refocused-step/spec/s ,refocused RuleName Z_next)))
       1)
      (check-equal?
       (length
        (build-derivations
         (z:refocused-step/direct/s ,refocused RuleName Z_next)))
       1)
      (check-equal? direct-proof specification-proof)
      (check-equal? (first direct-proof) expected-name)
      (check-equal?
       (term (z:readback-Z/s ,(second direct-proof)))
       source-target))

    (for ([terminal (in-list TERMINAL-REPRESENTATIVES)])
      (define decomposition (decompose/s terminal))
      (define refocused (term (z:D->Z/s ,decomposition)))
      (check-equal? (term (z:Z->D/s ,refocused)) decomposition)
      (check-equal? (term (z:readback-Z/s ,refocused)) terminal)
      (check-equal?
       (judgment-holds
        (z:refocused-step/direct/s ,refocused RuleName Z_next)
        (RuleName Z_next))
       '())))

  (test-case "S allocation derives support from the separated focus"
    (define decomposition (decompose/s allocation-source))
    (match-define `(DecAllocate ,allocation-redex ,work-focus)
      decomposition)

    (check-equal?
     (term (s:whole-frontier-support/s ,allocation-source))
     (term (u:0 u:2)))
    (check-equal?
     (term (s:separated-work-support/s ,work-focus ,allocation-redex))
     (term (u:0 u:2)))
    (check-true
     (term (s:support-split-agrees?/s ,work-focus ,allocation-redex)))
    (check-equal?
     (term
      (s:fresh-intro/whole/s
       ,allocation-source
       (x:q)))
     (term (u:1)))
    (check-equal?
     (term
      (s:fresh-intro/separated/s
       ,work-focus
       ,allocation-redex
       (x:q)))
     (term (u:1)))

    (match-define
      (list source-name source-target)
      (only-result
       'allocate-source-step
       (apply-reduction-relation/tag-with-names
        source-red:core-red
        allocation-source)))
    (check-equal? (normalize-rule-name source-name) 'allocate-fresh)
    (check-equal? source-target allocation-target)
    (check-equal?
     (judgment-holds (source-wf:wf-cfg/core? ,allocation-source))
     #t)
    (check-equal?
     (judgment-holds (source-wf:wf-cfg/core? ,allocation-target))
     #t))

  (test-case "R[E] is a cumulative-support calculus with the same 13 labels"
    (define static-rule-names
      (map normalize-rule-name
           (reduction-relation->rule-names e-red:core-e-red)))
    (check-equal? (length static-rule-names)
                  (length CORE-RULE-NAMES))
    (check-equal? (sort static-rule-names symbol<?)
                  CORE-RULE-NAMES)

    (for ([representative (in-list RULE-REPRESENTATIVES)])
      (match-define (list expected-name source) representative)
      (define e-source (term (q:Q-SE/F ,source)))
      (define s-decomposition (decompose/s source))
      (define e-decompositions
        (judgment-holds (e-d:decompose/e ,e-source D) D))

      (check-true
       (judgment-holds (source-wf:wf-cfg/core? ,source)))
      (check-true (redex-match? e-lang:core-e-lang F e-source))
      (check-true (judgment-holds (e-wf:wf-cfg/e? ,e-source)))
      (check-true (q:source-square-premise?/s->e source))
      (check-true (q:source-square/raw?/s->e source))
      (check-true (q:decomposition-square/raw?/s->e source))
      (check-true (q:contract-square/raw?/s->e s-decomposition))
      (check-true
       (q:decomposed-step-square/raw?/s->e s-decomposition))

      (match-define
        (list e-name _e-target)
        (only-result
         'source-step/e
         (apply-reduction-relation/tag-with-names
          e-red:core-e-red
          e-source)))
      (check-equal? (normalize-rule-name e-name) expected-name)
      (check-equal? (length e-decompositions) 1)
      (check-equal?
       (length (build-derivations (e-d:decompose/e ,e-source D)))
       1)
      (check-equal?
       (length
        (build-derivations
         (e-d:decomposed-step/e
          ,(first e-decompositions)
          RuleName
          D_next)))
       1)))

  (test-case "Q_SE threads cumulative support through structural partitions"
    (define nested-s
      (term
       (More
        (Conj
         ,owner-u0
         (Returned ,owner-u1 ,sigma-empty)
         (u:0 =? u:0 (label "continue"))))))
    (define last-s
      (term (Last ,owner-u0 (Answer ,owner-u1 ,sigma-empty))))

    (check-equal?
     (term (q:Q-SE/F ,nested-s))
     (term
      (More
       (Conj
        (Support u:0)
        (Returned (Support u:0 u:1) ,sigma-empty)
        (u:0 =? u:0 (label "continue"))))))
    (check-equal?
     (term (q:Q-SE/F ,last-s))
     (term
      (Last (Support u:0)
            (Answer (Support u:0 u:1) ,sigma-empty))))
    (check-equal?
     (term (q:Q-SE/F (Done ,owner-u0)))
     (term (Done (Support u:0))))
    (check-equal?
     (term
      (q:erase-owners
       (source-lang:owners-append ,owner-u0 ,owner-u1)))
     (term
      (e-lang:support-append
       (q:erase-owners ,owner-u0)
       (q:erase-owners ,owner-u1))))
    (check-false
     (redex-match?
      e-lang:core-e-lang
      F
      (term (Done ,owner-u0)))))

  (test-case "allocation is the explicit S-to-E support boundary"
    (define s-decomposition (decompose/s allocation-source))
    (define e-source (term (q:Q-SE/F ,allocation-source)))
    (define e-target (term (q:Q-SE/F ,allocation-target)))
    (define e-decomposition
      (only-result
       'decompose-allocation/e
       (judgment-holds (e-d:decompose/e ,e-source D) D)))

    (check-equal?
     (q:allocation-support-sides/s->e s-decomposition)
     '((u:0 u:2) (u:0 u:2)))
    (check-true
     (q:allocation-support-agrees?/s->e s-decomposition))
    (check-equal?
     (term (q:Q-SE/D ,s-decomposition))
     e-decomposition)
    (match-define
      (list name next)
      (only-result
       'allocate-step/e
       (apply-reduction-relation/tag-with-names
        e-red:core-e-red
        e-source)))
    (check-equal? (normalize-rule-name name) 'allocate-fresh)
    (check-equal? next e-target)
    (check-true (judgment-holds (e-wf:wf-cfg/e? ,e-target))))

  (test-case "one finite program runs in lockstep across all five cells"
    (define source
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
    (define d/s (decompose/s source))
    (define z/s (term (z:D->Z/s ,d/s)))
    (define e-source (term (q:Q-SE/F ,source)))
    (define d/e
      (only-result
       'trace-decompose/e
       (judgment-holds (e-d:decompose/e ,e-source D) D)))
    (define-values (labels terminal/s terminal/e)
      (matrix-trace source e-source d/s z/s d/e))

    (check-equal?
     labels
     '(allocate-fresh
       expand-conjunction
       expand-conjunction
       unify-success
       conj-return
       disequality-success
       conj-return
       succeed
       finish-success))
    (check-equal?
     terminal/s
     (term
      (Last
       (Owners (Owner (u:0 u:1) (label "allocate-two")))
       (Answer
        (Owners)
        (state ((u:0 (sym "cat")))
               ((u:1 (sym "dog")))
               ((u:0 =? (sym "cat") (label "bind-x")))
               (label "state"))))))
    (check-equal? terminal/e (term (q:Q-SE/F ,terminal/s)))))

(module+ test
  (run-tests CORE-MATRIX-SEED))
