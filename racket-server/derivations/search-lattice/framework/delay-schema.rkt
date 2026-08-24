#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: "./core-redex-parameter.rkt")
         "./core-source-schema.rkt"
         "./core-stage-renderers.rkt"
         (for-syntax racket/base
                     racket/list
                     racket/match
                     racket/syntax
                     syntax/parse))

(provide define-delay-representation-view
         define-generated-delay-source
         define-generated-delay-stage-extension)

;; Delay is a feature schema over a selected core source.  The descriptor owns
;; only the representation of the two new wrappers; every core carrier,
;; traversal, and relation is supplied through the source extension visitor.
(begin-for-syntax
  (struct delay-view-binding (declaration)
    #:property prop:procedure
    (lambda (_self use-stx)
      (raise-syntax-error
       #f
       "a Delay representation view is valid only after #:representation"
       use-stx)))

  (struct delay-view-info
    (pending pending-prefix forced forced-prefix transfer-pending declaration)
    #:transparent)

  (struct delay-stage-extension-info (force-target)
    #:transparent)

  (struct delay-source-binding
    (language redex-parameters relation raw-successors branch-copy
     work-raw frontier-raw allocation-raw
     subst-goal subst-goal-open
     wf-root wf-goal wf-answer wf-returned
     live-supply failure-summary wf-work wf-frontier
     wf-goal-case wf-goal-tasks live-case wf-node-case wf-nodes
     state-template answer-template returned-template
     work-template dead-template conj-template last-template more-template
     work-focus-prefix work-focus-prefix-open
     prefix-empty q-prefix-empty prefix-extend-premises
     pending-template pending-prefix-template
     forced-template forced-prefix-template
     transfer-work transfer-work-open transfer-work-host
     q-export-local q-rebuild-local
     q-work-export-open q-work-support-open q-work-rebuild-open
     q-frontier-export-open q-frontier-support-open q-frontier-rebuild-open
     q-path-export-open q-path-rebuild-open
     q-failure-export q-failure-rebuild q-address-goal-open
     q-frontier-export-context-open
     q-frontier-support-context-open
     q-frontier-rebuild-context-open
     q-spine-export-open q-spine-rebuild-open
     q-focus-shape-open q-focus-shape-rebuild-open
     q-export q-rebuild
     q-focus-export q-focus-rebuild
     q-root-focus-export q-root-focus-rebuild
     q-failure-focus-export q-failure-focus-rebuild
     q-terminal-export q-terminal-rebuild)
    #:property prop:procedure
    (lambda (self use-stx)
      (syntax-parse use-stx
        [(_ #:visit visitor:id argument ...)
         #`(visitor
            #:language #,(delay-source-binding-language self)
            #:Q-export #,(delay-source-binding-q-export self)
            #:Q-rebuild #,(delay-source-binding-q-rebuild self)
            #:Q-focus-export #,(delay-source-binding-q-focus-export self)
            #:Q-focus-rebuild #,(delay-source-binding-q-focus-rebuild self)
            #:Q-root-focus-export
            #,(delay-source-binding-q-root-focus-export self)
            #:Q-root-focus-rebuild
            #,(delay-source-binding-q-root-focus-rebuild self)
            #:Q-failure-focus-export
            #,(delay-source-binding-q-failure-focus-export self)
            #:Q-failure-focus-rebuild
            #,(delay-source-binding-q-failure-focus-rebuild self)
            #:Q-terminal-export #,(delay-source-binding-q-terminal-export self)
            #:Q-terminal-rebuild
            #,(delay-source-binding-q-terminal-rebuild self)
            argument ...)]
        [(_ #:visit-delay visitor:id argument ...)
         #`(visitor
            #:language #,(delay-source-binding-language self)
            #:relation #,(delay-source-binding-relation self)
            #:R-work-raw #,(delay-source-binding-work-raw self)
            #:R-frontier-raw #,(delay-source-binding-frontier-raw self)
            #:R-allocation-raw #,(delay-source-binding-allocation-raw self)
            #:wf-root #,(delay-source-binding-wf-root self)
            #:live-supply #,(delay-source-binding-live-supply self)
            #:failure-summary #,(delay-source-binding-failure-summary self)
            #:Q-export #,(delay-source-binding-q-export self)
            #:Q-rebuild #,(delay-source-binding-q-rebuild self)
            #:Q-focus-export #,(delay-source-binding-q-focus-export self)
            #:Q-focus-rebuild #,(delay-source-binding-q-focus-rebuild self)
            #:Q-root-focus-export
            #,(delay-source-binding-q-root-focus-export self)
            #:Q-root-focus-rebuild
            #,(delay-source-binding-q-root-focus-rebuild self)
            #:Q-failure-focus-export
            #,(delay-source-binding-q-failure-focus-export self)
            #:Q-failure-focus-rebuild
            #,(delay-source-binding-q-failure-focus-rebuild self)
            #:Q-terminal-export #,(delay-source-binding-q-terminal-export self)
            #:Q-terminal-rebuild
            #,(delay-source-binding-q-terminal-rebuild self)
            argument ...)]
        [(_ #:visit-extension visitor:id argument ...)
         #`(visitor
            #:language #,(delay-source-binding-language self)
            #:redex-parameters
            #,(delay-source-binding-redex-parameters self)
            #:branch-copy #,(delay-source-binding-branch-copy self)
            #:R-work-raw #,(delay-source-binding-work-raw self)
            #:R-frontier-raw #,(delay-source-binding-frontier-raw self)
            #:R-allocation-raw #,(delay-source-binding-allocation-raw self)
            #:subst-goal #,(delay-source-binding-subst-goal self)
            #:subst-goal-open #,(delay-source-binding-subst-goal-open self)
            #:wf-root #,(delay-source-binding-wf-root self)
            #:wf-goal #,(delay-source-binding-wf-goal self)
            #:wf-answer #,(delay-source-binding-wf-answer self)
            #:wf-returned #,(delay-source-binding-wf-returned self)
            #:live-supply #,(delay-source-binding-live-supply self)
            #:failure-summary
            #,(delay-source-binding-failure-summary self)
            #:wf-work #,(delay-source-binding-wf-work self)
            #:wf-frontier #,(delay-source-binding-wf-frontier self)
            #:WF-open
            [#:goal-case #,(delay-source-binding-wf-goal-case self)
             #:goal-tasks #,(delay-source-binding-wf-goal-tasks self)
             #:live-case #,(delay-source-binding-live-case self)
             #:node-case #,(delay-source-binding-wf-node-case self)
             #:nodes #,(delay-source-binding-wf-nodes self)]
            #:carrier-view
            [#:state #,(delay-source-binding-state-template self)
             #:answer #,(delay-source-binding-answer-template self)
             #:returned #,(delay-source-binding-returned-template self)
             #:work #,(delay-source-binding-work-template self)
             #:dead #,(delay-source-binding-dead-template self)
             #:conj #,(delay-source-binding-conj-template self)
             #:last #,(delay-source-binding-last-template self)
             #:more #,(delay-source-binding-more-template self)
             #:empty-supply #,(delay-source-binding-prefix-empty self)]
            #:prefix-view
            [#:extend-premises
             (#,@(syntax->list
                  (delay-source-binding-prefix-extend-premises self)))
             #:Q-empty
             #,(delay-source-binding-q-prefix-empty self)
             #:work-focus-support
             #,(delay-source-binding-work-focus-prefix self)
             #:work-focus-support-open
             #,(delay-source-binding-work-focus-prefix-open self)
             #:transfer-work
             #,(delay-source-binding-transfer-work self)
             #:transfer-work-open
             #,(delay-source-binding-transfer-work-open self)
             #:transfer-work-host
             #,(delay-source-binding-transfer-work-host self)
             #:Q-export-local
             #,(delay-source-binding-q-export-local self)
             #:Q-rebuild-local
             #,(delay-source-binding-q-rebuild-local self)]
            #:Q-open
            [#:work-export
             #,(delay-source-binding-q-work-export-open self)
             #:work-support
             #,(delay-source-binding-q-work-support-open self)
             #:work-rebuild
             #,(delay-source-binding-q-work-rebuild-open self)
             #:frontier-export
             #,(delay-source-binding-q-frontier-export-open self)
             #:frontier-support
             #,(delay-source-binding-q-frontier-support-open self)
             #:frontier-rebuild
             #,(delay-source-binding-q-frontier-rebuild-open self)
             #:path-export
             #,(delay-source-binding-q-path-export-open self)
             #:path-rebuild
             #,(delay-source-binding-q-path-rebuild-open self)
             #:failure-export
             #,(delay-source-binding-q-failure-export self)
             #:failure-rebuild
             #,(delay-source-binding-q-failure-rebuild self)
             #:address-goal
             #,(delay-source-binding-q-address-goal-open self)]
            #:Q-context-open
            [#:frontier-export
             #,(delay-source-binding-q-frontier-export-context-open self)
             #:frontier-support
             #,(delay-source-binding-q-frontier-support-context-open self)
             #:frontier-rebuild
             #,(delay-source-binding-q-frontier-rebuild-context-open self)
             #:spine-export
             #,(delay-source-binding-q-spine-export-open self)
             #:spine-rebuild
             #,(delay-source-binding-q-spine-rebuild-open self)
             #:focus-shape
             #,(delay-source-binding-q-focus-shape-open self)
             #:focus-shape-rebuild
             #,(delay-source-binding-q-focus-shape-rebuild-open self)]
            argument ...)]
        [(_ #:instantiate-with _renderer:id #:instance _instance:id)
         (raise-syntax-error
          #f
          (string-append
           "Delay sources are staged by applying their feature extension to "
           "an already-generated core row")
          use-stx)]
        [_
         (raise-syntax-error
          #f
          "a generated Delay source is valid only through its visitor protocol"
          use-stx)])))

  (define (parse-delay-view-declaration declaration)
    (syntax-parse declaration
      [(_ _name:id
          #:pending pending
          #:pending-prefix pending-prefix
          #:forced forced
          #:forced-prefix forced-prefix
          (~optional
           (~seq #:transfer-pending transfer-pending:id)
           #:defaults ([transfer-pending #'#f])))
       (delay-view-info
        #'pending
        #'pending-prefix
        #'forced
        #'forced-prefix
        #'transfer-pending
        declaration)]))

  (define (parse-delay-view identifier)
    (define value (syntax-local-value identifier (lambda () #f)))
    (unless (delay-view-binding? value)
      (raise-syntax-error #f "expected a Delay representation view" identifier))
    (parse-delay-view-declaration
     (delay-view-binding-declaration value)))

  (define (instantiate-template template replacements)
    (define (walk datum)
      (cond
        [(identifier? datum)
         (match (assoc (syntax-e datum) replacements)
           [(cons _ replacement) replacement]
           [#f datum])]
        [(syntax? datum)
         (define value (syntax-e datum))
         (if (pair? value)
             (datum->syntax
              datum
              (cons (walk (car value)) (walk-tail (cdr value)))
              datum)
             datum)]
        [(pair? datum) (cons (walk (car datum)) (walk-tail (cdr datum)))]
        [else datum]))
    (define (walk-tail datum)
      (cond
        [(pair? datum) (cons (walk (car datum)) (walk-tail (cdr datum)))]
        [(syntax? datum) (walk datum)]
        [else datum]))
    (walk template))

  (define (render-delay-source use-stx view fields outputs)
    (match-define
      (list base-language base-redex-parameters
            base-branch-copy
            base-work-raw base-frontier-raw base-allocation-raw
            base-subst-goal base-subst-goal-open
            base-wf-root base-wf-goal base-wf-answer base-wf-returned
            base-live-supply base-failure-summary
            base-wf-work base-wf-frontier
            base-wf-goal-case base-wf-goal-tasks
            base-live-case base-wf-node-case base-wf-nodes
            state-template answer-template returned-template
            work-template dead-template conj-template last-template
            more-template empty-supply
            q-prefix-empty
            prefix-extend-premises
            base-work-focus-prefix base-work-focus-prefix-open
            base-transfer-work base-transfer-work-open
            q-export-local q-rebuild-local
            q-work-export-open q-work-support-open q-work-rebuild-open
            q-frontier-export-open q-frontier-support-open
            q-frontier-rebuild-open
            q-path-export-open q-path-rebuild-open
            q-failure-export q-failure-rebuild q-address-goal-open
            base-q-frontier-export-context-open
            base-q-frontier-support-context-open
            base-q-frontier-rebuild-context-open
            base-q-spine-export-open base-q-spine-rebuild-open
            base-q-focus-shape-open base-q-focus-shape-rebuild-open)
      fields)
    (match-define
      (list binding-id language-id relation-id raw-successors-id
            wf-root-id live-supply-id failure-summary-id
            q-export-id q-rebuild-id
            q-focus-export-id q-focus-rebuild-id
            q-root-focus-export-id q-root-focus-rebuild-id
            q-failure-focus-export-id q-failure-focus-rebuild-id
            q-terminal-export-id q-terminal-rebuild-id)
      outputs)

    (define (slot symbol)
      (datum->syntax language-id symbol language-id language-id))
    (define supply (slot 'supply))
    (define supply-in (slot 'supply_in))
    (define supply-local (slot 'supply_local))
    (define supply-out (slot 'supply_out))
    (define supply-body (slot 'supply_body))
    (define g (slot 'g))
    (define tag (slot 'tag))
    (define sigma (slot 'sigma))
    (define W (slot 'W))
    (define W-attached (slot 'W_attached))
    (define F (slot 'F))
    (define WorkPath (slot 'WorkPath))
    (define SpineContext (slot 'SpineContext))
    (define WorkFocus (slot 'WorkFocus))
    (define support (slot 'support))
    (define alloc (slot 'alloc))

    (define (view-term template replacements)
      (instantiate-template template replacements))
    (define (match-pattern template replacements)
      #`(quasiquote
         #,(instantiate-template
            template
            (for/list ([replacement (in-list replacements)])
              (cons (car replacement)
                    #`(unquote #,(cdr replacement)))))))
    (define (host-expression template replacements)
      #`(quasiquote
         #,(instantiate-template
            template
            (for/list ([replacement (in-list replacements)])
              (cons (car replacement)
                    #`(unquote #,(cdr replacement)))))))
    (define pending
      (lambda (local body)
        (view-term
         (delay-view-info-pending view)
         (list (cons 'supply local) (cons 'W body)))))
    (define forced
      (lambda (local frontier)
        (view-term
         (delay-view-info-forced view)
         (list (cons 'supply local) (cons 'F frontier)))))
    (define pending-expression
      (lambda (local body)
        (host-expression
         (delay-view-info-pending view)
         (list (cons 'supply local) (cons 'W body)))))
    (define forced-expression
      (lambda (local frontier)
        (host-expression
         (delay-view-info-forced view)
         (list (cons 'supply local) (cons 'F frontier)))))
    (define more-expression
      (lambda (body)
        (host-expression more-template (list (cons 'W body)))))
    (define (pending-prefix local)
      (view-term
       (delay-view-info-pending-prefix view)
       (list (cons 'supply local) (cons 'empty empty-supply))))
    (define (forced-prefix local)
      (view-term
       (delay-view-info-forced-prefix view)
       (list (cons 'supply local) (cons 'empty empty-supply))))
    (define (pending-prefix-expression local)
      (host-expression
       (delay-view-info-pending-prefix view)
       (list (cons 'supply local)
             (cons 'empty #`(term #,empty-supply)))))
    (define (forced-prefix-expression local)
      (host-expression
       (delay-view-info-forced-prefix view)
       (list (cons 'supply local)
             (cons 'empty #`(term #,empty-supply)))))
    (define (core-work local goal state)
      (view-term
       work-template
       (list (cons 'supply local) (cons 'g goal) (cons 'sigma state))))
    (define (core-conj local body goal)
      (view-term
       conj-template
       (list (cons 'supply local) (cons 'W body) (cons 'g goal))))
    (define (core-more body)
      (view-term more-template (list (cons 'W body))))

    (define work-raw-id (format-id relation-id "~a/work-raw" relation-id))
    (define frontier-raw-id
      (format-id relation-id "~a/frontier-raw" relation-id))
    (define allocation-raw-id
      (format-id relation-id "~a/allocation-raw" relation-id))
    (define work-base-id (format-id relation-id "~a/work-base" relation-id))
    (define frontier-base-id
      (format-id relation-id "~a/frontier-base" relation-id))
    (define subst-goal-host-id
      (format-id relation-id "~a/subst-goal/host" relation-id))
    (define subst-goal-open-id
      (format-id relation-id "~a/subst-goal/open" relation-id))
    (define subst-goal-id
      (format-id relation-id "~a/subst-goal" relation-id))
    (define work-focus-host-id
      (format-id relation-id "~a/work-focus-prefix-support/host" relation-id))
    (define work-focus-open-id
      (format-id relation-id "~a/work-focus-prefix-support/open" relation-id))
    (define work-focus-id
      (format-id relation-id "~a/work-focus-prefix-support" relation-id))
    (define transfer-work-id
      (format-id relation-id "~a/transfer-work-prefix" relation-id))
    (define transfer-work-open-id
      (format-id relation-id "~a/transfer-work-prefix/open" relation-id))
    (define transfer-work-direct-id
      (format-id relation-id "~a/transfer-work-prefix/direct" relation-id))
    (define work-transfer-parameter-id
      (format-id relation-id "~a/work-transfer" relation-id))

    (define wf-goal-case-id (format-id wf-root-id "~a/goal-case" wf-root-id))
    (define wf-goal-tasks-id
      (format-id wf-root-id "~a/goal-tasks" wf-root-id))
    (define wf-goal-id (format-id wf-root-id "~a/goal" wf-root-id))
    (define live-case-id (format-id live-supply-id "~a/one" live-supply-id))
    (define wf-node-case-id (format-id wf-root-id "~a/node-case" wf-root-id))
    (define wf-nodes-id (format-id wf-root-id "~a/nodes" wf-root-id))
    (define wf-work-id (format-id wf-root-id "~a/work" wf-root-id))
    (define wf-frontier-id (format-id wf-root-id "~a/frontier" wf-root-id))

    (define q-work-export-id (format-id q-export-id "~a/work" q-export-id))
    (define q-work-export-open-id
      (format-id q-export-id "~a/work/open" q-export-id))
    (define q-work-support-id (format-id q-export-id "~a/work-support" q-export-id))
    (define q-work-support-open-id
      (format-id q-export-id "~a/work-support/open" q-export-id))
    (define q-work-rebuild-id (format-id q-rebuild-id "~a/work" q-rebuild-id))
    (define q-work-rebuild-open-id
      (format-id q-rebuild-id "~a/work/open" q-rebuild-id))
    (define q-frontier-export-id
      (format-id q-export-id "~a/frontier" q-export-id))
    (define q-frontier-export-open-id
      (format-id q-export-id "~a/frontier/open" q-export-id))
    (define q-frontier-export-context-open-id
      (format-id q-export-id "~a/frontier/context-open" q-export-id))
    (define q-frontier-support-id
      (format-id q-export-id "~a/frontier-support" q-export-id))
    (define q-frontier-support-open-id
      (format-id q-export-id "~a/frontier-support/open" q-export-id))
    (define q-frontier-support-context-open-id
      (format-id q-export-id "~a/frontier-support/context-open" q-export-id))
    (define q-frontier-rebuild-id
      (format-id q-rebuild-id "~a/frontier" q-rebuild-id))
    (define q-frontier-rebuild-open-id
      (format-id q-rebuild-id "~a/frontier/open" q-rebuild-id))
    (define q-frontier-rebuild-context-open-id
      (format-id q-rebuild-id "~a/frontier/context-open" q-rebuild-id))
    (define q-path-export-id (format-id q-export-id "~a/path" q-export-id))
    (define q-path-export-composed-open-id
      (format-id q-export-id "~a/path/open" q-export-id))
    (define q-path-rebuild-id (format-id q-rebuild-id "~a/path" q-rebuild-id))
    (define q-path-rebuild-composed-open-id
      (format-id q-rebuild-id "~a/path/open" q-rebuild-id))
    (define q-spine-export-id (format-id q-export-id "~a/spine" q-export-id))
    (define q-spine-export-open-id
      (format-id q-export-id "~a/spine/open" q-export-id))
    (define q-spine-rebuild-id (format-id q-rebuild-id "~a/spine" q-rebuild-id))
    (define q-spine-rebuild-open-id
      (format-id q-rebuild-id "~a/spine/open" q-rebuild-id))
    (define q-focus-shape-id (format-id q-export-id "~a/focus-shape" q-export-id))
    (define q-focus-shape-open-id
      (format-id q-export-id "~a/focus-shape/open" q-export-id))
    (define q-focus-shape-rebuild-id
      (format-id q-rebuild-id "~a/focus-shape" q-rebuild-id))
    (define q-focus-shape-rebuild-open-id
      (format-id q-rebuild-id "~a/focus-shape/open" q-rebuild-id))
    (define q-address-goal-id
      (format-id q-rebuild-id "~a/address-goal" q-rebuild-id))
    (define q-address-goal-composed-open-id
      (format-id q-rebuild-id "~a/address-goal/open" q-rebuild-id))

    (define pending-grammar (pending supply W))
    (define forced-grammar (forced supply F))
    (define forced-spine (forced supply SpineContext))
    (define pending-match
      (match-pattern
       (delay-view-info-pending view)
       (list (cons 'supply supply-local) (cons 'W W))))
    (define forced-match
      (match-pattern
       (delay-view-info-forced view)
       (list (cons 'supply supply-local) (cons 'F F))))
    (define forced-spine-match
      (match-pattern
       (delay-view-info-forced view)
       (list (cons 'supply supply-local)
             (cons 'F SpineContext))))
    (define more-match
      (match-pattern more-template (list (cons 'W WorkPath))))
    (define suspended-work
      (core-work supply #`(suspend #,g #,tag) sigma))
    (define resumed-work (core-work empty-supply g sigma))
    (define suspended-target (pending (pending-prefix supply) resumed-work))
    (define bubble-source
      (core-conj supply-in (pending supply-local W) g))
    (define bubble-target
      (pending
       (pending-prefix supply-in)
       (core-conj empty-supply W-attached g)))
    (define force-source (core-more (pending supply-local W)))
    (define force-target
      (forced (forced-prefix supply-local) (core-more W)))

    (define pending-wf-prefix
      (for/list ([premise (in-list prefix-extend-premises)])
        (instantiate-template
         premise
         (list (cons 'supply_in supply-in)
               (cons 'supply_local (pending-prefix supply-local))
               (cons 'supply_out supply-body)))))
    (define forced-wf-prefix
      (for/list ([premise (in-list prefix-extend-premises)])
        (instantiate-template
         premise
         (list (cons 'supply_in supply-in)
               (cons 'supply_local (forced-prefix supply-local))
               (cons 'supply_out supply-body)))))

    (define transfer-pending (delay-view-info-transfer-pending view))
    (define base-focus-open? (and base-work-focus-prefix-open
                                  (syntax-e base-work-focus-prefix-open)))
    (define base-transfer? (and base-transfer-work
                                (syntax-e base-transfer-work)))
    (define base-context-open?
      (and base-q-frontier-export-context-open
           (syntax-e base-q-frontier-export-context-open)))
    (define delay-redex-parameters
      (for/list ([parameter (in-list base-redex-parameters)])
        (match-define (cons local default) parameter)
        (cons
         local
         (cond
           [(free-identifier=? default base-subst-goal) subst-goal-id]
           [(free-identifier=? default base-work-focus-prefix) work-focus-id]
           [else default]))))
    (unless
        (for/or ([parameter (in-list delay-redex-parameters)])
          (free-identifier=? (cdr parameter) subst-goal-id))
      (raise-syntax-error
       #f
       "base source redex parameters omit the allocation substitution dependency"
       use-stx))
    (unless
        (for/or ([parameter (in-list delay-redex-parameters)])
          (free-identifier=? (cdr parameter) work-focus-id))
      (raise-syntax-error
       #f
       "base source redex parameters omit the allocation focus-prefix dependency"
       use-stx))

    #`(begin
        (define-syntax #,binding-id
          (delay-source-binding
           (quote-syntax #,language-id)
           (quote-syntax
            (#,@(for/list ([parameter (in-list delay-redex-parameters)])
                  #`[#,(car parameter) #,(cdr parameter)])))
           (quote-syntax #,relation-id)
           (quote-syntax #,raw-successors-id)
           (quote-syntax #,base-branch-copy)
           (quote-syntax #,work-raw-id)
           (quote-syntax #,frontier-raw-id)
           (quote-syntax #,allocation-raw-id)
           (quote-syntax #,subst-goal-id)
           (quote-syntax #,subst-goal-open-id)
           (quote-syntax #,wf-root-id)
           (quote-syntax #,wf-goal-id)
           (quote-syntax #,base-wf-answer)
           (quote-syntax #,base-wf-returned)
           (quote-syntax #,live-supply-id)
           (quote-syntax #,failure-summary-id)
           (quote-syntax #,wf-work-id)
           (quote-syntax #,wf-frontier-id)
           (quote-syntax #,wf-goal-case-id)
           (quote-syntax #,wf-goal-tasks-id)
           (quote-syntax #,live-case-id)
           (quote-syntax #,wf-node-case-id)
           (quote-syntax #,wf-nodes-id)
           (quote-syntax #,state-template)
           (quote-syntax #,answer-template)
           (quote-syntax #,returned-template)
           (quote-syntax #,work-template)
           (quote-syntax #,dead-template)
           (quote-syntax #,conj-template)
           (quote-syntax #,last-template)
           (quote-syntax #,more-template)
           (quote-syntax #,work-focus-id)
           (quote-syntax #,work-focus-open-id)
           (quote-syntax #,empty-supply)
           (quote-syntax #,q-prefix-empty)
           (quote-syntax (#,@prefix-extend-premises))
           (quote-syntax #,(delay-view-info-pending view))
           (quote-syntax #,(delay-view-info-pending-prefix view))
           (quote-syntax #,(delay-view-info-forced view))
           (quote-syntax #,(delay-view-info-forced-prefix view))
           (quote-syntax #,transfer-work-direct-id)
           (quote-syntax #,transfer-work-open-id)
           (quote-syntax #,transfer-work-id)
           (quote-syntax #,q-export-local)
           (quote-syntax #,q-rebuild-local)
           (quote-syntax #,q-work-export-open-id)
           (quote-syntax #,q-work-support-open-id)
           (quote-syntax #,q-work-rebuild-open-id)
           (quote-syntax #,q-frontier-export-open-id)
           (quote-syntax #,q-frontier-support-open-id)
           (quote-syntax #,q-frontier-rebuild-open-id)
           (quote-syntax #,q-path-export-composed-open-id)
           (quote-syntax #,q-path-rebuild-composed-open-id)
           (quote-syntax #,q-failure-export)
           (quote-syntax #,q-failure-rebuild)
           (quote-syntax #,q-address-goal-composed-open-id)
           (quote-syntax #,q-frontier-export-context-open-id)
           (quote-syntax #,q-frontier-support-context-open-id)
           (quote-syntax #,q-frontier-rebuild-context-open-id)
           (quote-syntax #,q-spine-export-open-id)
           (quote-syntax #,q-spine-rebuild-open-id)
           (quote-syntax #,q-focus-shape-open-id)
           (quote-syntax #,q-focus-shape-rebuild-open-id)
           (quote-syntax #,q-export-id)
           (quote-syntax #,q-rebuild-id)
           (quote-syntax #,q-focus-export-id)
           (quote-syntax #,q-focus-rebuild-id)
           (quote-syntax #,q-root-focus-export-id)
           (quote-syntax #,q-root-focus-rebuild-id)
           (quote-syntax #,q-failure-focus-export-id)
           (quote-syntax #,q-failure-focus-rebuild-id)
           (quote-syntax #,q-terminal-export-id)
           (quote-syntax #,q-terminal-rebuild-id)))

        (define-extended-language #,language-id #,base-language
          [g .... (suspend g tag)]
          [W .... #,pending-grammar]
          [F .... #,forced-grammar]
          [SpineContext .... #,forced-spine])

        (define (#,subst-goal-open-id recur goal substitutions)
          (match goal
            [`(suspend ,body ,goal-tag)
             `(suspend
               ,(recur body substitutions)
               ,goal-tag)]
            [_
             (#,base-subst-goal-open
              recur
              goal
              substitutions)]))

        (define (#,subst-goal-host-id goal substitutions)
          (#,subst-goal-open-id
           #,subst-goal-host-id
           goal
           substitutions))

        (redex-parameter:define-extended-metafunction*
          #,base-subst-goal
          #,language-id
          #,subst-goal-id : g alloc -> g
          [(#,subst-goal-id g alloc)
           ,(#,subst-goal-host-id (term g) (term alloc))])

        (define (#,work-focus-open-id focus support recur)
          (match focus
            [#,forced-spine-match
             (match-define (list _provenance support-next)
               (#,q-export-local
                #,(forced-prefix-expression supply-local)
                support))
             (recur #,SpineContext support-next)]
            [_
             #,(if base-focus-open?
                   #`(#,base-work-focus-prefix-open
                      focus support recur)
                   #'support)]))

        (define (#,work-focus-host-id focus support)
          (#,work-focus-open-id
           focus support #,work-focus-host-id))

        (redex-parameter:define-extended-metafunction*
          #,base-work-focus-prefix
          #,language-id
          #,work-focus-id : WorkFocus support -> support
          [(#,work-focus-id WorkFocus support)
           ,(#,work-focus-host-id (term WorkFocus) (term support))])

        (define (#,transfer-work-open-id prefix work extension)
          (match work
            [#,pending-match
             #,(if (syntax-e transfer-pending)
                   #`(#,transfer-pending prefix work)
                   #`(#,base-transfer-work-open
                      prefix work extension))]
            [_
             (#,base-transfer-work-open
              prefix work extension)]))

        (define (#,transfer-work-id prefix work)
          (#,transfer-work-open-id
           prefix
           work
           (lambda (_prefix unsupported)
             (error '#,transfer-work-id
                    "expected an extensible work carrier, received ~e"
                    unsupported))))

        #,@(if base-transfer?
               (list
                #`(redex-parameter:define-extended-metafunction*
                    #,base-transfer-work
                    #,language-id
                    #,transfer-work-direct-id : any W -> W
                    [(#,transfer-work-direct-id any_0 W)
                     ,(#,transfer-work-id
                       (term any_0)
                       (term W))]))
               (list
                #`(redex-parameter:define-metafunction*
                    #,language-id
                    #,transfer-work-direct-id : any W -> W
                    [(#,transfer-work-direct-id any_0 W)
                     ,(#,transfer-work-id
                       (term any_0)
                       (term W))])))

        (redex-parameter:define-extended-reduction-relation*
          #,work-raw-id
          #,base-work-raw
          #,language-id
          #:parameters
          ([#,work-transfer-parameter-id #,transfer-work-direct-id])
          #:domain any
          [--> #,suspended-work
               #,suspended-target
               "suspend-goal"]
          [--> #,bubble-source
               #,bubble-target
               (where #,W-attached
                      (#,work-transfer-parameter-id
                       #,(pending-prefix supply-local)
                       #,W))
               "bubble-delay-through-conj"])

        (redex-parameter:define-extended-reduction-relation*
          #,frontier-raw-id
          #,base-frontier-raw
          #,language-id
          #:domain any
          [--> #,force-source #,force-target "force-delay"])

        ;; The inherited allocation equation is reconstructed in this exact
        ;; language and automatically selects the two extensions above.
        (redex-parameter:define-extended-reduction-relation*
          #,allocation-raw-id
          #,base-allocation-raw
          #,language-id
          #:domain F)

        (define #,work-base-id
          (context-closure #,work-raw-id #,language-id WorkFocus))
        (define #,frontier-base-id
          (context-closure #,frontier-raw-id #,language-id SpineContext))
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
            (list (string->symbol (~a name)) target)))

        (redex-parameter:define-extended-judgment-form*
          #,base-wf-goal-case
          #,language-id
          #:mode (#,wf-goal-case-id I O)
          [----
           (#,wf-goal-case-id
            (GoalCheck
             (suspend g tag)
             (x_bound (... ...))
             supply_in)
            (GoalChecks
             (GoalCheck g (x_bound (... ...)) supply_in)))])

        (redex-parameter:define-extended-judgment-form*
          #,base-wf-goal-tasks
          #,language-id
          #:mode (#,wf-goal-tasks-id I)
          #:parameters ([wf-goal-next #,wf-goal-case-id]))

        (redex-parameter:define-extended-judgment-form*
          #,base-wf-goal
          #,language-id
          #:mode (#,wf-goal-id I I I)
          #:parameters ([wf-goal-run #,wf-goal-tasks-id]))

        (redex-parameter:define-extended-judgment-form*
          #,base-live-case
          #,language-id
          #:mode (#,live-case-id I I O)
          [#,@pending-wf-prefix
           ----
           (#,live-case-id
            #,(pending supply-local W)
            #,supply-in
            (LiveContinue #,W #,supply-body))])

        #,(render-selected-live-supply-driver
           language-id live-supply-id base-live-case)

        (redex-parameter:define-extended-judgment-form*
          #,base-wf-node-case
          #,language-id
          #:mode (#,wf-node-case-id I O)
          #:parameters
          ([wf-node-goal #,wf-goal-id]
           [wf-node-live #,live-supply-id])
          [#,@pending-wf-prefix
           ----
           (#,wf-node-case-id
            (WorkCheck #,(pending supply-local W) #,supply-in)
            (NodeChecks (WorkCheck #,W #,supply-body)))]
          [#,@forced-wf-prefix
           ----
           (#,wf-node-case-id
            (FrontierCheck #,(forced supply-local F) #,supply-in)
            (NodeChecks (FrontierCheck #,F #,supply-body)))])

        (redex-parameter:define-extended-judgment-form*
          #,base-wf-nodes
          #,language-id
          #:mode (#,wf-nodes-id I)
          #:parameters ([wf-node-next #,wf-node-case-id]))

        (redex-parameter:define-extended-judgment-form*
          #,base-wf-work
          #,language-id
          #:mode (#,wf-work-id I I)
          #:parameters ([wf-work-run #,wf-nodes-id]))

        (redex-parameter:define-extended-judgment-form*
          #,base-wf-frontier
          #,language-id
          #:mode (#,wf-frontier-id I I)
          #:parameters ([wf-frontier-run #,wf-nodes-id]))

        (redex-parameter:define-extended-judgment-form*
          #,base-wf-root
          #,language-id
          #:mode (#,wf-root-id I)
          #:parameters ([wf-root-frontier #,wf-frontier-id]))

        (define-metafunction #,language-id
          #,failure-summary-id : any -> supply
          [(#,failure-summary-id any_0)
           (#,base-failure-summary any_0)])

        ;; Prefix-aware open Q traversal.  The base row owns every core case;
        ;; this schema owns only Pending, Forced, and the spine shell.
        (define (#,q-address-goal-composed-open-id recur goal support)
          (match goal
            [`(suspend ,body ,goal-tag)
             `(suspend
               ,(recur body support)
               ,goal-tag)]
            [_
             (#,q-address-goal-open
              recur goal support)]))

        (define (#,q-address-goal-id goal support)
          (#,q-address-goal-composed-open-id
           #,q-address-goal-id goal support))

        (define (#,q-work-export-open-id work support recur)
          (match work
            [#,pending-match
             (match-define (list provenance support-next)
               (#,q-export-local
                #,(pending-prefix-expression supply-local)
                support))
             `(q-pending
               ,provenance
               ,(recur #,W support-next))]
            [_
             (#,q-work-export-open
              work support recur)]))

        (define (#,q-work-export-id work support)
          (#,q-work-export-open-id
           work support #,q-work-export-id))

        (define (#,q-work-support-open-id neutral recur)
          (match neutral
            [`(q-pending ,_provenance ,q-work)
             (recur q-work)]
            [_
             (#,q-work-support-open
              neutral recur)]))

        (define (#,q-work-support-id neutral)
          (#,q-work-support-open-id
           neutral #,q-work-support-id))

        (define (#,q-work-rebuild-open-id neutral support recur map-goal)
          (match neutral
            [`(q-pending ,provenance ,q-work)
             #,(pending-expression
                #`(#,q-rebuild-local provenance)
                #`(recur q-work support))]
            [_
             (#,q-work-rebuild-open
              neutral
              support
              recur
              map-goal)]))

        (define (#,q-work-rebuild-id neutral support)
          (#,q-work-rebuild-open-id
           neutral support #,q-work-rebuild-id #,q-address-goal-id))

        (define (#,q-frontier-export-context-open-id
                 frontier support recur-work recur-frontier)
          (match frontier
            [#,forced-match
             (match-define (list provenance support-next)
               (#,q-export-local
                #,(forced-prefix-expression supply-local)
                support))
             `(q-forced
               ,provenance
               ,(recur-frontier #,F support-next))]
            [_
             #,(if base-context-open?
                   #`(#,base-q-frontier-export-context-open
                      frontier support recur-work recur-frontier)
                   #`(#,q-frontier-export-open
                      frontier support recur-work))]))

        (define (#,q-frontier-export-open-id frontier support recur-work)
          (#,q-frontier-export-context-open-id
           frontier support recur-work #,q-frontier-export-id))

        (define (#,q-frontier-export-id frontier support)
          (#,q-frontier-export-open-id
           frontier support #,q-work-export-id))

        (define (#,q-frontier-support-context-open-id
                 neutral recur-work recur-frontier)
          (match neutral
            [`(q-forced ,_provenance ,q-frontier)
             (recur-frontier q-frontier)]
            [_
             #,(if base-context-open?
                   #`(#,base-q-frontier-support-context-open
                      neutral recur-work recur-frontier)
                   #`(#,q-frontier-support-open
                      neutral recur-work))]))

        (define (#,q-frontier-support-open-id neutral recur-work)
          (#,q-frontier-support-context-open-id
           neutral recur-work #,q-frontier-support-id))

        (define (#,q-frontier-support-id neutral)
          (#,q-frontier-support-open-id
           neutral #,q-work-support-id))

        (define (#,q-frontier-rebuild-context-open-id
                 neutral support recur-work recur-frontier)
          (match neutral
            [`(q-forced ,provenance ,q-frontier)
             #,(forced-expression
                #`(#,q-rebuild-local provenance)
                #`(recur-frontier q-frontier support))]
            [_
             #,(if base-context-open?
                   #`(#,base-q-frontier-rebuild-context-open
                      neutral support recur-work recur-frontier)
                   #`(#,q-frontier-rebuild-open
                      neutral support recur-work))]))

        (define (#,q-frontier-rebuild-open-id neutral support recur-work)
          (#,q-frontier-rebuild-context-open-id
           neutral support recur-work #,q-frontier-rebuild-id))

        (define (#,q-frontier-rebuild-id neutral support)
          (#,q-frontier-rebuild-open-id
           neutral support #,q-work-rebuild-id))

        (define (#,q-path-export-composed-open-id path support recur)
          (#,q-path-export-open
           path support recur))

        (define (#,q-path-export-id path support)
          (#,q-path-export-composed-open-id
           path support #,q-path-export-id))

        (define (#,q-path-rebuild-composed-open-id
                 neutral support recur map-goal)
          (#,q-path-rebuild-open
           neutral
           support
           recur
           map-goal))

        (define (#,q-path-rebuild-id neutral support)
          (#,q-path-rebuild-composed-open-id
           neutral support #,q-path-rebuild-id #,q-address-goal-id))

        (define (#,q-spine-export-open-id spine support recur)
          (match spine
            [#,forced-spine-match
             (match-define (list provenance support-next)
               (#,q-export-local
                #,(forced-prefix-expression supply-local)
                support))
             (define-values (q-spine support-at-hole)
               (recur #,SpineContext support-next))
             (values
              `(q-spine-forced ,provenance ,q-spine)
              support-at-hole)]
            [_
             #,(if base-context-open?
                   #`(#,base-q-spine-export-open
                      spine support recur)
                   #`(if (equal? spine (term hole))
                         (values 'q-spine-hole support)
                         (error '#,q-spine-export-id
                                "expected an extensible SpineContext, received ~e"
                                spine)))]))

        (define (#,q-spine-export-id spine support)
          (#,q-spine-export-open-id
           spine support #,q-spine-export-id))

        (define (#,q-spine-rebuild-open-id neutral recur)
          (match neutral
            [`(q-spine-forced ,provenance ,q-spine)
             #,(forced-expression
                #`(#,q-rebuild-local provenance)
                #`(recur q-spine))]
            [_
             #,(if base-context-open?
                   #`(#,base-q-spine-rebuild-open neutral recur)
                   #`(match neutral
                       ['q-spine-hole (term hole)]
                       [_
                        (error '#,q-spine-rebuild-id
                               "expected a neutral extensible spine, received ~e"
                               neutral)]))]))

        (define (#,q-spine-rebuild-id neutral)
          (#,q-spine-rebuild-open-id
           neutral #,q-spine-rebuild-id))

        (define (#,q-focus-shape-open-id
                 focus support recur path-export)
          (match focus
            [#,forced-spine-match
             (match-define (list provenance support-next)
               (#,q-export-local
                #,(forced-prefix-expression supply-local)
                support))
             (match-define
               (list q-spine q-path support-at-hole)
               (recur #,SpineContext support-next))
             (list
              `(q-spine-forced ,provenance ,q-spine)
              q-path
              support-at-hole)]
            [_
             #,(if base-context-open?
                   #`(#,base-q-focus-shape-open
                      focus support recur path-export)
                   #`(match focus
                       [#,more-match
                        (define-values (q-path support-at-hole)
                          (path-export #,WorkPath support))
                        (list 'q-spine-hole q-path support-at-hole)]
                       [_
                        (error '#,q-focus-shape-id
                               "expected an extensible WorkFocus, received ~e"
                               focus)]))]))

        (define (#,q-focus-shape-id focus support)
          (#,q-focus-shape-open-id
           focus support #,q-focus-shape-id #,q-path-export-id))

        (define (#,q-focus-shape-rebuild-open-id
                 q-spine q-path support recur path-rebuild)
          (match q-spine
            [`(q-spine-forced ,provenance ,q-inner)
             #,(forced-expression
                #`(#,q-rebuild-local provenance)
                #`(recur q-inner q-path support))]
            [_
             #,(if base-context-open?
                   #`(#,base-q-focus-shape-rebuild-open
                      q-spine q-path support recur path-rebuild)
                   #`(match q-spine
                       ['q-spine-hole
                        #,(more-expression
                           #`(path-rebuild q-path support))]
                       [_
                        (error '#,q-focus-shape-rebuild-id
                               "expected a neutral extensible spine, received ~e"
                               q-spine)]))]))

        (define (#,q-focus-shape-rebuild-id q-spine q-path support)
          (#,q-focus-shape-rebuild-open-id
           q-spine
           q-path
           support
           #,q-focus-shape-rebuild-id
           #,q-path-rebuild-id))

        (define (#,q-export-id frontier)
          (#,q-frontier-export-id frontier #,q-prefix-empty))

        (define (#,q-rebuild-id neutral)
          (#,q-frontier-rebuild-id
           neutral
           (#,q-frontier-support-id neutral)))

        (define (#,q-focus-export-id focused focus)
          (match-define (list q-spine q-path support-at-hole)
            (#,q-focus-shape-id focus #,q-prefix-empty))
          `(q-focused
            ,(#,q-work-export-id focused support-at-hole)
            (q-work-focus ,q-spine ,q-path)))

        (define (#,q-focus-rebuild-id neutral)
          (match neutral
            [`(q-focused
               ,q-work
               (q-work-focus ,q-spine ,q-path))
             (define support (#,q-work-support-id q-work))
             (list
              (#,q-work-rebuild-id q-work support)
              (#,q-focus-shape-rebuild-id
               q-spine q-path support))]
            [_
             (error '#,q-focus-rebuild-id
                    "expected a neutral Delay focus, received ~e"
                    neutral)]))

        (define (#,q-root-focus-export-id frontier spine)
          (define-values (q-spine support-at-hole)
            (#,q-spine-export-id spine #,q-prefix-empty))
          `(q-root-focused
            ,(#,q-frontier-export-id frontier support-at-hole)
            ,q-spine))

        (define (#,q-root-focus-rebuild-id neutral)
          (match neutral
            [`(q-root-focused ,q-frontier ,q-spine)
             (define support
               (#,q-frontier-support-id q-frontier))
             (list
              (#,q-frontier-rebuild-id q-frontier support)
              (#,q-spine-rebuild-id q-spine))]
            [_
             (error '#,q-root-focus-rebuild-id
                    "expected a neutral Delay root focus, received ~e"
                    neutral)]))

        (define (#,q-failure-focus-export-id summary focus)
          (match-define (list q-spine q-path support-at-hole)
            (#,q-focus-shape-id focus #,q-prefix-empty))
          (match-define (list provenance support)
            (#,q-failure-export summary support-at-hole))
          `(q-failure-focused
            ,provenance
            ,support
            (q-work-focus ,q-spine ,q-path)))

        (define (#,q-failure-focus-rebuild-id neutral)
          (match neutral
            [`(q-failure-focused
               ,provenance
               ,support
               (q-work-focus ,q-spine ,q-path))
             (list
              (#,q-failure-rebuild provenance support)
              (#,q-focus-shape-rebuild-id
               q-spine q-path support))]
            [_
             (error '#,q-failure-focus-rebuild-id
                    "expected a neutral Delay failure focus, received ~e"
                    neutral)]))

        (define (#,q-terminal-export-id terminal)
          (#,q-frontier-export-id terminal #,q-prefix-empty))

        (define (#,q-terminal-rebuild-id neutral)
          (#,q-frontier-rebuild-id
           neutral
           (#,q-frontier-support-id neutral))))))

(define-syntax (define-delay-representation-view stx)
  (syntax-parse stx
    [(_ name:id . _)
     (parse-delay-view-declaration stx)
     #`(define-syntax name
         (delay-view-binding (quote-syntax #,stx)))]))

(define-syntax (render-generated-delay-source stx)
  (syntax-parse stx
    [(_ #:language base-language:id
        #:redex-parameters
        ([base-parameter-local:id base-parameter-default:id] ...)
        #:branch-copy base-branch-copy:id
        #:R-work-raw base-work-raw:id
        #:R-frontier-raw base-frontier-raw:id
        #:R-allocation-raw base-allocation-raw:id
        #:subst-goal base-subst-goal:id
        #:subst-goal-open base-subst-goal-open:id
        #:wf-root base-wf-root:id
        #:wf-goal base-wf-goal:id
        #:wf-answer base-wf-answer:id
        #:wf-returned base-wf-returned:id
        #:live-supply base-live-supply:id
        #:failure-summary base-failure-summary:id
        #:wf-work base-wf-work:id
        #:wf-frontier base-wf-frontier:id
        #:WF-open
        [#:goal-case base-wf-goal-case:id
         #:goal-tasks base-wf-goal-tasks:id
         #:live-case base-live-case:id
         #:node-case base-wf-node-case:id
         #:nodes base-wf-nodes:id]
        #:carrier-view
        [#:state state-template
         #:answer answer-template
         #:returned returned-template
         #:work work-template
         #:dead dead-template
         #:conj conj-template
         #:last last-template
         #:more more-template
         #:empty-supply empty-supply]
        #:prefix-view
        [#:extend-premises (prefix-premise ...)
         #:Q-empty q-prefix-empty
         #:work-focus-support base-work-focus-prefix:id
         #:work-focus-support-open base-work-focus-prefix-open
         (~optional
          (~seq #:transfer-work base-transfer-work:id)
          #:defaults ([base-transfer-work #'#f]))
         #:transfer-work-open base-transfer-work-open:id
         (~optional
          (~seq #:transfer-work-host _base-transfer-work-host:id)
          #:defaults ([_base-transfer-work-host #'#f]))
         #:Q-export-local q-export-local:id
         #:Q-rebuild-local q-rebuild-local:id]
        #:Q-open
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
         #:address-goal q-address-goal-open:id]
        (~optional
         (~seq
          #:Q-context-open
          [#:frontier-export base-q-frontier-export-context-open:id
           #:frontier-support base-q-frontier-support-context-open:id
           #:frontier-rebuild base-q-frontier-rebuild-context-open:id
           #:spine-export base-q-spine-export-open:id
           #:spine-rebuild base-q-spine-rebuild-open:id
           #:focus-shape base-q-focus-shape-open:id
           #:focus-shape-rebuild base-q-focus-shape-rebuild-open:id])
         #:defaults
         ([base-q-frontier-export-context-open #'#f]
          [base-q-frontier-support-context-open #'#f]
          [base-q-frontier-rebuild-context-open #'#f]
          [base-q-spine-export-open #'#f]
          [base-q-spine-rebuild-open #'#f]
          [base-q-focus-shape-open #'#f]
          [base-q-focus-shape-rebuild-open #'#f]))
        #:representation representation:id
        #:binding binding-id:id
        #:language language-id:id
        #:relation relation-id:id
        #:raw-successors raw-successors-id:id
        #:wf-root wf-root-id:id
        #:live-supply live-supply-id:id
        #:failure-summary failure-summary-id:id
        #:Q
        [#:export q-export-id:id
         #:rebuild q-rebuild-id:id
         #:focus-export q-focus-export-id:id
         #:focus-rebuild q-focus-rebuild-id:id
         #:root-focus-export q-root-focus-export-id:id
         #:root-focus-rebuild q-root-focus-rebuild-id:id
         #:failure-focus-export q-failure-focus-export-id:id
         #:failure-focus-rebuild q-failure-focus-rebuild-id:id
         #:terminal-export q-terminal-export-id:id
         #:terminal-rebuild q-terminal-rebuild-id:id])
     (render-delay-source
      stx
      (parse-delay-view #'representation)
      (list #'base-language
            (for/list ([local (in-list (syntax->list #'(base-parameter-local ...)))]
                       [default
                        (in-list
                         (syntax->list #'(base-parameter-default ...)))])
              (cons local default))
            #'base-branch-copy
            #'base-work-raw #'base-frontier-raw #'base-allocation-raw
            #'base-subst-goal #'base-subst-goal-open
            #'base-wf-root #'base-wf-goal #'base-wf-answer #'base-wf-returned
            #'base-live-supply
            #'base-failure-summary
            #'base-wf-work #'base-wf-frontier
            #'base-wf-goal-case #'base-wf-goal-tasks
            #'base-live-case #'base-wf-node-case #'base-wf-nodes
            #'state-template #'answer-template #'returned-template
            #'work-template #'dead-template #'conj-template #'last-template
            #'more-template
            #'empty-supply
            #'q-prefix-empty
            (syntax->list #'(prefix-premise ...))
            #'base-work-focus-prefix #'base-work-focus-prefix-open
            #'base-transfer-work #'base-transfer-work-open
            #'q-export-local #'q-rebuild-local
            #'q-work-export-open #'q-work-support-open #'q-work-rebuild-open
            #'q-frontier-export-open #'q-frontier-support-open
            #'q-frontier-rebuild-open
            #'q-path-export-open #'q-path-rebuild-open
            #'q-failure-export #'q-failure-rebuild #'q-address-goal-open
            #'base-q-frontier-export-context-open
            #'base-q-frontier-support-context-open
            #'base-q-frontier-rebuild-context-open
            #'base-q-spine-export-open #'base-q-spine-rebuild-open
            #'base-q-focus-shape-open #'base-q-focus-shape-rebuild-open)
      (list #'binding-id #'language-id #'relation-id #'raw-successors-id
            #'wf-root-id #'live-supply-id #'failure-summary-id
            #'q-export-id #'q-rebuild-id
            #'q-focus-export-id #'q-focus-rebuild-id
            #'q-root-focus-export-id #'q-root-focus-rebuild-id
            #'q-failure-focus-export-id #'q-failure-focus-rebuild-id
            #'q-terminal-export-id #'q-terminal-rebuild-id))]))

(define-syntax (define-generated-delay-source stx)
  (syntax-parse stx
    [(_ binding-id:id
        #:base base-source:id
        #:representation representation:id
        #:language language-id:id
        #:relation relation-id:id
        #:raw-successors raw-successors-id:id
        #:wf-root wf-root-id:id
        #:live-supply live-supply-id:id
        #:failure-summary failure-summary-id:id
        #:Q
        [#:export q-export-id:id
         #:rebuild q-rebuild-id:id
         #:focus-export q-focus-export-id:id
         #:focus-rebuild q-focus-rebuild-id:id
         #:root-focus-export q-root-focus-export-id:id
         #:root-focus-rebuild q-root-focus-rebuild-id:id
         #:failure-focus-export q-failure-focus-export-id:id
         #:failure-focus-rebuild q-failure-focus-rebuild-id:id
         #:terminal-export q-terminal-export-id:id
         #:terminal-rebuild q-terminal-rebuild-id:id])
     #`(base-source
        #:visit-extension render-generated-delay-source
        #:representation representation
        #:binding binding-id
        #:language language-id
        #:relation relation-id
        #:raw-successors raw-successors-id
        #:wf-root wf-root-id
        #:live-supply live-supply-id
        #:failure-summary failure-summary-id
        #:Q
        [#:export q-export-id
         #:rebuild q-rebuild-id
         #:focus-export q-focus-export-id
         #:focus-rebuild q-focus-rebuild-id
         #:root-focus-export q-root-focus-export-id
         #:root-focus-rebuild q-root-focus-rebuild-id
         #:failure-focus-export q-failure-focus-export-id
         #:failure-focus-rebuild q-failure-focus-rebuild-id
         #:terminal-export q-terminal-export-id
         #:terminal-rebuild q-terminal-rebuild-id])]))

(begin-for-syntax
  (define (lookup-delay-source identifier)
    (define value (syntax-local-value identifier (lambda () #f)))
    (unless (delay-source-binding? value)
      (raise-syntax-error
       #f
       "expected a generated Delay source"
       identifier))
    value)

  (define (parse-delay-redex-parameters source declaration)
    (for/list
        ([entry
          (in-list
           (syntax->list
            (delay-source-binding-redex-parameters source)))])
      (syntax-parse entry
        [[local:id default:id] (cons #'local #'default)]
        [_
         (raise-syntax-error
          #f
          "Delay source redex parameters must be [local default] pairs"
          declaration
          entry)])))

  (define (render-delay-stage-extension use-stx name source)
    (define (output suffix)
      (format-id name "~a/~a" (syntax-e name) suffix))
    (define (slot symbol)
      (datum->syntax name symbol name name))
    (define (placeholder phase local [diagnostic? #f])
      (datum->syntax
       name
       (string->symbol
        (format "BASE-~a~a-PARAMETER-~a"
                phase
                (if diagnostic? "-DIAGNOSTIC" "")
                (syntax-e local)))
       name
       name))
    (define source-language (delay-source-binding-language source))
    (define source-subst (delay-source-binding-subst-goal source))
    (define source-subst-open (delay-source-binding-subst-goal-open source))
    (define source-focus (delay-source-binding-work-focus-prefix source))
    (define source-focus-open
      (delay-source-binding-work-focus-prefix-open source))
    (define source-transfer-host
      (delay-source-binding-transfer-work-host source))
    (define source-parameters
      (parse-delay-redex-parameters source use-stx))
    (define subst-parameter
      (for/first ([parameter (in-list source-parameters)]
                  #:when (free-identifier=? (cdr parameter) source-subst))
        (car parameter)))
    (define focus-parameter
      (for/first ([parameter (in-list source-parameters)]
                  #:when (free-identifier=? (cdr parameter) source-focus))
        (car parameter)))
    (unless subst-parameter
      (raise-syntax-error
       #f
       "Delay source omits its allocation substitution parameter"
       use-stx))
    (unless focus-parameter
      (raise-syntax-error
       #f
       "Delay source omits its allocation focus-prefix parameter"
       use-stx))
    (unless (and source-focus-open (syntax-e source-focus-open))
      (raise-syntax-error
       #f
       "Delay staging requires an open WorkFocus prefix traversal"
       use-stx))

    (define work-template (delay-source-binding-work-template source))
    (define dead-template (delay-source-binding-dead-template source))
    (define conj-template (delay-source-binding-conj-template source))
    (define more-template (delay-source-binding-more-template source))
    (define pending-template (delay-source-binding-pending-template source))
    (define pending-prefix-template
      (delay-source-binding-pending-prefix-template source))
    (define forced-template (delay-source-binding-forced-template source))
    (define forced-prefix-template
      (delay-source-binding-forced-prefix-template source))
    (define empty-supply (delay-source-binding-prefix-empty source))

    (define supply (slot 'supply))
    (define supply-in (slot 'supply_in))
    (define supply-local (slot 'supply_local))
    (define g (slot 'g))
    (define tag (slot 'tag))
    (define sigma (slot 'sigma))
    (define W (slot 'W))
    (define W-attached (slot 'W_attached))
    (define F (slot 'F))
    (define SourceWorkFocus (slot 'SourceWorkFocus))
    (define SourceSpineContext (slot 'SourceSpineContext))

    (define (term template replacements)
      (instantiate-template template replacements))
    (define (work local goal state)
      (term work-template
            (list (cons 'supply local)
                  (cons 'g goal)
                  (cons 'sigma state))))
    (define (conj local body goal)
      (term conj-template
            (list (cons 'supply local)
                  (cons 'W body)
                  (cons 'g goal))))
    (define (dead local)
      (term dead-template (list (cons 'supply local))))
    (define (more body)
      (term more-template (list (cons 'W body))))
    (define (pending local body)
      (term pending-template
            (list (cons 'supply local) (cons 'W body))))
    (define (forced local frontier)
      (term forced-template
            (list (cons 'supply local) (cons 'F frontier))))
    (define (pending-prefix local)
      (term pending-prefix-template
            (list (cons 'supply local) (cons 'empty empty-supply))))
    (define (forced-prefix local)
      (term forced-prefix-template
            (list (cons 'supply local) (cons 'empty empty-supply))))
    (define suspended-work
      (work supply #`(suspend #,g #,tag) sigma))
    (define resumed-work (work empty-supply g sigma))
    (define suspended-target
      (pending (pending-prefix supply) resumed-work))
    (define bubble-source
      (conj supply-in (pending supply-local W) g))
    (define bubble-target
      (pending
       (pending-prefix supply-in)
       (conj empty-supply W-attached g)))
    (define force-source (more (pending supply-local W)))
    (define force-target
      (forced (forced-prefix supply-local) (more W)))
    (define pending-grammar (pending supply W))
    (define forced-grammar (forced supply F))
    (define forced-spine
      (forced supply (slot 'SpineContext)))
    (define forced-terminal
      (forced supply (slot 'T)))
    ;; Use one suffixed Redex variable in both the carrier template and every
    ;; diagnostic pattern that binds its summary.  Reconstructing a fresh
    ;; unsuffixed identifier here would give the template a different scope
    ;; and turn the summary into literal syntax in generated modules.
    (define failure-summary-var (slot 'FailureSummary_0))
    (define dead-term (dead failure-summary-var))

    (define transfer-parameter (output "transfer-work-parameter"))
    (define (phase-data phase)
      (define prefix (string-downcase phase))
      (define language (output (format "~a-language" phase)))
      (define subst (output (format "~a-subst-goal" prefix)))
      (define subst-host (output (format "~a-subst-goal/host" prefix)))
      (define focus (output (format "~a-work-focus-prefix" prefix)))
      (define focus-host
        (output (format "~a-work-focus-prefix/host" prefix)))
      (define transfer (output (format "~a-transfer-work" prefix)))
      (list language subst subst-host focus focus-host transfer))
    (define D-phase (phase-data "D"))
    (define Z-phase (phase-data "Z"))
    (define M-phase (phase-data "M"))
    (define B-phase (phase-data "B"))
    (define Big-phase (phase-data "Big"))

    (define (phase-parameters phase data [diagnostic? #f])
      (match-define (list _language subst _subst-host focus _focus-host transfer)
        data)
      #`(#,@(for/list ([parameter (in-list source-parameters)])
               (match-define (cons local default) parameter)
               #`[#,local
                  #,(cond
                      [(free-identifier=? default source-subst) subst]
                      [(free-identifier=? default source-focus) focus]
                      [else (placeholder phase local diagnostic?)])])
         [#,transfer-parameter #,transfer]))

    (define (dependency-forms phase data)
      (match-define (list language subst subst-host focus focus-host transfer)
        data)
      (define base-subst (placeholder phase subst-parameter))
      (define base-focus (placeholder phase focus-parameter))
      (list
       #`(define (#,subst-host goal substitutions)
           (#,source-subst-open #,subst-host goal substitutions))
       #`(redex-parameter:define-extended-metafunction*
          #,base-subst
          #,language
          #,subst : g alloc -> g
          [(#,subst g alloc)
           ,(#,subst-host (term g) (term alloc))])
       #`(define (#,focus-host focus-value support-value)
           (#,source-focus-open
            focus-value support-value #,focus-host))
       #`(redex-parameter:define-extended-metafunction*
          #,base-focus
          #,language
          #,focus : WorkFocus support -> support
          [(#,focus WorkFocus support)
           ,(#,focus-host (term WorkFocus) (term support))])
       #`(redex-parameter:define-metafunction*
          #,language
          #,transfer : any W -> W
          [(#,transfer any_0 W)
           ,(#,source-transfer-host (term any_0) (term W))])))

    (define D-language (first D-phase))
    (define D-plug-D (output "D-plug-D"))
    (define D-plug-C (output "D-plug-C"))
    (define D-contract-label (output "D-contract-label"))
    (define D-decompose (output "D-decompose"))
    (define D-contract (output "D-contract"))
    (define D-step (output "D-step"))

    (define Z-language (first Z-phase))
    (define Z-refocus-phase (output "Z-refocus-phase"))
    (define Z-refocus-work (output "Z-refocus-work"))
    (define Z-refocus-frontier (output "Z-refocus-frontier"))
    (define Z-refocus (output "Z-refocus"))
    (define Z-step (output "Z-step"))
    (define Z-D->Z (output "diagnostic-D->Z"))
    (define Z-Z->D (output "diagnostic-Z->D"))
    (define Z-readback (output "diagnostic-readback-Z"))
    (define Z-refocus-spec (output "diagnostic-refocus-Z"))
    (define Z-step-spec (output "diagnostic-Z-step"))

    (define M-language (first M-phase))
    (define M-machineize (output "M-machineize"))
    (define M-refocus-work (output "M-refocus-work"))
    (define M-refocus-frontier (output "M-refocus-frontier"))
    (define M-refocus (output "M-refocus"))
    (define M-step (output "M-step"))
    (define M-encode-ZM (output "diagnostic-encode-ZM"))
    (define M-decode-MZ (output "diagnostic-decode-MZ"))
    (define M-D->M (output "diagnostic-D->M"))
    (define M-M->D (output "diagnostic-M->D"))
    (define M-readback (output "diagnostic-readback-M"))
    (define M-corresponds (output "diagnostic-ZM-corresponds"))
    (define M-step-spec (output "diagnostic-M-step"))
    (define M-square (output "diagnostic-ZM-square"))

    (define B-language (first B-phase))
    (define B-compress (output "B-compress"))
    (define B-refocus-frontier (output "B-refocus-frontier"))
    (define B-span-labels (output "B-span-labels"))
    (define B-produce-settled (output "B-produce-settled"))
    (define B-produce-dead (output "B-produce-dead"))
    (define B-advance-settled (output "B-advance-settled"))
    (define B-advance-dead (output "B-advance-dead"))
    (define B-singleton (output "B-singleton"))
    (define B-step (output "B-step"))
    (define B-encode-MB (output "diagnostic-encode-MB"))
    (define B-decode-BM (output "diagnostic-decode-BM"))
    (define B-readback (output "diagnostic-readback-B"))
    (define B-corresponds (output "diagnostic-MB-corresponds"))
    (define B-replay (output "diagnostic-replay-M"))
    (define B-step-spec (output "diagnostic-B-step"))
    (define B-square (output "diagnostic-MB-square"))

    (define Big-language (first Big-phase))
    (define Big-dispatch-one (output "Big-dispatch-one"))
    (define Big-dispatch (output "Big-dispatch"))
    (define Big-refocus-frontier (output "Big-refocus-frontier"))
    (define Big-control-one (output "Big-control-one"))
    (define Big-control (output "Big-control"))
    (define Big-frontier (output "Big-frontier"))
    (define Big-run (output "Big-run"))
    (define Big-settled (output "Big-settled"))
    (define Big-dead (output "Big-dead"))
    (define Big-final (output "Big-final"))
    (define Big-evaluate (output "Big-evaluate"))
    (define Big-promote (output "Big-promote"))
    (define Big-readback (output "diagnostic-readback-Big"))
    (define Big-spec-language (output "diagnostic-Big-language"))
    (define Big-initialize (output "diagnostic-initialize-B"))
    (define Big-close (output "diagnostic-close-B"))
    (define Big-flatten (output "diagnostic-flatten-BTrace"))
    (define Big-evaluate-spec (output "diagnostic-Big-evaluate"))
    (define Big-unfold-square (output "diagnostic-B-Big-unfold"))
    (define Big-closure-square (output "diagnostic-B-Big-closure"))
    (define Big-root-square (output "diagnostic-B-Big-root"))

    (define D-transfer (sixth D-phase))
    (define Z-transfer (sixth Z-phase))
    (define M-transfer (sixth M-phase))
    (define B-transfer (sixth B-phase))
    (define Big-transfer (sixth Big-phase))
    (define metadata-id
      (format-id name "~a/delay-stage-metadata" (syntax-e name)))

    #`(begin
        (define-selected-stage-extension #,name
        #:source-language #,source-language
        #:feature-singletons
        (suspend-goal bubble-delay-through-conj force-delay)
        #:D
        [#:parameters #,(phase-parameters "D" D-phase)
         #:artifacts
         (D-artifacts
          #:language #,D-language
          #:plug-D #,D-plug-D
          #:plug-C #,D-plug-C
          #:contract-label #,D-contract-label
          #:decompose #,D-decompose
          #:contract #,D-contract
          #:step #,D-step)
         #:forms
         ((provide #,D-language #,D-plug-D #,D-plug-C
                   #,D-contract-label #,D-decompose #,D-contract #,D-step)
          (define-extended-language #,D-language BASE-D-LANGUAGE
            [g .... (suspend g tag)]
            [W .... #,pending-grammar]
            [F .... #,forced-grammar]
            [SpineContext .... #,forced-spine]
            ;; Reopen each selected-view alias in the exact feature language.
            ;; Redex otherwise retains the inherited production reference to
            ;; the base language and rejects feature payloads inside generic
            ;; continuation/control shells.
            [SourceW .... W]
            [SourceF .... F]
            [SourceWorkFocus .... WorkFocus]
            [SourceSpineContext .... SpineContext]
            [T .... #,forced-terminal]
            [D .... (Final T)]
            [RuleName .... suspend-goal bubble-delay-through-conj force-delay]
            [FeatureRuleName
             suspend-goal bubble-delay-through-conj force-delay]
            [WR .... #,suspended-work #,bubble-source]
            [FR .... #,force-source])
          #,@(dependency-forms "D" D-phase)
          (redex-parameter:define-extended-metafunction*
           BASE-D-PLUG #,D-language #,D-plug-D : D -> SourceF)
          (redex-parameter:define-extended-metafunction*
           BASE-C-PLUG #,D-language #,D-plug-C : C -> SourceF)
          (redex-parameter:define-extended-metafunction*
           BASE-CONTRACT-LABEL #,D-language
           #,D-contract-label : C -> RuleName)
          (redex-parameter:define-extended-judgment-form*
           BASE-DECOMPOSE #,D-language
           #:mode (#,D-decompose I O))
          (redex-parameter:define-extended-judgment-form*
           BASE-CONTRACT #,D-language
           #:mode (#,D-contract I O)
           #:parameters ([#,transfer-parameter #,D-transfer])
           [---------------- "suspend-goal"
            (#,D-contract
             (DecWork #,suspended-work SourceWorkFocus)
             (ContractWork
              suspend-goal #,suspended-target SourceWorkFocus))]
           [(where #,W-attached
                   (#,transfer-parameter
                    #,(pending-prefix supply-local) #,W))
            ---------------- "bubble-delay-through-conj"
            (#,D-contract
             (DecWork #,bubble-source SourceWorkFocus)
             (ContractWork
              bubble-delay-through-conj
              #,bubble-target SourceWorkFocus))]
           [---------------- "force-delay"
            (#,D-contract
             (DecFrontier #,force-source SourceSpineContext)
             (ContractFrontier
              force-delay #,force-target SourceSpineContext))])
          (redex-parameter:define-extended-judgment-form*
           BASE-D-STEP #,D-language
           #:mode (#,D-step I O O)
           #:parameters
           ([step-contract #,D-contract]
            [step-contract-label #,D-contract-label]
            [step-plug-C #,D-plug-C]
            [step-decompose #,D-decompose]))) ]

        #:Z
        [#:parameters #,(phase-parameters "Z" Z-phase)
         #:artifacts
         (Z-artifacts
          #:language #,Z-language
          #:refocus-phase #,Z-refocus-phase
          #:refocus-work-direct #,Z-refocus-work
          #:refocus-frontier-direct #,Z-refocus-frontier
          #:refocus-direct #,Z-refocus
          #:step-direct #,Z-step)
         #:forms
         ((provide #,Z-language #,Z-refocus-phase #,Z-refocus-work
                   #,Z-refocus-frontier #,Z-refocus #,Z-step)
          (define-extended-language #,Z-language BASE-Z-LANGUAGE
            [g .... (suspend g tag)]
            [W .... #,pending-grammar]
            [F .... #,forced-grammar]
            [SpineContext .... #,forced-spine]
            [T .... #,forced-terminal]
            [Z .... (ZFinal T)]
            [RuleName .... suspend-goal bubble-delay-through-conj force-delay]
            [WR .... #,suspended-work #,bubble-source]
            [FR .... #,force-source]
            [RunW .... #,suspended-work #,bubble-source])
          #,@(dependency-forms "Z" Z-phase)
          (redex-parameter:define-extended-metafunction*
           BASE-REFOCUS-PHASE #,Z-language
           #,Z-refocus-phase : D -> Z)
          (redex-parameter:define-extended-judgment-form*
           BASE-Z-REFOCUS-FRONTIER #,Z-language
           #:mode (#,Z-refocus-frontier I O))
          (redex-parameter:define-extended-judgment-form*
           BASE-Z-REFOCUS-WORK #,Z-language
           #:mode (#,Z-refocus-work I I O)
           #:parameters
           ([step-refocus-frontier #,Z-refocus-frontier])
           [(step-refocus-frontier
             (in-hole SourceWorkFocus #,pending-grammar) Z_1)
            ----
            (#,Z-refocus-work
             #,pending-grammar SourceWorkFocus Z_1)])
          (redex-parameter:define-extended-judgment-form*
           BASE-Z-REFOCUS #,Z-language
           #:mode (#,Z-refocus I O)
           #:parameters
           ([refocus-work-dependency #,Z-refocus-work]))
          (redex-parameter:define-extended-judgment-form*
           BASE-Z-STEP #,Z-language
           #:mode (#,Z-step I O O)
           #:parameters
           ([#,transfer-parameter #,Z-transfer]
            [step-refocus-work #,Z-refocus-work]
            [step-refocus-frontier #,Z-refocus-frontier])
           [(step-refocus-work
             #,suspended-target SourceWorkFocus Z_1)
            ---------------- "suspend-goal"
            (#,Z-step
             (ZWork #,suspended-work SourceWorkFocus)
             suspend-goal Z_1)]
           [(where #,W-attached
                   (#,transfer-parameter
                    #,(pending-prefix supply-local) #,W))
            (step-refocus-work
             #,bubble-target SourceWorkFocus Z_1)
            ---------------- "bubble-delay-through-conj"
            (#,Z-step
             (ZWork #,bubble-source SourceWorkFocus)
             bubble-delay-through-conj Z_1)]
           [(step-refocus-frontier
             (in-hole SourceSpineContext #,force-target) Z_1)
            ---------------- "force-delay"
            (#,Z-step
             (ZFrontier #,force-source SourceSpineContext)
             force-delay Z_1)]))
         #:diagnostic-parameters #,(phase-parameters "Z" Z-phase #t)
         #:diagnostics
         (Z-diagnostics
          #:D->Z #,Z-D->Z #:Z->D #,Z-Z->D #:readback #,Z-readback
          #:refocus-spec #,Z-refocus-spec #:step-spec #,Z-step-spec)
         #:diagnostic-forms
         ((module+ diagnostics
            (provide #,Z-D->Z #,Z-Z->D #,Z-readback
                     #,Z-refocus-spec #,Z-step-spec))
          (define-metafunction #,Z-language
            #,Z-D->Z : D -> Z
            [(#,Z-D->Z (Final T)) (ZFinal T)]
            [(#,Z-D->Z (DecWork WR SourceWorkFocus))
             (ZWork WR SourceWorkFocus)]
            [(#,Z-D->Z (DecFrontier FR SourceSpineContext))
             (ZFrontier FR SourceSpineContext)]
            [(#,Z-D->Z (DecAllocate AR SourceWorkFocus))
             (ZAllocate AR SourceWorkFocus)])
          (define-metafunction #,Z-language
            #,Z-Z->D : Z -> D
            [(#,Z-Z->D (ZFinal T)) (Final T)]
            [(#,Z-Z->D (ZWork WR SourceWorkFocus))
             (DecWork WR SourceWorkFocus)]
            [(#,Z-Z->D (ZFrontier FR SourceSpineContext))
             (DecFrontier FR SourceSpineContext)]
            [(#,Z-Z->D (ZAllocate AR SourceWorkFocus))
             (DecAllocate AR SourceWorkFocus)])
          (define-metafunction #,Z-language
            #,Z-readback : Z -> SourceF
            [(#,Z-readback (ZFinal T)) T]
            [(#,Z-readback (ZWork WR SourceWorkFocus))
             (in-hole SourceWorkFocus WR)]
            [(#,Z-readback (ZFrontier FR SourceSpineContext))
             (in-hole SourceSpineContext FR)]
            [(#,Z-readback (ZAllocate AR SourceWorkFocus))
             (in-hole SourceWorkFocus AR)])
          (define-judgment-form #,Z-language
            #:mode (#,Z-refocus-spec I O)
            #:contract (#,Z-refocus-spec C Z)
            [(where SourceF_0 (#,D-plug-C C_0))
             (#,D-decompose SourceF_0 D_0)
             (where Z_0 (#,Z-D->Z D_0))
             ----
             (#,Z-refocus-spec C_0 Z_0)])
          (define-judgment-form #,Z-language
            #:mode (#,Z-step-spec I O O)
            #:contract (#,Z-step-spec Z RuleName Z)
            [(where D_0 (#,Z-Z->D Z_0))
             (#,D-contract D_0 C_0)
             (where RuleName_0 (#,D-contract-label C_0))
             (#,Z-refocus-spec C_0 Z_1)
             ----
             (#,Z-step-spec Z_0 RuleName_0 Z_1)]))]

        #:M
        [#:parameters #,(phase-parameters "M" M-phase)
         #:artifacts
         (M-artifacts
          #:language #,M-language
          #:machineize #,M-machineize
          #:refocus-work-direct #,M-refocus-work
          #:refocus-frontier-direct #,M-refocus-frontier
          #:refocus-direct #,M-refocus
          #:step-direct #,M-step)
         #:forms
         ((provide #,M-language #,M-machineize #,M-refocus-work
                   #,M-refocus-frontier #,M-refocus #,M-step)
          (define-extended-language #,M-language BASE-M-LANGUAGE
            [g .... (suspend g tag)]
            [W .... #,pending-grammar]
            [F .... #,forced-grammar]
            [SpineContext .... #,forced-spine]
            [T .... #,forced-terminal]
            [M .... (MFinal T)]
            [RuleName .... suspend-goal bubble-delay-through-conj force-delay]
            [WR .... #,suspended-work #,bubble-source]
            [FR .... #,force-source]
            [RunW .... #,suspended-work #,bubble-source])
          #,@(dependency-forms "M" M-phase)
          (redex-parameter:define-extended-metafunction*
           BASE-MACHINEIZE #,M-language
           #,M-machineize : Z -> M)
          (redex-parameter:define-extended-judgment-form*
           BASE-M-REFOCUS-FRONTIER #,M-language
           #:mode (#,M-refocus-frontier I O))
          (redex-parameter:define-extended-judgment-form*
           BASE-M-REFOCUS-WORK #,M-language
           #:mode (#,M-refocus-work I I O)
           #:parameters
           ([step-refocus-frontier #,M-refocus-frontier])
           [(step-refocus-frontier
             (in-hole SourceWorkFocus #,pending-grammar) M_1)
            ----
            (#,M-refocus-work
             #,pending-grammar SourceWorkFocus M_1)])
          (redex-parameter:define-extended-judgment-form*
           BASE-M-REFOCUS #,M-language
           #:mode (#,M-refocus I O)
           #:parameters
           ([refocus-work-dependency #,M-refocus-work]))
          (redex-parameter:define-extended-judgment-form*
           BASE-M-STEP #,M-language
           #:mode (#,M-step I O O)
           #:parameters
           ([#,transfer-parameter #,M-transfer]
            [step-refocus-work #,M-refocus-work]
            [step-refocus-frontier #,M-refocus-frontier])
           [(step-refocus-work
             #,suspended-target SourceWorkFocus M_1)
            ---------------- "suspend-goal"
            (#,M-step
             (MWork #,suspended-work SourceWorkFocus)
             suspend-goal M_1)]
           [(where #,W-attached
                   (#,transfer-parameter
                    #,(pending-prefix supply-local) #,W))
            (step-refocus-work
             #,bubble-target SourceWorkFocus M_1)
            ---------------- "bubble-delay-through-conj"
            (#,M-step
             (MWork #,bubble-source SourceWorkFocus)
             bubble-delay-through-conj M_1)]
           [(step-refocus-frontier
             (in-hole SourceSpineContext #,force-target) M_1)
            ---------------- "force-delay"
            (#,M-step
             (MFrontier #,force-source SourceSpineContext)
             force-delay M_1)]))
         #:diagnostic-parameters #,(phase-parameters "M" M-phase #t)
         #:diagnostics
         (M-diagnostics
          #:encode-ZM #,M-encode-ZM #:decode-MZ #,M-decode-MZ
          #:D->M #,M-D->M #:M->D #,M-M->D #:readback #,M-readback
          #:corresponds #,M-corresponds #:step-spec #,M-step-spec
          #:square #,M-square)
         #:diagnostic-forms
         ((module+ diagnostics
            (provide #,M-encode-ZM #,M-decode-MZ #,M-D->M #,M-M->D
                     #,M-readback #,M-corresponds #,M-step-spec #,M-square))
          (define-metafunction #,M-language
            #,M-encode-ZM : Z -> M
            [(#,M-encode-ZM (ZFinal T)) (MFinal T)]
            [(#,M-encode-ZM (ZWork WR SourceWorkFocus))
             (MWork WR SourceWorkFocus)]
            [(#,M-encode-ZM (ZFrontier FR SourceSpineContext))
             (MFrontier FR SourceSpineContext)]
            [(#,M-encode-ZM (ZAllocate AR SourceWorkFocus))
             (MAllocate AR SourceWorkFocus)])
          (define-metafunction #,M-language
            #,M-decode-MZ : M -> Z
            [(#,M-decode-MZ (MFinal T)) (ZFinal T)]
            [(#,M-decode-MZ (MWork WR SourceWorkFocus))
             (ZWork WR SourceWorkFocus)]
            [(#,M-decode-MZ (MFrontier FR SourceSpineContext))
             (ZFrontier FR SourceSpineContext)]
            [(#,M-decode-MZ (MAllocate AR SourceWorkFocus))
             (ZAllocate AR SourceWorkFocus)])
          (define-metafunction #,M-language
            #,M-D->M : D -> M
            [(#,M-D->M (Final T)) (MFinal T)]
            [(#,M-D->M (DecWork WR SourceWorkFocus))
             (MWork WR SourceWorkFocus)]
            [(#,M-D->M (DecFrontier FR SourceSpineContext))
             (MFrontier FR SourceSpineContext)]
            [(#,M-D->M (DecAllocate AR SourceWorkFocus))
             (MAllocate AR SourceWorkFocus)])
          (define-metafunction #,M-language
            #,M-M->D : M -> D
            [(#,M-M->D (MFinal T)) (Final T)]
            [(#,M-M->D (MWork WR SourceWorkFocus))
             (DecWork WR SourceWorkFocus)]
            [(#,M-M->D (MFrontier FR SourceSpineContext))
             (DecFrontier FR SourceSpineContext)]
            [(#,M-M->D (MAllocate AR SourceWorkFocus))
             (DecAllocate AR SourceWorkFocus)])
          (define-metafunction #,M-language
            #,M-readback : M -> SourceF
            [(#,M-readback (MFinal T)) T]
            [(#,M-readback (MWork WR SourceWorkFocus))
             (in-hole SourceWorkFocus WR)]
            [(#,M-readback (MFrontier FR SourceSpineContext))
             (in-hole SourceSpineContext FR)]
            [(#,M-readback (MAllocate AR SourceWorkFocus))
             (in-hole SourceWorkFocus AR)])
          (define-judgment-form #,M-language
            #:mode (#,M-corresponds I O)
            #:contract (#,M-corresponds Z M)
            [(where M_0 (#,M-encode-ZM Z_0))
             ---- (#,M-corresponds Z_0 M_0)])
          (define-judgment-form #,M-language
            #:mode (#,M-step-spec I O O)
            #:contract (#,M-step-spec M RuleName M)
            [(where Z_0 (#,M-decode-MZ M_0))
             (#,Z-step Z_0 RuleName_0 Z_1)
             (where M_1 (#,M-encode-ZM Z_1))
             ---- (#,M-step-spec M_0 RuleName_0 M_1)])
          (define-judgment-form #,M-language
            #:mode (#,M-square I O O O O)
            #:contract (#,M-square Z RuleName Z M M)
            [(where M_0 (#,M-encode-ZM Z_0))
             (#,Z-step Z_0 RuleName_0 Z_1)
             (where M_1 (#,M-encode-ZM Z_1))
             (#,M-step M_0 RuleName_0 M_1)
             ---- (#,M-square Z_0 RuleName_0 Z_1 M_0 M_1)]))]

        #:B
        [#:parameters #,(phase-parameters "B" B-phase)
         #:artifacts
         (B-artifacts
          #:language #,B-language #:compress #,B-compress
          #:refocus-frontier-direct #,B-refocus-frontier
          #:span-labels #,B-span-labels
          #:produce-settled #,B-produce-settled
          #:produce-dead #,B-produce-dead
          #:advance-settled #,B-advance-settled
          #:advance-dead #,B-advance-dead
          #:base-singleton #,B-singleton #:step-direct #,B-step)
         #:forms
         ((provide #,B-language #,B-compress #,B-refocus-frontier
                   #,B-span-labels #,B-produce-settled #,B-produce-dead
                   #,B-advance-settled #,B-advance-dead
                   #,B-singleton #,B-step)
          (define-extended-language #,B-language BASE-B-LANGUAGE
            [g .... (suspend g tag)]
            [W .... #,pending-grammar]
            [F .... #,forced-grammar]
            [SpineContext .... #,forced-spine]
            [T .... #,forced-terminal]
            [B .... (BFinal T)]
            [RuleName .... suspend-goal bubble-delay-through-conj force-delay]
            [WR .... #,suspended-work #,bubble-source]
            [FR .... #,force-source]
            [RunW .... #,suspended-work #,bubble-source]
            [NonAllocateRun .... #,suspended-work #,bubble-source]
            [SingletonRuleName
             .... suspend-goal bubble-delay-through-conj force-delay])
          #,@(dependency-forms "B" B-phase)
          (redex-parameter:define-extended-metafunction*
           BASE-COMPRESS #,B-language #,B-compress : M -> B)
          (redex-parameter:define-extended-metafunction*
           BASE-B-REFOCUS-FRONTIER #,B-language
           #,B-refocus-frontier : SourceF -> B)
          (redex-parameter:define-extended-metafunction*
           BASE-SPAN-LABELS #,B-language
           #,B-span-labels : TransitionSpan -> LabelTrace)
          (redex-parameter:define-extended-judgment-form*
           BASE-B-PRODUCE-SETTLED #,B-language
           #:mode (#,B-produce-settled I I O O O))
          (redex-parameter:define-extended-judgment-form*
           BASE-B-PRODUCE-DEAD #,B-language
           #:mode (#,B-produce-dead I I O O O))
          (redex-parameter:define-extended-judgment-form*
           BASE-B-ADVANCE-SETTLED #,B-language
           #:mode (#,B-advance-settled I I O O))
          (redex-parameter:define-extended-judgment-form*
           BASE-B-ADVANCE-DEAD #,B-language
           #:mode (#,B-advance-dead I I O O))
          (redex-parameter:define-extended-judgment-form*
           BASE-B-SINGLETON #,B-language
           #:mode (#,B-singleton I O O)
           #:parameters
           ([#,transfer-parameter #,B-transfer]
            [singleton-refocus-frontier #,B-refocus-frontier]
            [singleton-advance-settled #,B-advance-settled]
            [singleton-advance-dead #,B-advance-dead])
           [(where B_1
                   (singleton-refocus-frontier
                    (in-hole SourceWorkFocus #,suspended-target)))
            ---------------- "suspend-goal"
            (#,B-singleton
             (BRun #,suspended-work SourceWorkFocus)
             (transition-span suspend-goal) B_1)]
           [(where #,W-attached
                   (#,transfer-parameter
                    #,(pending-prefix supply-local) #,W))
            (where B_1
                   (singleton-refocus-frontier
                    (in-hole SourceWorkFocus #,bubble-target)))
            ---------------- "bubble-delay-through-conj"
            (#,B-singleton
             (BRun #,bubble-source SourceWorkFocus)
             (transition-span bubble-delay-through-conj) B_1)]
           [(where B_1
                   (singleton-refocus-frontier
                    (in-hole SourceSpineContext #,force-target)))
            ---------------- "force-delay"
            (#,B-singleton
             (BFrontier #,force-source SourceSpineContext)
             (transition-span force-delay) B_1)])
          (redex-parameter:define-extended-judgment-form*
           BASE-B-STEP #,B-language
           #:mode (#,B-step I O O)
           #:parameters
           ([step-produce-settled #,B-produce-settled]
            [step-produce-dead #,B-produce-dead]
            [step-base-advance-settled #,B-advance-settled]
            [step-base-advance-dead #,B-advance-dead]
            [step-singleton #,B-singleton])))
         #:diagnostic-parameters #,(phase-parameters "B" B-phase #t)
         #:diagnostics
         (B-diagnostics
          #:encode-MB #,B-encode-MB #:decode-BM #,B-decode-BM
          #:readback #,B-readback #:corresponds #,B-corresponds
          #:replay #,B-replay #:step-spec #,B-step-spec #:square #,B-square)
         #:diagnostic-forms
         ((module+ diagnostics
            (provide #,B-encode-MB #,B-decode-BM #,B-readback
                     #,B-corresponds #,B-replay #,B-step-spec #,B-square))
          (define-metafunction #,B-language
            #,B-encode-MB : M -> B
            [(#,B-encode-MB (MFinal T)) (BFinal T)]
            [(#,B-encode-MB (MAllocate AR SourceWorkFocus))
             (BRun AR SourceWorkFocus)]
            [(#,B-encode-MB (MWork NonAllocateRun SourceWorkFocus))
             (BRun NonAllocateRun SourceWorkFocus)]
            [(#,B-encode-MB (MWork (in-hole Frame Settled) SourceWorkFocus))
             (BSettled Settled (in-hole SourceWorkFocus Frame))]
            [(#,B-encode-MB
              (MWork (in-hole Frame #,dead-term) SourceWorkFocus))
             (BDead #,failure-summary-var
                    (in-hole SourceWorkFocus Frame))]
            [(#,B-encode-MB
              (MFrontier (in-hole RootFocus Settled) SourceSpineContext))
             (BSettled Settled
                       (in-hole SourceSpineContext RootFocus))]
            [(#,B-encode-MB
             (MFrontier
               (in-hole RootFocus #,dead-term)
               SourceSpineContext))
             (BDead #,failure-summary-var
                    (in-hole SourceSpineContext RootFocus))]
            [(#,B-encode-MB (MFrontier FR SourceSpineContext))
             (BFrontier FR SourceSpineContext)])
          (define-metafunction #,B-language
            #,B-decode-BM : B -> M
            [(#,B-decode-BM (BFinal T)) (MFinal T)]
            [(#,B-decode-BM (BRun AR SourceWorkFocus))
             (MAllocate AR SourceWorkFocus)]
            [(#,B-decode-BM (BRun NonAllocateRun SourceWorkFocus))
             (MWork NonAllocateRun SourceWorkFocus)]
            [(#,B-decode-BM (BFrontier FR SourceSpineContext))
             (MFrontier FR SourceSpineContext)]
            [(#,B-decode-BM
              (BSettled Settled (in-hole SourceWorkFocus Frame)))
             (MWork (in-hole Frame Settled) SourceWorkFocus)]
            [(#,B-decode-BM
              (BDead #,failure-summary-var
                     (in-hole SourceWorkFocus Frame)))
             (MWork
              (in-hole Frame #,dead-term)
              SourceWorkFocus)]
            [(#,B-decode-BM
              (BSettled Settled (in-hole SourceSpineContext RootFocus)))
             (MFrontier (in-hole RootFocus Settled) SourceSpineContext)]
            [(#,B-decode-BM
              (BDead
               #,failure-summary-var
               (in-hole SourceSpineContext RootFocus)))
             (MFrontier
              (in-hole RootFocus #,dead-term)
              SourceSpineContext)])
          (define-metafunction #,B-language
            #,B-readback : B -> SourceF
            [(#,B-readback (BRun NonAllocateRun SourceWorkFocus))
             (in-hole SourceWorkFocus NonAllocateRun)]
            [(#,B-readback (BRun AR SourceWorkFocus))
             (in-hole SourceWorkFocus AR)]
            [(#,B-readback (BFrontier FR SourceSpineContext))
             (in-hole SourceSpineContext FR)]
            [(#,B-readback (BSettled Settled SourceWorkFocus))
             (in-hole SourceWorkFocus Settled)]
            [(#,B-readback
              (BDead #,failure-summary-var SourceWorkFocus))
             (in-hole SourceWorkFocus #,dead-term)]
            [(#,B-readback (BFinal T)) T])
          (define-judgment-form #,B-language
            #:mode (#,B-corresponds I O)
            #:contract (#,B-corresponds M B)
            [(where B_0 (#,B-compress M_0))
             ---- (#,B-corresponds M_0 B_0)])
          (define-judgment-form #,B-language
            #:mode (#,B-replay I O O)
            #:contract (#,B-replay M TransitionSpan M)
            [(#,M-step M_0 SingletonRuleName M_1)
             ----
             (#,B-replay M_0 (transition-span SingletonRuleName) M_1)]
            [(#,M-step M_0 SettledProducerName M_1)
             (#,M-step M_1 SettledFollowerName M_2)
             ----
             (#,B-replay M_0
                        (transition-span
                         SettledProducerName SettledFollowerName)
                        M_2)]
            [(#,M-step M_0 DeadProducerName M_1)
             (#,M-step M_1 DeadFollowerName M_2)
             ----
             (#,B-replay M_0
                        (transition-span DeadProducerName DeadFollowerName)
                        M_2)])
          (define-judgment-form #,B-language
            #:mode (#,B-step-spec I O O)
            #:contract (#,B-step-spec B TransitionSpan B)
            [(where M_0 (#,B-decode-BM B_0))
             (#,B-replay M_0 TransitionSpan_0 M_1)
             (where B_1 (#,B-encode-MB M_1))
             ---- (#,B-step-spec B_0 TransitionSpan_0 B_1)])
          (define-judgment-form #,B-language
            #:mode (#,B-square I O O O O)
            #:contract (#,B-square B TransitionSpan B M M)
            [(where M_0 (#,B-decode-BM B_0))
             (#,B-replay M_0 TransitionSpan_0 M_1)
             (where B_1 (#,B-encode-MB M_1))
             (#,B-step B_0 TransitionSpan_0 B_1)
             ---- (#,B-square B_0 TransitionSpan_0 B_1 M_0 M_1)]))]

        #:Big
        [#:parameters #,(phase-parameters "BIG" Big-phase)
         #:artifacts
         (Big-artifacts
          #:language #,Big-language
          #:dispatch-one #,Big-dispatch-one #:dispatch #,Big-dispatch
          #:refocus-frontier-direct #,Big-refocus-frontier
          #:control-one #,Big-control-one #:control #,Big-control
          #:frontier #,Big-frontier #:run #,Big-run
          #:settled #,Big-settled #:dead #,Big-dead #:final #,Big-final
          #:evaluate #,Big-evaluate
          #:promotion-language #,Big-language #:promote #,Big-promote)
         #:forms
         ((provide #,Big-language #,Big-dispatch-one #,Big-dispatch
                   #,Big-refocus-frontier #,Big-control-one #,Big-control
                   #,Big-frontier #,Big-run #,Big-settled #,Big-dead
                   #,Big-final #,Big-evaluate #,Big-promote)
          (define-extended-language #,Big-language BASE-BIG-LANGUAGE
            [g .... (suspend g tag)]
            [W .... #,pending-grammar]
            [F .... #,forced-grammar]
            [SpineContext .... #,forced-spine]
            [T .... #,forced-terminal]
            [Big .... (BigFinal T)]
            [WR .... #,suspended-work #,bubble-source]
            [FR .... #,force-source]
            [RunW .... #,suspended-work #,bubble-source]
            [NonAllocateRun .... #,suspended-work #,bubble-source]
            ;; A suspended Work remains an active leaf when it appears below
            ;; an inherited structural frame.  Pending is deliberately not
            ;; open: a whole conjunction containing it is the Delay-owned
            ;; bubble redex and must not also take the descent clause.
            [OpenW .... #,suspended-work]
            [B
             ....
             (BRun NonAllocateRun SourceWorkFocus)
             (BRun AR SourceWorkFocus)
             (BFrontier FR SourceSpineContext)
             (BSettled Settled SourceWorkFocus)
             (BDead FailureSummary SourceWorkFocus)
             (BFinal T)]
            ;; Redex preserves inherited production references to their
            ;; original language.  Repeat only the generic continuation and
            ;; control shells so their payloads are checked in this exact
            ;; extended language.
            [BigNext
             ....
             (BigContinue SourceW SourceWorkFocus)
             (BigFrontierContinue SourceF)]
            [Control
             ....
             (BigWorkControl SourceW SourceWorkFocus)
             (BigFrontierControl FR SourceSpineContext)]
            [ControlNext
             ....
             (BigControlContinue Control)
             (BigControlDone Big)])
          #,@(dependency-forms "BIG" Big-phase)
          (redex-parameter:define-extended-judgment-form*
           BASE-BIG-DISPATCH-ONE #,Big-language
           #:mode (#,Big-dispatch-one I I O)
           #:parameters ([#,transfer-parameter #,Big-transfer])
           [---------------- "suspend-goal"
            (#,Big-dispatch-one
             #,suspended-work SourceWorkFocus
             (BigFrontierContinue
              (in-hole SourceWorkFocus #,suspended-target)))]
           [(where #,W-attached
                   (#,transfer-parameter
                    #,(pending-prefix supply-local) #,W))
            ---------------- "bubble-delay-through-conj"
            (#,Big-dispatch-one
             #,bubble-source SourceWorkFocus
             (BigFrontierContinue
              (in-hole SourceWorkFocus #,bubble-target)))])
          (redex-parameter:define-extended-judgment-form*
           BASE-BIG-DISPATCH #,Big-language
           #:mode (#,Big-dispatch I I O)
           #:parameters ([dispatch-next #,Big-dispatch-one]))
          (redex-parameter:define-extended-judgment-form*
           BASE-BIG-REFOCUS-FRONTIER #,Big-language
           #:mode (#,Big-refocus-frontier I O))
          (redex-parameter:define-extended-judgment-form*
           BASE-BIG-CONTROL-ONE #,Big-language
           #:mode (#,Big-control-one I O)
           #:parameters
           ([control-work-next #,Big-dispatch-one]
            [control-frontier-refocus #,Big-refocus-frontier])
           [(control-frontier-refocus
             (in-hole SourceSpineContext #,force-target)
             ControlNext_1)
            ---------------- "force-delay"
            (#,Big-control-one
             (BigFrontierControl #,force-source SourceSpineContext)
             ControlNext_1)])
          (redex-parameter:define-extended-judgment-form*
           BASE-BIG-CONTROL #,Big-language
           #:mode (#,Big-control I O)
           #:parameters ([control-next #,Big-control-one]))
          (redex-parameter:define-extended-judgment-form*
           BASE-BIG-FRONTIER #,Big-language
           #:mode (#,Big-frontier I I O)
           #:parameters ([frontier-control #,Big-control]))
          (redex-parameter:define-extended-judgment-form*
           BASE-BIG-RUN #,Big-language
           #:mode (#,Big-run I I O)
           #:parameters ([run-dispatch #,Big-control]))
          (redex-parameter:define-extended-judgment-form*
           BASE-BIG-SETTLED #,Big-language
           #:mode (#,Big-settled I I O)
           #:parameters ([settled-dispatch #,Big-control]))
          (redex-parameter:define-extended-judgment-form*
           BASE-BIG-DEAD #,Big-language
           #:mode (#,Big-dead I I O)
           #:parameters ([dead-dispatch #,Big-control]))
          (redex-parameter:define-extended-judgment-form*
           BASE-BIG-FINAL #,Big-language
           #:mode (#,Big-final I O))
          (redex-parameter:define-extended-judgment-form*
           BASE-BIG-EVALUATE #,Big-language
           #:mode (#,Big-evaluate I O)
           #:parameters
           ([evaluate-dispatch #,Big-control]
            [evaluate-final #,Big-refocus-frontier]))
          (redex-parameter:define-extended-judgment-form*
           BASE-PROMOTE #,Big-language
           #:mode (#,Big-promote I O)
           #:parameters
           ([promote-run #,Big-run]
            [promote-frontier #,Big-frontier]
            [promote-settled #,Big-settled]
            [promote-dead #,Big-dead]
            [promote-final #,Big-final])))
         #:diagnostic-parameters #,(phase-parameters "BIG" Big-phase #t)
         #:diagnostics
         (Big-diagnostics
          #:readback #,Big-readback #:spec-language #,Big-spec-language
          #:initialize #,Big-initialize #:close #,Big-close
          #:flatten #,Big-flatten #:evaluate-spec #,Big-evaluate-spec
          #:unfold-square #,Big-unfold-square
          #:closure-square #,Big-closure-square
          #:root-square #,Big-root-square)
         #:diagnostic-forms
         ((module+ diagnostics
            (provide #,Big-readback #,Big-spec-language #,Big-initialize
                     #,Big-close #,Big-flatten #,Big-evaluate-spec
                     #,Big-unfold-square #,Big-closure-square
                     #,Big-root-square))
          (define-metafunction #,Big-language
            #,Big-readback : Big -> SourceF
            [(#,Big-readback (BigFinal T)) T])
          (define-extended-language #,Big-spec-language #,B-language
            [Big (BigFinal T)]
            [BigNext (BigContinue SourceW SourceWorkFocus)
                     (BigFrontierContinue SourceF)
                     (BigDone Big)]
            [BTrace (TransitionSpan (... ...))])
          (define-judgment-form #,Big-spec-language
            #:mode (#,Big-initialize I O)
            #:contract (#,Big-initialize SourceF B)
            [(#,D-decompose SourceF_0 D_0)
             (where Z_0 (#,Z-refocus-phase D_0))
             (where M_0 (#,M-machineize Z_0))
             (where B_0 (#,B-compress M_0))
             ---- (#,Big-initialize SourceF_0 B_0)])
          (define-judgment-form #,Big-spec-language
            #:mode (#,Big-close I O O)
            #:contract (#,Big-close B BTrace T)
            [---- (#,Big-close (BFinal T) () T)]
            [(#,B-step B_0 TransitionSpan_0 B_1)
             (#,Big-close B_1 (TransitionSpan_rest (... ...)) T_0)
             ----
             (#,Big-close
              B_0
              (TransitionSpan_0 TransitionSpan_rest (... ...))
              T_0)])
          (define-metafunction #,Big-spec-language
            #,Big-flatten : BTrace -> LabelTrace
            [(#,Big-flatten ()) ()]
            [(#,Big-flatten
              (TransitionSpan_0 TransitionSpan_rest (... ...)))
             (RuleName_span (... ...) RuleName_rest (... ...))
             (where (RuleName_span (... ...))
                    (#,B-span-labels TransitionSpan_0))
             (where (RuleName_rest (... ...))
                    (#,Big-flatten
                     (TransitionSpan_rest (... ...))))])
          (define-judgment-form #,Big-spec-language
            #:mode (#,Big-evaluate-spec I O O)
            #:contract (#,Big-evaluate-spec SourceF BTrace Big)
            [(#,Big-initialize SourceF_0 B_0)
             (#,Big-close B_0 BTrace_0 T_0)
             ----
             (#,Big-evaluate-spec SourceF_0 BTrace_0 (BigFinal T_0))])
          (define-judgment-form #,Big-spec-language
            #:mode (#,Big-unfold-square I O O O)
            #:contract (#,Big-unfold-square B TransitionSpan B Big)
            [(#,B-step B_0 TransitionSpan_0 B_1)
             (#,Big-promote B_0 Big_0)
             (#,Big-promote B_1 Big_0)
             ----
             (#,Big-unfold-square B_0 TransitionSpan_0 B_1 Big_0)])
          (define-judgment-form #,Big-spec-language
            #:mode (#,Big-closure-square I O O)
            #:contract (#,Big-closure-square B BTrace Big)
            [(#,Big-close B_0 BTrace_0 T_0)
             (#,Big-promote B_0 (BigFinal T_0))
             ----
             (#,Big-closure-square B_0 BTrace_0 (BigFinal T_0))])
          (define-judgment-form #,Big-spec-language
            #:mode (#,Big-root-square I O O)
            #:contract (#,Big-root-square SourceF BTrace Big)
            [(#,Big-evaluate-spec SourceF_0 BTrace_0 Big_0)
             (#,Big-evaluate SourceF_0 Big_0)
             ----
             (#,Big-root-square SourceF_0 BTrace_0 Big_0)]))])
        (define-syntax #,metadata-id
          (delay-stage-extension-info
           (quote-syntax #,force-target))))))

(define-syntax (assert-generated-delay-stage-force-target stx)
  (syntax-parse stx
    [(_ extension:id #:equals expected)
     (define metadata-id
       (format-id
        #'extension "~a/delay-stage-metadata" (syntax-e #'extension)))
     (define metadata
       (syntax-local-value metadata-id (lambda () #f)))
     (unless (delay-stage-extension-info? metadata)
       (raise-syntax-error
        #f
        "expected a generated Delay stage extension"
        stx
        #'extension))
     (unless
         (equal?
          (syntax->datum
           (delay-stage-extension-info-force-target metadata))
          (syntax->datum #'expected))
       (raise-syntax-error
        #f
        "generated Delay D force target differs"
        stx
        #'expected))
     #'(void)]))

(module+ test-support
  (provide assert-generated-delay-stage-force-target))

(define-syntax (define-generated-delay-stage-extension stx)
  (syntax-parse stx
    [(_ name:id #:source source:id)
     (render-delay-stage-extension
      stx #'name (lookup-delay-source #'source))]))
