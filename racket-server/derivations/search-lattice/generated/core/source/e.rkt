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
         transfer-work-prefix/open/generated/e
         transfer-work-prefix/generated/e
         q-export-local-prefix/generated/e
         q-rebuild-local-prefix/generated/e
         q-work-export/open/generated/e
         q-work-support/open/generated/e
         q-work-rebuild/open/generated/e
         q-frontier-export/open/generated/e
         q-frontier-support/open/generated/e
         q-frontier-rebuild/open/generated/e
         q-path-export/open/generated/e
         q-path-rebuild/open/generated/e
         q-failure-export/generated/e
         q-failure-rebuild/generated/e
         q-address-goal/open/generated/e
         q-export/generated/e
         q-rebuild/generated/e
         q-focus-export/generated/e
         q-focus-rebuild/generated/e
         q-root-focus-export/generated/e
         q-root-focus-rebuild/generated/e
         q-failure-focus-export/generated/e
         q-failure-focus-rebuild/generated/e
         q-terminal-export/generated/e
         q-terminal-rebuild/generated/e
         generated-core-e-source)

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
            (SUBST-GOAL-HOOK g ((x_bound rv_new) ...))))]
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
   #:extension-prefix
   [#:transfer-work-open transfer-work-prefix/open/generated/e
    #:transfer-work transfer-work-prefix/generated/e
    #:Q-export-local q-export-local-prefix/generated/e
    #:Q-rebuild-local q-rebuild-local-prefix/generated/e]
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
    ((where supply_prefix supply_in))
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
     (define (q-address-goal/open/generated/e _recur goal _support)
       goal)
     (define (transfer-work-prefix/open/generated/e
              _prefix work _extension)
       work)
     (define (transfer-work-prefix/generated/e _prefix work)
       work)
     (define (q-export-local-prefix/generated/e _local accumulated)
       (list #f accumulated))
     (define (q-rebuild-local-prefix/generated/e _provenance)
       '(Support))
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
     (define (q-work-export/open/generated/e work support recur)
       (match work
         [`(Work ,goal ,state)
          `(q-work #f ,goal ,(state->q/generated/e state))]
         [`(Returned ,state)
          `(q-returned #f ,(state->q/generated/e state))]
         [`(Dead ,support)
          `(q-dead #f ,(support-list/generated/e support))]
         [`(Conj ,inner ,goal)
          `(q-conj #f ,(recur inner support) ,goal)]
         [_
          (error 'q-export/generated/e
                 "expected E work, received ~e"
                 work)]))
     (define (work->q/generated/e work [support '()])
       (q-work-export/open/generated/e work support work->q/generated/e))
     (define (q-work-support/open/generated/e q-work recur)
       (match q-work
         [`(q-work ,_ ,_ (q-state ,support ,_ ,_ ,_ ,_)) support]
         [`(q-returned ,_ (q-state ,support ,_ ,_ ,_ ,_)) support]
         [`(q-dead ,_ ,support) support]
         [`(q-conj ,_ ,inner ,_) (recur inner)]
         [_
          (error 'q-work-support/open/generated/e
                 "expected neutral work, received ~e"
                 q-work)]))
     (define (q-work-support/generated/e q-work)
       (q-work-support/open/generated/e
        q-work
        q-work-support/generated/e))
     (define (q-frontier-export/open/generated/e
              frontier prefix recur-work)
       (match frontier
         [`(More ,work)
          `(q-more ,(recur-work work prefix))]
         [`(Done ,support)
          `(q-done #f ,(support-list/generated/e support))]
         [`(Last (Answer ,state))
          `(q-last #f (q-answer #f ,(state->q/generated/e state)))]
         [_
          (error 'q-export/generated/e
                 "expected E frontier, received ~e"
                 frontier)]))
     (define (q-export/generated/e frontier)
       (q-frontier-export/open/generated/e
        frontier
        '()
        work->q/generated/e))
     (define (q-frontier-support/open/generated/e neutral recur-work)
       (match neutral
         [`(q-more ,q-work) (recur-work q-work)]
         [`(q-done ,_ ,support) support]
         [`(q-last ,_ (q-answer ,_ (q-state ,support ,_ ,_ ,_ ,_)))
          support]
         [_
          (error 'q-frontier-support/open/generated/e
                 "expected neutral frontier, received ~e"
                 neutral)]))
     (define (q-frontier-support/generated/e neutral)
       (q-frontier-support/open/generated/e
        neutral
        q-work-support/generated/e))
     (define (q-state->e/generated/e q-state)
       (match q-state
         [`(q-state ,support ,sub ,dis ,trail ,state-tag)
          `(state (Support ,@support) ,sub ,dis ,trail ,state-tag)]
         [_
          (error 'q-rebuild/generated/e
                 "expected neutral state, received ~e"
                 q-state)]))
     (define (q-work-rebuild/open/generated/e
              q-work support recur map-goal)
       (match q-work
         [`(q-work ,_ ,goal ,q-state)
          `(Work
            ,(map-goal goal support)
            ,(q-state->e/generated/e q-state))]
         [`(q-returned ,_ ,q-state)
          `(Returned ,(q-state->e/generated/e q-state))]
         [`(q-dead ,_ ,support)
          `(Dead (Support ,@support))]
         [`(q-conj ,_ ,inner ,goal)
          `(Conj
            ,(recur inner support)
            ,(map-goal goal support))]
         [_
          (error 'q-rebuild/generated/e
                 "expected neutral work, received ~e"
                 q-work)]))
     (define (q-work->e/generated/e
              q-work
              [support (q-work-support/generated/e q-work)])
       (q-work-rebuild/open/generated/e
        q-work
        support
        q-work->e/generated/e
        (lambda (goal _support) goal)))
     (define (q-frontier-rebuild/open/generated/e
              neutral support recur-work)
       (match neutral
         [`(q-more ,q-work)
          `(More ,(recur-work q-work support))]
         [`(q-done ,_ ,support)
          `(Done (Support ,@support))]
         [`(q-last ,_ (q-answer ,_ ,q-state))
          `(Last (Answer ,(q-state->e/generated/e q-state)))]
         [_
          (error 'q-rebuild/generated/e
                 "expected neutral core frontier, received ~e"
                 neutral)]))
     (define (q-rebuild/generated/e neutral)
       (q-frontier-rebuild/open/generated/e
        neutral
        (q-frontier-support/generated/e neutral)
        q-work->e/generated/e))
     (define (q-path-export/open/generated/e path support recur)
       (match path
         [(? (lambda (datum) (equal? datum (term hole))))
          (values 'q-focus-hole support)]
         [`(Conj ,inner ,goal)
          (define-values (q-inner support-at-hole)
            (recur inner support))
          (values
           `(q-focus-conj #f ,q-inner ,goal)
           support-at-hole)]
         [_
          (error 'q-focus-export/generated/e
                 "expected an E WorkPath, received ~e"
                 path)]))
     (define (focus-path->q/generated/e path [support '()])
       (q-path-export/open/generated/e
        path
        support
        focus-path->q/generated/e))
     (define (q-focus-export/generated/e focused focus)
       (match focus
         [`(More ,path)
          (define-values (q-path support-at-hole)
            (focus-path->q/generated/e path))
          `(q-focused
            ,(work->q/generated/e focused support-at-hole)
            (q-work-focus ,q-path))]
         [_
          (error 'q-focus-export/generated/e
                 "expected an E WorkFocus, received ~e"
                 focus)]))
     (define (q-path-rebuild/open/generated/e
              q-path support recur map-goal)
       (match q-path
         ['q-focus-hole (term hole)]
         [`(q-focus-conj ,_ ,q-inner ,goal)
          `(Conj
            ,(recur q-inner support)
            ,(map-goal goal support))]
         [_
          (error 'q-focus-rebuild/generated/e
                 "expected a neutral WorkPath, received ~e"
                 q-path)]))
     (define (q-focus-path->e/generated/e q-path [support '()])
       (q-path-rebuild/open/generated/e
        q-path
        support
        q-focus-path->e/generated/e
        (lambda (goal _support) goal)))
     (define (q-focus-rebuild/generated/e neutral)
       (match neutral
         [`(q-focused ,q-work (q-work-focus ,q-path))
          (define support (q-work-support/generated/e q-work))
          (list
           (q-work->e/generated/e q-work support)
           `(More ,(q-focus-path->e/generated/e q-path support)))]
         [_
          (error 'q-focus-rebuild/generated/e
                 "expected a neutral focused pair, received ~e"
                 neutral)]))
     (define (q-root-focus-export/generated/e frontier spine)
       (unless (equal? spine (term hole))
         (error 'q-root-focus-export/generated/e
                "expected the E root spine, received ~e"
                spine))
       (match frontier
         [`(More ,work)
          `(q-root-focused ,(work->q/generated/e work))]
         [other
          (error 'q-root-focus-export/generated/e
                 "expected an E root frontier, received ~e"
                 other)]))
     (define (q-root-focus-rebuild/generated/e neutral)
       (match neutral
         [`(q-root-focused ,q-work)
          (define support (q-work-support/generated/e q-work))
          (list `(More ,(q-work->e/generated/e q-work support))
                (term hole))]
         [other
          (error 'q-root-focus-rebuild/generated/e
                 "expected a neutral root focus, received ~e"
                 other)]))
     (define (q-failure-export/generated/e summary _prefix)
       (list #f (support-list/generated/e summary)))
     (define (q-failure-rebuild/generated/e _provenance support)
       `(Support ,@support))
     (define (q-failure-focus-export/generated/e summary focus)
       (match focus
         [`(More ,path)
          (define-values (q-path support-at-hole)
            (focus-path->q/generated/e path))
          (match-define (list provenance support)
            (q-failure-export/generated/e summary support-at-hole))
          `(q-failure-focused
            ,provenance
            ,support
            (q-work-focus ,q-path))]
         [other
          (error 'q-failure-focus-export/generated/e
                 "expected an E WorkFocus, received ~e"
                 other)]))
     (define (q-failure-focus-rebuild/generated/e neutral)
       (match neutral
         [`(q-failure-focused ,provenance ,support (q-work-focus ,q-path))
          (list
           (q-failure-rebuild/generated/e provenance support)
           `(More ,(q-focus-path->e/generated/e q-path support)))]
         [other
          (error 'q-failure-focus-rebuild/generated/e
                 "expected a neutral failure focus, received ~e"
                 other)]))
     (define (q-terminal-export/generated/e terminal)
       (q-frontier-export/open/generated/e
        terminal
        '()
        work->q/generated/e))
     (define (q-terminal-rebuild/generated/e neutral)
       (q-frontier-rebuild/open/generated/e
        neutral
        (q-frontier-support/generated/e neutral)
        q-work->e/generated/e)))
    #:open
    [#:work-export q-work-export/open/generated/e
     #:work-support q-work-support/open/generated/e
     #:work-rebuild q-work-rebuild/open/generated/e
     #:frontier-export q-frontier-export/open/generated/e
     #:frontier-support q-frontier-support/open/generated/e
     #:frontier-rebuild q-frontier-rebuild/open/generated/e
     #:path-export q-path-export/open/generated/e
     #:path-rebuild q-path-rebuild/open/generated/e
     #:failure-export q-failure-export/generated/e
     #:failure-rebuild q-failure-rebuild/generated/e
     #:address-goal q-address-goal/open/generated/e]
    #:export q-export/generated/e
    #:rebuild q-rebuild/generated/e
    #:focus-export q-focus-export/generated/e
    #:focus-rebuild q-focus-rebuild/generated/e
    #:root-focus-export q-root-focus-export/generated/e
    #:root-focus-rebuild q-root-focus-rebuild/generated/e
    #:failure-focus-export q-failure-focus-export/generated/e
    #:failure-focus-rebuild q-failure-focus-rebuild/generated/e
    #:terminal-export q-terminal-export/generated/e
    #:terminal-rebuild q-terminal-rebuild/generated/e]])

(define-generated-core-source
  #:strategy core-e-representation-strategy
  #:language generated-core-e-lang
  #:relation generated-core-e-red
  #:raw-successors raw-successors/generated/e
  #:branch-copy branch-copy/generated/e
  #:source-interface generated-core-e-source)
