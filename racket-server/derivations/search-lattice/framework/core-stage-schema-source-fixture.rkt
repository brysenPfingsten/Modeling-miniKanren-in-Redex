#lang racket

(require redex/reduction-semantics
         "./core-source-schema.rkt")

;; Deliberately export only the syntax interface.  The generated language,
;; relation, allocation metafunctions, and all first-order helpers remain
;; private to this module.  A consumer that can generate and run D therefore
;; demonstrates lexical retention rather than accidental name lookup.
(provide foreign-core-source)

(define-core-representation-strategy foreign-core-strategy
  #:variable
  [#:runtime-variable-production natural
   #:productions ()
   #:definitions
   ((define-metafunction LANG
      allocate/private-fixture : supply d -> (rv ...)
      [(allocate/private-fixture supply (x ...))
       ,(build-list (length (term (x ...)))
                    (lambda (offset) (+ (term supply) offset)))])
    (define-metafunction LANG
      advance/private-fixture : supply d -> supply
      [(advance/private-fixture supply (x ...))
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
    ((where (rv_new ...)
            (allocate/private-fixture supply (x_bound ...)))
     (where supply_new
            (advance/private-fixture supply (x_bound ...)))
     (where g_new
            ,(SUBST-GOAL-HOOK
              (term g)
              (term ((x_bound rv_new) ...)))))]
   #:addressing-hook address/private-fixture]
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
   #:join-return-supply supply_inner
   #:join-failure-supply supply_inner
   #:terminal-answer-supply supply
   #:live-supply-hook live-supply/private-fixture
   #:failure-summary-hook failure-summary/private-fixture
   #:definitions ()
   #:well-formedness
   [#:definitions
    ((define-judgment-form
       LANG
       #:contract (allocated/private-fixture? rv supply)
       #:mode (allocated/private-fixture? I I)
       [(side-condition (< (term rv) (term supply)))
        ----------------------------------------
        (allocated/private-fixture? rv supply)])
     (define-judgment-form
       LANG
       #:contract (valid-supply/private-fixture? supply)
       #:mode (valid-supply/private-fixture? I)
       [----------------------------------------
        (valid-supply/private-fixture? supply)])
     (define-judgment-form
       LANG
       #:contract
       (extend-supply/private-fixture supply supply supply)
       #:mode (extend-supply/private-fixture I I O)
       [----------------------------------------
        (extend-supply/private-fixture
         supply_in supply_local supply_local)])
     (define-metafunction LANG
       acyclic-substitution/private-fixture? : sub -> boolean
       [(acyclic-substitution/private-fixture? sub) #t]))
    #:allocated-hook allocated/private-fixture?
    #:valid-supply-hook valid-supply/private-fixture?
    #:extend-supply-hook extend-supply/private-fixture
    #:acyclic-substitution-hook acyclic-substitution/private-fixture?
    #:state-supply-premises
    ((where supply_in supply_local))
    #:frame-prefix-premises
    ((where supply_frame supply_in))
    #:conjunction-goal-supply-premises
    ((LIVE-SUPPLY-HOOK W supply_frame supply_goal))
    #:terminal-prefix-premises
    ((where supply_prefix 0))
    #:root wf-core/private-fixture?]
   #:q-map
   [#:definitions
    ((define (address/private-fixture value _support) value)
     (define (q-export/private-fixture frontier) frontier)
     (define (q-rebuild/private-fixture neutral) neutral)
     (define (q-focus-export/private-fixture focused focus)
       `(q-focused ,focused ,focus))
     (define (q-focus-rebuild/private-fixture neutral)
       (match neutral
         [`(q-focused ,focused ,focus) (list focused focus)]))
     (define (q-root-focus-export/private-fixture frontier spine)
       `(q-root-focused ,frontier ,spine))
     (define (q-root-focus-rebuild/private-fixture neutral)
       (match neutral
         [`(q-root-focused ,frontier ,spine) (list frontier spine)]))
     (define (q-failure-focus-export/private-fixture summary focus)
       `(q-failure-focused ,summary ,focus))
     (define (q-failure-focus-rebuild/private-fixture neutral)
       (match neutral
         [`(q-failure-focused ,summary ,focus) (list summary focus)]))
     (define (q-terminal-export/private-fixture terminal) terminal)
     (define (q-terminal-rebuild/private-fixture neutral) neutral))
    #:export q-export/private-fixture
    #:rebuild q-rebuild/private-fixture
    #:focus-export q-focus-export/private-fixture
    #:focus-rebuild q-focus-rebuild/private-fixture
    #:root-focus-export q-root-focus-export/private-fixture
    #:root-focus-rebuild q-root-focus-rebuild/private-fixture
    #:failure-focus-export q-failure-focus-export/private-fixture
    #:failure-focus-rebuild q-failure-focus-rebuild/private-fixture
    #:terminal-export q-terminal-export/private-fixture
    #:terminal-rebuild q-terminal-rebuild/private-fixture]])

(define-generated-core-source
  #:strategy foreign-core-strategy
  #:language foreign-private-lang
  #:relation foreign-private-red
  #:raw-successors foreign-private-successors
  #:branch-copy foreign-private-branch-copy
  #:source-interface foreign-core-source)
