#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "./core-source-schema.rkt")

(provide CORE-SOURCE-SCHEMA-TESTS)

;; This intentionally foreign representation exercises the public strategy
;; surface without making the framework depend on any project row.
(define-core-representation-strategy smoke-strategy
  #:variable
  [#:runtime-variable-production natural
   #:productions ()
   #:definitions
   ((define-metafunction LANG
      allocate/smoke : supply d -> (rv ...)
      [(allocate/smoke supply (x ...))
       ,(build-list (length (term (x ...)))
                    (lambda (offset) (+ (term supply) offset)))])
    (define-metafunction LANG
      advance/smoke : supply d -> supply
      [(advance/smoke supply (x ...))
       ,(+ (term supply) (length (term (x ...))))]))
   #:walk-hook generated-structural
   #:unify-hook generated-first-order
   #:invalid-hook generated-store-check
   #:lexical-substitution-hook generated-binder-local
   #:allocation
   [#:source
    (in-hole
     WorkFocus
     (Work
      supply
      (∃ (x_bound ...) g tag)
      (box supply sub dis trail tag_state)))
    #:target
    (in-hole
     WorkFocus
     (Work
      supply_new
      g_new
      (box supply_new sub dis trail tag_state)))
    #:premises
    ((where (rv_new ...) (allocate/smoke supply (x_bound ...)))
     (where supply_new (advance/smoke supply (x_bound ...)))
     (where g_new
            ,(subst-goal-hook
              (term g)
              (term ((x_bound rv_new) ...)))))]
   #:addressing-hook address/smoke]
  #:supply/provenance
  [#:productions ([supply natural])
   #:carriers
   [#:state (box supply sub dis trail tag)
    #:answer (Answer supply sigma)
    #:returned (Returned supply sigma)
    #:work (Work supply g sigma)
    #:dead (Dead supply)
    #:conj (Conj supply W g)
    #:last (Last supply A)
    #:done (Done supply)
    #:more (More W)]
   #:empty-supply 0
   #:conjunction-focus-supply 17
   #:branch-copy-supply 23
   #:join-return-supply supply_inner
   #:join-failure-supply supply_inner
   #:terminal-answer-supply supply
   #:live-supply-hook live-supply/smoke
   #:failure-summary-hook failure-summary/smoke
   #:definitions ()
   #:well-formedness
   [#:definitions
    ((define-judgment-form
       LANG
       #:contract (allocated/smoke? rv supply)
       #:mode (allocated/smoke? I I)
       [(side-condition (< (term rv) (term supply)))
        ------------------------------ "allocated smoke variable"
        (allocated/smoke? rv supply)])
     (define-judgment-form
       LANG
       #:contract (valid-supply/smoke? supply)
       #:mode (valid-supply/smoke? I)
       [------------------------------ "natural smoke supply"
        (valid-supply/smoke? supply)])
     (define-judgment-form
       LANG
       #:contract (extend-supply/smoke supply supply supply)
       #:mode (extend-supply/smoke I I O)
       [------------------------------ "state-local smoke supply"
        (extend-supply/smoke supply_in supply_local supply_local)])
     (define-metafunction LANG
       acyclic-substitution/smoke? : sub -> boolean
       [(acyclic-substitution/smoke? sub) #t]))
    #:allocated-hook allocated/smoke?
    #:valid-supply-hook valid-supply/smoke?
    #:extend-supply-hook extend-supply/smoke
    #:acyclic-substitution-hook acyclic-substitution/smoke?
    #:state-supply-premises
    ((where supply_in supply_local))
    #:frame-prefix-premises
    ((where supply_frame supply_in))
    #:conjunction-goal-supply-premises
    ((live-supply/smoke W supply_frame supply_goal))
    #:terminal-prefix-premises
    ((where supply_prefix 0))
    #:root wf-core/smoke]
   #:q-map
   [#:definitions
    ((define (address/smoke value) value)
     (define (export/smoke frontier) frontier)
     (define (rebuild/smoke neutral) neutral)
     (define (focus-export/smoke focused focus)
       `(q-focused ,focused ,focus))
     (define (focus-rebuild/smoke neutral)
       (match neutral
         [`(q-focused ,focused ,focus) (list focused focus)])))
    #:export export/smoke
    #:rebuild rebuild/smoke
    #:focus-export focus-export/smoke
    #:focus-rebuild focus-rebuild/smoke]])

(define-generated-core-source
  #:strategy smoke-strategy
  #:language smoke-generated-lang
  #:relation smoke-generated-red
  #:raw-successors raw-successors/smoke
  #:branch-copy branch-copy/smoke)

(define-generated-core-representation-maps
  #:s-strategy smoke-strategy
  #:e-strategy smoke-strategy
  #:n-strategy smoke-strategy
  #:Q-SE Q-SE/smoke
  #:Q-EN Q-EN/smoke
  #:Q-SN Q-SN/smoke
  #:composition Q-composition/smoke?)

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

(define EMPTY-STATE
  (term (box 0 () () () (label "state"))))

(define (strategy-declaration-for-expansion
         variable-productions
         variable-definitions
         [extra-supply-fields '()])
  #`(define-core-representation-strategy rejected-strategy
      #:variable
      [#:runtime-variable-production natural
       #:productions #,variable-productions
       #:definitions #,variable-definitions
       #:walk-hook generated-structural
       #:unify-hook generated-first-order
       #:invalid-hook generated-store-check
       #:lexical-substitution-hook generated-binder-local
       #:allocation
       [#:source allocation-source
        #:target allocation-target
        #:premises ()]
       #:addressing-hook rejected-address]
      #:supply/provenance
      [#:productions ([supply natural])
       #:carriers
       [#:state (box supply sub dis trail tag)
        #:answer (Answer supply sigma)
        #:returned (Returned supply sigma)
        #:work (Work supply g sigma)
        #:dead (Dead supply)
        #:conj (Conj supply W g)
        #:last (Last supply A)
        #:done (Done supply)
        #:more (More W)]
       #:empty-supply 0
       #:conjunction-focus-supply supply
       #:branch-copy-supply supply
       #,@extra-supply-fields
       #:join-return-supply supply_inner
       #:join-failure-supply supply_inner
       #:terminal-answer-supply supply
       #:live-supply-hook rejected-live
       #:failure-summary-hook rejected-failure
       #:definitions ()
       #:well-formedness
       [#:definitions ()
        #:allocated-hook rejected-allocated
        #:valid-supply-hook rejected-valid
        #:extend-supply-hook rejected-extend
        #:acyclic-substitution-hook rejected-acyclic
        #:state-supply-premises ()
        #:frame-prefix-premises ()
        #:conjunction-goal-supply-premises ()
        #:terminal-prefix-premises ()
        #:root rejected-wf]
       #:q-map
       [#:definitions ()
        #:export rejected-export
        #:rebuild rejected-rebuild
        #:focus-export rejected-focus-export
        #:focus-rebuild rejected-focus-rebuild]]))

(define-test-suite CORE-SOURCE-SCHEMA-TESTS
  (test-case "a foreign strategy emits a complete static source artifact"
    (check-true
     (redex-match?
      smoke-generated-lang
      F
      (term (More (Work 0 (succeed (label "yes")) ,EMPTY-STATE)))))
    (define actual-labels
      (map (lambda (name) (string->symbol (~a name)))
           (reduction-relation->rule-names smoke-generated-red)))
    (check-equal? (length actual-labels) 13)
    (check-equal? (length actual-labels)
                  (length (remove-duplicates actual-labels)))
    (check-equal? (sort actual-labels symbol<?) CORE-RULE-NAMES))

  (test-case "carrier templates and allocation hooks are operational"
    (check-equal? (term (branch-copy/smoke 5)) 23)

    (define success-source
      (term (More (Work 0 (succeed (label "yes")) ,EMPTY-STATE))))
    (check-equal?
     (raw-successors/smoke success-source)
     (list
      (list
       'succeed
       (term (More (Returned 0 ,EMPTY-STATE))))))

    ;; These deliberately distinct literals prove that conjunction focus is
    ;; not accidentally rendered from either true-empty or branch-copy data.
    (define conjunction-source
      (term
       (More
        (Work
         5
         ((succeed (label "left"))
          ∧
          (fail (label "right"))
          (label "and"))
         (box 5 () () () (label "state-5"))))))
    (check-equal?
     (raw-successors/smoke conjunction-source)
     (list
      (list
       'expand-conjunction
       (term
        (More
         (Conj
          5
          (Work
           17
           (succeed (label "left"))
           (box 5 () () () (label "state-5")))
          (fail (label "right"))))))))

    (define allocation-source
      (term
       (More
        (Work
         0
         (∃ (x:a x:b)
            (x:a =? x:b (label "body"))
            (label "fresh"))
         ,EMPTY-STATE))))
    (check-equal?
     (raw-successors/smoke allocation-source)
     (list
      (list
       'allocate-fresh
       (term
        (More
         (Work
          2
          (0 =? 1 (label "body"))
          (box 2 () () () (label "state")))))))))

  (test-case "unification and disequality premises share carrier bindings"
    (define bind-state
      (term (box 1 () () () (label "bind-state"))))
    (check-equal?
     (raw-successors/smoke
      (term
       (More
        (Work
         1
         (0 =? (nat 7) (label "bind"))
         ,bind-state))))
     (list
      (list
       'unify-success
       (term
        (More
         (Returned
          1
          (box
           1
           ((0 (nat 7)))
           ()
           ((0 =? (nat 7) (label "bind")))
           (label "bind-state"))))))))

    (check-equal?
     (raw-successors/smoke
      (term
       (More
        (Work
         0
         ((nat 0) =? (nat 1) (label "different"))
         ,EMPTY-STATE))))
     (list (list 'unify-fail (term (More (Dead 0))))))

    (check-equal?
     (raw-successors/smoke
      (term
       (More
        (Work
         0
         ((nat 0) != (nat 1) (label "apart"))
         ,EMPTY-STATE))))
     (list
      (list
       'disequality-success
       (term
        (More
         (Returned
          0
          (box
           0
           ()
           (((nat 0) (nat 1)))
           ()
           (label "state"))))))))

    (check-equal?
     (raw-successors/smoke
      (term
       (More
        (Work
         0
         ((nat 0) != (nat 0) (label "same"))
         ,EMPTY-STATE))))
     (list (list 'disequality-fail (term (More (Dead 0)))))))

  (test-case "WF and direct static map surfaces are emitted"
    (define frontier
      (term (More (Work 0 (succeed (label "yes")) ,EMPTY-STATE))))
    (check-true (judgment-holds (wf-core/smoke ,frontier)))
    (check-equal? (Q-SE/smoke frontier) frontier)
    (check-equal? (Q-EN/smoke frontier) frontier)
    (check-equal? (Q-SN/smoke frontier) frontier)
    (check-true (Q-composition/smoke? frontier)))

  (test-case "strategy definitions cannot smuggle source semantics"
    (check-exn
     #rx"may not contain source-relation forms or rule labels"
     (lambda ()
       (expand
        #`(let ()
            #,(strategy-declaration-for-expansion
               #'()
               #'((define hidden-label "succeed")))
            #t))))
    (check-exn
     #rx"may not contain source-relation forms or rule labels"
     (lambda ()
       (expand
        #`(let ()
            #,(strategy-declaration-for-expansion
               #'()
               #'((define hidden-relation
                    (reduction-relation LANG #:domain any))))
            #t)))))

  (test-case "duplicate productions and malformed fields fail at expansion"
    (check-exn
     #rx"strategy productions must have distinct nonterminal names"
     (lambda ()
       (expand
        #`(let ()
            #,(strategy-declaration-for-expansion
               #'([aux natural] [aux boolean])
               #'())
            #t))))
    (check-exn
     exn:fail:syntax?
     (lambda ()
       (expand
        #`(let ()
            #,(strategy-declaration-for-expansion
               #'()
               #'()
               (list #'#:branch-copy-supply #'supply))
            #t))))))

(module+ test
  (run-tests CORE-SOURCE-SCHEMA-TESTS))
