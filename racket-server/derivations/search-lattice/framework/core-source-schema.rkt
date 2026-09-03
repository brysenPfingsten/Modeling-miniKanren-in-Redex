#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: redex/parameter)
         (for-syntax racket/base
                     racket/list
                     racket/match
                     racket/syntax
                     syntax/parse))

(provide define-core-representation-strategy
         define-generated-core-source
         define-generated-core-representation-maps
         (for-syntax render-selected-live-supply-driver))

;; A representation strategy is syntax, not a runtime value.  Keeping the
;; declaration at expansion time lets an instance emit ordinary, statically
;; named Redex artifacts without a compiled-language registry or grammar
;; introspection.
(begin-for-syntax
  ;; Live-supply traversal is a fixed-point scaffold over an extensible
  ;; one-layer case judgment.  Rendering the same scaffold in each exact
  ;; feature language keeps recursive descent in that language; descendants
  ;; extend only the case artifact and never copy a semantic clause.
  (define (render-selected-live-supply-driver
           language relation case-relation)
    (with-syntax ([language language]
                  [relation relation]
                  [case-relation case-relation])
      #'(redex-parameter:define-judgment-form*
          language
          #:parameters ([live-next case-relation])
          #:mode (relation I I O)
          #:contract (relation W supply supply)
          [(live-next W_0 supply_in (LiveDone supply_out))
           ----
           (relation W_0 supply_in supply_out)]
          [(live-next W_0 supply_in (LiveContinue W_1 supply_next))
           (relation W_1 supply_next supply_out)
           ----
           (relation W_0 supply_in supply_out)])))

  (struct strategy-binding (declaration)
    #:property prop:procedure
    (lambda (_self use-stx)
      (raise-syntax-error
       #f
       "a core representation strategy is valid only after #:strategy"
       use-stx)))

  ;; A generated source publishes the exact compile-time description consumed
  ;; by horizontal staging.  The binding is deliberately active only through
  ;; the two private protocol messages below; treating it as a runtime value
  ;; would reintroduce the registry/introspection architecture this framework
  ;; is designed to avoid.
  (struct source-interface-binding
    (selected-view
     language
     redex-parameters
     branch-copy
     work-raw frontier-raw allocation-raw
     subst-goal subst-goal-open
     wf-root wf-goal wf-answer wf-returned
     live-supply failure-summary wf-work wf-frontier
     wf-goal-case wf-goal-tasks live-supply-case wf-node-case wf-nodes
     state-template answer-template returned-template
     work-template dead-template conj-template last-template more-template
     work-focus-prefix
     work-focus-prefix-open
     prefix-empty q-prefix-empty prefix-extend-premises
     transfer-work-host transfer-work-open
     q-export-local q-rebuild-local
     q-work-export-open q-work-support-open q-work-rebuild-open
     q-frontier-export-open q-frontier-support-open q-frontier-rebuild-open
     q-path-export-open q-path-rebuild-open
     q-failure-export q-failure-rebuild q-address-goal-open
     q-export q-rebuild
     focus-export focus-rebuild
     root-focus-export root-focus-rebuild
     failure-focus-export failure-focus-rebuild
     terminal-export terminal-rebuild)
    #:property prop:procedure
    (lambda (self use-stx)
      (syntax-parse use-stx
        [(_ #:instantiate-with renderer:id #:instance instance:id)
         (syntax-parse (source-interface-binding-selected-view self)
           [(_template-name:id _placeholder:id . tail)
            #`(renderer instance . tail)])]
        [(_ #:visit visitor:id argument ...)
         #`(visitor
            #:language #,(source-interface-binding-language self)
            #:Q-export #,(source-interface-binding-q-export self)
            #:Q-rebuild #,(source-interface-binding-q-rebuild self)
            #:Q-focus-export #,(source-interface-binding-focus-export self)
            #:Q-focus-rebuild #,(source-interface-binding-focus-rebuild self)
            #:Q-root-focus-export
            #,(source-interface-binding-root-focus-export self)
            #:Q-root-focus-rebuild
            #,(source-interface-binding-root-focus-rebuild self)
            #:Q-failure-focus-export
            #,(source-interface-binding-failure-focus-export self)
            #:Q-failure-focus-rebuild
            #,(source-interface-binding-failure-focus-rebuild self)
            #:Q-terminal-export
            #,(source-interface-binding-terminal-export self)
            #:Q-terminal-rebuild
            #,(source-interface-binding-terminal-rebuild self)
            argument ...)]
        [(_ #:visit-extension visitor:id argument ...)
         (unless
             (and (source-interface-binding-q-work-export-open self)
                  (syntax-e
                   (source-interface-binding-q-work-export-open self)))
           (raise-syntax-error
            #f
            "this source strategy does not declare the extension visitor hooks"
            use-stx))
         #`(visitor
            #:language #,(source-interface-binding-language self)
            #:redex-parameters
            #,(source-interface-binding-redex-parameters self)
            #:branch-copy #,(source-interface-binding-branch-copy self)
            #:R-work-raw #,(source-interface-binding-work-raw self)
            #:R-frontier-raw #,(source-interface-binding-frontier-raw self)
            #:R-allocation-raw #,(source-interface-binding-allocation-raw self)
            #:subst-goal #,(source-interface-binding-subst-goal self)
            #:subst-goal-open #,(source-interface-binding-subst-goal-open self)
            #:wf-root #,(source-interface-binding-wf-root self)
            #:wf-goal #,(source-interface-binding-wf-goal self)
            #:wf-answer #,(source-interface-binding-wf-answer self)
            #:wf-returned #,(source-interface-binding-wf-returned self)
            #:live-supply #,(source-interface-binding-live-supply self)
            #:failure-summary
            #,(source-interface-binding-failure-summary self)
            #:wf-work #,(source-interface-binding-wf-work self)
            #:wf-frontier #,(source-interface-binding-wf-frontier self)
            #:WF-open
            [#:goal-case #,(source-interface-binding-wf-goal-case self)
             #:goal-tasks #,(source-interface-binding-wf-goal-tasks self)
             #:live-case #,(source-interface-binding-live-supply-case self)
             #:node-case #,(source-interface-binding-wf-node-case self)
             #:nodes #,(source-interface-binding-wf-nodes self)]
            #:carrier-view
            [#:state #,(source-interface-binding-state-template self)
             #:answer #,(source-interface-binding-answer-template self)
             #:returned #,(source-interface-binding-returned-template self)
             #:work #,(source-interface-binding-work-template self)
             #:dead #,(source-interface-binding-dead-template self)
             #:conj #,(source-interface-binding-conj-template self)
             #:last #,(source-interface-binding-last-template self)
             #:more #,(source-interface-binding-more-template self)
             #:empty-supply #,(source-interface-binding-prefix-empty self)]
            #:prefix-view
            [#:extend-premises
             (#,@(syntax->list
                  (source-interface-binding-prefix-extend-premises self)))
             #:Q-empty
             #,(source-interface-binding-q-prefix-empty self)
             #:work-focus-support
             #,(source-interface-binding-work-focus-prefix self)
             #:work-focus-support-open
             #,(source-interface-binding-work-focus-prefix-open self)
             #:transfer-work-open
             #,(source-interface-binding-transfer-work-open self)
             #:transfer-work-host
             #,(source-interface-binding-transfer-work-host self)
             #:Q-export-local
             #,(source-interface-binding-q-export-local self)
             #:Q-rebuild-local
             #,(source-interface-binding-q-rebuild-local self)]
            #:Q-open
            [#:work-export
             #,(source-interface-binding-q-work-export-open self)
             #:work-support
             #,(source-interface-binding-q-work-support-open self)
             #:work-rebuild
             #,(source-interface-binding-q-work-rebuild-open self)
             #:frontier-export
             #,(source-interface-binding-q-frontier-export-open self)
             #:frontier-support
             #,(source-interface-binding-q-frontier-support-open self)
             #:frontier-rebuild
             #,(source-interface-binding-q-frontier-rebuild-open self)
             #:path-export
             #,(source-interface-binding-q-path-export-open self)
             #:path-rebuild
             #,(source-interface-binding-q-path-rebuild-open self)
             #:failure-export
             #,(source-interface-binding-q-failure-export self)
             #:failure-rebuild
             #,(source-interface-binding-q-failure-rebuild self)
             #:address-goal
             #,(source-interface-binding-q-address-goal-open self)]
            argument ...)]
        [_
         (raise-syntax-error
          #f
          (string-append
           "a core source interface is valid only after #:source-interface "
           "or through the framework visitor protocol")
          use-stx)])))

  (struct core-control (kind arguments) #:transparent)
  (struct core-rule-ir (label site from to premises) #:transparent)

  (struct variable-info
    (runtime-production
     productions
     definitions
     allocation-source
     allocation-target
     allocation-premises
     work-focus-prefix-open
     addressing-hook)
    #:transparent)

  (struct wf-info
    (definitions
     allocated-hook
     valid-supply-hook
     extend-supply-hook
     acyclic-substitution-hook
     state-supply-premises
     frame-prefix-premises
     conjunction-goal-supply-premises
     terminal-prefix-premises
     root)
    #:transparent)
  (struct q-info
    (definitions
     work-export-open work-support-open work-rebuild-open
     frontier-export-open frontier-support-open frontier-rebuild-open
     path-export-open path-rebuild-open
     failure-export failure-rebuild address-goal-open
     export rebuild
     focus-export focus-rebuild
     root-focus-export root-focus-rebuild
     failure-focus-export failure-focus-rebuild
     terminal-export terminal-rebuild)
    #:transparent)

  (struct prefix-info
    (transfer-work-open transfer-work q-export-local q-rebuild-local)
    #:transparent)

  (struct supply-info
    (productions
     state answer returned work dead conj last done more
     empty-supply
     conjunction-focus-supply
     branch-copy-supply
     join-return-supply
     join-failure-supply
     terminal-answer-supply
     live-supply-hook
     failure-summary-hook
     definitions
     prefix
     wf
     q)
    #:transparent)

  (struct strategy-info (variable supply declaration) #:transparent)

  (define semantic-rule-labels
    '("expand-conjunction"
      "succeed"
      "fail"
      "conj-return"
      "conj-fail"
      "unify-success"
      "unify-violates-disequality"
      "unify-fail"
      "disequality-success"
      "disequality-fail"
      "finish-success"
      "finish-failure"
      "allocate-fresh"))

  (define forbidden-relation-heads
    '(reduction-relation
      extend-reduction-relation
      union-reduction-relations
      context-closure
      -->
      -->/fresh))

  (define opaque-syntax-heads
    '(quote quasiquote syntax quasisyntax))

  (define (syntax-tree-contains? stx predicate)
    (define (walk datum)
      (cond
        [(syntax? datum)
         (define value (syntax-e datum))
         (cond
           [(and (pair? value)
                 (identifier? (car value))
                 (memq (syntax-e (car value)) opaque-syntax-heads))
            #f]
           [else (walk value)])]
        [(pair? datum)
         (or (walk (car datum)) (walk (cdr datum)))]
        [else (predicate datum)]))
    (walk stx))

  (define (validate-spliced-definitions who definitions declaration)
    (for ([definition (in-list definitions)])
      (when
          (syntax-tree-contains?
           definition
           (lambda (datum)
             (or (and (string? datum)
                      (member datum semantic-rule-labels))
                 (and (symbol? datum)
                      (memq datum forbidden-relation-heads)))))
        (raise-syntax-error
         #f
         (format
          "~a definitions may not contain source-relation forms or rule labels"
          who)
         declaration
         definition))))

  (define fixed-nonterminals
    '(d alloc support eq g t pt x rv tag sigma sub dis maybe-sub trail
        A S W F WorkPath SpineContext WorkFocus))

  (define (production-name production)
    (syntax-parse production
      [(name:id _ ...+) (syntax-e #'name)]
      [_
       (raise-syntax-error
        #f
        "expected a nonterminal production [name rhs ...]"
        production)]))

  (define (validate-productions variable-productions
                                supply-productions
                                declaration)
    (define names
      (map production-name
           (append variable-productions supply-productions)))
    (unless (= (length names) (length (remove-duplicates names)))
      (raise-syntax-error
       #f
       "strategy productions must have distinct nonterminal names"
       declaration))
    (for ([name (in-list names)])
      (when (memq name fixed-nonterminals)
        (raise-syntax-error
         #f
         (format "strategy production conflicts with fixed nonterminal ~a" name)
         declaration))))

  (define (validate-generated-hook actual expected declaration)
    (unless (eq? (syntax-e actual) expected)
      (raise-syntax-error
       #f
       (format "expected ~a" expected)
       declaration
       actual)))

  (define (parse-strategy declaration)
    (syntax-parse declaration
      [(_ _name:id
          #:variable
          [#:runtime-variable-production runtime-production
           #:productions (variable-production ...)
           #:definitions (variable-definition ...)
           #:walk-hook walk-hook:id
           #:unify-hook unify-hook:id
           #:invalid-hook invalid-hook:id
           #:lexical-substitution-hook lexical-hook:id
           #:allocation
           [#:source allocation-source
            #:target allocation-target
            #:premises (allocation-premise ...)]
           (~optional
            (~seq #:work-focus-prefix-open work-focus-prefix-open:id)
            #:defaults ([work-focus-prefix-open #'#f]))
           #:addressing-hook addressing-hook:id]
          #:supply/provenance
          [#:productions (supply-production ...)
           #:carriers
           [#:state state-template
            #:answer answer-template
            #:returned returned-template
            #:work work-template
            #:dead dead-template
            #:conj conj-template
            #:last last-template
            #:done done-template
            #:more more-template]
           #:empty-supply empty-supply
           #:conjunction-focus-supply conjunction-focus-supply
           #:branch-copy-supply branch-copy-supply
           #:join-return-supply join-return-supply
           #:join-failure-supply join-failure-supply
           #:terminal-answer-supply terminal-answer-supply
           #:live-supply-hook live-supply-hook:id
           #:failure-summary-hook failure-summary-hook:id
           #:definitions (supply-definition ...)
           (~optional
            (~seq
             #:extension-prefix
             [#:transfer-work-open transfer-work-open:id
              #:transfer-work transfer-work:id
              #:Q-export-local q-export-local:id
              #:Q-rebuild-local q-rebuild-local:id])
            #:defaults
            ([transfer-work-open #'#f]
             [transfer-work #'#f]
             [q-export-local #'#f]
             [q-rebuild-local #'#f]))
           #:well-formedness
           [#:definitions (wf-definition ...)
            #:allocated-hook allocated-hook:id
            #:valid-supply-hook valid-supply-hook:id
            #:extend-supply-hook extend-supply-hook:id
            #:acyclic-substitution-hook acyclic-substitution-hook:id
            #:state-supply-premises (state-supply-premise ...)
            #:frame-prefix-premises (frame-prefix-premise ...)
            #:conjunction-goal-supply-premises
            (conjunction-goal-supply-premise ...)
            #:terminal-prefix-premises (terminal-prefix-premise ...)
            #:root wf-root:id]
           #:q-map
           [#:definitions (q-definition ...)
            (~optional
             (~seq
              #:open
              [#:work-export q-work-export-open:id
               #:work-support q-work-support-open:id
               #:work-rebuild q-work-rebuild-open:id
               #:frontier-export q-frontier-export-open:id
               #:frontier-support q-frontier-support-open:id
               #:frontier-rebuild q-frontier-rebuild-open:id
               #:path-export q-path-export-open:id
               #:path-rebuild q-path-rebuild-open:id
               #:failure-export q-failure-export:id
               #:failure-rebuild q-failure-rebuild:id
               #:address-goal q-address-goal-open:id])
             #:defaults
             ([q-work-export-open #'#f]
              [q-work-support-open #'#f]
              [q-work-rebuild-open #'#f]
              [q-frontier-export-open #'#f]
              [q-frontier-support-open #'#f]
              [q-frontier-rebuild-open #'#f]
              [q-path-export-open #'#f]
              [q-path-rebuild-open #'#f]
              [q-failure-export #'#f]
              [q-failure-rebuild #'#f]
              [q-address-goal-open #'#f]))
            #:export q-export:id
            #:rebuild q-rebuild:id
            #:focus-export q-focus-export:id
            #:focus-rebuild q-focus-rebuild:id
            #:root-focus-export q-root-focus-export:id
            #:root-focus-rebuild q-root-focus-rebuild:id
            #:failure-focus-export q-failure-focus-export:id
            #:failure-focus-rebuild q-failure-focus-rebuild:id
            #:terminal-export q-terminal-export:id
            #:terminal-rebuild q-terminal-rebuild:id]])
       (validate-generated-hook #'walk-hook
                                'generated-structural
                                declaration)
       (validate-generated-hook #'unify-hook
                                'generated-first-order
                                declaration)
       (validate-generated-hook #'invalid-hook
                                'generated-store-check
                                declaration)
       (validate-generated-hook #'lexical-hook
                                'generated-binder-local
                                declaration)
       (define variable-productions
         (syntax->list #'(variable-production ...)))
       (define supply-productions
         (syntax->list #'(supply-production ...)))
       (validate-productions variable-productions
                             supply-productions
                             declaration)
       (define variable-definitions
         (syntax->list #'(variable-definition ...)))
       (define supply-definitions
         (syntax->list #'(supply-definition ...)))
       (define wf-definitions
         (syntax->list #'(wf-definition ...)))
       (define q-definitions
         (syntax->list #'(q-definition ...)))
       (validate-spliced-definitions
        'variable
        variable-definitions
        declaration)
       (validate-spliced-definitions
        'supply/provenance
        supply-definitions
        declaration)
       (validate-spliced-definitions
        'well-formedness
        wf-definitions
        declaration)
       (validate-spliced-definitions
        'q-map
        q-definitions
        declaration)
       (strategy-info
        (variable-info
         #'runtime-production
         variable-productions
         variable-definitions
         #'allocation-source
         #'allocation-target
         (syntax->list #'(allocation-premise ...))
         #'work-focus-prefix-open
         #'addressing-hook)
        (supply-info
         supply-productions
         #'state-template
         #'answer-template
         #'returned-template
         #'work-template
         #'dead-template
         #'conj-template
         #'last-template
         #'done-template
         #'more-template
         #'empty-supply
         #'conjunction-focus-supply
         #'branch-copy-supply
         #'join-return-supply
         #'join-failure-supply
         #'terminal-answer-supply
         #'live-supply-hook
         #'failure-summary-hook
         supply-definitions
         (prefix-info
          #'transfer-work-open
          #'transfer-work
          #'q-export-local
          #'q-rebuild-local)
         (wf-info
          wf-definitions
          #'allocated-hook
          #'valid-supply-hook
          #'extend-supply-hook
          #'acyclic-substitution-hook
          (syntax->list #'(state-supply-premise ...))
          (syntax->list #'(frame-prefix-premise ...))
          (syntax->list #'(conjunction-goal-supply-premise ...))
          (syntax->list #'(terminal-prefix-premise ...))
          #'wf-root)
         (q-info q-definitions
                 #'q-work-export-open
                 #'q-work-support-open
                 #'q-work-rebuild-open
                 #'q-frontier-export-open
                 #'q-frontier-support-open
                 #'q-frontier-rebuild-open
                 #'q-path-export-open
                 #'q-path-rebuild-open
                 #'q-failure-export
                 #'q-failure-rebuild
                 #'q-address-goal-open
                 #'q-export
                 #'q-rebuild
                 #'q-focus-export
                 #'q-focus-rebuild
                 #'q-root-focus-export
                 #'q-root-focus-rebuild
                 #'q-failure-focus-export
                 #'q-failure-focus-rebuild
                 #'q-terminal-export
                 #'q-terminal-rebuild))
        declaration)]))

  (define (lookup-strategy identifier)
    (define value (syntax-local-value identifier (lambda () #f)))
    (unless (strategy-binding? value)
      (raise-syntax-error
       #f
       "expected a core representation strategy"
       identifier))
    (parse-strategy (strategy-binding-declaration value)))

  ;; Replace only identifiers selected by a renderer.  Quoted Racket data and
  ;; syntax literals are deliberately opaque, so the LANG placeholder and
  ;; carrier slots cannot rewrite strings, symbols, or host data accidentally.
  (define (instantiate-template template replacements)
    (define replacement-table
      (for/hash ([replacement (in-list replacements)])
        (values (car replacement) (cdr replacement))))
    (define (walk-tail datum)
      (cond
        [(pair? datum)
         (cons (walk (car datum)) (walk-tail (cdr datum)))]
        [(syntax? datum) (walk datum)]
        [else datum]))
    (define (walk stx)
      (cond
        [(identifier? stx)
         (hash-ref replacement-table (syntax-e stx) (lambda () stx))]
        [else
         (define datum (syntax-e stx))
         (cond
           [(and (pair? datum)
                 (identifier? (car datum))
                 (memq (syntax-e (car datum)) opaque-syntax-heads))
            stx]
           [(pair? datum)
            (datum->syntax
             stx
             (cons (walk (car datum)) (walk-tail (cdr datum)))
             stx
             stx)]
           [else stx])]))
    (walk template))

  (define (instantiate-definitions definitions language replacements)
    (for/list ([definition (in-list definitions)])
      (instantiate-template
       definition
       (cons (cons 'LANG language) replacements))))

  (define (make-id context symbol)
    (datum->syntax context symbol context context))

  (define (make-template-renderers strategy use-stx)
    (define supply (strategy-info-supply strategy))
    (define (render template replacements)
      (instantiate-template template replacements))
    (define (state supply-value sub-value dis-value trail-value tag-value)
      (render
       (supply-info-state supply)
       (list (cons 'supply supply-value)
             (cons 'sub sub-value)
             (cons 'dis dis-value)
             (cons 'trail trail-value)
             (cons 'tag tag-value))))
    (define (answer supply-value state-value)
      (render
       (supply-info-answer supply)
       (list (cons 'supply supply-value)
             (cons 'sigma state-value))))
    (define (returned supply-value state-value)
      (render
       (supply-info-returned supply)
       (list (cons 'supply supply-value)
             (cons 'sigma state-value))))
    (define (work supply-value goal-value state-value)
      (render
       (supply-info-work supply)
       (list (cons 'supply supply-value)
             (cons 'g goal-value)
             (cons 'sigma state-value))))
    (define (dead supply-value)
      (render
       (supply-info-dead supply)
       (list (cons 'supply supply-value))))
    (define (conj supply-value work-value goal-value)
      (render
       (supply-info-conj supply)
       (list (cons 'supply supply-value)
             (cons 'W work-value)
             (cons 'g goal-value))))
    (define (last supply-value answer-value)
      (render
       (supply-info-last supply)
       (list (cons 'supply supply-value)
             (cons 'A answer-value))))
    (define (done supply-value)
      (render
       (supply-info-done supply)
       (list (cons 'supply supply-value))))
    (define (more work-value)
      (render
       (supply-info-more supply)
       (list (cons 'W work-value))))
    (values state answer returned work dead conj last done more))

  (define (control kind . arguments)
    (core-control kind arguments))

  ;; The rule IR records semantic control, not a particular presentation of
  ;; that control.  R renders a focused redex/contractum while D and later
  ;; stages consume the control form retained by the selected source view.
  (define (control->source-term control site root-focus)
    (match-define (core-control kind arguments) control)
    (match* (kind arguments)
      [('run (list payload context))
       (if (eq? site 'allocation)
           #`(in-hole #,context #,payload)
           payload)]
      [('pop-settled (list frame payload _context))
       #`(in-hole #,frame #,payload)]
      [('pop-failed (list frame _summary raw _context))
       #`(in-hole #,frame #,raw)]
      [('root-settled (list payload _spine))
       #`(in-hole #,root-focus #,payload)]
      [('root-failed (list _summary raw _spine))
       #`(in-hole #,root-focus #,raw)]
      [('frontier (list payload _spine)) payload]
      [(_ _)
       (error 'control->source-term
              "unsupported source control ~e"
              control)]))

  (define (control->target-term control site)
    (match-define (core-control kind arguments) control)
    (match* (kind arguments)
      [('run (list payload context))
       (if (eq? site 'allocation)
           #`(in-hole #,context #,payload)
           payload)]
      [('push (list frame payload _context))
       #`(in-hole #,frame #,payload)]
      [('settled (list payload _context)) payload]
      [('failed (list _summary raw _context)) raw]
      [('frontier (list payload _spine)) payload]
      [('final (list payload _spine)) payload]
      [(_ _)
       (error 'control->target-term
              "unsupported target control ~e"
              control)]))

  (define (control->stage-syntax control)
    (match-define (core-control kind arguments) control)
    (define head (make-id (car arguments) kind))
    #`(#,head #,@arguments))

  (define (render-R-rule rule root-focus)
    (define label (core-rule-ir-label rule))
    (define site (core-rule-ir-site rule))
    (define source
      (control->source-term (core-rule-ir-from rule) site root-focus))
    (define target (control->target-term (core-rule-ir-to rule) site))
    (define premises (core-rule-ir-premises rule))
    #`[--> #,source
          #,target
          #,@premises
          #,(symbol->string label)])

  (define (render-stage-rule rule context)
    (define label (make-id context (core-rule-ir-label rule)))
    (define site (make-id context (core-rule-ir-site rule)))
    (define from (control->stage-syntax (core-rule-ir-from rule)))
    (define to (control->stage-syntax (core-rule-ir-to rule)))
    (define premises (core-rule-ir-premises rule))
    #`[#,label
       #:site #,site
       #:from #,from
       #:to #,to
       #:premises (#,@premises)])

  (define (render-source-instance strategy
                                  use-stx
                                  language-id
                                  relation-id
                                  raw-successors-id
                                  branch-copy-id
                                  source-interface-id)
    (define variable (strategy-info-variable strategy))
    (define supply (strategy-info-supply strategy))

    (define-values (state answer returned work dead conj last done more)
      (make-template-renderers strategy use-stx))

    (define (slot symbol)
      (make-id use-stx symbol))

    (define supply-v (slot 'supply))
    (define supply-in (slot 'supply_in))
    (define supply-local (slot 'supply_local))
    (define supply-out (slot 'supply_out))
    (define supply-frame (slot 'supply_frame))
    (define supply-goal (slot 'supply_goal))
    (define supply-prefix (slot 'supply_prefix))
    (define supply-outer (slot 'supply_outer))
    (define supply-inner (slot 'supply_inner))
    (define sigma-v (slot 'sigma))
    (define sub-v (slot 'sub))
    (define sub-1 (slot 'sub_1))
    (define dis-v (slot 'dis))
    (define dis-1 (slot 'dis_1))
    (define trail-v (slot 'trail))
    (define state-tag (slot 'tag_state))
    (define tag-v (slot 'tag))
    (define tag-1 (slot 'tag_1))
    (define tag-2 (slot 'tag_2))
    (define t-1 (slot 't_1))
    (define t-2 (slot 't_2))
    (define t-3 (slot 't_3))
    (define t-4 (slot 't_4))
    (define g-v (slot 'g))
    (define g-1 (slot 'g_1))
    (define g-2 (slot 'g_2))
    (define W-v (slot 'W))
    (define A-v (slot 'A))
    (define rv-v (slot 'rv))
    (define x-v (slot 'x))

    (define state/current
      (state supply-v sub-v dis-v trail-v state-tag))
    (define work/current
      (work supply-v g-v state/current))

    (define grammar-conj
      (conj (slot 'supply) (slot 'W) (slot 'g)))
    (define grammar-more (more (slot 'W)))
    (define path-conj
      (conj (slot 'supply) (slot 'WorkPath) (slot 'g)))
    (define focus-more (more (slot 'WorkPath)))

    (define (public-hook declared-id)
      (datum->syntax use-stx
                     (syntax-e declared-id)
                     use-stx
                     use-stx))

    (define work-raw-id (format-id relation-id "~a/work-raw" relation-id))
    (define frontier-raw-id
      (format-id relation-id "~a/frontier-raw" relation-id))
    (define allocation-raw-id
      (format-id relation-id "~a/allocation-raw" relation-id))
    (define allocation-subst-goal-id
      (format-id relation-id "~a/allocation-subst-goal" relation-id))
    (define allocation-work-focus-prefix-id
      (format-id relation-id
                 "~a/allocation-work-focus-prefix-support"
                 relation-id))
    (define work-base-id (format-id relation-id "~a/work-base" relation-id))
    (define frontier-base-id
      (format-id relation-id "~a/frontier-base" relation-id))
    (define walk-id (format-id relation-id "~a/walk" relation-id))
    (define occurs-id (format-id relation-id "~a/occurs?" relation-id))
    (define extend-id (format-id relation-id "~a/extend" relation-id))
    (define unify-id (format-id relation-id "~a/unify" relation-id))
    (define invalid-id (format-id relation-id "~a/invalid?" relation-id))
    (define lexical-variable-id
      (format-id relation-id "~a/lexical-variable?" relation-id))
    (define subst-term-id
      (format-id relation-id "~a/subst-term" relation-id))
    (define drop-shadowed-id
      (format-id relation-id "~a/drop-shadowed" relation-id))
    (define subst-goal-id
      (format-id relation-id "~a/subst-goal" relation-id))
    (define subst-goal-open-id
      (format-id relation-id "~a/subst-goal/open" relation-id))
    (define subst-goal-artifact-id
      (format-id relation-id "~a/subst-goal/direct" relation-id))
    (define work-focus-prefix-id
      (format-id relation-id "~a/work-focus-prefix-support" relation-id))
    (define work-focus-prefix-host-id
      (format-id relation-id "~a/work-focus-prefix-support/host" relation-id))
    (define wf-root-id
      (public-hook (wf-info-root (supply-info-wf supply))))
    (define live-supply-id
      (public-hook (supply-info-live-supply-hook supply)))
    (define failure-summary-id
      (public-hook (supply-info-failure-summary-hook supply)))
    (define wf-term-id (format-id wf-root-id "~a/term" wf-root-id))
    (define wf-sub-id (format-id wf-root-id "~a/sub" wf-root-id))
    (define wf-dis-id (format-id wf-root-id "~a/dis" wf-root-id))
    (define wf-trail-id (format-id wf-root-id "~a/trail" wf-root-id))
    (define wf-state-id (format-id wf-root-id "~a/state" wf-root-id))
    (define wf-goal-id (format-id wf-root-id "~a/goal" wf-root-id))
    (define wf-goal-case-id
      (format-id wf-root-id "~a/goal-case" wf-root-id))
    (define wf-goal-tasks-id
      (format-id wf-root-id "~a/goal-tasks" wf-root-id))
    (define wf-answer-id (format-id wf-root-id "~a/answer" wf-root-id))
    (define wf-returned-id
      (format-id wf-root-id "~a/returned" wf-root-id))
    (define wf-work-id (format-id wf-root-id "~a/work" wf-root-id))
    (define wf-frontier-id
      (format-id wf-root-id "~a/frontier" wf-root-id))
    (define wf-node-case-id
      (format-id wf-root-id "~a/node-case" wf-root-id))
    (define wf-nodes-id
      (format-id wf-root-id "~a/nodes" wf-root-id))
    (define live-supply-one-id
      (format-id live-supply-id "~a/one" live-supply-id))

    (define wf (supply-info-wf supply))
    (define wf-root (wf-info-root wf))
    (define allocated-hook (public-hook (wf-info-allocated-hook wf)))
    (define valid-supply-hook
      (public-hook (wf-info-valid-supply-hook wf)))
    (define extend-supply-hook
      (public-hook (wf-info-extend-supply-hook wf)))
    (define acyclic-substitution-hook
      (public-hook (wf-info-acyclic-substitution-hook wf)))
    (define q-export
      (q-info-export (supply-info-q supply)))
    (define q-rebuild
      (q-info-rebuild (supply-info-q supply)))
    (define q-focus-export
      (q-info-focus-export (supply-info-q supply)))
    (define q-focus-rebuild
      (q-info-focus-rebuild (supply-info-q supply)))
    (define q-root-focus-export
      (q-info-root-focus-export (supply-info-q supply)))
    (define q-root-focus-rebuild
      (q-info-root-focus-rebuild (supply-info-q supply)))
    (define q-failure-focus-export
      (q-info-failure-focus-export (supply-info-q supply)))
    (define q-failure-focus-rebuild
      (q-info-failure-focus-rebuild (supply-info-q supply)))
    (define q-terminal-export
      (q-info-terminal-export (supply-info-q supply)))
    (define q-terminal-rebuild
      (q-info-terminal-rebuild (supply-info-q supply)))
    (define prefix (supply-info-prefix supply))
    (define work-focus-prefix-open
      (variable-info-work-focus-prefix-open variable))
    (define q-open (supply-info-q supply))
    (define (optional-public-hook declared-id)
      (and (syntax-e declared-id) (public-hook declared-id)))
    (define extension-hook-identifiers
      (filter
       (lambda (identifier) (syntax-e identifier))
       (list work-focus-prefix-open
             (prefix-info-transfer-work-open prefix)
             (prefix-info-transfer-work prefix)
             (prefix-info-q-export-local prefix)
             (prefix-info-q-rebuild-local prefix)
             (q-info-work-export-open q-open)
             (q-info-work-support-open q-open)
             (q-info-work-rebuild-open q-open)
             (q-info-frontier-export-open q-open)
             (q-info-frontier-support-open q-open)
             (q-info-frontier-rebuild-open q-open)
             (q-info-path-export-open q-open)
             (q-info-path-rebuild-open q-open)
             (q-info-failure-export q-open)
             (q-info-failure-rebuild q-open)
             (q-info-address-goal-open q-open))))
    (define hook-replacements
      (append
       (list
       (cons 'WALK-HOOK walk-id)
       (cons 'UNIFY-HOOK unify-id)
       (cons 'INVALID-HOOK invalid-id)
       (cons 'SUBST-GOAL-HOOK subst-goal-id)
       (cons 'WF-ROOT-HOOK (public-hook wf-root))
       (cons 'ALLOCATED-HOOK allocated-hook)
       (cons 'VALID-SUPPLY-HOOK valid-supply-hook)
       (cons 'EXTEND-SUPPLY-HOOK extend-supply-hook)
       (cons 'ACYCLIC-SUBSTITUTION-HOOK acyclic-substitution-hook)
       (cons 'ADDRESSING-HOOK
             (public-hook (variable-info-addressing-hook variable)))
       (cons 'LIVE-SUPPLY-HOOK
             (public-hook (supply-info-live-supply-hook supply)))
       (cons 'FAILURE-SUMMARY-HOOK
             (public-hook (supply-info-failure-summary-hook supply)))
       (cons 'Q-EXPORT-HOOK (public-hook q-export))
       (cons 'Q-REBUILD-HOOK (public-hook q-rebuild))
       (cons 'Q-FOCUS-EXPORT-HOOK (public-hook q-focus-export))
       (cons 'Q-FOCUS-REBUILD-HOOK (public-hook q-focus-rebuild))
       (cons 'Q-ROOT-FOCUS-EXPORT-HOOK
             (public-hook q-root-focus-export))
       (cons 'Q-ROOT-FOCUS-REBUILD-HOOK
             (public-hook q-root-focus-rebuild))
       (cons 'Q-FAILURE-FOCUS-EXPORT-HOOK
             (public-hook q-failure-focus-export))
       (cons 'Q-FAILURE-FOCUS-REBUILD-HOOK
             (public-hook q-failure-focus-rebuild))
       (cons 'Q-TERMINAL-EXPORT-HOOK
             (public-hook q-terminal-export))
       (cons 'Q-TERMINAL-REBUILD-HOOK
             (public-hook q-terminal-rebuild))
       (cons (syntax-e (variable-info-addressing-hook variable))
             (public-hook (variable-info-addressing-hook variable)))
       (cons (syntax-e (supply-info-live-supply-hook supply))
             (public-hook (supply-info-live-supply-hook supply)))
       (cons (syntax-e (supply-info-failure-summary-hook supply))
             (public-hook (supply-info-failure-summary-hook supply)))
       (cons (syntax-e (wf-info-allocated-hook wf)) allocated-hook)
       (cons (syntax-e (wf-info-valid-supply-hook wf)) valid-supply-hook)
       (cons (syntax-e (wf-info-extend-supply-hook wf)) extend-supply-hook)
       (cons (syntax-e (wf-info-acyclic-substitution-hook wf))
             acyclic-substitution-hook)
       (cons (syntax-e wf-root) (public-hook wf-root))
       (cons (syntax-e q-export) (public-hook q-export))
       (cons (syntax-e q-rebuild) (public-hook q-rebuild))
       (cons (syntax-e q-focus-export) (public-hook q-focus-export))
       (cons (syntax-e q-focus-rebuild) (public-hook q-focus-rebuild))
       (cons (syntax-e q-root-focus-export)
             (public-hook q-root-focus-export))
       (cons (syntax-e q-root-focus-rebuild)
             (public-hook q-root-focus-rebuild))
       (cons (syntax-e q-failure-focus-export)
             (public-hook q-failure-focus-export))
       (cons (syntax-e q-failure-focus-rebuild)
             (public-hook q-failure-focus-rebuild))
       (cons (syntax-e q-terminal-export)
             (public-hook q-terminal-export))
       (cons (syntax-e q-terminal-rebuild)
             (public-hook q-terminal-rebuild)))
       (for/list ([identifier (in-list extension-hook-identifiers)])
         (cons (syntax-e identifier) (public-hook identifier)))))

    (define variable-definitions
      (instantiate-definitions
       (variable-info-definitions variable)
       language-id
       hook-replacements))
    (define supply-definitions
      (instantiate-definitions
       (supply-info-definitions supply)
       language-id
       hook-replacements))
    (define wf-definitions
      (instantiate-definitions
       (wf-info-definitions (supply-info-wf supply))
       language-id
       hook-replacements))
    (define q-definitions
      (instantiate-definitions
       (q-info-definitions (supply-info-q supply))
       language-id
       hook-replacements))
    (define (instantiate-wf-premises premises)
      (for/list ([premise (in-list premises)])
        (instantiate-template premise hook-replacements)))
    (define state-supply-premises
      (instantiate-wf-premises (wf-info-state-supply-premises wf)))
    (define frame-prefix-premises
      (instantiate-wf-premises (wf-info-frame-prefix-premises wf)))
    (define extension-prefix-premises
      (for/list ([premise (in-list (wf-info-frame-prefix-premises wf))])
        (instantiate-template
         premise
         (cons (cons 'supply_frame supply-out)
               hook-replacements))))
    (define conjunction-goal-supply-premises
      (for/list
          ([premise
            (in-list
             (wf-info-conjunction-goal-supply-premises wf))])
        (instantiate-template
         premise
         (append hook-replacements
                 (list (cons 'LIVE-SUPPLY-HOOK #'wf-node-live))))))
    (define terminal-prefix-premises
      (instantiate-wf-premises (wf-info-terminal-prefix-premises wf)))

    (define join-return
      (instantiate-template
       (supply-info-join-return-supply supply)
       (list (cons 'supply_outer supply-outer)
             (cons 'supply_inner supply-inner))))
    (define join-failure
      (instantiate-template
       (supply-info-join-failure-supply supply)
       (list (cons 'supply_outer supply-outer)
             (cons 'supply_inner supply-inner))))
    (define terminal-answer-supply
      (instantiate-template
       (supply-info-terminal-answer-supply supply)
       (list (cons 'supply supply-v))))
    (define empty-supply
      (instantiate-template
       (supply-info-empty-supply supply)
       (list (cons 'supply supply-v))))
    (define branch-copy-supply
      (instantiate-template
       (supply-info-branch-copy-supply supply)
       (list (cons 'supply supply-v))))
    (define conjunction-focus-supply
      (instantiate-template
       (supply-info-conjunction-focus-supply supply)
       (list (cons 'supply supply-v))))

    (define expanded-source-state
      (state supply-v sub-v dis-v trail-v tag-1))
    (define expanded-target-work
      (work conjunction-focus-supply g-1 expanded-source-state))
    (define expanded-source
      (work supply-v #`(#,g-1 ∧ #,g-2 #,tag-v) expanded-source-state))

    (define success-state
      (state supply-v sub-v dis-v trail-v state-tag))
    (define success-source
      (work supply-v #`(succeed #,tag-v) success-state))
    (define success-target (returned supply-v success-state))

    (define failure-source
      (work supply-v #`(fail #,tag-v) success-state))
    (define failure-target (dead supply-v))

    (define returned-inner-state
      (state supply-inner sub-v dis-v trail-v state-tag))
    (define conj-return-target
      (work join-return g-v returned-inner-state))

    (define conj-failure-target (dead join-failure))

    (define unify-source-state
      (state
       supply-v
       sub-v
       dis-v
       #`((#,t-3 =? #,t-4 #,tag-1) (... ...))
       tag-2))
    (define unify-goal #`(#,t-1 =? #,t-2 #,tag-v))
    (define unify-source (work supply-v unify-goal unify-source-state))
    (define unify-target-state
      (state
       supply-v
       sub-1
       dis-v
       #`((#,t-3 =? #,t-4 #,tag-1) (... ...)
          (#,t-1 =? #,t-2 #,tag-v))
       tag-2))
    (define unify-target
      (returned supply-v unify-target-state))
    (define unify-general-source
      (work
       supply-v
       unify-goal
       (state supply-v sub-v dis-v trail-v tag-2)))

    (define disequality-goal #`(#,t-1 != #,t-2 #,tag-v))
    (define disequality-source
      (work
       supply-v
       disequality-goal
       (state supply-v sub-v dis-v trail-v tag-2)))
    (define disequality-target-state
      (state supply-v
             sub-v
             dis-1
             trail-v
             tag-2))
    (define disequality-target
      (returned supply-v disequality-target-state))

    (define finish-success-target
      (last supply-v
            (answer terminal-answer-supply success-state)))
    (define finish-failure-target (done supply-v))

    (define allocation-source
      (instantiate-template
       (variable-info-allocation-source variable)
       (append
        hook-replacements
        (list (cons 'SUBST-GOAL-HOOK allocation-subst-goal-id)
              (cons 'subst-goal-hook allocation-subst-goal-id)
              (cons 'WORK-FOCUS-PREFIX-HOOK
                    allocation-work-focus-prefix-id)))))
    (define allocation-target
      (instantiate-template
       (variable-info-allocation-target variable)
       (append
        hook-replacements
        (list (cons 'SUBST-GOAL-HOOK allocation-subst-goal-id)
              (cons 'subst-goal-hook allocation-subst-goal-id)
              (cons 'WORK-FOCUS-PREFIX-HOOK
                    allocation-work-focus-prefix-id)))))
    (define allocation-premises
      (for/list ([premise
                  (in-list (variable-info-allocation-premises variable))])
        (instantiate-template
         premise
         (append
          hook-replacements
          (list (cons 'SUBST-GOAL-HOOK allocation-subst-goal-id)
                (cons 'subst-goal-hook allocation-subst-goal-id)
                (cons 'WORK-FOCUS-PREFIX-HOOK
                      allocation-work-focus-prefix-id))))))

    (define hole-v (slot 'hole))
    (define work-focus-v (slot 'WorkFocus))
    (define root-spine hole-v)
    (define root-focus (more hole-v))
    (define expand-frame
      (conj supply-v hole-v g-2))
    (define conj-return-frame
      (conj supply-outer hole-v g-v))
    (define returned-inner
      (returned supply-inner returned-inner-state))
    (define conj-failure-frame
      (conj supply-outer hole-v g-v))
    (define allocation-payload #f)
    (define allocation-context #f)
    (syntax-parse allocation-source
      [((~datum in-hole) context payload)
       (set! allocation-context #'context)
       (set! allocation-payload #'payload)]
      [_
       (raise-syntax-error
        #f
        "allocation source must expose (in-hole WorkFocus payload)"
        (strategy-info-declaration strategy)
        allocation-source)])
    (define allocation-target-payload #f)
    (define allocation-target-context #f)
    (syntax-parse allocation-target
      [((~datum in-hole) context payload)
       (set! allocation-target-context #'context)
       (set! allocation-target-payload #'payload)]
      [_
       (raise-syntax-error
        #f
        "allocation target must expose (in-hole WorkFocus payload)"
        (strategy-info-declaration strategy)
        allocation-target)])

    ;; This is the one 13-equation compile-time IR.  Both the source relation
    ;; below and the retained selected-stage view are projections of this list.
    (define semantic-rules
      (list
       (core-rule-ir
        'expand-conjunction
        'work
        (control 'run expanded-source work-focus-v)
        (control 'push expand-frame expanded-target-work work-focus-v)
        '())
       (core-rule-ir
        'succeed
        'work
        (control 'run success-source work-focus-v)
        (control 'settled success-target work-focus-v)
        '())
       (core-rule-ir
        'fail
        'work
        (control 'run failure-source work-focus-v)
        (control 'failed supply-v failure-target work-focus-v)
        '())
       (core-rule-ir
        'conj-return
        'work
        (control 'pop-settled
                 conj-return-frame
                 returned-inner
                 work-focus-v)
        (control 'run conj-return-target work-focus-v)
        '())
       (core-rule-ir
        'conj-fail
        'work
        (control 'pop-failed
                 conj-failure-frame
                 supply-inner
                 (dead supply-inner)
                 work-focus-v)
        (control 'failed join-failure conj-failure-target work-focus-v)
        '())
       (core-rule-ir
        'unify-success
        'work
        (control 'run unify-source work-focus-v)
        (control 'settled unify-target work-focus-v)
        (list
         #`(where #,sub-1
                  (#,unify-id
                   (#,walk-id #,t-1 #,sub-v)
                   (#,walk-id #,t-2 #,sub-v)
                   #,sub-v))
         #`(where #f (#,invalid-id #,sub-1 #,dis-v))))
       (core-rule-ir
        'unify-violates-disequality
        'work
        (control 'run unify-general-source work-focus-v)
        (control 'failed supply-v failure-target work-focus-v)
        (list
         #`(where #,sub-1
                  (#,unify-id
                   (#,walk-id #,t-1 #,sub-v)
                   (#,walk-id #,t-2 #,sub-v)
                   #,sub-v))
         #`(where #t (#,invalid-id #,sub-1 #,dis-v))))
       (core-rule-ir
        'unify-fail
        'work
        (control 'run unify-general-source work-focus-v)
        (control 'failed supply-v failure-target work-focus-v)
        (list
         #`(where #f
                  (#,unify-id
                   (#,walk-id #,t-1 #,sub-v)
                   (#,walk-id #,t-2 #,sub-v)
                   #,sub-v))))
       (core-rule-ir
        'disequality-success
        'work
        (control 'run disequality-source work-focus-v)
        (control 'settled disequality-target work-focus-v)
        (list
         #`(where #,dis-1
                  ((#,t-1 #,t-2) ,@(term #,dis-v)))
         #`(where #f (#,invalid-id #,sub-v #,dis-1))))
       (core-rule-ir
        'disequality-fail
        'work
        (control 'run disequality-source work-focus-v)
        (control 'failed supply-v failure-target work-focus-v)
        (list
         #`(where #,dis-1
                  ((#,t-1 #,t-2) ,@(term #,dis-v)))
         #`(where #t (#,invalid-id #,sub-v #,dis-1))))
       (core-rule-ir
        'finish-success
        'frontier
        (control 'root-settled (returned supply-v success-state) root-spine)
        (control 'final finish-success-target root-spine)
        '())
       (core-rule-ir
        'finish-failure
        'frontier
        (control 'root-failed supply-v (dead supply-v) root-spine)
        (control 'final finish-failure-target root-spine)
        '())
       (core-rule-ir
        'allocate-fresh
        'allocation
        (control 'run allocation-payload allocation-context)
        (control 'run allocation-target-payload allocation-target-context)
        allocation-premises)))

    (define (rules-at site)
      (filter (lambda (rule) (eq? (core-rule-ir-site rule) site))
              semantic-rules))
    (define work-R-rules
      (map (lambda (rule) (render-R-rule rule root-focus))
           (rules-at 'work)))
    (define frontier-R-rules
      (map (lambda (rule) (render-R-rule rule root-focus))
           (rules-at 'frontier)))
    (define allocation-R-rules
      (map (lambda (rule) (render-R-rule rule root-focus))
           (rules-at 'allocation)))
    (define stage-rules
      (map (lambda (rule) (render-stage-rule rule use-stx))
           semantic-rules))

    (define (syntax-deduplicate forms)
      (reverse
       (for/fold ([kept '()]) ([form (in-list forms)])
         (if (for/or ([prior (in-list kept)])
               (equal? (syntax->datum prior) (syntax->datum form)))
             kept
             (cons form kept)))))
    (define run-productions
      (list (work supply-v g-v sigma-v)))
    (define nonallocation-run-productions
      (list (work supply-v (slot 'eq) sigma-v)
            (work supply-v #`(#,t-1 != #,t-2 #,tag-v) sigma-v)
            (work supply-v #`(succeed #,tag-v) sigma-v)
            (work supply-v #`(fail #,tag-v) sigma-v)
            (work supply-v #`(#,g-1 ∧ #,g-2 #,tag-v) sigma-v)))
    (define frames
      (list (conj supply-v hole-v g-v)))
    (define work-redexes
      (syntax-deduplicate
       (for/list ([rule (in-list (rules-at 'work))])
         (control->source-term
          (core-rule-ir-from rule)
          'work
          root-focus))))
    (define frontier-redexes
      (syntax-deduplicate
       (for/list ([rule (in-list (rules-at 'frontier))])
         (control->source-term
          (core-rule-ir-from rule)
          'frontier
          root-focus))))
    (define allocation-redexes (list allocation-payload))
    (define terminals
      (syntax-deduplicate
       (for/list ([rule (in-list (rules-at 'frontier))])
         (control->target-term (core-rule-ir-to rule) 'frontier))))
    (define open-work-productions
      (list (conj supply-v (slot 'OpenW) g-v)))
    (define selected-stage-view
      #`(define-selected-core-instance SOURCE-INSTANCE
          #:source-language #,language-id
          #:redex-parameters
          ([#,allocation-subst-goal-id #,subst-goal-artifact-id]
           [#,allocation-work-focus-prefix-id #,work-focus-prefix-id])
          #:variable-view
          [#:runtime-variable #,rv-v]
          #:live-state-view
          [#:state #,state/current
           #:work #,(slot 'W)
           #:run-productions (#,@run-productions)
           #:nonallocation-run-productions
           (#,@nonallocation-run-productions)]
          #:returned-view
          [#:carrier #,(slot 'S)
           #:materialized #,(returned supply-v sigma-v)]
          #:failure-summary-view
          [#:carrier #,supply-v
           #:materialized #,(dead supply-v)]
          #:terminal-view
          [#:frontier #,(slot 'F)
           #:success #,finish-success-target
           #:failure #,finish-failure-target]
          #:payload/context-view
          [#:work-focus #,(slot 'WorkFocus)
           #:spine-context #,(slot 'SpineContext)
           #:root-focus #,root-focus
           #:root-spine #,root-spine
           #:frames (#,@frames)
           #:work-redexes (#,@work-redexes)
           #:frontier-redexes (#,@frontier-redexes)
           #:allocation-redexes (#,@allocation-redexes)
           #:open-work-productions (#,@open-work-productions)]
          #:rules (#,@stage-rules)))

    (define wf-state-pattern
      (state supply-local sub-v dis-v trail-v state-tag))
    (define wf-active-pattern
      (work supply-local g-v wf-state-pattern))
    (define wf-returned-pattern
      (returned supply-local wf-state-pattern))
    (define wf-dead-pattern (dead supply-local))
    (define wf-conj-pattern
      (conj supply-local W-v g-v))
    (define wf-answer-pattern
      (answer supply-local wf-state-pattern))
    (define wf-more-pattern (more W-v))
    (define wf-last-pattern
      (last supply-local A-v))
    (define wf-done-pattern (done supply-local))

    (define wf-structural-definitions
      (instantiate-template
       #`(begin
          ;; Strategies define the primitive supply judgments.  Traversal of
          ;; terms, states, goals, work, and frontiers is shared here.
          (define-judgment-form
            #,language-id
            #:contract (#,wf-term-id t (x (... ...)) supply)
            #:mode (#,wf-term-id I I I)

            [(#,allocated-hook rv supply)
             ---------------------------------------- "allocated runtime variable"
             (#,wf-term-id rv (x_bound (... ...)) supply)]

            [---------------------------------------- "primitive term"
             (#,wf-term-id pt (x_bound (... ...)) supply)]

            [(#,wf-term-id t_1 (x_bound (... ...)) supply)
             (#,wf-term-id t_2 (x_bound (... ...)) supply)
             ---------------------------------------- "pair term"
             (#,wf-term-id
              (t_1 : t_2)
              (x_bound (... ...))
              supply)]

            [---------------------------------------- "bound lexical variable"
             (#,wf-term-id
              x
              (x_before (... ...) x x_after (... ...))
              supply)])

          (define-judgment-form
            #,language-id
            #:contract (#,wf-sub-id sub supply)
            #:mode (#,wf-sub-id I I)
            [(#,allocated-hook rv supply) (... ...)
             (#,wf-term-id t () supply) (... ...)
             (where #t (#,acyclic-substitution-hook ([rv t] (... ...))))
             ---------------------------------------- "closed acyclic substitution"
             (#,wf-sub-id ([rv t] (... ...)) supply)])

          (define-judgment-form
            #,language-id
            #:contract (#,wf-dis-id dis supply)
            #:mode (#,wf-dis-id I I)

            [---------------------------------------- "empty disequality store"
             (#,wf-dis-id () supply)]

            [(#,wf-term-id t_1 () supply)
             (#,wf-term-id t_2 () supply)
             (#,wf-dis-id ((t_3 t_4) (... ...)) supply)
             ---------------------------------------- "disequality store pair"
             (#,wf-dis-id
              ((t_1 t_2) (t_3 t_4) (... ...))
              supply)])

          (define-judgment-form
            #,language-id
            #:contract (#,wf-trail-id trail supply sub sub)
            #:mode (#,wf-trail-id I I I I)

            [---------------------------------------- "empty trail"
             (#,wf-trail-id () supply sub sub)]

            [(#,wf-term-id t_1 () supply)
             (#,wf-term-id t_2 () supply)
             (where sub_next
                    (#,unify-id
                     (#,walk-id t_1 sub_acc)
                     (#,walk-id t_2 sub_acc)
                     sub_acc))
             (#,wf-trail-id
              (eq_rest (... ...))
              supply
              sub_next
              sub_final)
             ---------------------------------------- "trail replay step"
             (#,wf-trail-id
              ((t_1 =? t_2 tag) eq_rest (... ...))
              supply
              sub_acc
              sub_final)])

          (define-judgment-form
            #,language-id
            #:contract (#,wf-state-id sigma supply)
            #:mode (#,wf-state-id I I)
            [#,@state-supply-premises
             (#,valid-supply-hook supply_in)
             (#,wf-sub-id sub supply_in)
             (#,wf-dis-id dis supply_in)
             (#,wf-trail-id trail supply_in () sub)
             ---------------------------------------- "logical state"
             (#,wf-state-id #,wf-state-pattern supply_in)])

          ;; Goal traversal is split into a feature-extensible, nonrecursive
          ;; classifier and a representation-neutral task driver.  Lifting
          ;; the driver to an extended language therefore routes every nested
          ;; goal through the exact-language classifier.
          (redex-parameter:define-judgment-form*
            #,language-id
            #:mode (#,wf-goal-case-id I O)
            #:contract (#,wf-goal-case-id WFGoalTask WFGoalTasks)

            [---------------------------------------- "success goal"
             (#,wf-goal-case-id
              (GoalCheck (succeed tag) (x_bound (... ...)) supply)
              (GoalChecks))]

            [---------------------------------------- "failure goal"
             (#,wf-goal-case-id
              (GoalCheck (fail tag) (x_bound (... ...)) supply)
              (GoalChecks))]

            [(#,wf-term-id t_1 (x_bound (... ...)) supply)
             (#,wf-term-id t_2 (x_bound (... ...)) supply)
             ---------------------------------------- "unification goal"
             (#,wf-goal-case-id
              (GoalCheck
               (t_1 =? t_2 tag)
               (x_bound (... ...))
               supply)
              (GoalChecks))]

            [(#,wf-term-id t_1 (x_bound (... ...)) supply)
             (#,wf-term-id t_2 (x_bound (... ...)) supply)
             ---------------------------------------- "disequality goal"
             (#,wf-goal-case-id
              (GoalCheck
               (t_1 != t_2 tag)
               (x_bound (... ...))
               supply)
              (GoalChecks))]

            [---------------------------------------- "fresh goal"
             (#,wf-goal-case-id
              (GoalCheck
               (∃ (x_fresh (... ...)) g tag)
               (x_bound (... ...))
               supply)
              (GoalChecks
               (GoalCheck
                g
                (x_fresh (... ...) x_bound (... ...))
                supply)))]

            [---------------------------------------- "conjunction goal"
             (#,wf-goal-case-id
              (GoalCheck
               (g_1 ∧ g_2 tag)
               (x_bound (... ...))
               supply)
              (GoalChecks
               (GoalCheck g_1 (x_bound (... ...)) supply)
               (GoalCheck g_2 (x_bound (... ...)) supply)))])

          (redex-parameter:define-judgment-form*
            #,language-id
            #:parameters ([wf-goal-next #,wf-goal-case-id])
            #:mode (#,wf-goal-tasks-id I)
            #:contract (#,wf-goal-tasks-id WFGoalTasks)
            [----
             (#,wf-goal-tasks-id (GoalChecks))]
            [(wf-goal-next
              WFGoalTask_0
              (GoalChecks WFGoalTask_child (... ...)))
             (#,wf-goal-tasks-id
              (GoalChecks
               WFGoalTask_child (... ...)
               WFGoalTask_rest (... ...)))
             ----
             (#,wf-goal-tasks-id
              (GoalChecks WFGoalTask_0 WFGoalTask_rest (... ...)))])

          (redex-parameter:define-judgment-form*
            #,language-id
            #:parameters ([wf-goal-run #,wf-goal-tasks-id])
            #:mode (#,wf-goal-id I I I)
            #:contract (#,wf-goal-id g (x (... ...)) supply)
            [(wf-goal-run
              (GoalChecks (GoalCheck g (x_bound (... ...)) supply)))
             ----
             (#,wf-goal-id g (x_bound (... ...)) supply)])

          (redex-parameter:define-judgment-form*
            #,language-id
            #:mode (#,live-supply-one-id I I O)
            #:contract (#,live-supply-one-id W supply LiveNext)

            [(#,extend-supply-hook
              supply_in
              supply_local
              supply_out)
             ---------------------------------------- "work exposes supply"
             (#,live-supply-one-id
              #,wf-active-pattern
              supply_in
              (LiveDone supply_out))]

            [(#,extend-supply-hook
              supply_in
              supply_local
              supply_out)
             ---------------------------------------- "return exposes supply"
             (#,live-supply-one-id
              #,wf-returned-pattern
              supply_in
              (LiveDone supply_out))]

            [(#,extend-supply-hook
              supply_in
              supply_local
              supply_out)
             ---------------------------------------- "failure exposes supply"
             (#,live-supply-one-id
              #,wf-dead-pattern
              supply_in
              (LiveDone supply_out))]

            [#,@frame-prefix-premises
             ---------------------------------------- "supply through conjunction"
             (#,live-supply-one-id
              #,wf-conj-pattern
              supply_in
              (LiveContinue W supply_frame))])

          #,(render-selected-live-supply-driver
             language-id live-supply-id live-supply-one-id)

          (define-metafunction #,language-id
            #,failure-summary-id : any -> supply
            [(#,failure-summary-id #,wf-dead-pattern) supply_local]
            [(#,failure-summary-id #,wf-done-pattern) supply_local])

          (define-judgment-form
            #,language-id
            #:contract (#,wf-answer-id A supply)
            #:mode (#,wf-answer-id I I)
            [(#,extend-supply-hook
              supply_in
              supply_local
              supply_out)
             (#,wf-state-id #,wf-state-pattern supply_out)
             ---------------------------------------- "answer"
             (#,wf-answer-id #,wf-answer-pattern supply_in)])

          (define-judgment-form
            #,language-id
            #:contract (#,wf-returned-id S supply)
            #:mode (#,wf-returned-id I I)
            [(#,extend-supply-hook
              supply_in
              supply_local
              supply_out)
             (#,wf-state-id #,wf-state-pattern supply_out)
             ---------------------------------------- "returned"
             (#,wf-returned-id #,wf-returned-pattern supply_in)])

          ;; Work and frontier traversal share the same open task driver.
          ;; Delay extends only this nonrecursive classifier with Pending and
          ;; Forced cases; inherited Conj/More recursion then reaches those
          ;; cases through the exact-language `wf-node-next` dependency.
          (redex-parameter:define-judgment-form*
            #,language-id
            #:parameters
            ([wf-node-goal #,wf-goal-id]
             [wf-node-live #,live-supply-id])
            #:mode (#,wf-node-case-id I O)
            #:contract (#,wf-node-case-id WFNode WFNodes)

            [(#,extend-supply-hook
              supply_in
              supply_local
              supply_out)
             (wf-node-goal g () supply_out)
             (#,wf-state-id #,wf-state-pattern supply_out)
             ---------------------------------------- "active work"
             (#,wf-node-case-id
              (WorkCheck #,wf-active-pattern supply_in)
              (NodeChecks))]

            [(#,wf-returned-id #,wf-returned-pattern supply_in)
             ---------------------------------------- "returned work"
             (#,wf-node-case-id
              (WorkCheck #,wf-returned-pattern supply_in)
              (NodeChecks))]

            [(#,extend-supply-hook
              supply_in
              supply_local
              supply_out)
             (#,valid-supply-hook supply_out)
             ---------------------------------------- "dead work"
             (#,wf-node-case-id
              (WorkCheck #,wf-dead-pattern supply_in)
              (NodeChecks))]

            [#,@frame-prefix-premises
             #,@conjunction-goal-supply-premises
             (wf-node-goal g () supply_goal)
             ---------------------------------------- "conjunction frame"
             (#,wf-node-case-id
              (WorkCheck #,wf-conj-pattern supply_in)
              (NodeChecks (WorkCheck W supply_frame)))]

            [---------------------------------------- "unfinished frontier"
             (#,wf-node-case-id
              (FrontierCheck #,wf-more-pattern supply_in)
              (NodeChecks (WorkCheck W supply_in)))]

            [#,@terminal-prefix-premises
             (#,wf-answer-id A supply_prefix)
             ---------------------------------------- "successful terminal"
             (#,wf-node-case-id
              (FrontierCheck #,wf-last-pattern supply_in)
              (NodeChecks))]

            [(#,extend-supply-hook
              supply_in
              supply_local
              supply_out)
             (#,valid-supply-hook supply_out)
             ---------------------------------------- "failed terminal"
             (#,wf-node-case-id
              (FrontierCheck #,wf-done-pattern supply_in)
              (NodeChecks))])

          (redex-parameter:define-judgment-form*
            #,language-id
            #:parameters ([wf-node-next #,wf-node-case-id])
            #:mode (#,wf-nodes-id I)
            #:contract (#,wf-nodes-id WFNodes)
            [----
             (#,wf-nodes-id (NodeChecks))]
            [(wf-node-next
              WFNode_0
              (NodeChecks WFNode_child (... ...)))
             (#,wf-nodes-id
              (NodeChecks
               WFNode_child (... ...)
               WFNode_rest (... ...)))
             ----
             (#,wf-nodes-id
              (NodeChecks WFNode_0 WFNode_rest (... ...)))])

          (redex-parameter:define-judgment-form*
            #,language-id
            #:parameters ([wf-work-run #,wf-nodes-id])
            #:mode (#,wf-work-id I I)
            #:contract (#,wf-work-id W supply)
            [(wf-work-run (NodeChecks (WorkCheck W supply_in)))
             ---------------------------------------- "unfinished frontier"
             (#,wf-work-id W supply_in)])

          (redex-parameter:define-judgment-form*
            #,language-id
            #:parameters ([wf-frontier-run #,wf-nodes-id])
            #:mode (#,wf-frontier-id I I)
            #:contract (#,wf-frontier-id F supply)
            [(wf-frontier-run
              (NodeChecks (FrontierCheck F supply_in)))
             ----
             (#,wf-frontier-id F supply_in)])

          (redex-parameter:define-judgment-form*
            #,language-id
            #:parameters ([wf-root-frontier #,wf-frontier-id])
            #:mode (#,wf-root-id I)
            #:contract (#,wf-root-id F)
            [(wf-root-frontier F #,empty-supply)
             ---------------------------------------- "generated core root"
             (#,wf-root-id F)]))
       (for/list ([symbol
                   (in-list
                    '(F A S W
                        sigma supply supply_in supply_local supply_out
                        supply_frame supply_goal supply_prefix
                        sub sub_next sub_acc sub_final
                        dis trail eq_rest
                        rv t t_1 t_2 t_3 t_4
                        x x_bound x_before x_after x_fresh
                        g g_1 g_2 tag))])
         (cons symbol (slot symbol)))))

    #`(begin
        #,@(if source-interface-id
               (list
                #`(define-syntax #,source-interface-id
                    (source-interface-binding
                     (quote-syntax #,selected-stage-view)
                     (quote-syntax #,language-id)
                     (quote-syntax
                      ([#,allocation-subst-goal-id #,subst-goal-artifact-id]
                       [#,allocation-work-focus-prefix-id
                        #,work-focus-prefix-id]))
                     (quote-syntax #,branch-copy-id)
                     (quote-syntax #,work-raw-id)
                     (quote-syntax #,frontier-raw-id)
                     (quote-syntax #,allocation-raw-id)
                     (quote-syntax #,subst-goal-artifact-id)
                     (quote-syntax #,subst-goal-open-id)
                     (quote-syntax #,wf-root-id)
                     (quote-syntax #,wf-goal-id)
                     (quote-syntax #,wf-answer-id)
                     (quote-syntax #,wf-returned-id)
                     (quote-syntax #,live-supply-id)
                     (quote-syntax #,failure-summary-id)
                     (quote-syntax #,wf-work-id)
                     (quote-syntax #,wf-frontier-id)
                     (quote-syntax #,wf-goal-case-id)
                     (quote-syntax #,wf-goal-tasks-id)
                     (quote-syntax #,live-supply-one-id)
                     (quote-syntax #,wf-node-case-id)
                     (quote-syntax #,wf-nodes-id)
                     (quote-syntax #,(state supply-v sub-v dis-v trail-v state-tag))
                     (quote-syntax #,(answer supply-v sigma-v))
                     (quote-syntax #,(returned supply-v sigma-v))
                     (quote-syntax #,(work supply-v g-v sigma-v))
                     (quote-syntax #,(dead supply-v))
                     (quote-syntax #,(conj supply-v W-v g-v))
                     (quote-syntax #,(last supply-v A-v))
                     (quote-syntax #,(more W-v))
                     (quote-syntax #,work-focus-prefix-id)
                     (quote-syntax
                      #,(optional-public-hook work-focus-prefix-open))
                     (quote-syntax #,empty-supply)
                     (quote-syntax '())
                     (quote-syntax (#,@extension-prefix-premises))
                     (quote-syntax
                      #,(optional-public-hook
                         (prefix-info-transfer-work prefix)))
                     (quote-syntax
                      #,(optional-public-hook
                         (prefix-info-transfer-work-open prefix)))
                     (quote-syntax
                      #,(optional-public-hook
                         (prefix-info-q-export-local prefix)))
                     (quote-syntax
                      #,(optional-public-hook
                         (prefix-info-q-rebuild-local prefix)))
                     (quote-syntax
                      #,(optional-public-hook
                         (q-info-work-export-open q-open)))
                     (quote-syntax
                      #,(optional-public-hook
                         (q-info-work-support-open q-open)))
                     (quote-syntax
                      #,(optional-public-hook
                         (q-info-work-rebuild-open q-open)))
                     (quote-syntax
                      #,(optional-public-hook
                         (q-info-frontier-export-open q-open)))
                     (quote-syntax
                      #,(optional-public-hook
                         (q-info-frontier-support-open q-open)))
                     (quote-syntax
                      #,(optional-public-hook
                         (q-info-frontier-rebuild-open q-open)))
                     (quote-syntax
                      #,(optional-public-hook
                         (q-info-path-export-open q-open)))
                     (quote-syntax
                      #,(optional-public-hook
                         (q-info-path-rebuild-open q-open)))
                     (quote-syntax
                      #,(optional-public-hook
                         (q-info-failure-export q-open)))
                     (quote-syntax
                      #,(optional-public-hook
                         (q-info-failure-rebuild q-open)))
                     (quote-syntax
                      #,(optional-public-hook
                         (q-info-address-goal-open q-open)))
                     (quote-syntax #,(public-hook q-export))
                     (quote-syntax #,(public-hook q-rebuild))
                     (quote-syntax #,(public-hook q-focus-export))
                     (quote-syntax #,(public-hook q-focus-rebuild))
                     (quote-syntax #,(public-hook q-root-focus-export))
                     (quote-syntax #,(public-hook q-root-focus-rebuild))
                     (quote-syntax #,(public-hook q-failure-focus-export))
                     (quote-syntax #,(public-hook q-failure-focus-rebuild))
                     (quote-syntax #,(public-hook q-terminal-export))
                     (quote-syntax #,(public-hook q-terminal-rebuild)))))
               '())
        (define-language #,language-id
          [d (x_!_ (... ...))]
          [alloc ((x_!_ rv) (... ...))]
          [support (rv_!_ (... ...))]
          [eq (t =? t tag)]
          [g eq
             (t != t tag)
             (succeed tag)
             (fail tag)
             (∃ d g tag)
             (g ∧ g tag)]
          [t x rv pt (t : t)]
          [pt (sym string)
              (nat number)
              boolean
              (str string)
              empty]
          [x (variable-prefix x:)]
          [rv #,(variable-info-runtime-production variable)]
          [tag (label string)]
          [sigma #,(supply-info-state supply)]
          [sub ((rv_!_ t) (... ...))]
          [dis ((t t) (... ...))]
          [maybe-sub sub #f]
          [trail (eq (... ...))]
          #,@(variable-info-productions variable)
          #,@(supply-info-productions supply)
          [A #,(supply-info-answer supply)]
          [S #,(supply-info-returned supply)]
          [W #,(supply-info-work supply)
             #,(supply-info-returned supply)
             #,(supply-info-dead supply)
             #,grammar-conj]
          [F #,(supply-info-last supply)
             #,(supply-info-done supply)
             #,(supply-info-more supply)]
          [WorkPath hole #,path-conj]
          [SpineContext hole]
          [WorkFocus (in-hole SpineContext #,focus-more)]
          [WFGoalTask (GoalCheck g (x (... ...)) supply)]
          [WFGoalTasks (GoalChecks WFGoalTask (... ...))]
          [WFNode (WorkCheck W supply)
                  (FrontierCheck F supply)]
          [WFNodes (NodeChecks WFNode (... ...))]
          [LiveNext (LiveDone supply)
                    (LiveContinue W supply)]
          #:binding-forms
          (∃ (x (... ...)) g #:refers-to (shadow x (... ...))))

        ;; Feature schemas consume this ordinary static operation when a
        ;; branch duplicates one possible world's allocation supply.
        (define-metafunction #,language-id
          #,branch-copy-id : supply -> supply
          [(#,branch-copy-id #,supply-v) #,branch-copy-supply])

        (define-metafunction #,language-id
          #,walk-id : t sub -> t
          [(#,walk-id
            rv
            (name sub (_ (... ...) [rv t] _ (... ...))))
           (#,walk-id t sub)]
          [(#,walk-id t _) t])

        (define-relation #,language-id
          #,occurs-id ⊆ rv × t × sub
          [(#,occurs-id rv (t : _) sub)
           (#,occurs-id rv (#,walk-id t sub) sub)]
          [(#,occurs-id rv (_ : t) sub)
           (#,occurs-id rv (#,walk-id t sub) sub)]
          [(#,occurs-id rv_1 rv_1 sub)])

        (define-metafunction #,language-id
          #,extend-id : rv t sub -> maybe-sub
          [(#,extend-id rv t sub) #f
           (side-condition
            (judgment-holds (#,occurs-id rv t sub)))]
          [(#,extend-id rv t sub) ([rv t] ,@(term sub))
           (side-condition
            (not (judgment-holds (#,occurs-id rv t sub))))])

        (define-metafunction #,language-id
          #,unify-id : t t sub -> maybe-sub
          [(#,unify-id rv_1 rv_1 sub) sub]
          [(#,unify-id rv t sub) (#,extend-id rv t sub)]
          [(#,unify-id t rv sub) (#,extend-id rv t sub)]
          [(#,unify-id (t_1a : t_1b) (t_2a : t_2b) sub)
           (#,unify-id
            (#,walk-id t_1b sub_1)
            (#,walk-id t_2b sub_1)
            sub_1)
           (where sub_1
                  (#,unify-id
                   (#,walk-id t_1a sub)
                   (#,walk-id t_2a sub)
                   sub))]
          [(#,unify-id t_1 t_1 sub) sub]
          [(#,unify-id _ _ _) #f])

        (define-metafunction #,language-id
          #,invalid-id : sub dis -> boolean
          [(#,invalid-id sub ()) #f]
          [(#,invalid-id
            sub
            ((t_1 t_2) (t_3 t_4) (... ...)))
           #t
           (where sub
                  (#,unify-id
                   (#,walk-id t_1 sub)
                   (#,walk-id t_2 sub)
                   sub))]
          [(#,invalid-id
            sub
            ((t_1 t_2) (t_3 t_4) (... ...)))
           (#,invalid-id sub ((t_3 t_4) (... ...)))])

        (define (#,lexical-variable-id datum)
          (and (symbol? datum)
               (regexp-match? #rx"^x:" (symbol->string datum))))

        (define (#,subst-term-id term substitutions)
          (match term
            [(? #,lexical-variable-id x)
             (match (assoc x substitutions)
               [(list _ replacement) replacement]
               [#f x])]
            [`(,left : ,right)
             `(,(#,subst-term-id left substitutions)
               :
               ,(#,subst-term-id right substitutions))]
            [_ term]))

        (define (#,drop-shadowed-id binders substitutions)
          (match substitutions
            ['() '()]
            [(cons (and binding (list x _)) rest)
             (if (member x binders)
                 (#,drop-shadowed-id binders rest)
                 (cons binding
                       (#,drop-shadowed-id binders rest)))]))

        (define (#,subst-goal-open-id recur goal substitutions)
          (match goal
            [`(succeed ,goal-tag) `(succeed ,goal-tag)]
            [`(fail ,goal-tag) `(fail ,goal-tag)]
            [`(,left =? ,right ,goal-tag)
             `(,(#,subst-term-id left substitutions)
               =?
               ,(#,subst-term-id right substitutions)
               ,goal-tag)]
            [`(,left != ,right ,goal-tag)
             `(,(#,subst-term-id left substitutions)
               !=
               ,(#,subst-term-id right substitutions)
               ,goal-tag)]
            [`(,left ∧ ,right ,goal-tag)
             `(,(recur left substitutions)
               ∧
               ,(recur right substitutions)
               ,goal-tag)]
            [`(∃ ,binders ,body ,goal-tag)
             `(∃ ,binders
                 ,(recur
                   body
                   (#,drop-shadowed-id binders substitutions))
                 ,goal-tag)]
            [_
             (error '#,subst-goal-open-id
                    "unsupported generated core goal: ~e"
                    goal)]))

        (define (#,subst-goal-id goal substitutions)
          (#,subst-goal-open-id
           #,subst-goal-id
           goal
           substitutions))

        ;; Allocation depends on this exact-language object.  A feature
        ;; supplies one host-level open-recursive traversal and registers a
        ;; single catch-all extension at its source language; no inherited
        ;; allocation equation or core goal case is copied.
        (redex-parameter:define-metafunction*
          #,language-id
          #,subst-goal-artifact-id : g alloc -> g
          [(#,subst-goal-artifact-id g alloc)
           ,(#,subst-goal-id (term g) (term alloc))])

        #,@variable-definitions
        #,@supply-definitions
        #,@wf-definitions
        #,@q-definitions

        #,@(if (syntax-e work-focus-prefix-open)
               (list
                #`(define (#,work-focus-prefix-host-id focus support)
                    (#,(public-hook work-focus-prefix-open)
                     focus
                     support
                     #,work-focus-prefix-host-id))
                #`(redex-parameter:define-metafunction*
                    #,language-id
                    #,work-focus-prefix-id : WorkFocus support -> support
                    [(#,work-focus-prefix-id WorkFocus support)
                     ,(#,work-focus-prefix-host-id
                       (term WorkFocus)
                       (term support))]))
               (list
                #`(redex-parameter:define-metafunction*
                    #,language-id
                    #,work-focus-prefix-id : WorkFocus support -> support
                    [(#,work-focus-prefix-id WorkFocus support) support])))
        #,wf-structural-definitions

        ;; R is one renderer of the shared 13-equation compile-time IR.
        (redex-parameter:define-reduction-relation*
          #,work-raw-id
          #,language-id
          #:domain any
          #,@work-R-rules)

        (redex-parameter:define-reduction-relation*
          #,frontier-raw-id
          #,language-id
          #:domain any
          #,@frontier-R-rules)

        (redex-parameter:define-reduction-relation*
          #,allocation-raw-id
          #,language-id
          #:parameters
          ([#,allocation-subst-goal-id #,subst-goal-artifact-id]
           [#,allocation-work-focus-prefix-id #,work-focus-prefix-id])
          #:domain F
          #,@allocation-R-rules)

        (define #,work-base-id
          (context-closure #,work-raw-id #,language-id WorkFocus))

        (define #,frontier-base-id
          (context-closure
           #,frontier-raw-id
           #,language-id
           SpineContext))

        (define #,relation-id
          (extend-reduction-relation
           (union-reduction-relations
            #,work-base-id
            #,frontier-base-id
            #,allocation-raw-id)
           #,language-id
           #:domain F))

        (define (#,raw-successors-id frontier)
          (for/list ([named-step
                      (in-list
                       (apply-reduction-relation/tag-with-names
                        #,relation-id
                        frontier))])
            (match-define (list name target) named-step)
            (list (string->symbol (~a name)) target)))))

  (define (render-representation-maps s-strategy
                                      e-strategy
                                      n-strategy
                                      q-se-id
                                      q-en-id
                                      q-sn-id
                                      composition-id)
    ;; A strategy and a map consumer may be expanded in separate macro turns.
    ;; Recontextualizing the declared public hook name at the consumer site
    ;; resolves the ordinary binding emitted by the source instance, without
    ;; rewriting any hook body or quoted datum.
    (define (consumer-hook declared-id)
      (datum->syntax q-se-id
                     (syntax-e declared-id)
                     q-se-id
                     q-se-id))
    (define s-export
      (consumer-hook
       (q-info-export
        (supply-info-q (strategy-info-supply s-strategy)))))
    (define e-export
      (consumer-hook
       (q-info-export
        (supply-info-q (strategy-info-supply e-strategy)))))
    (define e-rebuild
      (consumer-hook
       (q-info-rebuild
        (supply-info-q (strategy-info-supply e-strategy)))))
    (define n-rebuild
      (consumer-hook
       (q-info-rebuild
        (supply-info-q (strategy-info-supply n-strategy)))))
    #`(begin
        (define (#,q-se-id frontier)
          (#,e-rebuild (#,s-export frontier)))

        (define (#,q-en-id frontier)
          (#,n-rebuild (#,e-export frontier)))

        ;; The direct map deliberately consumes S's export.  It does not call
        ;; either adjacent map or the middle representation's export hook.
        (define (#,q-sn-id frontier)
          (#,n-rebuild (#,s-export frontier)))

        (define (#,composition-id frontier)
          (equal? (#,q-sn-id frontier)
                  (#,q-en-id (#,q-se-id frontier)))))))

(define-syntax (define-core-representation-strategy stx)
  (syntax-parse stx
    [(_ name:id . _)
     (parse-strategy stx)
     #`(define-syntax name
         (strategy-binding (quote-syntax #,stx)))]))

(define-syntax (define-generated-core-source stx)
  (syntax-parse stx
    [(_ #:strategy strategy-id:id
        #:language language-id:id
        #:relation relation-id:id
        #:raw-successors raw-successors-id:id
        #:branch-copy branch-copy-id:id
        (~optional
         (~seq #:source-interface source-interface-id:id)
         #:defaults ([source-interface-id #'#f])))
     (render-source-instance
      (lookup-strategy #'strategy-id)
      stx
      #'language-id
      #'relation-id
      #'raw-successors-id
      #'branch-copy-id
      (and (syntax-e #'source-interface-id)
           #'source-interface-id))]))

(define-syntax (define-generated-core-representation-maps stx)
  (syntax-parse stx
    [(_ #:s-strategy s-strategy-id:id
        #:e-strategy e-strategy-id:id
        #:n-strategy n-strategy-id:id
        #:Q-SE q-se-id:id
        #:Q-EN q-en-id:id
        #:Q-SN q-sn-id:id
        #:composition composition-id:id)
     (render-representation-maps
      (lookup-strategy #'s-strategy-id)
      (lookup-strategy #'e-strategy-id)
      (lookup-strategy #'n-strategy-id)
      #'q-se-id
      #'q-en-id
      #'q-sn-id
      #'composition-id)]))
