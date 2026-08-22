#lang racket

(require redex/reduction-semantics
         "../../../framework/core-source-schema.rkt")

(provide core-n-representation-strategy
         generated-core-n-lang
         generated-core-n-red
         raw-successors/generated/n
         branch-copy/generated/n
         wf-core/generated/n?
         live-supply/generated/n
         failure-summary/generated/n
         address/generated/n
         q-export/generated/n
         q-rebuild/generated/n
         q-focus-export/generated/n
         q-focus-rebuild/generated/n
         q-root-focus-export/generated/n
         q-root-focus-rebuild/generated/n
         q-failure-focus-export/generated/n
         q-failure-focus-rebuild/generated/n
         q-terminal-export/generated/n
         q-terminal-rebuild/generated/n
         generated-core-n-source)

(check-redundancy #t)

;; This is the selected numeric strategy.  A live or returned state owns its
;; next allocation level; Dead and Done retain only that level.
(define-core-representation-strategy core-n-representation-strategy
  #:variable
  [#:runtime-variable-production natural
   #:productions ()
   #:definitions
   ((define-metafunction LANG
      allocate-interval/generated/n : supply d -> (rv ...)
      [(allocate-interval/generated/n supply (x ...))
       ,(build-list (length (term (x ...)))
                    (lambda (offset) (+ (term supply) offset)))])
    (define-metafunction LANG
      advance-next/generated/n : supply d -> supply
      [(advance-next/generated/n supply (x ...))
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
            (allocate-interval/generated/n supply (x_bound ...)))
     (where supply_new
            (advance-next/generated/n supply (x_bound ...)))
     (where g_new
            ,(SUBST-GOAL-HOOK
              (term g)
              (term ((x_bound rv_new) ...)))))]
   #:addressing-hook address/generated/n]
  #:supply/provenance
  [#:productions ([supply natural])
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
   #:empty-supply 0
   #:conjunction-focus-supply supply
   #:branch-copy-supply supply
   #:join-return-supply supply_inner
   #:join-failure-supply supply_inner
   #:terminal-answer-supply supply
   #:live-supply-hook live-supply/generated/n
   #:failure-summary-hook failure-summary/generated/n
   #:definitions ()
   #:well-formedness
   [#:definitions
    ((define (runtime-levels/generated/n term [acc '()])
     (match term
         ['() acc]
         [`(nat ,_) acc]
         [`(sym ,_) acc]
         [`(str ,_) acc]
         [(? exact-nonnegative-integer? level)
          (if (member level acc) acc (cons level acc))]
         [(cons a d)
          (runtime-levels/generated/n
           a
           (runtime-levels/generated/n d acc))]
         [_ acc]))
     (define (sub-dependencies/generated/n level substitution)
       (match (assoc level substitution)
         [(list _ term)
          (define domain (map first substitution))
          (filter (lambda (dependency) (member dependency domain))
                  (runtime-levels/generated/n term))]
         [#f '()]))
     (define (acyclic-from/generated/n level substitution [path '()])
       (and
        (not (member level path))
        (for/and ([dependency
                   (in-list
                    (sub-dependencies/generated/n level substitution))])
          (acyclic-from/generated/n
           dependency
           substitution
           (cons level path)))))
     (define (substitution-acyclic?/generated/n substitution)
       (for/and ([level (in-list (map first substitution))])
         (acyclic-from/generated/n level substitution)))
     (define-judgment-form
       LANG
       #:contract (allocated/generated/n? rv supply)
       #:mode (allocated/generated/n? I I)
       [(where #t ,(< (term rv) (term supply)))
        -------------------------------------------------- "allocated level/n"
        (allocated/generated/n? rv supply)])
     (define-judgment-form
       LANG
       #:contract (valid-supply/generated/n? supply)
       #:mode (valid-supply/generated/n? I)
       [-------------------------------------------------- "valid next level/n"
        (valid-supply/generated/n? supply)])
     (define-judgment-form
       LANG
       #:contract (extend-supply/generated/n supply supply supply)
       #:mode (extend-supply/generated/n I I O)
       [-------------------------------------------------- "state-local next/n"
        (extend-supply/generated/n
         supply_in
         supply_local
         supply_local)])
     (define-metafunction LANG
       acyclic-substitution/generated/n? : sub -> boolean
       [(acyclic-substitution/generated/n? sub)
        ,(substitution-acyclic?/generated/n (term sub))]))
    #:allocated-hook allocated/generated/n?
    #:valid-supply-hook valid-supply/generated/n?
    #:extend-supply-hook extend-supply/generated/n
    #:acyclic-substitution-hook acyclic-substitution/generated/n?
    #:state-supply-premises
    ((where supply_in supply_local))
    #:frame-prefix-premises
    ((where supply_frame supply_in))
    #:conjunction-goal-supply-premises
    ((LIVE-SUPPLY-HOOK W supply_frame supply_goal))
    #:terminal-prefix-premises
    ((where supply_prefix 0))
    #:root wf-core/generated/n?]
   #:q-map
   [#:definitions
    ((define (u-symbol?/generated/n datum)
       (and (symbol? datum)
            (regexp-match? #rx"^u:" (symbol->string datum))))
     (define (duplicate-free?/generated/n values)
       (= (length values) (length (remove-duplicates values))))
     (define (validate-q-support/generated/n support)
       (unless (duplicate-free?/generated/n support)
         (error 'q-rebuild/generated/n
                "duplicate neutral support: ~e"
                support))
       support)
     (define (address-runtime/generated/n runtime-variable support)
       (validate-q-support/generated/n support)
       (cond
         [(u-symbol?/generated/n runtime-variable)
          (match (index-of support runtime-variable)
            [#f
             (error 'q-rebuild/generated/n
                    "runtime atom ~e is absent from support ~e"
                    runtime-variable
                    support)]
            [index index])]
         [(exact-nonnegative-integer? runtime-variable)
          (if (< runtime-variable (length support))
              runtime-variable
              (error 'q-rebuild/generated/n
                     "runtime level ~e is outside support ~e"
                     runtime-variable
                     support))]
         [else
          (error 'q-rebuild/generated/n
                 "expected a runtime variable, received ~e"
                 runtime-variable)]))
     (define (address-term/generated/n term support)
       (match term
         [(? u-symbol?/generated/n runtime-variable)
          (address-runtime/generated/n runtime-variable support)]
         [(? exact-nonnegative-integer? runtime-variable)
          (address-runtime/generated/n runtime-variable support)]
         [`(,left : ,right)
          `(,(address-term/generated/n left support)
            :
            ,(address-term/generated/n right support))]
         [_ term]))
     (define (address-goal/generated/n goal support)
       (match goal
         [`(succeed ,goal-tag) `(succeed ,goal-tag)]
         [`(fail ,goal-tag) `(fail ,goal-tag)]
         [`(,left =? ,right ,goal-tag)
          `(,(address-term/generated/n left support)
            =?
            ,(address-term/generated/n right support)
            ,goal-tag)]
         [`(,left != ,right ,goal-tag)
          `(,(address-term/generated/n left support)
            !=
            ,(address-term/generated/n right support)
            ,goal-tag)]
         [`(,left ∧ ,right ,goal-tag)
          `(,(address-goal/generated/n left support)
            ∧
            ,(address-goal/generated/n right support)
            ,goal-tag)]
         [`(∃ ,binders ,body ,goal-tag)
          `(∃ ,binders
              ,(address-goal/generated/n body support)
              ,goal-tag)]
         [_
          (error 'q-rebuild/generated/n
                 "expected a core goal, received ~e"
                 goal)]))
     (define (address-substitution/generated/n substitution support)
       (for/list ([binding (in-list substitution)])
         (match binding
           [(list runtime-variable term)
            (list
             (address-runtime/generated/n runtime-variable support)
             (address-term/generated/n term support))])))
     (define (address-disequalities/generated/n disequalities support)
       (for/list ([disequality (in-list disequalities)])
         (match disequality
           [(list left right)
            (list
             (address-term/generated/n left support)
             (address-term/generated/n right support))])))
     (define (address-equation/generated/n equation support)
       (match equation
         [`(,left =? ,right ,equation-tag)
          `(,(address-term/generated/n left support)
            =?
            ,(address-term/generated/n right support)
            ,equation-tag)]))
     (define (address/generated/n value support)
       (address-term/generated/n value support))
     (define (state->q/generated/n state)
       (match state
         [`(state ,next ,sub ,dis ,trail ,state-tag)
          `(q-state
            ,(build-list next values)
            ,sub
            ,dis
            ,trail
            ,state-tag)]
         [_
          (error 'q-export/generated/n
                 "expected N state, received ~e"
                 state)]))
     (define (work->q/generated/n work)
       (match work
         [`(Work ,goal ,state)
          `(q-work #f ,goal ,(state->q/generated/n state))]
         [`(Returned ,state)
          `(q-returned #f ,(state->q/generated/n state))]
         [`(Dead ,next)
          `(q-dead #f ,(build-list next values))]
         [`(Conj ,inner ,goal)
          `(q-conj #f ,(work->q/generated/n inner) ,goal)]
         [_
          (error 'q-export/generated/n
                 "expected N work, received ~e"
                 work)]))
     (define (q-export/generated/n frontier)
       (match frontier
         [`(More ,work)
          `(q-more ,(work->q/generated/n work))]
         [`(Done ,next)
          `(q-done #f ,(build-list next values))]
         [`(Last (Answer ,state))
          `(q-last #f (q-answer #f ,(state->q/generated/n state)))]
         [_
          (error 'q-export/generated/n
                 "expected N frontier, received ~e"
                 frontier)]))
     (define (q-state-support/generated/n q-state)
       (match q-state
         [`(q-state ,support ,_sub ,_dis ,_trail ,_state-tag)
          (validate-q-support/generated/n support)]
         [_
          (error 'q-rebuild/generated/n
                 "expected neutral state, received ~e"
                 q-state)]))
     (define (q-work-support/generated/n q-work)
       (match q-work
         [`(q-work ,_ ,_ ,q-state)
          (q-state-support/generated/n q-state)]
         [`(q-returned ,_ ,q-state)
          (q-state-support/generated/n q-state)]
         [`(q-dead ,_ ,support)
          (validate-q-support/generated/n support)]
         [`(q-conj ,_ ,inner ,_)
          (q-work-support/generated/n inner)]
         [_
          (error 'q-rebuild/generated/n
                 "expected neutral work, received ~e"
                 q-work)]))
     (define (q-state->n/generated/n q-state support)
       (match q-state
         [`(q-state ,state-support ,sub ,dis ,trail ,state-tag)
          (unless (equal? state-support support)
            (error 'q-rebuild/generated/n
                   "state support ~e disagrees with world support ~e"
                   state-support
                   support))
          `(state
            ,(length support)
            ,(address-substitution/generated/n sub support)
            ,(address-disequalities/generated/n dis support)
            ,(for/list ([equation (in-list trail)])
               (address-equation/generated/n equation support))
            ,state-tag)]))
     (define (q-work->n/generated/n q-work support)
       (match q-work
         [`(q-work ,_ ,goal ,q-state)
          `(Work
            ,(address-goal/generated/n goal support)
            ,(q-state->n/generated/n q-state support))]
         [`(q-returned ,_ ,q-state)
          `(Returned ,(q-state->n/generated/n q-state support))]
         [`(q-dead ,_ ,dead-support)
          (unless (equal? dead-support support)
            (error 'q-rebuild/generated/n
                   "Dead support ~e disagrees with world support ~e"
                   dead-support
                   support))
          `(Dead ,(length support))]
         [`(q-conj ,_ ,inner ,goal)
          `(Conj
            ,(q-work->n/generated/n inner support)
            ,(address-goal/generated/n goal support))]
         [_
          (error 'q-rebuild/generated/n
                 "expected neutral work, received ~e"
                 q-work)]))
     (define (q-rebuild/generated/n neutral)
       (match neutral
         [`(q-more ,q-work)
          (define support (q-work-support/generated/n q-work))
          `(More ,(q-work->n/generated/n q-work support))]
         [`(q-done ,_ ,support)
          (validate-q-support/generated/n support)
          `(Done ,(length support))]
         [`(q-last ,_ (q-answer ,_ ,q-state))
          (define support (q-state-support/generated/n q-state))
          `(Last (Answer ,(q-state->n/generated/n q-state support)))]
         [_
          (error 'q-rebuild/generated/n
                 "expected neutral core frontier, received ~e"
                 neutral)]))
     (define (focus-path->q/generated/n path)
       (match path
         [(? (lambda (datum) (equal? datum (term hole))))
          'q-focus-hole]
         [`(Conj ,inner ,goal)
          `(q-focus-conj
            #f
            ,(focus-path->q/generated/n inner)
            ,goal)]
         [_
          (error 'q-focus-export/generated/n
                 "expected an N WorkPath, received ~e"
                 path)]))
     (define (q-focus-export/generated/n focused focus)
       (match focus
         [`(More ,path)
          `(q-focused
            ,(work->q/generated/n focused)
            (q-work-focus ,(focus-path->q/generated/n path)))]
         [_
          (error 'q-focus-export/generated/n
                 "expected an N WorkFocus, received ~e"
                 focus)]))
     (define (q-focus-path->n/generated/n q-path support)
       (match q-path
         ['q-focus-hole (term hole)]
         [`(q-focus-conj ,_ ,q-inner ,goal)
          `(Conj
            ,(q-focus-path->n/generated/n q-inner support)
            ,(address-goal/generated/n goal support))]
         [_
          (error 'q-focus-rebuild/generated/n
                 "expected a neutral WorkPath, received ~e"
                 q-path)]))
     (define (q-focus-rebuild/generated/n neutral)
       (match neutral
         [`(q-focused ,q-work (q-work-focus ,q-path))
          (define support (q-work-support/generated/n q-work))
          (list
           (q-work->n/generated/n q-work support)
           `(More
             ,(q-focus-path->n/generated/n q-path support)))]
         [_
          (error 'q-focus-rebuild/generated/n
                 "expected a neutral focused pair, received ~e"
                 neutral)]))
     (define (q-root-focus-export/generated/n frontier spine)
       (unless (equal? spine (term hole))
         (error 'q-root-focus-export/generated/n
                "expected the N root spine, received ~e"
                spine))
       (match frontier
         [`(More ,work)
          `(q-root-focused ,(work->q/generated/n work))]
         [other
          (error 'q-root-focus-export/generated/n
                 "expected an N root frontier, received ~e"
                 other)]))
     (define (q-root-focus-rebuild/generated/n neutral)
       (match neutral
         [`(q-root-focused ,q-work)
          (define support (q-work-support/generated/n q-work))
          (list
           `(More ,(q-work->n/generated/n q-work support))
           (term hole))]
         [other
          (error 'q-root-focus-rebuild/generated/n
                 "expected a neutral root focus, received ~e"
                 other)]))
     (define (q-failure-focus-export/generated/n summary focus)
       (match focus
         [`(More ,path)
          `(q-failure-focused
            #f
            ,(build-list summary values)
            (q-work-focus ,(focus-path->q/generated/n path)))]
         [other
          (error 'q-failure-focus-export/generated/n
                 "expected an N WorkFocus, received ~e"
                 other)]))
     (define (q-failure-focus-rebuild/generated/n neutral)
       (match neutral
         [`(q-failure-focused ,_provenance ,support (q-work-focus ,q-path))
          (validate-q-support/generated/n support)
          (list
           (length support)
           `(More
             ,(q-focus-path->n/generated/n q-path support)))]
         [other
          (error 'q-failure-focus-rebuild/generated/n
                 "expected a neutral failure focus, received ~e"
                 other)]))
     (define (q-terminal-export/generated/n terminal)
       (match terminal
         [`(Done ,next)
          `(q-done #f ,(build-list next values))]
         [`(Last (Answer ,state))
          `(q-last #f (q-answer #f ,(state->q/generated/n state)))]
         [other
          (error 'q-terminal-export/generated/n
                 "expected an N terminal, received ~e"
                 other)]))
     (define (q-terminal-rebuild/generated/n neutral)
       (match neutral
         [`(q-done ,_provenance ,support)
          (validate-q-support/generated/n support)
          `(Done ,(length support))]
         [`(q-last ,_provenance (q-answer ,_answer-provenance ,q-state))
          (define support (q-state-support/generated/n q-state))
          `(Last (Answer ,(q-state->n/generated/n q-state support)))]
         [other
          (error 'q-terminal-rebuild/generated/n
                 "expected a neutral terminal, received ~e"
                 other)])))
    #:export q-export/generated/n
    #:rebuild q-rebuild/generated/n
    #:focus-export q-focus-export/generated/n
    #:focus-rebuild q-focus-rebuild/generated/n
    #:root-focus-export q-root-focus-export/generated/n
    #:root-focus-rebuild q-root-focus-rebuild/generated/n
    #:failure-focus-export q-failure-focus-export/generated/n
    #:failure-focus-rebuild q-failure-focus-rebuild/generated/n
    #:terminal-export q-terminal-export/generated/n
    #:terminal-rebuild q-terminal-rebuild/generated/n]])

(define-generated-core-source
  #:strategy core-n-representation-strategy
  #:language generated-core-n-lang
  #:relation generated-core-n-red
  #:raw-successors raw-successors/generated/n
  #:branch-copy branch-copy/generated/n
  #:source-interface generated-core-n-source)
