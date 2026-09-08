#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in core-lang:
                    "../../source/languages/core-lang.rkt")
         (prefix-in core:
                    "../../source/reduction-relations/core-red.rkt")
         (prefix-in disj:
                    "../../source/reduction-relations/disj-red.rkt")
         (prefix-in disj-wf:
                    "../../source/wf/disj-wf.rkt")
         "../../source/structural-observations.rkt")

(provide STRUCTURAL-ALLOCATION)

(define empty-state
  (term (state () () () (label "state"))))

(define (only-named-successor relation source expected-name)
  (define successors
    (apply-reduction-relation/tag-with-names relation source))
  (check-equal?
   (apply-reduction-relation/tag-with-names relation source)
   successors
   (format "expected deterministic raw proofs for ~s" source))
  (check-equal? (length successors)
                1
                (format "expected one raw proof for ~s; got ~s"
                        source successors))
  (match successors
    [(list (list name successor))
     (check-equal? (~a name) expected-name)
     successor]
    [_ #f]))

(define (fresh-goal lexical-variable tag-name)
  `(∃ (,lexical-variable)
      (,lexical-variable
       =?
       ,lexical-variable
       (label ,(string-append tag-name "-body")))
      (label ,tag-name)))

(define/provide-test-suite STRUCTURAL-ALLOCATION
  (test-case "carrier removes caches and fresh-marker wrappers while retaining structural owners"
    (check-true
     (redex-match? core-lang:core-lang
                   σ
                   (term (state () () () (label "state")))))
    (check-false
     (redex-match? core-lang:core-lang
                   σ
                   (term (state () () () () (label "old-state")))))
    (check-true
     (redex-match? core-lang:core-lang
                   W
                   (term (Conj (Owners)
                               (Dead (Owners))
                               (succeed (label "next"))))))
    (check-false
     (redex-match? core-lang:core-lang
                   W
                   (term (Conj (Dead (Owners))
                               (succeed (label "next"))))))
    (check-true
     (redex-match? core-lang:core-lang
                   W
                   (term (Dead (Owners (Owner (u:0) (label "owner")))))))
    (check-false
     (redex-match? core-lang:core-lang
                   W
                   (term
                    (Dead
                     (Owners (Owner (u:0 u:0) (label "owner"))))))))

  (test-case "nested fresh allocation preserves an empty middle owner"
    (define source
      (term
       (More
        (Work (Owners)
         (∃ (x:0)
            (∃ ()
               (∃ (x:1)
                  (succeed (label "ok"))
                  (label "fy"))
               (label "fempty"))
            (label "fx"))
         ,empty-state))))
    (define after-outer-allocation
      (only-named-successor core:core-red source "allocate-fresh"))
    (define after-empty-allocation
      (only-named-successor core:core-red
                            after-outer-allocation
                            "allocate-fresh"))
    (define after-inner-allocation
      (only-named-successor core:core-red
                            after-empty-allocation
                            "allocate-fresh"))

    (check-equal?
     after-inner-allocation
     (term
      (More
       (Work (Owners
              (Owner (u:0) (label "fx"))
              (Owner () (label "fempty"))
              (Owner (u:1) (label "fy")))
             (succeed (label "ok"))
             ,empty-state)))))

  (test-case "multiple binders allocate once in lexical order"
    (define source
      (term
       (More
        (Work (Owners)
         (∃ (x:first x:second x:third)
            ((x:first : (x:second : x:third))
             =?
             (x:first : (x:second : x:third))
             (label "body"))
            (label "fresh"))
         ,empty-state))))
    (check-equal?
     (only-named-successor core:allocate/base source "allocate-fresh")
     (term
      (More
       (Work (Owners (Owner (u:0 u:1 u:2) (label "fresh")))
             ((u:0 : (u:1 : u:2))
              =?
              (u:0 : (u:1 : u:2))
              (label "body"))
             ,empty-state))))
    (check-equal? (reduction-relation->rule-names core:allocate/base)
                  '(allocate-fresh)))

  (test-case "whole-frontier freshness sees an otherwise unused outer owner"
    (define source
      (term
       (More
        (Work (Owners (Owner (u:0) (label "outer-owner")))
              ,(fresh-goal 'x:q "fresh")
              ,empty-state))))
    (check-equal?
     (only-named-successor core:allocate/base source "allocate-fresh")
     (term
      (More
       (Work (Owners
              (Owner (u:0) (label "outer-owner"))
              (Owner (u:1) (label "fresh")))
             (u:1 =? u:1 (label "fresh-body"))
             ,empty-state)))))

  (test-case "whole-frontier freshness scans the focused state"
    (define active-state
      (term
       (state ((u:0 (nat 0)))
              ()
              ((u:0 =? (nat 0) (label "active-binding")))
              (label "active"))))
    (define source
      (term
       (More
        (Work (Owners) ,(fresh-goal 'x:q "fresh") ,active-state))))
    (check-equal?
     (only-named-successor core:allocate/base source "allocate-fresh")
     (term
      (More
       (Work (Owners (Owner (u:1) (label "fresh")))
             (u:1 =? u:1 (label "fresh-body"))
             ,active-state)))))

  (test-case "whole-frontier freshness scans an unmarked completed answer state"
    (define completed-state
      (term
       (state ((u:0 (nat 0)))
              ()
              ((u:0 =? (nat 0) (label "old-answer")))
              (label "completed"))))
    (define source
      (term
       (Emit (Owners)
        (Answer (Owners) ,completed-state)
        (More
         (Work (Owners) ,(fresh-goal 'x:q "fresh") ,empty-state)))))
    (check-equal?
     (only-named-successor disj:disj-red source "allocate-fresh")
     (term
      (Emit (Owners)
       (Answer (Owners) ,completed-state)
       (More
        (Work (Owners (Owner (u:1) (label "fresh")))
              (u:1 =? u:1 (label "fresh-body"))
              ,empty-state))))))

  (test-case "whole-frontier freshness sees a committed answer"
    (define completed-state
      (term
       (state ((u:0 (nat 0)))
              ()
              ((u:0 =? (nat 0) (label "old-answer")))
              (label "completed"))))
    (define source
      (term
       (Emit (Owners)
        (Answer (Owners (Owner (u:0) (label "completed-owner")))
                ,completed-state)
        (More
         (Work (Owners) ,(fresh-goal 'x:q "fresh") ,empty-state)))))
    (check-true
     (judgment-holds (disj-wf:wf-cfg/disj? ,source)))
    (define successor
      (only-named-successor disj:disj-red source "allocate-fresh"))
    (check-equal?
     successor
     (term
      (Emit (Owners)
       (Answer (Owners (Owner (u:0) (label "completed-owner")))
               ,completed-state)
       (More
        (Work (Owners (Owner (u:1) (label "fresh")))
              (u:1 =? u:1 (label "fresh-body"))
              ,empty-state))))))

  (test-case "feature-extended whole-frontier freshness sees a sibling"
    (define sibling-state
      (term
       (state ((u:0 (nat 0)))
              ()
              ((u:0 =? (nat 0) (label "sibling-binding")))
              (label "sibling"))))
    (define source
      (term
       (More
        (DisjL (Owners)
         (Work (Owners) ,(fresh-goal 'x:q "fresh") ,empty-state)
         (Returned (Owners (Owner (u:0) (label "sibling-owner")))
                   ,sibling-state)))))
    (check-true
     (judgment-holds (disj-wf:wf-cfg/disj? ,source)))
    (check-equal?
     (only-named-successor disj:disj-red source "allocate-fresh")
     (term
      (More
       (DisjL (Owners)
        (Work (Owners (Owner (u:1) (label "fresh")))
              (u:1 =? u:1 (label "fresh-body"))
              ,empty-state)
        (Returned (Owners (Owner (u:0) (label "sibling-owner")))
                  ,sibling-state))))))

  (test-case "a dead sibling adds no freshness blocker"
    (define source
      (term
       (More
        (DisjL (Owners)
         (Work (Owners) ,(fresh-goal 'x:q "fresh") ,empty-state)
         (Dead (Owners))))))
    (check-equal?
     (only-named-successor disj:disj-red source "allocate-fresh")
     (term
      (More
       (DisjL (Owners)
        (Work (Owners (Owner (u:0) (label "fresh")))
              (u:0 =? u:0 (label "fresh-body"))
              ,empty-state)
        (Dead (Owners)))))))

  (test-case "an unpruned dead-tail owner blocks whole-frontier name reuse"
    (define source
      (term
       (More
        (DisjL (Owners)
         (Work (Owners) ,(fresh-goal 'x:q "fresh") ,empty-state)
         (Dead
          (Owners (Owner (u:0) (label "unpruned-dead-owner"))))))))
    (check-equal?
     (only-named-successor disj:disj-red source "allocate-fresh")
     (term
      (More
       (DisjL (Owners)
        (Work (Owners (Owner (u:1) (label "fresh")))
              (u:1 =? u:1 (label "fresh-body"))
              ,empty-state)
        (Dead
         (Owners (Owner (u:0) (label "unpruned-dead-owner")))))))))

  (test-case "Done ownership blocks primitive freshness without creating an allocation focus"
    ;; The frontier grammar has one spine, so a terminal Done cannot coexist
    ;; with live More work in one well-formed operational frontier. Exercise
    ;; Redex's whole-term freshness primitive directly instead of fabricating
    ;; such a source configuration.
    (define owned-done
      (term (Done (Owners (Owner (u:0) (label "terminal-owner"))))))
    (check-equal? (variables-not-in owned-done '(u:0)) '(u:1))
    (check-equal? (variables-not-in owned-done '(u:0)) '(u:1))
    (check-equal?
     (apply-reduction-relation/tag-with-names
      core:allocate/base
      (term (Done (Owners))))
     '())
    (check-equal?
     (apply-reduction-relation/tag-with-names
      disj:disj-red
      (term
       (Emit (Owners)
             (Answer (Owners) ,empty-state)
             (Done (Owners)))))
     '()))

  (test-case "core dead tails retain conjunction and payload owners in order"
    (define source
      (term
       (More
        (Conj (Owners (Owner (u:0) (label "conjunction-owner")))
              (Dead (Owners (Owner (u:1) (label "dead-owner"))))
              (succeed (label "unreached"))))))
    (define dead-tail
      (only-named-successor core:core-red source "conj-fail"))
    (check-equal?
     dead-tail
     (term
      (More
       (Dead
        (Owners
         (Owner (u:0) (label "conjunction-owner"))
         (Owner (u:1) (label "dead-owner")))))))
    (check-equal?
     (term (structural-owner-record-occurrence-count ,dead-tail))
     2)
    (check-equal?
     (term (structural-introduced-name-occurrence-count ,dead-tail))
     2))

  (test-case "pruning dead ownership preserves live owners and permits name reuse"
    (define pending-fresh
      (term
       (Work (Owners (Owner (u:2) (label "remaining-owner")))
             ,(fresh-goal 'x:next "second")
             ,empty-state)))
    (define source
      (term
       (More
        (DisjL (Owners (Owner (u:0) (label "choice-owner")))
               (Dead (Owners (Owner (u:1) (label "dead-owner"))))
               ,pending-fresh))))
    (define after-prune
      (only-named-successor disj:disj-red source "skip-left-failure"))
    (check-equal?
     after-prune
     (term
      (More
       (Work (Owners
              (Owner (u:0) (label "choice-owner"))
              (Owner (u:2) (label "remaining-owner")))
             ,(fresh-goal 'x:next "second")
             ,empty-state))))
    (check-equal?
     (term (structural-owner-record-occurrence-count ,source))
     3)
    (check-equal?
     (term (structural-owner-record-occurrence-count ,after-prune))
     2)
    (check-equal?
     (term (structural-introduced-name-occurrence-count ,source))
     3)
    (check-equal?
     (term (structural-introduced-name-occurrence-count ,after-prune))
     2)
    (check-equal?
     (only-named-successor disj:disj-red after-prune "allocate-fresh")
     (term
      (More
       (Work (Owners
              (Owner (u:0) (label "choice-owner"))
              (Owner (u:2) (label "remaining-owner"))
              (Owner (u:1) (label "second")))
             (u:1 =? u:1 (label "second-body"))
             ,empty-state))))))

(module+ test
  (run-tests STRUCTURAL-ALLOCATION))
