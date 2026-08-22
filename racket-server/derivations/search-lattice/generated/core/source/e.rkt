#lang racket

(require redex/reduction-semantics
         "../../../framework/core-source-schema.rkt")

(provide core-e-representation-strategy
         generated-core-e-lang
         generated-core-e-red
         raw-successors/generated/e
         branch-copy/generated/e
         wf-core/generated/e?
         live-supply/generated/e
         failure-summary/generated/e
         address/generated/e
         q-export/generated/e
         q-rebuild/generated/e)

(check-redundancy #t)

;; This is the selected state-local E strategy.  Support occurs in live and
;; returned states, and only its narrow summary survives in Dead and Done.
(define-core-representation-strategy core-e-representation-strategy
  #:variable
  [#:runtime-variable-production (variable-prefix u:)
   #:productions ()
   #:definitions
   ((define (fresh-us/generated/e support count
                                  [candidate 0]
                                  [reversed-intro '()])
      (match support
        [`(Support ,visible ...)
         (cond
           [(zero? count) (reverse reversed-intro)]
           [else
            (define u (string->symbol (format "u:~a" candidate)))
            (if (member u visible)
                (fresh-us/generated/e
                 support
                 count
                 (add1 candidate)
                 reversed-intro)
                (fresh-us/generated/e
                 `(Support ,@visible ,u)
                 (sub1 count)
                 (add1 candidate)
                 (cons u reversed-intro)))])]
        [_
         (error 'fresh-us/generated/e
                "expected Support, received ~e"
                support)]))
    (define-metafunction LANG
      fresh-intro/generated/e : supply d -> (rv ...)
      [(fresh-intro/generated/e supply (x ...))
       ,(fresh-us/generated/e
         (term supply)
         (length (term (x ...))))])
    (define-metafunction LANG
      extend-support/generated/e : supply (rv ...) -> supply
      [(extend-support/generated/e
        (Support rv_visible ...)
        (rv_new ...))
       (Support rv_visible ... rv_new ...)]))
   #:walk-hook generated-structural
   #:unify-hook generated-first-order
   #:invalid-hook generated-store-check
   #:lexical-substitution-hook generated-binder-local
   #:allocation
   [#:source
    (in-hole
     WorkFocus
     (Work
      (∃ (x_bound ...) g tag)
      (state supply sub dis trail tag_state)))
    #:target
    (in-hole
     WorkFocus
     (Work
      g_new
      (state supply_new sub dis trail tag_state)))
    #:premises
    ((where (rv_new ...)
            (fresh-intro/generated/e supply (x_bound ...)))
     (where supply_new
            (extend-support/generated/e supply (rv_new ...)))
     (where g_new
            ,(SUBST-GOAL-HOOK
              (term g)
              (term ((x_bound rv_new) ...)))))]
   #:addressing-hook address/generated/e]
  #:supply/provenance
  [#:productions ([supply (Support rv_!_ ...)])
   #:carriers
   [#:state (state supply sub dis trail tag)
    #:answer (Answer sigma)
    #:returned (Returned sigma)
    #:work (Work g sigma)
    #:dead (Dead supply)
    #:conj (Conj W g)
    #:last (Last A)
    #:done (Done supply)
    #:more (More W)]
   #:empty-supply (Support)
   #:conjunction-focus-supply supply
   #:branch-copy-supply supply
   #:join-return-supply supply_inner
   #:join-failure-supply supply_inner
   #:terminal-answer-supply supply
   #:live-supply-hook live-supply/generated/e
   #:failure-summary-hook failure-summary/generated/e
   #:definitions ()
   #:well-formedness
   [#:definitions
    ((define (runtime-us/generated/e term [acc '()])
       (match term
         ['() acc]
         [(? symbol? u)
          (if (regexp-match? #rx"^u:" (symbol->string u))
              (if (member u acc) acc (cons u acc))
              acc)]
         [(cons a d)
          (runtime-us/generated/e
           a
           (runtime-us/generated/e d acc))]
         [_ acc]))
     (define (sub-dependencies/generated/e u substitution)
       (match (assoc u substitution)
         [(list _ term)
          (define domain (map first substitution))
          (filter (lambda (dependency) (member dependency domain))
                  (runtime-us/generated/e term))]
         [#f '()]))
     (define (acyclic-from/generated/e u substitution [path '()])
       (and
        (not (member u path))
        (for/and ([dependency
                   (in-list
                    (sub-dependencies/generated/e u substitution))])
          (acyclic-from/generated/e
           dependency
           substitution
           (cons u path)))))
     (define (substitution-acyclic?/generated/e substitution)
       (for/and ([u (in-list (map first substitution))])
         (acyclic-from/generated/e u substitution)))
     (define (duplicate-free-support?/generated/e support)
       (match support
         [`(Support ,u ...)
          (= (length u) (length (remove-duplicates u)))]
         [_ #f]))
     (define-judgment-form
       LANG
       #:contract (allocated/generated/e? rv supply)
       #:mode (allocated/generated/e? I I)
       [-------------------------------------------------- "allocated named variable/e"
        (allocated/generated/e?
         rv
         (Support rv_before ... rv rv_after ...))])
     (define-judgment-form
       LANG
       #:contract (valid-supply/generated/e? supply)
       #:mode (valid-supply/generated/e? I)
       [(where #t
               ,(duplicate-free-support?/generated/e
                 (term supply)))
        -------------------------------------------------- "valid ordered support/e"
        (valid-supply/generated/e? supply)])
     (define-judgment-form
       LANG
       #:contract (extend-supply/generated/e supply supply supply)
       #:mode (extend-supply/generated/e I I O)
       [-------------------------------------------------- "state-local support/e"
        (extend-supply/generated/e
         supply_in
         supply_local
         supply_local)])
     (define-metafunction LANG
       acyclic-substitution/generated/e? : sub -> boolean
       [(acyclic-substitution/generated/e? sub)
        ,(substitution-acyclic?/generated/e (term sub))]))
    #:allocated-hook allocated/generated/e?
    #:valid-supply-hook valid-supply/generated/e?
    #:extend-supply-hook extend-supply/generated/e
    #:acyclic-substitution-hook acyclic-substitution/generated/e?
    #:state-supply-premises
    ((where supply_in supply_local))
    #:frame-prefix-premises
    ((where supply_frame supply_in))
    #:conjunction-goal-supply-premises
    ((LIVE-SUPPLY-HOOK W supply_frame supply_goal))
    #:terminal-prefix-premises
    ((where supply_prefix (Support)))
    #:root wf-core/generated/e?]
   #:q-map
   [#:definitions
    ((define (support-list/generated/e support)
       (match support
         [`(Support ,u ...)
          (unless (= (length u) (length (remove-duplicates u)))
            (error 'q-export/generated/e
                   "duplicate E support: ~e"
                   support))
          u]
         [_
          (error 'q-export/generated/e
                 "expected Support, received ~e"
                 support)]))
     (define (address/generated/e value _support) value)
     (define (state->q/generated/e state)
       (match state
         [`(state ,support ,sub ,dis ,trail ,state-tag)
          `(q-state
            ,(support-list/generated/e support)
            ,sub
            ,dis
            ,trail
            ,state-tag)]
         [_
          (error 'q-export/generated/e
                 "expected E state, received ~e"
                 state)]))
     (define (work->q/generated/e work)
       (match work
         [`(Work ,goal ,state)
          `(q-work #f ,goal ,(state->q/generated/e state))]
         [`(Returned ,state)
          `(q-returned #f ,(state->q/generated/e state))]
         [`(Dead ,support)
          `(q-dead #f ,(support-list/generated/e support))]
         [`(Conj ,inner ,goal)
          `(q-conj #f ,(work->q/generated/e inner) ,goal)]
         [_
          (error 'q-export/generated/e
                 "expected E work, received ~e"
                 work)]))
     (define (q-export/generated/e frontier)
       (match frontier
         [`(More ,work)
          `(q-more ,(work->q/generated/e work))]
         [`(Done ,support)
          `(q-done #f ,(support-list/generated/e support))]
         [`(Last (Answer ,state))
          `(q-last #f (q-answer #f ,(state->q/generated/e state)))]
         [_
          (error 'q-export/generated/e
                 "expected E frontier, received ~e"
                 frontier)]))
     (define (q-state->e/generated/e q-state)
       (match q-state
         [`(q-state ,support ,sub ,dis ,trail ,state-tag)
          `(state (Support ,@support) ,sub ,dis ,trail ,state-tag)]
         [_
          (error 'q-rebuild/generated/e
                 "expected neutral state, received ~e"
                 q-state)]))
     (define (q-work->e/generated/e q-work)
       (match q-work
         [`(q-work ,_ ,goal ,q-state)
          `(Work ,goal ,(q-state->e/generated/e q-state))]
         [`(q-returned ,_ ,q-state)
          `(Returned ,(q-state->e/generated/e q-state))]
         [`(q-dead ,_ ,support)
          `(Dead (Support ,@support))]
         [`(q-conj ,_ ,inner ,goal)
          `(Conj ,(q-work->e/generated/e inner) ,goal)]
         [_
          (error 'q-rebuild/generated/e
                 "expected neutral work, received ~e"
                 q-work)]))
     (define (q-rebuild/generated/e neutral)
       (match neutral
         [`(q-more ,q-work)
          `(More ,(q-work->e/generated/e q-work))]
         [`(q-done ,_ ,support)
          `(Done (Support ,@support))]
         [`(q-last ,_ (q-answer ,_ ,q-state))
          `(Last (Answer ,(q-state->e/generated/e q-state)))]
         [_
          (error 'q-rebuild/generated/e
                 "expected neutral core frontier, received ~e"
                 neutral)])))
    #:export q-export/generated/e
    #:rebuild q-rebuild/generated/e]])

(define-generated-core-source
  #:strategy core-e-representation-strategy
  #:language generated-core-e-lang
  #:relation generated-core-e-red
  #:raw-successors raw-successors/generated/e
  #:branch-copy branch-copy/generated/e)
