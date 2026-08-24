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

(provide define-disjunction-representation-view
         define-generated-disjunction-source
         define-generated-disjunction-stage-extension)

;; Disjunction owns only its goal, left-active work, and emitted-frontier
;; wrappers.  Every carrier nested in those wrappers comes from the selected
;; source visitor, so the schema never inspects a concrete supply/state layout.
(begin-for-syntax
  (struct disjunction-view-binding (declaration)
    #:property prop:procedure
    (lambda (_self use-stx)
      (raise-syntax-error
       #f
       "a Disjunction representation view is valid only after #:representation"
       use-stx)))

  (struct disjunction-view-info
    (choice choice-prefix emit emit-prefix transfer-choice declaration)
    #:transparent)

  (define (source-field self key)
    (hash-ref
     (disjunction-source-binding-fields self)
     key
     (lambda ()
       (error 'disjunction-source-binding "missing field ~a" key))))

  (struct disjunction-source-binding (fields)
    #:property prop:procedure
    (lambda (self use-stx)
      (syntax-parse use-stx
        [(_ #:visit visitor:id argument ...)
         #`(visitor
            #:language #,(source-field self 'language)
            #:Q-export #,(source-field self 'q-export)
            #:Q-rebuild #,(source-field self 'q-rebuild)
            #:Q-focus-export #,(source-field self 'q-focus-export)
            #:Q-focus-rebuild #,(source-field self 'q-focus-rebuild)
            #:Q-root-focus-export #,(source-field self 'q-root-focus-export)
            #:Q-root-focus-rebuild #,(source-field self 'q-root-focus-rebuild)
            #:Q-failure-focus-export
            #,(source-field self 'q-failure-focus-export)
            #:Q-failure-focus-rebuild
            #,(source-field self 'q-failure-focus-rebuild)
            #:Q-terminal-export #,(source-field self 'q-terminal-export)
            #:Q-terminal-rebuild #,(source-field self 'q-terminal-rebuild)
            argument ...)]
        [(_ #:visit-extension visitor:id argument ...)
         #`(visitor
            #:language #,(source-field self 'language)
            #:redex-parameters #,(source-field self 'redex-parameters)
            #:branch-copy #,(source-field self 'branch-copy)
            #:R-work-raw #,(source-field self 'work-raw)
            #:R-frontier-raw #,(source-field self 'frontier-raw)
            #:R-allocation-raw #,(source-field self 'allocation-raw)
            #:subst-goal #,(source-field self 'subst-goal)
            #:subst-goal-open #,(source-field self 'subst-goal-open)
            #:wf-root #,(source-field self 'wf-root)
            #:wf-goal #,(source-field self 'wf-goal)
            #:wf-answer #,(source-field self 'wf-answer)
            #:wf-returned #,(source-field self 'wf-returned)
            #:live-supply #,(source-field self 'live-supply)
            #:failure-summary #,(source-field self 'failure-summary)
            #:wf-work #,(source-field self 'wf-work)
            #:wf-frontier #,(source-field self 'wf-frontier)
            #:WF-open
            [#:goal-case #,(source-field self 'wf-goal-case)
             #:goal-tasks #,(source-field self 'wf-goal-tasks)
             #:live-case #,(source-field self 'live-case)
             #:node-case #,(source-field self 'wf-node-case)
             #:nodes #,(source-field self 'wf-nodes)]
            #:carrier-view
            [#:state #,(source-field self 'state-template)
             #:answer #,(source-field self 'answer-template)
             #:returned #,(source-field self 'returned-template)
             #:work #,(source-field self 'work-template)
             #:dead #,(source-field self 'dead-template)
             #:conj #,(source-field self 'conj-template)
             #:last #,(source-field self 'last-template)
             #:more #,(source-field self 'more-template)
             #:empty-supply #,(source-field self 'empty-supply)]
            #:prefix-view
            [#:extend-premises
             (#,@(syntax->list (source-field self 'prefix-extend-premises)))
             #:Q-empty #,(source-field self 'q-prefix-empty)
             #:work-focus-support #,(source-field self 'work-focus-prefix)
             #:work-focus-support-open
             #,(source-field self 'work-focus-prefix-open)
             #:transfer-work #,(source-field self 'transfer-work)
             #:transfer-work-open #,(source-field self 'transfer-work-open)
             #:transfer-work-host #,(source-field self 'transfer-work-host)
             #:Q-export-local #,(source-field self 'q-export-local)
             #:Q-rebuild-local #,(source-field self 'q-rebuild-local)]
            #:Q-open
            [#:work-export #,(source-field self 'q-work-export-open)
             #:work-support #,(source-field self 'q-work-support-open)
             #:work-rebuild #,(source-field self 'q-work-rebuild-open)
             #:frontier-export #,(source-field self 'q-frontier-export-open)
             #:frontier-support #,(source-field self 'q-frontier-support-open)
             #:frontier-rebuild #,(source-field self 'q-frontier-rebuild-open)
             #:path-export #,(source-field self 'q-path-export-open)
             #:path-rebuild #,(source-field self 'q-path-rebuild-open)
             #:failure-export #,(source-field self 'q-failure-export)
             #:failure-rebuild #,(source-field self 'q-failure-rebuild)
             #:address-goal #,(source-field self 'q-address-goal-open)]
            #:Q-context-open
            [#:frontier-export #,(source-field self 'q-frontier-context-export)
             #:frontier-support #,(source-field self 'q-frontier-context-support)
             #:frontier-rebuild #,(source-field self 'q-frontier-context-rebuild)
             #:spine-export #,(source-field self 'q-spine-export-open)
             #:spine-rebuild #,(source-field self 'q-spine-rebuild-open)
             #:focus-shape #,(source-field self 'q-focus-shape-open)
             #:focus-shape-rebuild
             #,(source-field self 'q-focus-shape-rebuild-open)
             #:work-export-dependencies
             #,(source-field self 'q-work-export-dependencies-open)
             #:frontier-export-dependencies
             #,(source-field self 'q-frontier-export-dependencies-open)
             #:path-export-dependencies
             #,(source-field self 'q-path-export-dependencies-open)
             #:path-rebuild-dependencies
             #,(source-field self 'q-path-rebuild-dependencies-open)]
            argument ...)]
        [(_ #:instantiate-with _renderer:id #:instance _instance:id)
         (raise-syntax-error
          #f
          (string-append
           "Disjunction sources are staged by applying their feature extension "
           "to an already-generated selected row")
          use-stx)]
        [_
         (raise-syntax-error
          #f
          "a generated Disjunction source is valid only through its visitor protocol"
          use-stx)])))

  (define (parse-view-declaration declaration)
    (syntax-parse declaration
      [(_ _name:id
          #:choice choice
          #:choice-prefix choice-prefix
          #:emit emit
          #:emit-prefix emit-prefix
          #:transfer-choice transfer-choice:id)
       (disjunction-view-info
        #'choice #'choice-prefix #'emit #'emit-prefix #'transfer-choice
        declaration)]))

  (define (lookup-view identifier)
    (define value (syntax-local-value identifier (lambda () #f)))
    (unless (disjunction-view-binding? value)
      (raise-syntax-error
       #f "expected a Disjunction representation view" identifier))
    (parse-view-declaration
     (disjunction-view-binding-declaration value)))

  (define (lookup-source identifier)
    (define value (syntax-local-value identifier (lambda () #f)))
    (unless (disjunction-source-binding? value)
      (raise-syntax-error
       #f "expected a generated Disjunction source" identifier))
    value)

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

  (define (render-generated-source use-stx view base outputs)
    (define (base-ref key) (hash-ref base key))
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
    (define (output base-id suffix)
      (format-id base-id "~a/~a" (syntax-e base-id) suffix))
    (define (term template replacements)
      (instantiate-template template replacements))
    (define (host-expression template replacements)
      #`(quasiquote
         #,(instantiate-template
            template
            (for/list ([replacement (in-list replacements)])
              (cons (car replacement) #`(unquote #,(cdr replacement)))))))
    (define (match-pattern template replacements)
      #`(quasiquote
         #,(instantiate-template
            template
            (for/list ([replacement (in-list replacements)])
              (cons (car replacement) #`(unquote #,(cdr replacement)))))))

    (define base-language (base-ref 'language))
    (define base-parameters (base-ref 'redex-parameters))
    (define base-branch-copy (base-ref 'branch-copy))
    (define base-work-raw (base-ref 'work-raw))
    (define base-frontier-raw (base-ref 'frontier-raw))
    (define base-allocation-raw (base-ref 'allocation-raw))
    (define base-subst-goal (base-ref 'subst-goal))
    (define base-subst-goal-open (base-ref 'subst-goal-open))
    (define base-wf-root (base-ref 'wf-root))
    (define base-wf-goal (base-ref 'wf-goal))
    (define base-wf-answer (base-ref 'wf-answer))
    (define base-wf-returned (base-ref 'wf-returned))
    (define base-live-supply (base-ref 'live-supply))
    (define base-failure-summary (base-ref 'failure-summary))
    (define base-wf-work (base-ref 'wf-work))
    (define base-wf-frontier (base-ref 'wf-frontier))
    (define base-wf-goal-case (base-ref 'wf-goal-case))
    (define base-wf-goal-tasks (base-ref 'wf-goal-tasks))
    (define base-live-case (base-ref 'live-case))
    (define base-wf-node-case (base-ref 'wf-node-case))
    (define base-wf-nodes (base-ref 'wf-nodes))
    (define state-template (base-ref 'state-template))
    (define answer-template (base-ref 'answer-template))
    (define returned-template (base-ref 'returned-template))
    (define work-template (base-ref 'work-template))
    (define dead-template (base-ref 'dead-template))
    (define conj-template (base-ref 'conj-template))
    (define last-template (base-ref 'last-template))
    (define more-template (base-ref 'more-template))
    (define empty-supply (base-ref 'empty-supply))
    (define q-prefix-empty (base-ref 'q-prefix-empty))
    (define prefix-premises (base-ref 'prefix-premises))
    (define base-work-focus-prefix (base-ref 'work-focus-prefix))
    (define base-work-focus-prefix-open (base-ref 'work-focus-prefix-open))
    (define base-work-focus-open?
      (and base-work-focus-prefix-open
           (syntax-e base-work-focus-prefix-open)))
    (define base-transfer-work (base-ref 'transfer-work))
    (define base-transfer-open (base-ref 'transfer-work-open))
    (define base-transfer-host (base-ref 'transfer-work-host))
    (define q-export-local (base-ref 'q-export-local))
    (define q-rebuild-local (base-ref 'q-rebuild-local))
    (define base-q-work-export-open (base-ref 'q-work-export-open))
    (define base-q-work-support-open (base-ref 'q-work-support-open))
    (define base-q-work-rebuild-open (base-ref 'q-work-rebuild-open))
    (define base-q-frontier-export-open (base-ref 'q-frontier-export-open))
    (define base-q-frontier-support-open (base-ref 'q-frontier-support-open))
    (define base-q-frontier-rebuild-open (base-ref 'q-frontier-rebuild-open))
    (define base-q-path-export-open (base-ref 'q-path-export-open))
    (define base-q-path-rebuild-open (base-ref 'q-path-rebuild-open))
    (define q-failure-export (base-ref 'q-failure-export))
    (define q-failure-rebuild (base-ref 'q-failure-rebuild))
    (define base-q-address-goal-open (base-ref 'q-address-goal-open))
    (define base-context? (base-ref 'q-context?))
    (define base-q-frontier-context-export
      (base-ref 'q-frontier-context-export))
    (define base-q-frontier-context-support
      (base-ref 'q-frontier-context-support))
    (define base-q-frontier-context-rebuild
      (base-ref 'q-frontier-context-rebuild))
    (define base-q-spine-export-open (base-ref 'q-spine-export-open))
    (define base-q-spine-rebuild-open (base-ref 'q-spine-rebuild-open))
    (define base-q-focus-shape-open (base-ref 'q-focus-shape-open))
    (define base-q-focus-shape-rebuild-open
      (base-ref 'q-focus-shape-rebuild-open))
    (define base-q-work-export-dependencies-open
      (base-ref 'q-work-export-dependencies-open))
    (define base-q-frontier-export-dependencies-open
      (base-ref 'q-frontier-export-dependencies-open))
    (define base-q-path-export-dependencies-open
      (base-ref 'q-path-export-dependencies-open))
    (define base-q-path-rebuild-dependencies-open
      (base-ref 'q-path-rebuild-dependencies-open))

    (define supply (slot 'supply))
    (define supply-in (slot 'supply_in))
    (define supply-local (slot 'supply_local))
    (define supply-out (slot 'supply_out))
    (define supply-body (slot 'supply_body))
    (define supply-choice (slot 'supply_choice))
    (define supply-dead (slot 'supply_dead))
    (define supply-inner (slot 'supply_inner))
    (define supply-outer (slot 'supply_outer))
    (define supply-answer (slot 'supply_answer))
    (define sigma (slot 'sigma))
    (define sub (slot 'sub))
    (define dis (slot 'dis))
    (define trail (slot 'trail))
    (define state-tag (slot 'tag_state))
    (define g (slot 'g))
    (define g-1 (slot 'g_1))
    (define g-2 (slot 'g_2))
    (define tag (slot 'tag))
    (define x-bound (slot 'x_bound))
    (define W (slot 'W))
    (define W-1 (slot 'W_1))
    (define W-2 (slot 'W_2))
    (define W-left (slot 'W_left))
    (define W-attached (slot 'W_attached))
    (define W-settled (slot 'W_settled))
    (define W-residual (slot 'W_residual))
    (define W-target (slot 'W_target))
    (define A (slot 'A))
    (define F (slot 'F))
    (define WorkPath (slot 'WorkPath))
    (define SpineContext (slot 'SpineContext))
    (define support (slot 'support))

    (define (state local)
      (term state-template
            (list (cons 'supply local) (cons 'sub sub) (cons 'dis dis)
                  (cons 'trail trail) (cons 'tag state-tag))))
    (define (answer local state-value)
      (term answer-template
            (list (cons 'supply local) (cons 'sigma state-value))))
    (define (returned local state-value)
      (term returned-template
            (list (cons 'supply local) (cons 'sigma state-value))))
    (define (work local goal state-value)
      (term work-template
            (list (cons 'supply local) (cons 'g goal)
                  (cons 'sigma state-value))))
    (define (dead local)
      (term dead-template (list (cons 'supply local))))
    (define (conj local body goal)
      (term conj-template
            (list (cons 'supply local) (cons 'W body) (cons 'g goal))))
    (define (last local answer-value)
      (term last-template
            (list (cons 'supply local) (cons 'A answer-value))))
    (define (more body)
      (term more-template (list (cons 'W body))))
    (define (choice local left right)
      (term (disjunction-view-info-choice view)
            (list (cons 'supply local) (cons 'W_1 left) (cons 'W_2 right))))
    (define (emit local answer-value frontier)
      (term (disjunction-view-info-emit view)
            (list (cons 'supply local) (cons 'A answer-value)
                  (cons 'F frontier))))
    (define (choice-prefix local)
      (term (disjunction-view-info-choice-prefix view)
            (list (cons 'supply local) (cons 'empty empty-supply))))
    (define (emit-prefix local)
      (term (disjunction-view-info-emit-prefix view)
            (list (cons 'supply local) (cons 'empty empty-supply))))

    (define current-state (state supply))
    (define copied-state
      (state #`(#,base-branch-copy #,supply)))
    (define expansion-source
      (work supply #`(#,g-1 ∨ #,g-2 #,tag) current-state))
    (define expansion-left (work empty-supply g-1 copied-state))
    (define expansion-right (work empty-supply g-2 copied-state))
    (define expansion-target
      (choice (choice-prefix supply) expansion-left expansion-right))
    (define skip-dead (dead supply-dead))
    (define skip-source
      (choice (choice-prefix supply-choice) skip-dead W-2))
    (define returned-answer (returned supply-answer (state supply-answer)))
    (define reassociate-source
      (choice
       (choice-prefix supply-outer)
       (choice (choice-prefix supply-inner) returned-answer W-left)
       W-2))
    (define reassociate-target
      (choice
       (choice-prefix supply-outer)
       W-settled
       (choice (choice-prefix empty-supply) W-residual W-2)))
    (define commit-source
      (more
       (choice (choice-prefix supply-choice) returned-answer W-2)))
    (define commit-target
      (emit
       (emit-prefix supply-choice)
       (answer supply-answer (state supply-answer))
       (more W-2)))
    (define resume-source
      (conj
       supply-outer
       (choice (choice-prefix supply-choice) returned-answer W-2)
       g))
    (define resume-unattached-target
      (choice
       (choice-prefix supply-choice)
       (work supply-answer g (state supply-answer))
       (conj empty-supply W-2 g)))

    (define choice-grammar (choice (choice-prefix supply) W-1 W-2))
    (define emit-grammar (emit (emit-prefix supply) A F))
    (define choice-wf-term
      (choice (choice-prefix supply-local) W-1 W-2))
    (define emit-wf-term
      (emit (emit-prefix supply-local) A F))
    (define choice-path (choice (choice-prefix supply) WorkPath W))
    (define emit-spine (emit (emit-prefix supply) A SpineContext))
    (define emit-terminal (emit (emit-prefix supply) A (slot 'T)))
    (define choice-match
      (match-pattern
       (disjunction-view-info-choice view)
       (list (cons 'supply supply-local)
             (cons 'W_1 W-1) (cons 'W_2 W-2))))
    (define emit-match
      (match-pattern
       (disjunction-view-info-emit view)
       (list (cons 'supply supply-local) (cons 'A A) (cons 'F F))))
    (define choice-path-match
      (match-pattern
       (disjunction-view-info-choice view)
       (list (cons 'supply supply-local)
             (cons 'W_1 WorkPath) (cons 'W_2 W))))
    (define emit-spine-match
      (match-pattern
       (disjunction-view-info-emit view)
       (list (cons 'supply supply-local)
             (cons 'A A) (cons 'F SpineContext))))
    (define last-match
      (match-pattern last-template
                     (list (cons 'supply supply-local) (cons 'A A))))
    (define more-match
      (match-pattern more-template (list (cons 'W WorkPath))))
    (define choice-expression
      (lambda (local left right)
        (host-expression
         (disjunction-view-info-choice view)
         (list (cons 'supply local) (cons 'W_1 left) (cons 'W_2 right)))))
    (define emit-expression
      (lambda (local answer-value frontier)
        (host-expression
         (disjunction-view-info-emit view)
         (list (cons 'supply local) (cons 'A answer-value)
               (cons 'F frontier)))))
    (define choice-prefix-expression
      (lambda (local)
        (host-expression
         (disjunction-view-info-choice-prefix view)
         (list (cons 'supply local)
               (cons 'empty #`(term #,empty-supply))))))
    (define emit-prefix-expression
      (lambda (local)
        (host-expression
         (disjunction-view-info-emit-prefix view)
         (list (cons 'supply local)
               (cons 'empty #`(term #,empty-supply))))))
    (define more-expression
      (lambda (body)
        (host-expression more-template (list (cons 'W body)))))
    (define last-expression
      (lambda (local answer-value)
        (host-expression
         last-template
         (list (cons 'supply local) (cons 'A answer-value)))))

    (define work-raw-id (output relation-id "work-raw"))
    (define frontier-raw-id (output relation-id "frontier-raw"))
    (define allocation-raw-id (output relation-id "allocation-raw"))
    (define work-base-id (output relation-id "work-base"))
    (define frontier-base-id (output relation-id "frontier-base"))
    (define transfer-host-id (output relation-id "transfer-work-prefix"))
    (define transfer-open-id (output relation-id "transfer-work-prefix/open"))
    (define transfer-direct-id (output relation-id "transfer-work-prefix/direct"))
    (define transfer-parameter-id (output relation-id "work-transfer"))
    (define subst-goal-id (output relation-id "subst-goal"))
    (define subst-goal-open-id (output relation-id "subst-goal/open"))
    (define subst-goal-host-id (output relation-id "subst-goal/host"))
    (define work-focus-id (output relation-id "work-focus-prefix-support"))
    (define work-focus-open-id
      (output relation-id "work-focus-prefix-support/open"))
    (define work-focus-host-id
      (output relation-id "work-focus-prefix-support/host"))
    (define wf-goal-case-id (output wf-root-id "goal-case"))
    (define wf-goal-tasks-id (output wf-root-id "goal-tasks"))
    (define wf-goal-id (output wf-root-id "goal"))
    (define live-case-id (output live-supply-id "one"))
    (define wf-node-case-id (output wf-root-id "node-case"))
    (define wf-nodes-id (output wf-root-id "nodes"))
    (define wf-work-id (output wf-root-id "work"))
    (define wf-frontier-id (output wf-root-id "frontier"))

    ;; Q driver names are deliberately regular because every descendant source
    ;; rebuilds the same open recursion shell in its exact language.
    (define q-address-open-id (output q-rebuild-id "address-goal/open"))
    (define q-address-id (output q-rebuild-id "address-goal"))
    (define q-work-export-open-id (output q-export-id "work/open"))
    (define q-work-export-dependencies-open-id
      (output q-export-id "work/dependencies-open"))
    (define q-work-export-id (output q-export-id "work"))
    (define q-work-support-open-id (output q-export-id "work-support/open"))
    (define q-work-support-id (output q-export-id "work-support"))
    (define q-work-rebuild-open-id (output q-rebuild-id "work/open"))
    (define q-work-rebuild-id (output q-rebuild-id "work"))
    (define q-frontier-context-export-id
      (output q-export-id "frontier/context-open"))
    (define q-frontier-export-dependencies-open-id
      (output q-export-id "frontier/dependencies-open"))
    (define q-frontier-export-open-id (output q-export-id "frontier/open"))
    (define q-frontier-export-id (output q-export-id "frontier"))
    (define q-frontier-context-support-id
      (output q-export-id "frontier-support/context-open"))
    (define q-frontier-support-open-id
      (output q-export-id "frontier-support/open"))
    (define q-frontier-support-id (output q-export-id "frontier-support"))
    (define q-frontier-context-rebuild-id
      (output q-rebuild-id "frontier/context-open"))
    (define q-frontier-rebuild-open-id (output q-rebuild-id "frontier/open"))
    (define q-frontier-rebuild-id (output q-rebuild-id "frontier"))
    (define q-path-export-open-id (output q-export-id "path/open"))
    (define q-path-export-dependencies-open-id
      (output q-export-id "path/dependencies-open"))
    (define q-path-export-id (output q-export-id "path"))
    (define q-path-rebuild-open-id (output q-rebuild-id "path/open"))
    (define q-path-rebuild-dependencies-open-id
      (output q-rebuild-id "path/dependencies-open"))
    (define q-path-rebuild-id (output q-rebuild-id "path"))
    (define q-spine-export-open-id (output q-export-id "spine/open"))
    (define q-spine-export-id (output q-export-id "spine"))
    (define q-spine-rebuild-open-id (output q-rebuild-id "spine/open"))
    (define q-spine-rebuild-id (output q-rebuild-id "spine"))
    (define q-focus-shape-open-id (output q-export-id "focus-shape/open"))
    (define q-focus-shape-id (output q-export-id "focus-shape"))
    (define q-focus-shape-rebuild-open-id
      (output q-rebuild-id "focus-shape/open"))
    (define q-focus-shape-rebuild-id (output q-rebuild-id "focus-shape"))
    (define q-answer-export-id (output q-export-id "answer"))
    (define q-answer-rebuild-id (output q-rebuild-id "answer"))

    (define choice-wf-premises
      (for/list ([premise (in-list prefix-premises)])
        (instantiate-template
         premise
         (list (cons 'supply_in supply-in)
               (cons 'supply_local (choice-prefix supply-local))
               (cons 'supply_out supply-body)))))
    (define emit-wf-premises
      (for/list ([premise (in-list prefix-premises)])
        (instantiate-template
         premise
         (list (cons 'supply_in supply-in)
               (cons 'supply_local (emit-prefix supply-local))
               (cons 'supply_out supply-body)))))

    (define source-parameters
      (for/list ([entry (in-list (syntax->list base-parameters))])
        (syntax-parse entry
          [[local:id default:id] (cons #'local #'default)])))
    (define disjunction-parameters
      (for/list ([entry (in-list source-parameters)])
        (match-define (cons local default) entry)
        (cons
         local
         (cond
           [(free-identifier=? default base-subst-goal) subst-goal-id]
           [(free-identifier=? default base-work-focus-prefix) work-focus-id]
           [else default]))))
    (define q-context-export-base
      (if base-context?
          base-q-frontier-context-export
          base-q-frontier-export-open))
    (define q-context-support-base
      (if base-context?
          base-q-frontier-context-support
          base-q-frontier-support-open))
    (define q-context-rebuild-base
      (if base-context?
          base-q-frontier-context-rebuild
          base-q-frontier-rebuild-open))

    #`(begin
        (define-syntax #,binding-id
          (disjunction-source-binding
           (hasheq
            'language (quote-syntax #,language-id)
            'redex-parameters
            (quote-syntax
             (#,@(for/list ([entry (in-list disjunction-parameters)])
                   #`[#,(car entry) #,(cdr entry)])))
            'branch-copy (quote-syntax #,base-branch-copy)
            'relation (quote-syntax #,relation-id)
            'raw-successors (quote-syntax #,raw-successors-id)
            'work-raw (quote-syntax #,work-raw-id)
            'frontier-raw (quote-syntax #,frontier-raw-id)
            'allocation-raw (quote-syntax #,allocation-raw-id)
            'subst-goal (quote-syntax #,subst-goal-id)
            'subst-goal-open (quote-syntax #,subst-goal-open-id)
            'wf-root (quote-syntax #,wf-root-id)
            'wf-goal (quote-syntax #,wf-goal-id)
            'wf-answer (quote-syntax #,base-wf-answer)
            'wf-returned (quote-syntax #,base-wf-returned)
            'live-supply (quote-syntax #,live-supply-id)
            'failure-summary (quote-syntax #,failure-summary-id)
            'wf-work (quote-syntax #,wf-work-id)
            'wf-frontier (quote-syntax #,wf-frontier-id)
            'wf-goal-case (quote-syntax #,wf-goal-case-id)
            'wf-goal-tasks (quote-syntax #,wf-goal-tasks-id)
            'live-case (quote-syntax #,live-case-id)
            'wf-node-case (quote-syntax #,wf-node-case-id)
            'wf-nodes (quote-syntax #,wf-nodes-id)
            'state-template (quote-syntax #,state-template)
            'answer-template (quote-syntax #,answer-template)
            'returned-template (quote-syntax #,returned-template)
            'work-template (quote-syntax #,work-template)
            'dead-template (quote-syntax #,dead-template)
            'conj-template (quote-syntax #,conj-template)
            'last-template (quote-syntax #,last-template)
            'more-template (quote-syntax #,more-template)
            'empty-supply (quote-syntax #,empty-supply)
            'q-prefix-empty (quote-syntax #,q-prefix-empty)
            'prefix-extend-premises (quote-syntax (#,@prefix-premises))
            'work-focus-prefix (quote-syntax #,work-focus-id)
            'work-focus-prefix-open (quote-syntax #,work-focus-open-id)
            'transfer-work (quote-syntax #,transfer-direct-id)
            'transfer-work-open (quote-syntax #,transfer-open-id)
            'transfer-work-host (quote-syntax #,transfer-host-id)
            'q-export-local (quote-syntax #,q-export-local)
            'q-rebuild-local (quote-syntax #,q-rebuild-local)
            'q-work-export-open (quote-syntax #,q-work-export-open-id)
            'q-work-support-open (quote-syntax #,q-work-support-open-id)
            'q-work-rebuild-open (quote-syntax #,q-work-rebuild-open-id)
            'q-frontier-export-open (quote-syntax #,q-frontier-export-open-id)
            'q-frontier-support-open (quote-syntax #,q-frontier-support-open-id)
            'q-frontier-rebuild-open (quote-syntax #,q-frontier-rebuild-open-id)
            'q-path-export-open (quote-syntax #,q-path-export-open-id)
            'q-path-rebuild-open (quote-syntax #,q-path-rebuild-open-id)
            'q-failure-export (quote-syntax #,q-failure-export)
            'q-failure-rebuild (quote-syntax #,q-failure-rebuild)
            'q-address-goal-open (quote-syntax #,q-address-open-id)
            'q-frontier-context-export
            (quote-syntax #,q-frontier-context-export-id)
            'q-frontier-context-support
            (quote-syntax #,q-frontier-context-support-id)
            'q-frontier-context-rebuild
            (quote-syntax #,q-frontier-context-rebuild-id)
            'q-spine-export-open (quote-syntax #,q-spine-export-open-id)
            'q-spine-rebuild-open (quote-syntax #,q-spine-rebuild-open-id)
            'q-focus-shape-open (quote-syntax #,q-focus-shape-open-id)
            'q-focus-shape-rebuild-open
            (quote-syntax #,q-focus-shape-rebuild-open-id)
            'q-work-export-dependencies-open
            (quote-syntax #,q-work-export-dependencies-open-id)
            'q-frontier-export-dependencies-open
            (quote-syntax #,q-frontier-export-dependencies-open-id)
            'q-path-export-dependencies-open
            (quote-syntax #,q-path-export-dependencies-open-id)
            'q-path-rebuild-dependencies-open
            (quote-syntax #,q-path-rebuild-dependencies-open-id)
            'q-export (quote-syntax #,q-export-id)
            'q-rebuild (quote-syntax #,q-rebuild-id)
            'q-focus-export (quote-syntax #,q-focus-export-id)
            'q-focus-rebuild (quote-syntax #,q-focus-rebuild-id)
            'q-root-focus-export (quote-syntax #,q-root-focus-export-id)
            'q-root-focus-rebuild (quote-syntax #,q-root-focus-rebuild-id)
            'q-failure-focus-export
            (quote-syntax #,q-failure-focus-export-id)
            'q-failure-focus-rebuild
            (quote-syntax #,q-failure-focus-rebuild-id)
            'q-terminal-export (quote-syntax #,q-terminal-export-id)
            'q-terminal-rebuild (quote-syntax #,q-terminal-rebuild-id)
            'choice-template (quote-syntax #,(disjunction-view-info-choice view))
            'choice-prefix-template
            (quote-syntax #,(disjunction-view-info-choice-prefix view))
            'emit-template (quote-syntax #,(disjunction-view-info-emit view))
            'emit-prefix-template
            (quote-syntax #,(disjunction-view-info-emit-prefix view)))))

        (define-extended-language #,language-id #,base-language
          [g .... (g ∨ g tag)]
          [W .... #,choice-grammar]
          [F .... #,emit-grammar]
          [WorkPath .... #,choice-path]
          [SpineContext .... #,emit-spine])

        ;; Goal substitution/addressing remain open: a later feature can add a
        ;; goal constructor without copying the inherited disjunction clause.
        (define (#,subst-goal-open-id recur goal substitutions)
          (match goal
            [`(,left ∨ ,right ,goal-tag)
             `(,(recur left substitutions)
               ∨
               ,(recur right substitutions)
               ,goal-tag)]
            [_ (#,base-subst-goal-open recur goal substitutions)]))
        (define (#,q-address-open-id recur goal support-value)
          (match goal
            [`(,left ∨ ,right ,goal-tag)
             `(,(recur left support-value)
               ∨
               ,(recur right support-value)
               ,goal-tag)]
            [_ (#,base-q-address-goal-open recur goal support-value)]))
        (define (#,q-address-id goal support-value)
          (#,q-address-open-id #,q-address-id goal support-value))

        (define (#,subst-goal-host-id goal substitutions)
          (#,subst-goal-open-id
           #,subst-goal-host-id goal substitutions))

        (redex-parameter:define-extended-metafunction*
         #,base-subst-goal #,language-id #,subst-goal-id : g alloc -> g
         [(#,subst-goal-id g alloc)
          ,(#,subst-goal-host-id (term g) (term alloc))])

        ;; DisjL is an active WorkPath node, so allocation support follows its
        ;; left child after accounting for the wrapper's local prefix.
        (define (#,work-focus-open-id focus support-value recur)
          (match focus
            [#,choice-path-match
             (match-define (list _provenance support-next)
               (#,q-export-local
                #,(host-expression
                   (disjunction-view-info-choice-prefix view)
                   (list (cons 'supply supply-local)
                         (cons 'empty #`(term #,empty-supply))))
                support-value))
             (recur #,WorkPath support-next)]
            [#,emit-spine-match
             (match-define (list _provenance support-next)
               (#,q-export-local
                #,(host-expression
                   (disjunction-view-info-emit-prefix view)
                   (list (cons 'supply supply-local)
                         (cons 'empty #`(term #,empty-supply))))
                support-value))
             (recur #,SpineContext support-next)]
            [_ #,(if base-work-focus-open?
                     #`(#,base-work-focus-prefix-open
                        focus support-value recur)
                     #'support-value)]))
        (define (#,work-focus-host-id focus support-value)
          (#,work-focus-open-id
           focus support-value #,work-focus-host-id))
        (redex-parameter:define-extended-metafunction*
         #,base-work-focus-prefix #,language-id
         #,work-focus-id : WorkFocus support -> support
         [(#,work-focus-id WorkFocus support)
          ,(#,work-focus-host-id
            (term WorkFocus) (term support))])

        (define (#,transfer-open-id prefix work-value extension)
          (match work-value
            [#,choice-match
             (#,(disjunction-view-info-transfer-choice view)
              prefix work-value)]
            [_ (#,base-transfer-open prefix work-value extension)]))
        (define (#,transfer-host-id prefix work-value)
          (#,transfer-open-id
           prefix work-value
           (lambda (_prefix unsupported)
             (error '#,transfer-host-id
                    "expected an extensible work carrier, received ~e"
                    unsupported))))
        #,@(if (and base-transfer-work (syntax-e base-transfer-work))
               (list
                #`(redex-parameter:define-extended-metafunction*
                   #,base-transfer-work #,language-id
                   #,transfer-direct-id : any W -> W
                   [(#,transfer-direct-id any_0 W)
                    ,(#,transfer-host-id (term any_0) (term W))]))
               (list
                #`(redex-parameter:define-metafunction*
                   #,language-id #,transfer-direct-id : any W -> W
                   [(#,transfer-direct-id any_0 W)
                    ,(#,transfer-host-id (term any_0) (term W))])))

        (redex-parameter:define-extended-reduction-relation*
         #,work-raw-id #,base-work-raw #,language-id
         #:parameters ([#,transfer-parameter-id #,transfer-direct-id])
         #:domain any
         [--> #,expansion-source #,expansion-target "expand-disjunction"]
         [--> #,skip-source #,W-attached
              (where #,W-attached
                     (#,transfer-parameter-id
                      #,(choice-prefix supply-choice) #,W-2))
              "skip-left-failure"]
         [--> #,reassociate-source #,reassociate-target
              (where #,W-settled
                     (#,transfer-parameter-id
                      #,(choice-prefix supply-inner) #,returned-answer))
              (where #,W-residual
                     (#,transfer-parameter-id
                      #,(choice-prefix supply-inner) #,W-left))
              "reassociate-left-result"]
         [--> #,resume-source #,W-target
              (where #,W-target
                     (#,transfer-parameter-id
                      #,(choice-prefix supply-outer)
                      #,resume-unattached-target))
              "resume-left-choice-success"])
        (redex-parameter:define-extended-reduction-relation*
         #,frontier-raw-id #,base-frontier-raw #,language-id
         #:domain any
         [--> #,commit-source #,commit-target "commit-choice-answer"])
        (redex-parameter:define-extended-reduction-relation*
         #,allocation-raw-id #,base-allocation-raw #,language-id #:domain F)
        (define #,work-base-id
          (context-closure #,work-raw-id #,language-id WorkFocus))
        (define #,frontier-base-id
          (context-closure #,frontier-raw-id #,language-id SpineContext))
        (define #,relation-id
          (extend-reduction-relation
           (union-reduction-relations
            #,work-base-id #,frontier-base-id #,allocation-raw-id)
           #,language-id
           #:domain F))
        (define (#,raw-successors-id frontier)
          (for/list ([named-step
                      (in-list
                       (apply-reduction-relation/tag-with-names
                        #,relation-id frontier))])
            (match-define (list name target) named-step)
            (list (string->symbol (~a name)) target)))

        ;; Exact-language WF cases retain the two sibling obligations instead
        ;; of collapsing their possibly incomparable supplies.
        (redex-parameter:define-extended-judgment-form*
         #,base-wf-goal-case #,language-id
         #:mode (#,wf-goal-case-id I O)
         [----
          (#,wf-goal-case-id
           (GoalCheck
            (#,g-1 ∨ #,g-2 #,tag)
            (#,x-bound (... ...))
            #,supply-in)
           (GoalChecks
            (GoalCheck #,g-1 (#,x-bound (... ...)) #,supply-in)
            (GoalCheck #,g-2 (#,x-bound (... ...)) #,supply-in)))])
        (redex-parameter:define-extended-judgment-form*
         #,base-wf-goal-tasks #,language-id
         #:mode (#,wf-goal-tasks-id I)
         #:parameters ([wf-goal-next #,wf-goal-case-id]))
        (redex-parameter:define-extended-judgment-form*
         #,base-wf-goal #,language-id
         #:mode (#,wf-goal-id I I I)
         #:parameters ([wf-goal-run #,wf-goal-tasks-id]))
        (redex-parameter:define-extended-judgment-form*
         #,base-live-case #,language-id
         #:mode (#,live-case-id I I O)
         [#,@choice-wf-premises
          ----
          (#,live-case-id #,choice-wf-term #,supply-in
                          (LiveContinue #,W-1 #,supply-body))])
        #,(render-selected-live-supply-driver
           language-id live-supply-id base-live-case)
        (redex-parameter:define-extended-judgment-form*
         #,base-wf-node-case #,language-id
         #:mode (#,wf-node-case-id I O)
         #:parameters
         ([wf-node-goal #,wf-goal-id]
          [wf-node-live #,live-supply-id])
         [#,@choice-wf-premises
          ----
          (#,wf-node-case-id
           (WorkCheck #,choice-wf-term #,supply-in)
           (NodeChecks
            (WorkCheck #,W-1 #,supply-body)
            (WorkCheck #,W-2 #,supply-body)))]
         [#,@emit-wf-premises
          (#,base-wf-answer #,A #,supply-body)
          ----
          (#,wf-node-case-id
           (FrontierCheck #,emit-wf-term #,supply-in)
           (NodeChecks (FrontierCheck #,F #,supply-body)))])
        (redex-parameter:define-extended-judgment-form*
         #,base-wf-nodes #,language-id
         #:mode (#,wf-nodes-id I)
         #:parameters ([wf-node-next #,wf-node-case-id]))
        (redex-parameter:define-extended-judgment-form*
         #,base-wf-work #,language-id
         #:mode (#,wf-work-id I I)
         #:parameters ([wf-work-run #,wf-nodes-id]))
        (redex-parameter:define-extended-judgment-form*
         #,base-wf-frontier #,language-id
         #:mode (#,wf-frontier-id I I)
         #:parameters ([wf-frontier-run #,wf-nodes-id]))
        (redex-parameter:define-extended-judgment-form*
         #,base-wf-root #,language-id
         #:mode (#,wf-root-id I)
         #:parameters ([wf-root-frontier #,wf-frontier-id]))
        (define-metafunction #,language-id
          #,failure-summary-id : any -> supply
          [(#,failure-summary-id any_0) (#,base-failure-summary any_0)])

        ;; The Q implementation follows below; keeping it in this schema lets
        ;; one feature declaration render the same sibling-aware neutral view
        ;; for S, E, and N.
        #,@(render-disjunction-q-forms
            view
            (hasheq
             'language language-id
             'q-prefix-empty q-prefix-empty
             'empty-supply empty-supply
             'choice-match choice-match
             'choice-path-match choice-path-match
             'emit-match emit-match
             'emit-spine-match emit-spine-match
             'last-match last-match
             'more-match more-match
             'choice-expression choice-expression
             'emit-expression emit-expression
             'choice-prefix-expression choice-prefix-expression
             'emit-prefix-expression emit-prefix-expression
             'more-expression more-expression
             'last-expression last-expression
             'choice-prefix choice-prefix
             'emit-prefix emit-prefix
             'q-export-local q-export-local
             'q-rebuild-local q-rebuild-local
             'base-q-work-export-open base-q-work-export-open
             'base-q-work-support-open base-q-work-support-open
             'base-q-work-rebuild-open base-q-work-rebuild-open
             'base-q-frontier-export-open base-q-frontier-export-open
             'base-q-frontier-support-open base-q-frontier-support-open
             'base-q-frontier-rebuild-open base-q-frontier-rebuild-open
             'base-q-path-export-open base-q-path-export-open
             'base-q-path-rebuild-open base-q-path-rebuild-open
             'base-q-address-goal-open base-q-address-goal-open
             'base-context? base-context?
             'base-q-frontier-context-export q-context-export-base
             'base-q-frontier-context-support q-context-support-base
             'base-q-frontier-context-rebuild q-context-rebuild-base
             'base-q-spine-export-open base-q-spine-export-open
             'base-q-spine-rebuild-open base-q-spine-rebuild-open
             'base-q-focus-shape-open base-q-focus-shape-open
             'base-q-focus-shape-rebuild-open
             base-q-focus-shape-rebuild-open
             'base-q-work-export-dependencies-open
             base-q-work-export-dependencies-open
             'base-q-frontier-export-dependencies-open
             base-q-frontier-export-dependencies-open
             'base-q-path-export-dependencies-open
             base-q-path-export-dependencies-open
             'base-q-path-rebuild-dependencies-open
             base-q-path-rebuild-dependencies-open
             'q-address-open q-address-open-id
             'q-address q-address-id
             'q-work-export-open q-work-export-open-id
             'q-work-export-dependencies-open
             q-work-export-dependencies-open-id
             'q-work-export q-work-export-id
             'q-work-support-open q-work-support-open-id
             'q-work-support q-work-support-id
             'q-work-rebuild-open q-work-rebuild-open-id
             'q-work-rebuild q-work-rebuild-id
             'q-frontier-context-export q-frontier-context-export-id
             'q-frontier-export-dependencies-open
             q-frontier-export-dependencies-open-id
             'q-frontier-export-open q-frontier-export-open-id
             'q-frontier-export q-frontier-export-id
             'q-frontier-context-support q-frontier-context-support-id
             'q-frontier-support-open q-frontier-support-open-id
             'q-frontier-support q-frontier-support-id
             'q-frontier-context-rebuild q-frontier-context-rebuild-id
             'q-frontier-rebuild-open q-frontier-rebuild-open-id
             'q-frontier-rebuild q-frontier-rebuild-id
             'q-path-export-open q-path-export-open-id
             'q-path-export-dependencies-open
             q-path-export-dependencies-open-id
             'q-path-export q-path-export-id
             'q-path-rebuild-open q-path-rebuild-open-id
             'q-path-rebuild-dependencies-open
             q-path-rebuild-dependencies-open-id
             'q-path-rebuild q-path-rebuild-id
             'q-spine-export-open q-spine-export-open-id
             'q-spine-export q-spine-export-id
             'q-spine-rebuild-open q-spine-rebuild-open-id
             'q-spine-rebuild q-spine-rebuild-id
             'q-focus-shape-open q-focus-shape-open-id
             'q-focus-shape q-focus-shape-id
             'q-focus-shape-rebuild-open q-focus-shape-rebuild-open-id
             'q-focus-shape-rebuild q-focus-shape-rebuild-id
             'q-answer-export q-answer-export-id
             'q-answer-rebuild q-answer-rebuild-id
             'q-export q-export-id 'q-rebuild q-rebuild-id
             'q-focus-export q-focus-export-id
             'q-focus-rebuild q-focus-rebuild-id
             'q-root-focus-export q-root-focus-export-id
             'q-root-focus-rebuild q-root-focus-rebuild-id
             'q-failure-export q-failure-export
             'q-failure-rebuild q-failure-rebuild
             'q-failure-focus-export q-failure-focus-export-id
             'q-failure-focus-rebuild q-failure-focus-rebuild-id
             'q-terminal-export q-terminal-export-id
             'q-terminal-rebuild q-terminal-rebuild-id))))

  ;; Defined after `render-generated-source`; the binding is available at phase
  ;; one when that renderer runs.
  (define (render-disjunction-q-forms view fields)
    (define (ref key) (hash-ref fields key))
    (define language (ref 'language))
    (define (slot symbol)
      (datum->syntax language symbol language language))
    (define q-prefix-empty (ref 'q-prefix-empty))
    (define empty-supply (ref 'empty-supply))
    (define choice-match (ref 'choice-match))
    (define choice-path-match (ref 'choice-path-match))
    (define emit-match (ref 'emit-match))
    (define emit-spine-match (ref 'emit-spine-match))
    (define last-match (ref 'last-match))
    (define more-match (ref 'more-match))
    (define choice-expression (ref 'choice-expression))
    (define emit-expression (ref 'emit-expression))
    (define choice-prefix-expression (ref 'choice-prefix-expression))
    (define emit-prefix-expression (ref 'emit-prefix-expression))
    (define more-expression (ref 'more-expression))
    (define last-expression (ref 'last-expression))
    (define q-export-local (ref 'q-export-local))
    (define q-rebuild-local (ref 'q-rebuild-local))
    (define base-q-work-export-open (ref 'base-q-work-export-open))
    (define base-q-work-support-open (ref 'base-q-work-support-open))
    (define base-q-work-rebuild-open (ref 'base-q-work-rebuild-open))
    (define base-q-frontier-export-open (ref 'base-q-frontier-export-open))
    (define base-q-frontier-support-open (ref 'base-q-frontier-support-open))
    (define base-q-frontier-rebuild-open (ref 'base-q-frontier-rebuild-open))
    (define base-q-path-export-open (ref 'base-q-path-export-open))
    (define base-q-path-rebuild-open (ref 'base-q-path-rebuild-open))
    (define base-context? (ref 'base-context?))
    (define base-q-frontier-context-export
      (ref 'base-q-frontier-context-export))
    (define base-q-frontier-context-support
      (ref 'base-q-frontier-context-support))
    (define base-q-frontier-context-rebuild
      (ref 'base-q-frontier-context-rebuild))
    (define base-q-spine-export-open (ref 'base-q-spine-export-open))
    (define base-q-spine-rebuild-open (ref 'base-q-spine-rebuild-open))
    (define base-q-focus-shape-open (ref 'base-q-focus-shape-open))
    (define base-q-focus-shape-rebuild-open
      (ref 'base-q-focus-shape-rebuild-open))
    (define base-q-work-export-dependencies-open
      (ref 'base-q-work-export-dependencies-open))
    (define base-q-frontier-export-dependencies-open
      (ref 'base-q-frontier-export-dependencies-open))
    (define base-q-path-export-dependencies-open
      (ref 'base-q-path-export-dependencies-open))
    (define base-q-path-rebuild-dependencies-open
      (ref 'base-q-path-rebuild-dependencies-open))
    (define q-address (ref 'q-address))
    (define q-work-export-open (ref 'q-work-export-open))
    (define q-work-export-dependencies-open
      (ref 'q-work-export-dependencies-open))
    (define q-work-export (ref 'q-work-export))
    (define q-work-support-open (ref 'q-work-support-open))
    (define q-work-support (ref 'q-work-support))
    (define q-work-rebuild-open (ref 'q-work-rebuild-open))
    (define q-work-rebuild (ref 'q-work-rebuild))
    (define q-frontier-context-export (ref 'q-frontier-context-export))
    (define q-frontier-export-dependencies-open
      (ref 'q-frontier-export-dependencies-open))
    (define q-frontier-export-open (ref 'q-frontier-export-open))
    (define q-frontier-export (ref 'q-frontier-export))
    (define q-frontier-context-support (ref 'q-frontier-context-support))
    (define q-frontier-support-open (ref 'q-frontier-support-open))
    (define q-frontier-support (ref 'q-frontier-support))
    (define q-frontier-context-rebuild (ref 'q-frontier-context-rebuild))
    (define q-frontier-rebuild-open (ref 'q-frontier-rebuild-open))
    (define q-frontier-rebuild (ref 'q-frontier-rebuild))
    (define q-path-export-open (ref 'q-path-export-open))
    (define q-path-export-dependencies-open
      (ref 'q-path-export-dependencies-open))
    (define q-path-export (ref 'q-path-export))
    (define q-path-rebuild-open (ref 'q-path-rebuild-open))
    (define q-path-rebuild-dependencies-open
      (ref 'q-path-rebuild-dependencies-open))
    (define q-path-rebuild (ref 'q-path-rebuild))
    (define q-spine-export-open (ref 'q-spine-export-open))
    (define q-spine-export (ref 'q-spine-export))
    (define q-spine-rebuild-open (ref 'q-spine-rebuild-open))
    (define q-spine-rebuild (ref 'q-spine-rebuild))
    (define q-focus-shape-open (ref 'q-focus-shape-open))
    (define q-focus-shape (ref 'q-focus-shape))
    (define q-focus-shape-rebuild-open (ref 'q-focus-shape-rebuild-open))
    (define q-focus-shape-rebuild (ref 'q-focus-shape-rebuild))
    (define q-answer-export (ref 'q-answer-export))
    (define q-answer-rebuild (ref 'q-answer-rebuild))
    (define q-export (ref 'q-export))
    (define q-rebuild (ref 'q-rebuild))
    (define q-focus-export (ref 'q-focus-export))
    (define q-focus-rebuild (ref 'q-focus-rebuild))
    (define q-root-focus-export (ref 'q-root-focus-export))
    (define q-root-focus-rebuild (ref 'q-root-focus-rebuild))
    (define q-failure-export (ref 'q-failure-export))
    (define q-failure-rebuild (ref 'q-failure-rebuild))
    (define q-failure-focus-export (ref 'q-failure-focus-export))
    (define q-failure-focus-rebuild (ref 'q-failure-focus-rebuild))
    (define q-terminal-export (ref 'q-terminal-export))
    (define q-terminal-rebuild (ref 'q-terminal-rebuild))
    (define base-work-export-dependencies?
      (and base-q-work-export-dependencies-open
           (syntax-e base-q-work-export-dependencies-open)))
    (define base-frontier-export-dependencies?
      (and base-q-frontier-export-dependencies-open
           (syntax-e base-q-frontier-export-dependencies-open)))
    (define base-path-export-dependencies?
      (and base-q-path-export-dependencies-open
           (syntax-e base-q-path-export-dependencies-open)))
    (define base-path-rebuild-dependencies?
      (and base-q-path-rebuild-dependencies-open
           (syntax-e base-q-path-rebuild-dependencies-open)))
    (define supply-local (slot 'supply_local))
    (define W-1 (slot 'W_1))
    (define W-2 (slot 'W_2))
    (define W (slot 'W))
    (define F (slot 'F))
    (define A (slot 'A))
    (define WorkPath (slot 'WorkPath))
    (define SpineContext (slot 'SpineContext))
    (list
     #`(define (#,q-work-export-dependencies-open
                work support recur-work recur-work-support)
         (match work
           [#,choice-match
            (match-define (list provenance common-support)
              (#,q-export-local
               #,(choice-prefix-expression supply-local)
               support))
            (define q-left (recur-work #,W-1 common-support))
            (define q-right (recur-work #,W-2 common-support))
            `(q-disjunction
              ,provenance
              ,common-support
              ,q-left
              ,(recur-work-support q-left)
              ,q-right
              ,(recur-work-support q-right))]
           [_
            #,(if base-work-export-dependencies?
                  #`(#,base-q-work-export-dependencies-open
                     work support recur-work recur-work-support)
                  #`(#,base-q-work-export-open
                     work support recur-work))]))
     #`(define (#,q-work-export-open work support recur)
         (#,q-work-export-dependencies-open
          work support recur #,q-work-support))
     #`(define (#,q-work-export work support)
         (#,q-work-export-open work support #,q-work-export))
     #`(define (#,q-work-support-open neutral recur)
         (match neutral
           [`(q-disjunction
              ,_provenance ,_common-support
              ,_q-left ,left-support
              ,_q-right ,_right-support)
            left-support]
           [_ (#,base-q-work-support-open neutral recur)]))
     #`(define (#,q-work-support neutral)
         (#,q-work-support-open neutral #,q-work-support))
     #`(define (#,q-work-rebuild-open neutral support recur map-goal)
         (match neutral
           [`(q-disjunction
              ,provenance ,_common-support
              ,q-left ,left-support
              ,q-right ,right-support)
            #,(choice-expression
               #`(#,q-rebuild-local provenance)
               #`(recur q-left left-support)
               #`(recur q-right right-support))]
           [_
            (#,base-q-work-rebuild-open
             neutral support recur map-goal)]))
     #`(define (#,q-work-rebuild neutral support)
         (#,q-work-rebuild-open
          neutral support #,q-work-rebuild #,q-address))

     ;; Answers are neutralized through the source's own Last carrier.  This
     ;; avoids inspecting an S/E/N Answer layout while retaining its support.
     #`(define (#,q-answer-export answer support)
         (define neutral
           (#,q-frontier-export
            #,(last-expression #`(term #,empty-supply) #`answer)
            support))
         (list neutral (#,q-frontier-support neutral)))
     #`(define (#,q-answer-rebuild neutral support)
         (match (#,q-frontier-rebuild neutral support)
           [#,last-match #,A]
           [other
            (error '#,q-answer-rebuild
                   "expected a neutral Last answer, received ~e"
                   other)]))

     #`(define (#,q-frontier-export-dependencies-open
                frontier support
                recur-work recur-frontier recur-frontier-support)
         (match frontier
           [#,emit-match
            (match-define (list provenance common-support)
              (#,q-export-local
               #,(emit-prefix-expression supply-local)
               support))
            (match-define (list q-answer answer-support)
              (#,q-answer-export #,A common-support))
            (define q-residual (recur-frontier #,F common-support))
            `(q-emit
              ,provenance
              ,common-support
              ,q-answer
              ,answer-support
              ,q-residual
              ,(recur-frontier-support q-residual))]
           [_
            #,(cond
                [base-frontier-export-dependencies?
                 #`(#,base-q-frontier-export-dependencies-open
                    frontier support
                    recur-work recur-frontier recur-frontier-support)]
                [base-context?
                 #`(#,base-q-frontier-context-export
                    frontier support recur-work recur-frontier)]
                [else
                 #`(#,base-q-frontier-export-open
                    frontier support recur-work)])]))
     #`(define (#,q-frontier-context-export
                frontier support recur-work recur-frontier)
         (#,q-frontier-export-dependencies-open
          frontier support
          recur-work recur-frontier #,q-frontier-support))
     #`(define (#,q-frontier-export-open frontier support recur-work)
         (#,q-frontier-context-export
          frontier support recur-work #,q-frontier-export))
     #`(define (#,q-frontier-export frontier support)
         (#,q-frontier-export-open
          frontier support #,q-work-export))
     #`(define (#,q-frontier-context-support
                neutral recur-work recur-frontier)
         (match neutral
           [`(q-emit
              ,_provenance ,_common-support
              ,_q-answer ,_answer-support
              ,_q-residual ,residual-support)
            residual-support]
           [_
            #,(if base-context?
                  #`(#,base-q-frontier-context-support
                     neutral recur-work recur-frontier)
                  #`(#,base-q-frontier-support-open neutral recur-work))]))
     #`(define (#,q-frontier-support-open neutral recur-work)
         (#,q-frontier-context-support
          neutral recur-work #,q-frontier-support))
     #`(define (#,q-frontier-support neutral)
         (#,q-frontier-support-open neutral #,q-work-support))
     #`(define (#,q-frontier-context-rebuild
                neutral support recur-work recur-frontier)
         (match neutral
           [`(q-emit
              ,provenance ,_common-support
              ,q-answer ,answer-support
              ,q-residual ,residual-support)
            #,(emit-expression
               #`(#,q-rebuild-local provenance)
               #`(#,q-answer-rebuild q-answer answer-support)
               #`(recur-frontier q-residual residual-support))]
           [_
            #,(if base-context?
                  #`(#,base-q-frontier-context-rebuild
                     neutral support recur-work recur-frontier)
                  #`(#,base-q-frontier-rebuild-open
                     neutral support recur-work))]))
     #`(define (#,q-frontier-rebuild-open neutral support recur-work)
         (#,q-frontier-context-rebuild
          neutral support recur-work #,q-frontier-rebuild))
     #`(define (#,q-frontier-rebuild neutral support)
         (#,q-frontier-rebuild-open
          neutral support #,q-work-rebuild))

     #`(define (#,q-path-export-dependencies-open
                path support
                recur-path recur-work-export recur-work-support)
         (match path
           [#,choice-path-match
            (match-define (list provenance common-support)
              (#,q-export-local
               #,(choice-prefix-expression supply-local)
               support))
            (define-values (q-left-path support-at-hole)
              (recur-path #,WorkPath common-support))
            (define q-right (recur-work-export #,W common-support))
            (values
             `(q-focus-disjunction
               ,provenance
               ,common-support
               ,q-left-path
               ,q-right
               ,(recur-work-support q-right))
             support-at-hole)]
           [_
            #,(if base-path-export-dependencies?
                  #`(#,base-q-path-export-dependencies-open
                     path support
                     recur-path recur-work-export recur-work-support)
                  #`(#,base-q-path-export-open
                     path support recur-path))]))
     #`(define (#,q-path-export-open path support recur)
         (#,q-path-export-dependencies-open
          path support recur #,q-work-export #,q-work-support))
     #`(define (#,q-path-export path support)
         (#,q-path-export-open path support #,q-path-export))
     #`(define (#,q-path-rebuild-dependencies-open
                neutral support recur-path map-goal recur-work-rebuild)
         (match neutral
           [`(q-focus-disjunction
              ,provenance ,_common-support ,q-left-path
              ,q-right ,right-support)
            #,(choice-expression
               #`(#,q-rebuild-local provenance)
               #`(recur-path q-left-path support)
               #`(recur-work-rebuild q-right right-support))]
           [_
            #,(if base-path-rebuild-dependencies?
                  #`(#,base-q-path-rebuild-dependencies-open
                     neutral support
                     recur-path map-goal recur-work-rebuild)
                  #`(#,base-q-path-rebuild-open
                     neutral support recur-path map-goal))]))
     #`(define (#,q-path-rebuild-open neutral support recur map-goal)
         (#,q-path-rebuild-dependencies-open
          neutral support recur map-goal #,q-work-rebuild))
     #`(define (#,q-path-rebuild neutral support)
         (#,q-path-rebuild-open
          neutral support #,q-path-rebuild #,q-address))

     #`(define (#,q-spine-export-open spine support recur)
         (match spine
           [#,emit-spine-match
            (match-define (list provenance common-support)
              (#,q-export-local
               #,(emit-prefix-expression supply-local)
               support))
            (match-define (list q-answer answer-support)
              (#,q-answer-export #,A common-support))
            (define-values (q-spine support-at-hole)
              (recur #,SpineContext common-support))
            (values
             `(q-spine-emit
               ,provenance ,common-support
               ,q-answer ,answer-support ,q-spine)
             support-at-hole)]
           [_
            #,(if base-context?
                  #`(#,base-q-spine-export-open spine support recur)
                  #`(if (equal? spine (term hole))
                        (values 'q-spine-hole support)
                        (error '#,q-spine-export
                               "expected an extensible SpineContext, received ~e"
                               spine)))]))
     #`(define (#,q-spine-export spine support)
         (#,q-spine-export-open spine support #,q-spine-export))
     #`(define (#,q-spine-rebuild-open neutral recur)
         (match neutral
           [`(q-spine-emit
              ,provenance ,_common-support
              ,q-answer ,answer-support ,q-spine)
            #,(emit-expression
               #`(#,q-rebuild-local provenance)
               #`(#,q-answer-rebuild q-answer answer-support)
               #`(recur q-spine))]
           [_
            #,(if base-context?
                  #`(#,base-q-spine-rebuild-open neutral recur)
                  #`(match neutral
                      ['q-spine-hole (term hole)]
                      [other
                       (error '#,q-spine-rebuild
                              "expected a neutral extensible spine, received ~e"
                              other)]))]))
     #`(define (#,q-spine-rebuild neutral)
         (#,q-spine-rebuild-open neutral #,q-spine-rebuild))

     #`(define (#,q-focus-shape-open focus support recur path-export)
         (match focus
           [#,emit-spine-match
            (match-define (list provenance common-support)
              (#,q-export-local
               #,(emit-prefix-expression supply-local)
               support))
            (match-define (list q-answer answer-support)
              (#,q-answer-export #,A common-support))
            (match-define (list q-spine q-path support-at-hole)
              (recur #,SpineContext common-support))
            (list
             `(q-spine-emit
               ,provenance ,common-support
               ,q-answer ,answer-support ,q-spine)
             q-path
             support-at-hole)]
           [_
            #,(if base-context?
                  #`(#,base-q-focus-shape-open
                     focus support recur path-export)
                  #`(match focus
                      [#,more-match
                       (define-values (q-path support-at-hole)
                         (path-export #,WorkPath support))
                       (list 'q-spine-hole q-path support-at-hole)]
                      [other
                       (error '#,q-focus-shape
                              "expected an extensible WorkFocus, received ~e"
                              other)]))]))
     #`(define (#,q-focus-shape focus support)
         (#,q-focus-shape-open
          focus support #,q-focus-shape #,q-path-export))
     #`(define (#,q-focus-shape-rebuild-open
                q-spine q-path support recur path-rebuild)
         (match q-spine
           [`(q-spine-emit
              ,provenance ,_common-support
              ,q-answer ,answer-support ,q-inner)
            #,(emit-expression
               #`(#,q-rebuild-local provenance)
               #`(#,q-answer-rebuild q-answer answer-support)
               #`(recur q-inner q-path support))]
           [_
            #,(if base-context?
                  #`(#,base-q-focus-shape-rebuild-open
                     q-spine q-path support recur path-rebuild)
                  #`(match q-spine
                      ['q-spine-hole
                       #,(more-expression #`(path-rebuild q-path support))]
                      [other
                       (error '#,q-focus-shape-rebuild
                              "expected a neutral extensible spine, received ~e"
                              other)]))]))
     #`(define (#,q-focus-shape-rebuild q-spine q-path support)
         (#,q-focus-shape-rebuild-open
          q-spine q-path support
          #,q-focus-shape-rebuild #,q-path-rebuild))

     #`(define (#,q-export frontier)
         (#,q-frontier-export frontier #,q-prefix-empty))
     #`(define (#,q-rebuild neutral)
         (#,q-frontier-rebuild
          neutral (#,q-frontier-support neutral)))
     #`(define (#,q-focus-export focused focus)
         (match-define (list q-spine q-path support-at-hole)
           (#,q-focus-shape focus #,q-prefix-empty))
         `(q-focused
           ,(#,q-work-export focused support-at-hole)
           (q-work-focus ,q-spine ,q-path)))
     #`(define (#,q-focus-rebuild neutral)
         (match neutral
           [`(q-focused ,q-work (q-work-focus ,q-spine ,q-path))
            (define support (#,q-work-support q-work))
            (list
             (#,q-work-rebuild q-work support)
             (#,q-focus-shape-rebuild q-spine q-path support))]
           [other
            (error '#,q-focus-rebuild
                   "expected a neutral Disjunction focus, received ~e"
                   other)]))
     #`(define (#,q-root-focus-export frontier spine)
         (define-values (q-spine support-at-hole)
           (#,q-spine-export spine #,q-prefix-empty))
         `(q-root-focused
           ,(#,q-frontier-export frontier support-at-hole)
           ,q-spine))
     #`(define (#,q-root-focus-rebuild neutral)
         (match neutral
           [`(q-root-focused ,q-frontier ,q-spine)
            (define support (#,q-frontier-support q-frontier))
            (list
             (#,q-frontier-rebuild q-frontier support)
             (#,q-spine-rebuild q-spine))]
           [other
            (error '#,q-root-focus-rebuild
                   "expected a neutral Disjunction root focus, received ~e"
                   other)]))
     #`(define (#,q-failure-focus-export summary focus)
         (match-define (list q-spine q-path support-at-hole)
           (#,q-focus-shape focus #,q-prefix-empty))
         (match-define (list provenance support)
           (#,q-failure-export summary support-at-hole))
         `(q-failure-focused
           ,provenance ,support (q-work-focus ,q-spine ,q-path)))
     #`(define (#,q-failure-focus-rebuild neutral)
         (match neutral
           [`(q-failure-focused
              ,provenance ,support (q-work-focus ,q-spine ,q-path))
            (list
             (#,q-failure-rebuild provenance support)
             (#,q-focus-shape-rebuild q-spine q-path support))]
           [other
            (error '#,q-failure-focus-rebuild
                   "expected a neutral Disjunction failure focus, received ~e"
                   other)]))
     #`(define (#,q-terminal-export terminal)
         (#,q-frontier-export terminal #,q-prefix-empty))
     #`(define (#,q-terminal-rebuild neutral)
         (#,q-frontier-rebuild
          neutral (#,q-frontier-support neutral)))))
  )

(define-syntax (define-disjunction-representation-view stx)
  (syntax-parse stx
    [(_ name:id . _)
     (parse-view-declaration stx)
     #`(define-syntax name
         (disjunction-view-binding (quote-syntax #,stx)))]))

(define-syntax (render-generated-disjunction-source stx)
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
         #:transfer-work-open base-transfer-open:id
         #:transfer-work-host base-transfer-host:id
         #:Q-export-local q-export-local:id
         #:Q-rebuild-local q-rebuild-local:id]
        #:Q-open
        [#:work-export base-q-work-export-open:id
         #:work-support base-q-work-support-open:id
         #:work-rebuild base-q-work-rebuild-open:id
         #:frontier-export base-q-frontier-export-open:id
         #:frontier-support base-q-frontier-support-open:id
         #:frontier-rebuild base-q-frontier-rebuild-open:id
         #:path-export base-q-path-export-open:id
         #:path-rebuild base-q-path-rebuild-open:id
         #:failure-export q-failure-export:id
         #:failure-rebuild q-failure-rebuild:id
         #:address-goal base-q-address-goal-open:id]
        (~optional
         (~seq
          #:Q-context-open
          [#:frontier-export base-q-frontier-context-export:id
           #:frontier-support base-q-frontier-context-support:id
           #:frontier-rebuild base-q-frontier-context-rebuild:id
           #:spine-export base-q-spine-export-open:id
           #:spine-rebuild base-q-spine-rebuild-open:id
           #:focus-shape base-q-focus-shape-open:id
           #:focus-shape-rebuild base-q-focus-shape-rebuild-open:id
           (~optional
            (~seq #:work-export-dependencies
                  base-q-work-export-dependencies-open:id)
            #:defaults ([base-q-work-export-dependencies-open #'#f]))
           (~optional
            (~seq #:frontier-export-dependencies
                  base-q-frontier-export-dependencies-open:id)
            #:defaults ([base-q-frontier-export-dependencies-open #'#f]))
           (~optional
            (~seq #:path-export-dependencies
                  base-q-path-export-dependencies-open:id)
            #:defaults ([base-q-path-export-dependencies-open #'#f]))
           (~optional
            (~seq #:path-rebuild-dependencies
                  base-q-path-rebuild-dependencies-open:id)
            #:defaults ([base-q-path-rebuild-dependencies-open #'#f]))])
         #:defaults
         ([base-q-frontier-context-export #'#f]
          [base-q-frontier-context-support #'#f]
          [base-q-frontier-context-rebuild #'#f]
          [base-q-spine-export-open #'#f]
          [base-q-spine-rebuild-open #'#f]
          [base-q-focus-shape-open #'#f]
          [base-q-focus-shape-rebuild-open #'#f]
          [base-q-work-export-dependencies-open #'#f]
          [base-q-frontier-export-dependencies-open #'#f]
          [base-q-path-export-dependencies-open #'#f]
          [base-q-path-rebuild-dependencies-open #'#f]))
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
     (define context? (and (syntax-e #'base-q-frontier-context-export) #t))
     (render-generated-source
      stx
      (lookup-view #'representation)
      (hasheq
       'language #'base-language
       'redex-parameters
       #'([base-parameter-local base-parameter-default] ...)
       'branch-copy #'base-branch-copy
       'work-raw #'base-work-raw
       'frontier-raw #'base-frontier-raw
       'allocation-raw #'base-allocation-raw
       'subst-goal #'base-subst-goal
       'subst-goal-open #'base-subst-goal-open
       'wf-root #'base-wf-root 'wf-goal #'base-wf-goal
       'wf-answer #'base-wf-answer 'wf-returned #'base-wf-returned
       'live-supply #'base-live-supply
       'failure-summary #'base-failure-summary
       'wf-work #'base-wf-work 'wf-frontier #'base-wf-frontier
       'wf-goal-case #'base-wf-goal-case
       'wf-goal-tasks #'base-wf-goal-tasks
       'live-case #'base-live-case
       'wf-node-case #'base-wf-node-case 'wf-nodes #'base-wf-nodes
       'state-template #'state-template 'answer-template #'answer-template
       'returned-template #'returned-template 'work-template #'work-template
       'dead-template #'dead-template 'conj-template #'conj-template
       'last-template #'last-template 'more-template #'more-template
       'empty-supply #'empty-supply 'q-prefix-empty #'q-prefix-empty
       'prefix-premises (syntax->list #'(prefix-premise ...))
       'work-focus-prefix #'base-work-focus-prefix
       'work-focus-prefix-open #'base-work-focus-prefix-open
       'transfer-work #'base-transfer-work
       'transfer-work-open #'base-transfer-open
       'transfer-work-host #'base-transfer-host
       'q-export-local #'q-export-local 'q-rebuild-local #'q-rebuild-local
       'q-work-export-open #'base-q-work-export-open
       'q-work-support-open #'base-q-work-support-open
       'q-work-rebuild-open #'base-q-work-rebuild-open
       'q-frontier-export-open #'base-q-frontier-export-open
       'q-frontier-support-open #'base-q-frontier-support-open
       'q-frontier-rebuild-open #'base-q-frontier-rebuild-open
       'q-path-export-open #'base-q-path-export-open
       'q-path-rebuild-open #'base-q-path-rebuild-open
       'q-failure-export #'q-failure-export
       'q-failure-rebuild #'q-failure-rebuild
       'q-address-goal-open #'base-q-address-goal-open
       'q-context? context?
       'q-frontier-context-export #'base-q-frontier-context-export
       'q-frontier-context-support #'base-q-frontier-context-support
       'q-frontier-context-rebuild #'base-q-frontier-context-rebuild
       'q-spine-export-open #'base-q-spine-export-open
       'q-spine-rebuild-open #'base-q-spine-rebuild-open
       'q-focus-shape-open #'base-q-focus-shape-open
       'q-focus-shape-rebuild-open #'base-q-focus-shape-rebuild-open
       'q-work-export-dependencies-open
       #'base-q-work-export-dependencies-open
       'q-frontier-export-dependencies-open
       #'base-q-frontier-export-dependencies-open
       'q-path-export-dependencies-open
       #'base-q-path-export-dependencies-open
       'q-path-rebuild-dependencies-open
       #'base-q-path-rebuild-dependencies-open)
      (list #'binding-id #'language-id #'relation-id #'raw-successors-id
            #'wf-root-id #'live-supply-id #'failure-summary-id
            #'q-export-id #'q-rebuild-id
            #'q-focus-export-id #'q-focus-rebuild-id
            #'q-root-focus-export-id #'q-root-focus-rebuild-id
            #'q-failure-focus-export-id #'q-failure-focus-rebuild-id
            #'q-terminal-export-id #'q-terminal-rebuild-id))]))

(define-syntax (define-generated-disjunction-source stx)
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
        #:visit-extension render-generated-disjunction-source
        #:representation representation
        #:binding binding-id
        #:language language-id
        #:relation relation-id
        #:raw-successors raw-successors-id
        #:wf-root wf-root-id
        #:live-supply live-supply-id
        #:failure-summary failure-summary-id
        #:Q
        [#:export q-export-id #:rebuild q-rebuild-id
         #:focus-export q-focus-export-id #:focus-rebuild q-focus-rebuild-id
         #:root-focus-export q-root-focus-export-id
         #:root-focus-rebuild q-root-focus-rebuild-id
         #:failure-focus-export q-failure-focus-export-id
         #:failure-focus-rebuild q-failure-focus-rebuild-id
         #:terminal-export q-terminal-export-id
         #:terminal-rebuild q-terminal-rebuild-id])]))

(begin-for-syntax
  (define (parse-disjunction-redex-parameters parameters declaration)
    (for/list
        ([entry
          (in-list
           (syntax->list parameters))])
      (syntax-parse entry
        [[local:id default:id] (cons #'local #'default)]
        [_
         (raise-syntax-error
          #f
          "Disjunction source redex parameters must be [local default] pairs"
          declaration
          entry)])))

  (define (render-disjunction-stage-extension
           use-stx name source
           dependency-parameters
           dependency-subst dependency-subst-open
           dependency-focus dependency-focus-open
           dependency-transfer-host)
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

    (define source-language (source-field source 'language))
    (define source-parameters
      (parse-disjunction-redex-parameters dependency-parameters use-stx))
    (define subst-parameter
      (for/first ([parameter (in-list source-parameters)]
                  #:when
                  (free-identifier=? (cdr parameter) dependency-subst))
        (car parameter)))
    (define focus-parameter
      (for/first ([parameter (in-list source-parameters)]
                  #:when
                  (free-identifier=? (cdr parameter) dependency-focus))
        (car parameter)))
    (unless subst-parameter
      (raise-syntax-error
       #f
       "Disjunction source omits its allocation substitution parameter"
       use-stx))
    (unless focus-parameter
      (raise-syntax-error
       #f
       "Disjunction source omits its allocation focus-prefix parameter"
       use-stx))
    (unless (and dependency-focus-open (syntax-e dependency-focus-open))
      (raise-syntax-error
       #f
       "Disjunction staging requires an open WorkFocus prefix traversal"
       use-stx))

    (define branch-copy (source-field source 'branch-copy))
    (define state-template (source-field source 'state-template))
    (define answer-template (source-field source 'answer-template))
    (define returned-template (source-field source 'returned-template))
    (define work-template (source-field source 'work-template))
    (define dead-template (source-field source 'dead-template))
    (define conj-template (source-field source 'conj-template))
    (define more-template (source-field source 'more-template))
    (define choice-template (source-field source 'choice-template))
    (define choice-prefix-template
      (source-field source 'choice-prefix-template))
    (define emit-template (source-field source 'emit-template))
    (define emit-prefix-template (source-field source 'emit-prefix-template))
    (define empty-supply (source-field source 'empty-supply))

    (define supply (slot 'supply))
    (define supply-local (slot 'supply_local))
    (define supply-choice (slot 'supply_choice))
    (define supply-dead (slot 'supply_dead))
    (define supply-inner (slot 'supply_inner))
    (define supply-outer (slot 'supply_outer))
    (define supply-answer (slot 'supply_answer))
    (define g (slot 'g))
    (define g-1 (slot 'g_1))
    (define g-2 (slot 'g_2))
    (define tag (slot 'tag))
    (define sigma (slot 'sigma))
    (define W (slot 'W))
    (define W-1 (slot 'W_1))
    (define W-2 (slot 'W_2))
    (define W-left (slot 'W_left))
    (define W-attached (slot 'W_attached))
    (define W-settled (slot 'W_settled))
    (define W-residual (slot 'W_residual))
    (define W-target (slot 'W_target))
    (define A (slot 'A))
    (define F (slot 'F))
    (define SourceWorkFocus (slot 'SourceWorkFocus))
    (define SourceSpineContext (slot 'SourceSpineContext))
    (define WorkPath (slot 'WorkPath))
    (define SpineContext (slot 'SpineContext))
    (define hole (slot 'hole))

    (define (term template replacements)
      (instantiate-template template replacements))
    (define (state local)
      (term state-template (list (cons 'supply local))))
    (define (answer local state-value)
      (term answer-template
            (list (cons 'supply local) (cons 'sigma state-value))))
    (define (returned local state-value)
      (term returned-template
            (list (cons 'supply local) (cons 'sigma state-value))))
    (define (work local goal state-value)
      (term work-template
            (list (cons 'supply local) (cons 'g goal)
                  (cons 'sigma state-value))))
    (define (dead local)
      (term dead-template (list (cons 'supply local))))
    (define (conj local body goal)
      (term conj-template
            (list (cons 'supply local) (cons 'W body) (cons 'g goal))))
    (define (more body)
      (term more-template (list (cons 'W body))))
    (define (choice local left right)
      (term choice-template
            (list (cons 'supply local)
                  (cons 'W_1 left) (cons 'W_2 right))))
    (define (emit local answer-value frontier)
      (term emit-template
            (list (cons 'supply local)
                  (cons 'A answer-value) (cons 'F frontier))))
    (define (choice-prefix local)
      (term choice-prefix-template
            (list (cons 'supply local) (cons 'empty empty-supply))))
    (define (emit-prefix local)
      (term emit-prefix-template
            (list (cons 'supply local) (cons 'empty empty-supply))))

    (define current-state (state supply))
    (define copied-state (state #`(#,branch-copy #,supply)))
    (define expansion-source
      (work supply #`(#,g-1 ∨ #,g-2 #,tag) current-state))
    (define expansion-target
      (choice
       (choice-prefix supply)
       (work empty-supply g-1 copied-state)
       (work empty-supply g-2 copied-state)))
    (define skip-dead (dead supply-dead))
    (define skip-source
      (choice (choice-prefix supply-choice) skip-dead W-2))
    (define returned-answer (returned supply-answer (state supply-answer)))
    (define reassociate-source
      (choice
       (choice-prefix supply-outer)
       (choice (choice-prefix supply-inner) returned-answer W-left)
       W-2))
    (define reassociate-target
      (choice
       (choice-prefix supply-outer)
       W-settled
       (choice (choice-prefix empty-supply) W-residual W-2)))
    (define commit-source
      (more
       (choice (choice-prefix supply-choice) returned-answer W-2)))
    (define commit-target
      (emit
       (emit-prefix supply-choice)
       (answer supply-answer (state supply-answer))
       (more W-2)))
    (define resume-source
      (conj
       supply-outer
       (choice (choice-prefix supply-choice) returned-answer W-2)
       g))
    (define resume-unattached-target
      (choice
       (choice-prefix supply-choice)
       (work supply-answer g (state supply-answer))
       (conj empty-supply W-2 g)))

    (define choice-grammar (choice (choice-prefix supply) W-1 W-2))
    (define emit-grammar (emit (emit-prefix supply) A F))
    (define choice-path
      (choice (choice-prefix supply) WorkPath W))
    (define choice-frame
      (choice (choice-prefix supply) hole W))
    (define emit-spine
      (emit (emit-prefix supply) A SpineContext))
    (define emit-terminal
      (emit (emit-prefix supply) A (slot 'T)))
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
      (match-define
        (list _language subst _subst-host focus _focus-host transfer)
        data)
      #`(#,@(for/list ([parameter (in-list source-parameters)])
               (match-define (cons local default) parameter)
               #`[#,local
                  #,(cond
                      [(free-identifier=? default dependency-subst) subst]
                      [(free-identifier=? default dependency-focus) focus]
                      [else (placeholder phase local diagnostic?)])])
         [#,transfer-parameter #,transfer]))

    (define (dependency-forms phase data)
      (match-define (list language subst subst-host focus focus-host transfer)
        data)
      (define base-subst (placeholder phase subst-parameter))
      (define base-focus (placeholder phase focus-parameter))
      (list
       #`(define (#,subst-host goal substitutions)
           (#,dependency-subst-open #,subst-host goal substitutions))
       #`(redex-parameter:define-extended-metafunction*
          #,base-subst #,language #,subst : g alloc -> g
          [(#,subst g alloc)
           ,(#,subst-host (term g) (term alloc))])
       #`(define (#,focus-host focus-value support-value)
           (#,dependency-focus-open
            focus-value support-value #,focus-host))
       #`(redex-parameter:define-extended-metafunction*
          #,base-focus #,language #,focus : WorkFocus support -> support
          [(#,focus WorkFocus support)
           ,(#,focus-host (term WorkFocus) (term support))])
       #`(redex-parameter:define-metafunction*
         #,language #,transfer : any W -> W
          [(#,transfer any_0 W)
           ,(#,dependency-transfer-host (term any_0) (term W))])))

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
    (define B-feature-singleton (output "B-feature-singleton"))
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

    #`(begin
        #,(render-disjunction-stage-extension-body
           name source-language
           (hasheq
            'phase-parameters phase-parameters
            'dependency-forms dependency-forms
            'D-phase D-phase 'Z-phase Z-phase 'M-phase M-phase
            'B-phase B-phase 'Big-phase Big-phase
            'D-transfer D-transfer 'Z-transfer Z-transfer
            'M-transfer M-transfer 'B-transfer B-transfer
            'Big-transfer Big-transfer
            'transfer-parameter transfer-parameter
            'choice-grammar choice-grammar 'emit-grammar emit-grammar
            'choice-path choice-path 'choice-frame choice-frame
            'emit-spine emit-spine 'emit-terminal emit-terminal
            'expansion-source expansion-source
            'expansion-target expansion-target
            'skip-source skip-source 'skip-dead skip-dead
            'reassociate-source reassociate-source
            'reassociate-target reassociate-target
            'commit-source commit-source 'commit-target commit-target
            'resume-source resume-source
            'resume-unattached-target resume-unattached-target
            'choice-prefix choice-prefix
            'supply-choice supply-choice 'supply-dead supply-dead
            'supply-inner supply-inner
            'supply-outer supply-outer 'supply-local supply-local
            'W W 'W-2 W-2 'W-left W-left
            'W-attached W-attached 'W-settled W-settled
            'W-residual W-residual 'W-target W-target
            'returned-answer returned-answer
            'failure-summary-var failure-summary-var 'dead-term dead-term
            'D-language D-language 'D-plug-D D-plug-D
            'D-plug-C D-plug-C 'D-contract-label D-contract-label
            'D-decompose D-decompose 'D-contract D-contract 'D-step D-step
            'Z-language Z-language 'Z-refocus-phase Z-refocus-phase
            'Z-refocus-work Z-refocus-work
            'Z-refocus-frontier Z-refocus-frontier
            'Z-refocus Z-refocus 'Z-step Z-step
            'Z-D->Z Z-D->Z 'Z-Z->D Z-Z->D 'Z-readback Z-readback
            'Z-refocus-spec Z-refocus-spec 'Z-step-spec Z-step-spec
            'M-language M-language 'M-machineize M-machineize
            'M-refocus-work M-refocus-work
            'M-refocus-frontier M-refocus-frontier
            'M-refocus M-refocus 'M-step M-step
            'M-encode-ZM M-encode-ZM 'M-decode-MZ M-decode-MZ
            'M-D->M M-D->M 'M-M->D M-M->D 'M-readback M-readback
            'M-corresponds M-corresponds 'M-step-spec M-step-spec
            'M-square M-square
            'B-language B-language 'B-compress B-compress
            'B-refocus-frontier B-refocus-frontier
            'B-span-labels B-span-labels
            'B-produce-settled B-produce-settled
            'B-produce-dead B-produce-dead
            'B-advance-settled B-advance-settled
            'B-advance-dead B-advance-dead
            'B-feature-singleton B-feature-singleton
            'B-singleton B-singleton 'B-step B-step
            'B-encode-MB B-encode-MB 'B-decode-BM B-decode-BM
            'B-readback B-readback 'B-corresponds B-corresponds
            'B-replay B-replay 'B-step-spec B-step-spec 'B-square B-square
            'Big-language Big-language
            'Big-dispatch-one Big-dispatch-one 'Big-dispatch Big-dispatch
            'Big-refocus-frontier Big-refocus-frontier
            'Big-control-one Big-control-one 'Big-control Big-control
            'Big-frontier Big-frontier 'Big-run Big-run
            'Big-settled Big-settled 'Big-dead Big-dead
            'Big-final Big-final 'Big-evaluate Big-evaluate
            'Big-promote Big-promote 'Big-readback Big-readback
            'Big-spec-language Big-spec-language
            'Big-initialize Big-initialize 'Big-close Big-close
            'Big-flatten Big-flatten 'Big-evaluate-spec Big-evaluate-spec
            'Big-unfold-square Big-unfold-square
            'Big-closure-square Big-closure-square
            'Big-root-square Big-root-square))))

  ;; Kept separate so the compile-time view assembly above remains readable.
  (define (render-disjunction-stage-extension-body name source-language d)
    (define (r key) (hash-ref d key))
    (define phase-parameters (r 'phase-parameters))
    (define dependency-forms (r 'dependency-forms))
    (define labels
      #'(expand-disjunction skip-left-failure reassociate-left-result
                           commit-choice-answer resume-left-choice-success))
    #`(define-selected-stage-extension #,name
        #:source-language #,source-language
        #:feature-singletons #,labels
        #,@(render-disjunction-stage-phases
            name d phase-parameters dependency-forms)))

  (define (render-disjunction-stage-phases
           name d phase-parameters dependency-forms)
    (define (r key) (hash-ref d key))
    (define labels
      #'(expand-disjunction skip-left-failure reassociate-left-result
                           commit-choice-answer resume-left-choice-success))
    ;; Rebuild the two focus shells directly from the retained templates.  The
    ;; returned payload is replaced by the Redex hole, never by a concrete
    ;; state/supply case.
    (define (replace-syntax datum target replacement)
      (cond
        [(and (syntax? datum)
              (equal? (syntax->datum datum) (syntax->datum target)))
         replacement]
        [(syntax? datum)
         (define value (syntax-e datum))
         (if (pair? value)
             (datum->syntax
              datum
              (replace-syntax value target replacement)
              datum
              datum)
             datum)]
        [(pair? datum)
         (cons (replace-syntax (car datum) target replacement)
               (replace-syntax (cdr datum) target replacement))]
        [else datum]))
    ;; The generated module is not required to import Redex directly.  Retain
    ;; this schema's `hole` binding so RHS focus templates construct Redex
    ;; context holes instead of an ordinary symbol named `hole`.
    (define hole #'hole)
    (define skip-focus-term
      (replace-syntax (r 'skip-source) (r 'skip-dead) hole))
    (define reassociate-focus-term
      (replace-syntax
       (r 'reassociate-source) (r 'returned-answer) hole))
    (define reassociate-target-focus-term
      (replace-syntax
       (r 'reassociate-target) (r 'W-settled) hole))
    (define commit-focus-term
      (replace-syntax (r 'commit-source) (r 'returned-answer) hole))
    (define resume-focus-term
      (replace-syntax (r 'resume-source) (r 'returned-answer) hole))

    (define D-language (r 'D-language))
    (define D-plug-D (r 'D-plug-D))
    (define D-plug-C (r 'D-plug-C))
    (define D-contract-label (r 'D-contract-label))
    (define D-decompose (r 'D-decompose))
    (define D-contract (r 'D-contract))
    (define D-step (r 'D-step))
    (define Z-language (r 'Z-language))
    (define Z-refocus-phase (r 'Z-refocus-phase))
    (define Z-refocus-work (r 'Z-refocus-work))
    (define Z-refocus-frontier (r 'Z-refocus-frontier))
    (define Z-refocus (r 'Z-refocus))
    (define Z-step (r 'Z-step))
    (define M-language (r 'M-language))
    (define M-machineize (r 'M-machineize))
    (define M-refocus-work (r 'M-refocus-work))
    (define M-refocus-frontier (r 'M-refocus-frontier))
    (define M-refocus (r 'M-refocus))
    (define M-step (r 'M-step))
    (define B-language (r 'B-language))
    (define B-compress (r 'B-compress))
    (define B-refocus-frontier (r 'B-refocus-frontier))
    (define B-span-labels (r 'B-span-labels))
    (define B-produce-settled (r 'B-produce-settled))
    (define B-produce-dead (r 'B-produce-dead))
    (define B-advance-settled (r 'B-advance-settled))
    (define B-advance-dead (r 'B-advance-dead))
    (define B-feature-singleton (r 'B-feature-singleton))
    (define B-singleton (r 'B-singleton))
    (define B-step (r 'B-step))
    (define Big-language (r 'Big-language))
    (define Big-dispatch-one (r 'Big-dispatch-one))
    (define Big-dispatch (r 'Big-dispatch))
    (define Big-refocus-frontier (r 'Big-refocus-frontier))
    (define Big-control-one (r 'Big-control-one))
    (define Big-control (r 'Big-control))
    (define Big-frontier (r 'Big-frontier))
    (define Big-run (r 'Big-run))
    (define Big-settled (r 'Big-settled))
    (define Big-dead (r 'Big-dead))
    (define Big-final (r 'Big-final))
    (define Big-evaluate (r 'Big-evaluate))
    (define Big-promote (r 'Big-promote))

    (define transfer-parameter (r 'transfer-parameter))
    (define W (r 'W))
    (define W-2 (r 'W-2))
    (define W-left (r 'W-left))
    (define W-attached (r 'W-attached))
    (define W-settled (r 'W-settled))
    (define W-residual (r 'W-residual))
    (define W-target (r 'W-target))
    (define SourceWorkFocus (slot-from name 'SourceWorkFocus))
    (define SourceSpineContext (slot-from name 'SourceSpineContext))
    (define returned-answer (r 'returned-answer))

    (define (transfer-where target prefix input transfer)
      #`(where #,target (#,transfer-parameter #,prefix #,input)))
    (define skip-where
      (lambda (transfer)
        (transfer-where
         W-attached
         ((r 'choice-prefix) (r 'supply-choice))
         W-2
         transfer)))
    (define reassociate-wheres
      (lambda (transfer)
        (list
         (transfer-where
          W-settled
          ((r 'choice-prefix) (r 'supply-inner))
          returned-answer
          transfer)
         (transfer-where
          W-residual
          ((r 'choice-prefix) (r 'supply-inner))
          W-left
          transfer))))
    (define resume-where
      (lambda (transfer)
        (transfer-where
         W-target
         ((r 'choice-prefix) (r 'supply-outer))
         (r 'resume-unattached-target)
         transfer)))

    (define D-form
      #`[#:parameters #,(phase-parameters "D" (r 'D-phase))
         #:artifacts
         (D-artifacts
          #:language #,D-language
          #:plug-D #,D-plug-D #:plug-C #,D-plug-C
          #:contract-label #,D-contract-label
          #:decompose #,D-decompose #:contract #,D-contract #:step #,D-step)
         #:forms
         ((provide #,D-language #,D-plug-D #,D-plug-C
                   #,D-contract-label #,D-decompose #,D-contract #,D-step)
          (define-extended-language #,D-language BASE-D-LANGUAGE
            [g .... (g ∨ g tag)]
            [W .... #,(r 'choice-grammar)]
            [F .... #,(r 'emit-grammar)]
            [WorkPath .... #,(r 'choice-path)]
            [SpineContext .... #,(r 'emit-spine)]
            [T .... #,(r 'emit-terminal)]
            [D .... (Final T)]
            [SourceW .... W]
            [SourceF .... F]
            [SourceWorkFocus .... WorkFocus]
            [SourceSpineContext .... SpineContext]
            [RuleName .... #,@(syntax->list labels)]
            [FeatureRuleName #,@(syntax->list labels)]
            [WR .... #,(r 'expansion-source) #,(r 'skip-source)
                    #,(r 'reassociate-source) #,(r 'resume-source)]
            [FR .... #,(r 'commit-source)])
          #,@(dependency-forms "D" (r 'D-phase))
          (redex-parameter:define-extended-metafunction*
           BASE-D-PLUG #,D-language #,D-plug-D : D -> SourceF)
          (redex-parameter:define-extended-metafunction*
           BASE-C-PLUG #,D-language #,D-plug-C : C -> SourceF)
          (redex-parameter:define-extended-metafunction*
           BASE-CONTRACT-LABEL #,D-language
           #,D-contract-label : C -> RuleName)
          (redex-parameter:define-extended-judgment-form*
           BASE-DECOMPOSE #,D-language #:mode (#,D-decompose I O))
          (redex-parameter:define-extended-judgment-form*
           BASE-CONTRACT #,D-language
           #:mode (#,D-contract I O)
           #:parameters ([#,transfer-parameter #,(r 'D-transfer)])
           [---------------- "expand-disjunction"
            (#,D-contract
             (DecWork #,(r 'expansion-source) SourceWorkFocus)
             (ContractWork
              expand-disjunction #,(r 'expansion-target) SourceWorkFocus))]
           [#,(skip-where (r 'D-transfer))
            ---------------- "skip-left-failure"
            (#,D-contract
             (DecWork #,(r 'skip-source) SourceWorkFocus)
             (ContractWork
              skip-left-failure #,W-attached SourceWorkFocus))]
           [#,@(reassociate-wheres (r 'D-transfer))
            ---------------- "reassociate-left-result"
            (#,D-contract
             (DecWork #,(r 'reassociate-source) SourceWorkFocus)
             (ContractWork
              reassociate-left-result
              #,(r 'reassociate-target) SourceWorkFocus))]
           [---------------- "commit-choice-answer"
            (#,D-contract
             (DecFrontier #,(r 'commit-source) SourceSpineContext)
             (ContractFrontier
              commit-choice-answer #,(r 'commit-target) SourceSpineContext))]
           [#,(resume-where (r 'D-transfer))
            ---------------- "resume-left-choice-success"
            (#,D-contract
             (DecWork #,(r 'resume-source) SourceWorkFocus)
             (ContractWork
              resume-left-choice-success #,W-target SourceWorkFocus))])
          (redex-parameter:define-extended-judgment-form*
           BASE-D-STEP #,D-language
           #:mode (#,D-step I O O)
           #:parameters
           ([step-contract #,D-contract]
            [step-contract-label #,D-contract-label]
            [step-plug-C #,D-plug-C]
            [step-decompose #,D-decompose])))])

    (define (retained-phase-form
             phase language phase-data transform transform-placeholder
             refocus-work refocus-frontier refocus step
             carrier work-carrier frontier-carrier
             diagnostics-form)
      (define owned-redex?
        (format-id name "~a/~a-owned-redex?" (syntax-e name) phase))
      #`[#:parameters #,(phase-parameters phase phase-data)
         #:artifacts #,(if (equal? phase "Z")
                           #`(Z-artifacts
                              #:language #,language
                              #:refocus-phase #,transform
                              #:refocus-work-direct #,refocus-work
                              #:refocus-frontier-direct #,refocus-frontier
                              #:refocus-direct #,refocus
                              #:step-direct #,step)
                           #`(M-artifacts
                              #:language #,language
                              #:machineize #,transform
                              #:refocus-work-direct #,refocus-work
                              #:refocus-frontier-direct #,refocus-frontier
                              #:refocus-direct #,refocus
                              #:step-direct #,step))
         #:forms
         ((provide #,language #,transform #,refocus-work
                   #,refocus-frontier #,refocus #,step)
          (define-extended-language #,language
            #,(if (equal? phase "Z") #'BASE-Z-LANGUAGE #'BASE-M-LANGUAGE)
            [g .... (g ∨ g tag)]
            [W .... #,(r 'choice-grammar)]
            [F .... #,(r 'emit-grammar)]
            [WorkPath .... #,(r 'choice-path)]
            [SpineContext .... #,(r 'emit-spine)]
            [T .... #,(r 'emit-terminal)]
            [#,(if (equal? phase "Z") #'Z #'M)
             ....
             (#,(if (equal? phase "Z") #'ZFinal #'MFinal) T)]
            [RuleName .... #,@(syntax->list labels)]
            [WR .... #,(r 'expansion-source) #,(r 'skip-source)
                    #,(r 'reassociate-source) #,(r 'resume-source)]
            [FR .... #,(r 'commit-source)]
            [RunW .... #,(r 'expansion-source) #,(r 'skip-source)
                      #,(r 'reassociate-source) #,(r 'resume-source)])
          #,@(dependency-forms phase phase-data)
          (redex-parameter:define-extended-metafunction*
           #,transform-placeholder #,language #,transform
           : #,(if (equal? phase "Z") #'D #'Z)
             -> #,(if (equal? phase "Z") #'Z #'M))
          (redex-parameter:define-extended-judgment-form*
           #,(if (equal? phase "Z")
                 #'BASE-Z-REFOCUS-FRONTIER
                 #'BASE-M-REFOCUS-FRONTIER)
           #,language #:mode (#,refocus-frontier I O))
          (define (#,owned-redex? work-value)
            (redex-match? #,language WR work-value))
          (redex-parameter:define-extended-judgment-form*
           #,(if (equal? phase "Z")
                 #'BASE-Z-REFOCUS-WORK
                 #'BASE-M-REFOCUS-WORK)
           #,language #:mode (#,refocus-work I I O)
           #:parameters ([step-refocus-frontier #,refocus-frontier])
           [----
            (#,refocus-work
             #,(r 'skip-dead)
             (in-hole SourceWorkFocus #,skip-focus-term)
             (#,work-carrier #,(r 'skip-source) SourceWorkFocus))]
           [----
            (#,refocus-work
             #,returned-answer
             (in-hole SourceWorkFocus #,reassociate-focus-term)
             (#,work-carrier
              #,(r 'reassociate-source) SourceWorkFocus))]
           [----
            (#,refocus-work
             #,returned-answer
             (in-hole SourceSpineContext #,commit-focus-term)
             (#,frontier-carrier
              #,(r 'commit-source) SourceSpineContext))]
           [----
            (#,refocus-work
             #,returned-answer
             (in-hole SourceWorkFocus #,resume-focus-term)
             (#,work-carrier #,(r 'resume-source) SourceWorkFocus))]
           [(step-refocus-frontier
             (in-hole SourceWorkFocus #,(r 'choice-grammar)) #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))
            (side-condition
             ,(not
               (#,owned-redex? (term #,(r 'choice-grammar)))))
            ----
            (#,refocus-work
             #,(r 'choice-grammar) SourceWorkFocus
             #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))])
          (redex-parameter:define-extended-judgment-form*
           #,(if (equal? phase "Z") #'BASE-Z-REFOCUS #'BASE-M-REFOCUS)
           #,language #:mode (#,refocus I O)
           #:parameters ([refocus-work-dependency #,refocus-work]))
          (redex-parameter:define-extended-judgment-form*
           #,(if (equal? phase "Z") #'BASE-Z-STEP #'BASE-M-STEP)
           #,language #:mode (#,step I O O)
           #:parameters
           ([#,transfer-parameter #,(sixth phase-data)]
            [step-refocus-work #,refocus-work]
            [step-refocus-frontier #,refocus-frontier])
           [(step-refocus-work
             #,(r 'expansion-target) SourceWorkFocus #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))
            ---------------- "expand-disjunction"
            (#,step
             (#,work-carrier #,(r 'expansion-source) SourceWorkFocus)
             expand-disjunction #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))]
           [#,(skip-where (sixth phase-data))
            (step-refocus-work
             #,W-attached SourceWorkFocus #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))
            ---------------- "skip-left-failure"
            (#,step
             (#,work-carrier #,(r 'skip-source) SourceWorkFocus)
             skip-left-failure #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))]
           [#,@(reassociate-wheres (sixth phase-data))
            (step-refocus-work
             #,(r 'reassociate-target) SourceWorkFocus #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))
            ---------------- "reassociate-left-result"
            (#,step
             (#,work-carrier #,(r 'reassociate-source) SourceWorkFocus)
             reassociate-left-result #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))]
           [(step-refocus-frontier
             (in-hole SourceSpineContext #,(r 'commit-target))
             #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))
            ---------------- "commit-choice-answer"
            (#,step
             (#,frontier-carrier #,(r 'commit-source) SourceSpineContext)
             commit-choice-answer #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))]
           [#,(resume-where (sixth phase-data))
            (step-refocus-work
             #,W-target SourceWorkFocus #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))
            ---------------- "resume-left-choice-success"
            (#,step
             (#,work-carrier #,(r 'resume-source) SourceWorkFocus)
             resume-left-choice-success #,(slot-from name (if (equal? phase "Z") 'Z_1 'M_1)))]))
         #,@diagnostics-form])

    (define Z-diagnostic-clause
      (render-disjunction-Z-diagnostics name d phase-parameters))
    (define M-diagnostic-clause
      (render-disjunction-M-diagnostics name d phase-parameters))
    (define Z-form
      (retained-phase-form
       "Z" Z-language (r 'Z-phase) Z-refocus-phase #'BASE-REFOCUS-PHASE
       Z-refocus-work Z-refocus-frontier Z-refocus Z-step
       #'Z #'ZWork #'ZFrontier Z-diagnostic-clause))
    (define M-form
      (retained-phase-form
       "M" M-language (r 'M-phase) M-machineize #'BASE-MACHINEIZE
       M-refocus-work M-refocus-frontier M-refocus M-step
       #'M #'MWork #'MFrontier M-diagnostic-clause))
    (define B-form
      (render-disjunction-B-phase
       name d phase-parameters dependency-forms
       labels skip-focus-term reassociate-focus-term
       commit-focus-term resume-focus-term))
    (define Big-form
      (render-disjunction-Big-phase
       name d phase-parameters dependency-forms
       labels skip-focus-term reassociate-focus-term
       reassociate-target-focus-term commit-focus-term resume-focus-term))
    (list #'#:D D-form #'#:Z Z-form #'#:M M-form
          #'#:B B-form #'#:Big Big-form))

  (define (slot-from context symbol)
    (datum->syntax context symbol context context))

  (define (render-disjunction-Z-diagnostics name d phase-parameters)
    (define (r key) (hash-ref d key))
    (define language (r 'Z-language))
    (define D->Z (r 'Z-D->Z))
    (define Z->D (r 'Z-Z->D))
    (define readback (r 'Z-readback))
    (define refocus-spec (r 'Z-refocus-spec))
    (define step-spec (r 'Z-step-spec))
    (define D-plug-C (r 'D-plug-C))
    (define D-decompose (r 'D-decompose))
    (define D-contract (r 'D-contract))
    (define D-contract-label (r 'D-contract-label))
    (list
     #'#:diagnostic-parameters
     (phase-parameters "Z" (r 'Z-phase) #t)
     #'#:diagnostics
     #`(Z-diagnostics
        #:D->Z #,D->Z #:Z->D #,Z->D #:readback #,readback
        #:refocus-spec #,refocus-spec #:step-spec #,step-spec)
     #'#:diagnostic-forms
     #`((module+ diagnostics
          (provide #,D->Z #,Z->D #,readback #,refocus-spec #,step-spec))
        (define-metafunction #,language
          #,D->Z : D -> Z
          [(#,D->Z (Final T)) (ZFinal T)]
          [(#,D->Z (DecWork WR SourceWorkFocus))
           (ZWork WR SourceWorkFocus)]
          [(#,D->Z (DecFrontier FR SourceSpineContext))
           (ZFrontier FR SourceSpineContext)]
          [(#,D->Z (DecAllocate AR SourceWorkFocus))
           (ZAllocate AR SourceWorkFocus)])
        (define-metafunction #,language
          #,Z->D : Z -> D
          [(#,Z->D (ZFinal T)) (Final T)]
          [(#,Z->D (ZWork WR SourceWorkFocus))
           (DecWork WR SourceWorkFocus)]
          [(#,Z->D (ZFrontier FR SourceSpineContext))
           (DecFrontier FR SourceSpineContext)]
          [(#,Z->D (ZAllocate AR SourceWorkFocus))
           (DecAllocate AR SourceWorkFocus)])
        (define-metafunction #,language
          #,readback : Z -> SourceF
          [(#,readback (ZFinal T)) T]
          [(#,readback (ZWork WR SourceWorkFocus))
           (in-hole SourceWorkFocus WR)]
          [(#,readback (ZFrontier FR SourceSpineContext))
           (in-hole SourceSpineContext FR)]
          [(#,readback (ZAllocate AR SourceWorkFocus))
           (in-hole SourceWorkFocus AR)])
        (define-judgment-form #,language
          #:mode (#,refocus-spec I O)
          #:contract (#,refocus-spec C Z)
          [(where SourceF_0 (#,D-plug-C C_0))
           (#,D-decompose SourceF_0 D_0)
           (where Z_0 (#,D->Z D_0))
           ---- (#,refocus-spec C_0 Z_0)])
        (define-judgment-form #,language
          #:mode (#,step-spec I O O)
          #:contract (#,step-spec Z RuleName Z)
          [(where D_0 (#,Z->D Z_0))
           (#,D-contract D_0 C_0)
           (where RuleName_0 (#,D-contract-label C_0))
           (#,refocus-spec C_0 Z_1)
           ---- (#,step-spec Z_0 RuleName_0 Z_1)]))))

  (define (render-disjunction-M-diagnostics name d phase-parameters)
    (define (r key) (hash-ref d key))
    (define language (r 'M-language))
    (define encode (r 'M-encode-ZM))
    (define decode (r 'M-decode-MZ))
    (define D->M (r 'M-D->M))
    (define M->D (r 'M-M->D))
    (define readback (r 'M-readback))
    (define corresponds (r 'M-corresponds))
    (define step-spec (r 'M-step-spec))
    (define square (r 'M-square))
    (define Z-step (r 'Z-step))
    (define M-step (r 'M-step))
    (list
     #'#:diagnostic-parameters
     (phase-parameters "M" (r 'M-phase) #t)
     #'#:diagnostics
     #`(M-diagnostics
        #:encode-ZM #,encode #:decode-MZ #,decode
        #:D->M #,D->M #:M->D #,M->D #:readback #,readback
        #:corresponds #,corresponds #:step-spec #,step-spec #:square #,square)
     #'#:diagnostic-forms
     #`((module+ diagnostics
          (provide #,encode #,decode #,D->M #,M->D #,readback
                   #,corresponds #,step-spec #,square))
        (define-metafunction #,language
          #,encode : Z -> M
          [(#,encode (ZFinal T)) (MFinal T)]
          [(#,encode (ZWork WR SourceWorkFocus))
           (MWork WR SourceWorkFocus)]
          [(#,encode (ZFrontier FR SourceSpineContext))
           (MFrontier FR SourceSpineContext)]
          [(#,encode (ZAllocate AR SourceWorkFocus))
           (MAllocate AR SourceWorkFocus)])
        (define-metafunction #,language
          #,decode : M -> Z
          [(#,decode (MFinal T)) (ZFinal T)]
          [(#,decode (MWork WR SourceWorkFocus))
           (ZWork WR SourceWorkFocus)]
          [(#,decode (MFrontier FR SourceSpineContext))
           (ZFrontier FR SourceSpineContext)]
          [(#,decode (MAllocate AR SourceWorkFocus))
           (ZAllocate AR SourceWorkFocus)])
        (define-metafunction #,language
          #,D->M : D -> M
          [(#,D->M (Final T)) (MFinal T)]
          [(#,D->M (DecWork WR SourceWorkFocus))
           (MWork WR SourceWorkFocus)]
          [(#,D->M (DecFrontier FR SourceSpineContext))
           (MFrontier FR SourceSpineContext)]
          [(#,D->M (DecAllocate AR SourceWorkFocus))
           (MAllocate AR SourceWorkFocus)])
        (define-metafunction #,language
          #,M->D : M -> D
          [(#,M->D (MFinal T)) (Final T)]
          [(#,M->D (MWork WR SourceWorkFocus))
           (DecWork WR SourceWorkFocus)]
          [(#,M->D (MFrontier FR SourceSpineContext))
           (DecFrontier FR SourceSpineContext)]
          [(#,M->D (MAllocate AR SourceWorkFocus))
           (DecAllocate AR SourceWorkFocus)])
        (define-metafunction #,language
          #,readback : M -> SourceF
          [(#,readback (MFinal T)) T]
          [(#,readback (MWork WR SourceWorkFocus))
           (in-hole SourceWorkFocus WR)]
          [(#,readback (MFrontier FR SourceSpineContext))
           (in-hole SourceSpineContext FR)]
          [(#,readback (MAllocate AR SourceWorkFocus))
           (in-hole SourceWorkFocus AR)])
        (define-judgment-form #,language
          #:mode (#,corresponds I O)
          #:contract (#,corresponds Z M)
          [(where M_0 (#,encode Z_0)) ---- (#,corresponds Z_0 M_0)])
        (define-judgment-form #,language
          #:mode (#,step-spec I O O)
          #:contract (#,step-spec M RuleName M)
          [(where Z_0 (#,decode M_0))
           (#,Z-step Z_0 RuleName_0 Z_1)
           (where M_1 (#,encode Z_1))
           ---- (#,step-spec M_0 RuleName_0 M_1)])
        (define-judgment-form #,language
          #:mode (#,square I O O O O)
          #:contract (#,square Z RuleName Z M M)
          [(where M_0 (#,encode Z_0))
           (#,Z-step Z_0 RuleName_0 Z_1)
           (where M_1 (#,encode Z_1))
           (#,M-step M_0 RuleName_0 M_1)
           ---- (#,square Z_0 RuleName_0 Z_1 M_0 M_1)]))))

  (define (render-disjunction-B-phase
           name d phase-parameters dependency-forms
           labels skip-focus reassociate-focus commit-focus resume-focus)
    (define (r key) (hash-ref d key))
    (define language (r 'B-language))
    (define compress (r 'B-compress))
    (define refocus (r 'B-refocus-frontier))
    (define span-labels (r 'B-span-labels))
    (define produce-settled (r 'B-produce-settled))
    (define produce-dead (r 'B-produce-dead))
    (define advance-settled (r 'B-advance-settled))
    (define advance-dead (r 'B-advance-dead))
    (define feature-singleton (r 'B-feature-singleton))
    (define singleton (r 'B-singleton))
    (define step (r 'B-step))
    (define transfer-parameter (r 'transfer-parameter))
    (define transfer (r 'B-transfer))
    (define W-attached (r 'W-attached))
    (define W-settled (r 'W-settled))
    (define W-residual (r 'W-residual))
    (define W-target (r 'W-target))
    (define returned-answer (r 'returned-answer))
    (define dead-term (r 'dead-term))
    (define failure-summary (r 'failure-summary-var))
    (define choice-prefix (r 'choice-prefix))
    (define (transfer-where target prefix input)
      #`(where #,target (#,transfer-parameter #,prefix #,input)))
    (define (target-where target focus [spine? #f])
      #`(where B_1
               (feature-refocus
                (in-hole #,(if spine?
                               #'SourceSpineContext
                               #'SourceWorkFocus)
                         #,target))))
    (define diagnostics
      (render-disjunction-B-diagnostics
       name d phase-parameters
       skip-focus reassociate-focus commit-focus resume-focus))
    #`[#:parameters #,(phase-parameters "B" (r 'B-phase))
       #:artifacts
       (B-artifacts
        #:language #,language #:compress #,compress
        #:refocus-frontier-direct #,refocus
        #:span-labels #,span-labels
        #:produce-settled #,produce-settled #:produce-dead #,produce-dead
        #:advance-settled #,advance-settled #:advance-dead #,advance-dead
        #:base-singleton #,singleton #:step-direct #,step)
       #:forms
       ((provide #,language #,compress #,refocus #,span-labels
                 #,produce-settled #,produce-dead
                 #,advance-settled #,advance-dead
                 #,feature-singleton #,singleton #,step)
        (define-extended-language #,language BASE-B-LANGUAGE
          [g .... (g ∨ g tag)]
          [W .... #,(r 'choice-grammar)]
          [F .... #,(r 'emit-grammar)]
          [WorkPath .... #,(r 'choice-path)]
          [SpineContext .... #,(r 'emit-spine)]
          [T .... #,(r 'emit-terminal)]
          [SourceW W]
          [SourceF F]
          [SourceWorkFocus WorkFocus]
          [SourceSpineContext SpineContext]
          ;; Redex preserves inherited production references to their
          ;; original language.  Replace the normalized source aliases and
          ;; complete generic phase-carrier algebra so their payloads are
          ;; checked in this exact extended language.
          [B
           (BRun NonAllocateRun SourceWorkFocus)
           (BRun AR SourceWorkFocus)
           (BFrontier FR SourceSpineContext)
           (BSettled Settled SourceWorkFocus)
           (BDead FailureSummary SourceWorkFocus)
           (BFinal T)]
          [RuleName .... #,@(syntax->list labels)]
          [FeatureRuleName #,@(syntax->list labels)]
          [WR .... #,(r 'expansion-source) #,(r 'skip-source)
                  #,(r 'reassociate-source) #,(r 'resume-source)]
          [FR .... #,(r 'commit-source)]
          [RunW .... #,(r 'expansion-source)]
          [NonAllocateRun .... #,(r 'expansion-source)]
          [SingletonRuleName .... #,@(syntax->list labels)])
        #,@(dependency-forms "B" (r 'B-phase))
        (redex-parameter:define-extended-metafunction*
         BASE-COMPRESS #,language #,compress : M -> B
         [(#,compress (MWork #,(r 'skip-source) SourceWorkFocus))
          (BDead #,(r 'supply-dead)
                 (in-hole SourceWorkFocus #,skip-focus))]
         [(#,compress (MWork #,(r 'reassociate-source) SourceWorkFocus))
          (BSettled #,returned-answer
                    (in-hole SourceWorkFocus #,reassociate-focus))]
         [(#,compress (MWork #,(r 'resume-source) SourceWorkFocus))
          (BSettled #,returned-answer
                    (in-hole SourceWorkFocus #,resume-focus))])
        (redex-parameter:define-extended-metafunction*
         BASE-B-REFOCUS-FRONTIER #,language #,refocus : SourceF -> B
         [(#,refocus
           (in-hole SourceSpineContext #,(r 'commit-source)))
          (BFrontier #,(r 'commit-source) SourceSpineContext)])
        (redex-parameter:define-extended-metafunction*
         BASE-SPAN-LABELS #,language #,span-labels
         : TransitionSpan -> LabelTrace)
        (redex-parameter:define-extended-judgment-form*
         BASE-B-PRODUCE-SETTLED #,language
         #:mode (#,produce-settled I I O O O))
        (redex-parameter:define-extended-judgment-form*
         BASE-B-PRODUCE-DEAD #,language
         #:mode (#,produce-dead I I O O O))
        (redex-parameter:define-extended-judgment-form*
         BASE-B-ADVANCE-SETTLED #,language
         #:mode (#,advance-settled I I O O))
        (redex-parameter:define-extended-judgment-form*
         BASE-B-ADVANCE-DEAD #,language
         #:mode (#,advance-dead I I O O))
        (redex-parameter:define-judgment-form*
         #,language
         #:parameters
         ([#,transfer-parameter #,transfer]
          [feature-refocus #,refocus])
         #:mode (#,feature-singleton I O O)
         #:contract (#,feature-singleton B TransitionSpan B)
         [#,(target-where (r 'expansion-target) #'SourceWorkFocus)
          ---------------- "expand-disjunction"
          (#,feature-singleton
           (BRun #,(r 'expansion-source) SourceWorkFocus)
           (transition-span expand-disjunction) B_1)]
         [#,(transfer-where
             W-attached
             (choice-prefix (r 'supply-choice))
             (r 'W-2))
          #,(target-where W-attached #'SourceWorkFocus)
          ---------------- "skip-left-failure/boundary"
          (#,feature-singleton
           (BDead #,failure-summary
                  (in-hole SourceWorkFocus #,skip-focus))
           (transition-span skip-left-failure) B_1)]
         [#,(transfer-where
             W-settled
             (choice-prefix (r 'supply-inner))
             returned-answer)
          #,(transfer-where
             W-residual
             (choice-prefix (r 'supply-inner))
             (r 'W-left))
          #,(target-where (r 'reassociate-target) #'SourceWorkFocus)
          ---------------- "reassociate-left-result/boundary"
          (#,feature-singleton
           (BSettled #,returned-answer
                     (in-hole SourceWorkFocus #,reassociate-focus))
           (transition-span reassociate-left-result) B_1)]
         [(where B_1
                 (feature-refocus
                  (in-hole SourceSpineContext #,(r 'commit-target))))
          ---------------- "commit-choice-answer/frontier"
          (#,feature-singleton
           (BFrontier #,(r 'commit-source) SourceSpineContext)
           (transition-span commit-choice-answer) B_1)]
         [(where B_1
                 (feature-refocus
                  (in-hole SourceSpineContext #,(r 'commit-target))))
          ---------------- "commit-choice-answer/boundary"
          (#,feature-singleton
           (BSettled #,returned-answer
                     (in-hole SourceSpineContext #,commit-focus))
           (transition-span commit-choice-answer) B_1)]
         [#,(transfer-where
             W-target
             (choice-prefix (r 'supply-outer))
             (r 'resume-unattached-target))
          #,(target-where W-target #'SourceWorkFocus)
          ---------------- "resume-left-choice-success/boundary"
          (#,feature-singleton
           (BSettled #,returned-answer
                     (in-hole SourceWorkFocus #,resume-focus))
           (transition-span resume-left-choice-success) B_1)])
        (redex-parameter:define-extended-judgment-form*
         BASE-B-SINGLETON #,language
         #:mode (#,singleton I O O)
         #:parameters
         ([singleton-feature #,feature-singleton]
          [singleton-refocus-frontier #,refocus]
          [singleton-advance-settled #,advance-settled]
          [singleton-advance-dead #,advance-dead])
         [(singleton-feature B_0 TransitionSpan_0 B_1)
          ----
          (#,singleton B_0 TransitionSpan_0 B_1)])
        (redex-parameter:define-extended-judgment-form*
         BASE-B-STEP #,language
         #:mode (#,step I O O)
         #:parameters
         ([step-produce-settled #,produce-settled]
          [step-produce-dead #,produce-dead]
          [step-base-advance-settled #,advance-settled]
          [step-base-advance-dead #,advance-dead]
          [step-singleton #,singleton]
          [step-feature-singleton #,feature-singleton])
         [(step-produce-settled
           SourceW SourceWorkFocus_0
           SettledProducerName Settled SourceWorkFocus_1)
          (side-condition
           ,(and
             (not
              (judgment-holds
               (step-base-advance-settled
                ,(term Settled)
                ,(term SourceWorkFocus_1)
                SettledFollowerName_probe
                B_base-probe)))
             (judgment-holds
              (step-feature-singleton
               ,(term (BSettled Settled SourceWorkFocus_1))
               TransitionSpan_feature-probe
               B_feature-probe))))
          ---------------- "settled-disjunction-boundary"
          (#,step
           (BRun SourceW SourceWorkFocus_0)
           (transition-span SettledProducerName)
           (BSettled Settled SourceWorkFocus_1))]
         [(step-produce-dead
           SourceW SourceWorkFocus_0
           DeadProducerName FailureSummary SourceWorkFocus_1)
          (side-condition
           ,(and
             (not
              (judgment-holds
               (step-base-advance-dead
                ,(term FailureSummary)
                ,(term SourceWorkFocus_1)
                DeadFollowerName_probe
                B_base-probe)))
             (judgment-holds
              (step-feature-singleton
               ,(term (BDead FailureSummary SourceWorkFocus_1))
               TransitionSpan_feature-probe
               B_feature-probe))))
          ---------------- "dead-disjunction-boundary"
          (#,step
           (BRun SourceW SourceWorkFocus_0)
           (transition-span DeadProducerName)
           (BDead FailureSummary SourceWorkFocus_1))]))
       #,@diagnostics])

  (define (render-disjunction-B-diagnostics
           name d phase-parameters
           skip-focus reassociate-focus commit-focus resume-focus)
    (define (r key) (hash-ref d key))
    (define language (r 'B-language))
    (define encode (r 'B-encode-MB))
    (define decode (r 'B-decode-BM))
    (define readback (r 'B-readback))
    (define corresponds (r 'B-corresponds))
    (define replay (r 'B-replay))
    (define replay-target
      (format-id name "~a/B-diagnostic-replay-target" (syntax-e name)))
    (define replay-target-encode
      (format-id
       name "~a/B-diagnostic-replay-target-encode" (syntax-e name)))
    (define replay-M-refocus-frontier-bridge
      (format-id
       name
       "~a/B-diagnostic-replay-M-refocus-frontier-bridge"
       (syntax-e name)))
    (define replay-M-refocus-work-bridge
      (format-id
       name "~a/B-diagnostic-replay-M-refocus-work-bridge" (syntax-e name)))
    (define replay-machine-step-bridge
      (format-id
       name "~a/B-diagnostic-replay-machine-step-bridge" (syntax-e name)))
    (define replay-machine-step
      (format-id name "~a/B-diagnostic-replay-machine-step" (syntax-e name)))
    (define step-spec (r 'B-step-spec))
    (define step-spec-decode
      (format-id name "~a/B-diagnostic-step-decode" (syntax-e name)))
    (define step-spec-replay
      (format-id name "~a/B-diagnostic-step-replay" (syntax-e name)))
    (define step-spec-target
      (format-id name "~a/B-diagnostic-step-target" (syntax-e name)))
    (define square (r 'B-square))
    (define square-decode
      (format-id name "~a/B-diagnostic-square-decode" (syntax-e name)))
    (define square-replay
      (format-id name "~a/B-diagnostic-square-replay" (syntax-e name)))
    (define square-target
      (format-id name "~a/B-diagnostic-square-target" (syntax-e name)))
    (define square-B-step
      (format-id name "~a/B-diagnostic-square-B-step" (syntax-e name)))
    (define compress (r 'B-compress))
    (define M-refocus-work (r 'M-refocus-work))
    (define M-refocus-frontier (r 'M-refocus-frontier))
    (define M-step (r 'M-step))
    (define B-step (r 'B-step))
    (define feature-singleton (r 'B-feature-singleton))
    (define returned-answer (r 'returned-answer))
    (list
     #'#:diagnostic-parameters
     (phase-parameters "B" (r 'B-phase) #t)
     #'#:diagnostics
     #`(B-diagnostics
        #:encode-MB #,encode #:decode-BM #,decode #:readback #,readback
        #:corresponds #,corresponds #:replay #,replay
        #:step-spec #,step-spec #:square #,square)
     #'#:diagnostic-forms
     #`((module+ diagnostics
          (provide #,encode #,decode #,readback #,corresponds
                   #,replay #,step-spec #,square))
        ;; Disjunction contributes only its four carrier-normalization cases;
        ;; the generic codec remains inherited and is lifted to this exact
        ;; language (including any later feature payloads).
        (redex-parameter:define-extended-metafunction*
          BASE-ENCODE-MB #,language
          #,encode : M -> B
          [(#,encode (MWork #,(r 'skip-source) SourceWorkFocus))
           (BDead #,(r 'supply-dead)
                  (in-hole SourceWorkFocus #,skip-focus))]
          [(#,encode (MWork #,(r 'reassociate-source) SourceWorkFocus))
           (BSettled #,returned-answer
                     (in-hole SourceWorkFocus #,reassociate-focus))]
          [(#,encode
            (MFrontier #,(r 'commit-source) SourceSpineContext))
           (BFrontier #,(r 'commit-source) SourceSpineContext)]
          [(#,encode (MWork #,(r 'resume-source) SourceWorkFocus))
           (BSettled #,returned-answer
                     (in-hole SourceWorkFocus #,resume-focus))])
        (redex-parameter:define-extended-metafunction*
          BASE-DECODE-BM #,language
          #,decode : B -> M
          [(#,decode
            (BDead #,(r 'supply-dead)
                   (in-hole SourceWorkFocus #,skip-focus)))
           (MWork #,(r 'skip-source) SourceWorkFocus)]
          [(#,decode
            (BSettled #,returned-answer
                      (in-hole SourceWorkFocus #,reassociate-focus)))
           (MWork #,(r 'reassociate-source) SourceWorkFocus)]
          [(#,decode
            (BFrontier #,(r 'commit-source) SourceSpineContext))
           (MFrontier #,(r 'commit-source) SourceSpineContext)]
          [(#,decode
            (BSettled #,returned-answer
                      (in-hole SourceSpineContext #,commit-focus)))
           (MFrontier #,(r 'commit-source) SourceSpineContext)]
          [(#,decode
            (BSettled #,returned-answer
                      (in-hole SourceWorkFocus #,resume-focus)))
           (MWork #,(r 'resume-source) SourceWorkFocus)])
        (redex-parameter:define-extended-metafunction*
          BASE-B-READBACK #,language
          #,readback : B -> SourceF)
        (define-judgment-form #,language
          #:mode (#,corresponds I O)
          #:contract (#,corresponds M B)
          [(where B_0 (#,compress M_0)) ---- (#,corresponds M_0 B_0)])
        ;; Producer-boundary replay is the sole Disjunction-owned replay
        ;; behavior.  Register the current final M-step at this exact B
        ;; language, after its refocus dependencies, before lifting inherited
        ;; replay; then parameterize the owned clauses for later feature order.
        (redex-parameter:define-extended-judgment-form*
         #,M-refocus-frontier #,language
         #:mode (#,replay-M-refocus-frontier-bridge I O))
        (redex-parameter:define-extended-judgment-form*
         #,M-refocus-work #,language
         #:mode (#,replay-M-refocus-work-bridge I I O))
        (redex-parameter:define-extended-judgment-form*
         #,M-step #,language
         #:mode (#,replay-machine-step-bridge I O O))
        (redex-parameter:define-extended-judgment-form*
         BASE-B-REPLAY #,language
          #:mode (#,replay I O O)
          #:parameters
          ([replay-feature-singleton #,feature-singleton]
           [#,replay-machine-step #,M-step])
          #:contract (#,replay M TransitionSpan M)
          [(#,replay-machine-step
            M_0 DeadProducerName
            (MWork #,(r 'skip-source) SourceWorkFocus))
           (side-condition
            ,(and
              (not
               (judgment-holds
                (#,replay-machine-step
                 ,(term (MWork #,(r 'skip-source) SourceWorkFocus))
                 DeadFollowerName_probe M_probe)))
              (judgment-holds
               (replay-feature-singleton
                ,(term
                  (BDead #,(r 'supply-dead)
                         (in-hole SourceWorkFocus #,skip-focus)))
                TransitionSpan_feature-probe B_feature-probe))))
           ----
           (#,replay
            M_0 (transition-span DeadProducerName)
            (MWork #,(r 'skip-source) SourceWorkFocus))]
          [(#,replay-machine-step
            M_0 SettledProducerName
            (MWork #,(r 'reassociate-source) SourceWorkFocus))
           (side-condition
            ,(and
              (not
               (judgment-holds
                (#,replay-machine-step
                 ,(term
                   (MWork #,(r 'reassociate-source) SourceWorkFocus))
                 SettledFollowerName_probe M_probe)))
              (judgment-holds
               (replay-feature-singleton
                ,(term
                  (BSettled
                   #,returned-answer
                   (in-hole SourceWorkFocus #,reassociate-focus)))
                TransitionSpan_feature-probe B_feature-probe))))
           ----
           (#,replay
            M_0 (transition-span SettledProducerName)
            (MWork #,(r 'reassociate-source) SourceWorkFocus))]
          [(#,replay-machine-step
            M_0 SettledProducerName
            (MFrontier #,(r 'commit-source) SourceSpineContext))
           (side-condition
            ,(and
              (not
               (judgment-holds
                (#,replay-machine-step
                 ,(term
                   (MFrontier
                    #,(r 'commit-source) SourceSpineContext))
                 SettledFollowerName_probe M_probe)))
              (judgment-holds
               (replay-feature-singleton
                ,(term
                  (BSettled
                   #,returned-answer
                   (in-hole SourceSpineContext #,commit-focus)))
                TransitionSpan_feature-probe B_feature-probe))))
           ----
           (#,replay
            M_0 (transition-span SettledProducerName)
            (MFrontier #,(r 'commit-source) SourceSpineContext))]
          [(#,replay-machine-step
            M_0 SettledProducerName
            (MWork #,(r 'resume-source) SourceWorkFocus))
           (side-condition
            ,(and
              (not
               (judgment-holds
                (#,replay-machine-step
                 ,(term (MWork #,(r 'resume-source) SourceWorkFocus))
                 SettledFollowerName_probe M_probe)))
              (judgment-holds
               (replay-feature-singleton
                ,(term
                  (BSettled
                   #,returned-answer
                   (in-hole SourceWorkFocus #,resume-focus)))
                TransitionSpan_feature-probe B_feature-probe))))
           ----
           (#,replay
            M_0 (transition-span SettledProducerName)
            (MWork #,(r 'resume-source) SourceWorkFocus))])
        (redex-parameter:define-metafunction*
          #,language
          #:parameters ([#,replay-target-encode #,encode])
          #,replay-target : M TransitionSpan -> B
          [(#,replay-target
            (MWork #,(r 'skip-source) SourceWorkFocus)
            (transition-span DeadProducerName))
           (BDead #,(r 'supply-dead)
                  (in-hole SourceWorkFocus #,skip-focus))]
          [(#,replay-target
            (MWork #,(r 'reassociate-source) SourceWorkFocus)
            (transition-span SettledProducerName))
           (BSettled #,returned-answer
                     (in-hole SourceWorkFocus #,reassociate-focus))]
          [(#,replay-target
            (MFrontier #,(r 'commit-source) SourceSpineContext)
            (transition-span SettledProducerName))
           (BSettled #,returned-answer
                     (in-hole SourceSpineContext #,commit-focus))]
          [(#,replay-target
            (MWork #,(r 'resume-source) SourceWorkFocus)
            (transition-span SettledProducerName))
           (BSettled #,returned-answer
                     (in-hole SourceWorkFocus #,resume-focus))]
          [(#,replay-target M_0 TransitionSpan_0)
           (#,replay-target-encode M_0)])
        (redex-parameter:define-judgment-form*
          #,language
          #:parameters
          ([#,step-spec-decode #,decode]
           [#,step-spec-replay #,replay]
           [#,step-spec-target #,replay-target])
          #:mode (#,step-spec I O O)
          #:contract (#,step-spec B TransitionSpan B)
          [(where M_0 (#,step-spec-decode B_0))
           (#,step-spec-replay M_0 TransitionSpan_0 M_1)
           (where B_1 (#,step-spec-target M_1 TransitionSpan_0))
           ---- (#,step-spec B_0 TransitionSpan_0 B_1)])
        (redex-parameter:define-judgment-form*
          #,language
          #:parameters
          ([#,square-decode #,decode]
           [#,square-replay #,replay]
           [#,square-target #,replay-target]
           [#,square-B-step #,B-step])
          #:mode (#,square I O O O O)
          #:contract (#,square B TransitionSpan B M M)
          [(where M_0 (#,square-decode B_0))
           (#,square-replay M_0 TransitionSpan_0 M_1)
           (where B_1 (#,square-target M_1 TransitionSpan_0))
           (#,square-B-step B_0 TransitionSpan_0 B_1)
           ---- (#,square B_0 TransitionSpan_0 B_1 M_0 M_1)]))))

  (define (render-disjunction-Big-phase
           name d phase-parameters dependency-forms
           labels skip-focus reassociate-focus reassociate-target-focus
           commit-focus resume-focus)
    (define (r key) (hash-ref d key))
    (define language (r 'Big-language))
    (define dispatch-one (r 'Big-dispatch-one))
    (define dispatch (r 'Big-dispatch))
    (define refocus (r 'Big-refocus-frontier))
    (define base-refocus
      (format-id name "~a/Big-refocus-frontier/base" (syntax-e name)))
    (define commit-frontier?
      (format-id name "~a/Big-commit-frontier?" (syntax-e name)))
    (define commit-frontier-test
      (format-id
       name "~a/Big-commit-frontier?/dependency" (syntax-e name)))
    (define control-one (r 'Big-control-one))
    (define control (r 'Big-control))
    (define frontier (r 'Big-frontier))
    (define run (r 'Big-run))
    (define settled (r 'Big-settled))
    (define dead (r 'Big-dead))
    (define final (r 'Big-final))
    (define evaluate (r 'Big-evaluate))
    (define promote (r 'Big-promote))
    (define transfer-parameter (r 'transfer-parameter))
    (define transfer (r 'Big-transfer))
    (define returned-answer (r 'returned-answer))
    (define failure-summary (r 'failure-summary-var))
    (define dead-term (r 'dead-term))
    (define open-choice
      (instantiate-template
       (r 'choice-grammar)
       (list (cons 'W_1 (slot-from name 'OpenW)))))
    (define (transfer-where target prefix input)
      #`(where #,target (#,transfer-parameter #,prefix #,input)))
    (define diagnostics
      (render-disjunction-Big-diagnostics name d phase-parameters))
    #`[#:parameters #,(phase-parameters "BIG" (r 'Big-phase))
       #:artifacts
       (Big-artifacts
        #:language #,language
        #:dispatch-one #,dispatch-one #:dispatch #,dispatch
        #:refocus-frontier-direct #,refocus
        #:control-one #,control-one #:control #,control
        #:frontier #,frontier #:run #,run
        #:settled #,settled #:dead #,dead #:final #,final
        #:evaluate #,evaluate
        #:promotion-language #,language #:promote #,promote)
       #:forms
       ((provide #,language #,dispatch-one #,dispatch #,refocus
                 #,control-one #,control #,frontier #,run
                 #,settled #,dead #,final #,evaluate #,promote)
        (define-extended-language #,language BASE-BIG-LANGUAGE
          [g .... (g ∨ g tag)]
          [W .... #,(r 'choice-grammar)]
          [F .... #,(r 'emit-grammar)]
          [WorkPath .... #,(r 'choice-path)]
          [SpineContext .... #,(r 'emit-spine)]
          [T .... #,(r 'emit-terminal)]
          [SourceW W]
          [SourceF F]
          [SourceWorkFocus WorkFocus]
          [SourceSpineContext SpineContext]
          [Big (BigFinal T)]
          ;; Big classification intentionally exposes only expansion as a
          ;; whole work redex.  The four pop rules run from their settled/dead
          ;; controls, avoiding duplicate whole-WR and inner-carrier proofs.
          [WR .... #,(r 'expansion-source)]
          [FR .... #,(r 'commit-source)]
          [RunW .... #,(r 'expansion-source)]
          [NonAllocateRun .... #,(r 'expansion-source)]
          [OpenW .... #,(r 'expansion-source) #,open-choice]
          [B
           (BRun NonAllocateRun SourceWorkFocus)
           (BRun AR SourceWorkFocus)
           (BFrontier FR SourceSpineContext)
           (BSettled Settled SourceWorkFocus)
           (BDead FailureSummary SourceWorkFocus)
           (BFinal T)]
          [BigNext
           (BigContinue SourceW SourceWorkFocus)
           (BigFrontierContinue SourceF)
           (BigDone Big)]
          [Control
           (BigWorkControl SourceW SourceWorkFocus)
           (BigFrontierControl FR SourceSpineContext)]
          [ControlNext
           (BigControlContinue Control)
           (BigControlDone Big)])
        #,@(dependency-forms "BIG" (r 'Big-phase))
        (redex-parameter:define-extended-judgment-form*
         BASE-BIG-DISPATCH-ONE #,language
         #:mode (#,dispatch-one I I O)
         #:parameters ([#,transfer-parameter #,transfer])
         [---------------- "expand-disjunction"
          (#,dispatch-one
           #,(r 'expansion-source) SourceWorkFocus
           (BigFrontierContinue
            (in-hole SourceWorkFocus #,(r 'expansion-target))))]
         [#,(transfer-where
             (r 'W-attached)
             ((r 'choice-prefix) (r 'supply-choice))
             (r 'W-2))
          ---------------- "skip-left-failure"
          (#,dispatch-one
           #,dead-term
           (in-hole SourceWorkFocus #,skip-focus)
           (BigFrontierContinue
            (in-hole SourceWorkFocus #,(r 'W-attached))))]
         [#,(transfer-where
             (r 'W-settled)
             ((r 'choice-prefix) (r 'supply-inner))
             returned-answer)
          #,(transfer-where
             (r 'W-residual)
             ((r 'choice-prefix) (r 'supply-inner))
             (r 'W-left))
          ---------------- "reassociate-left-result"
          (#,dispatch-one
           #,returned-answer
           (in-hole SourceWorkFocus #,reassociate-focus)
           (BigContinue
            #,(r 'W-settled)
            (in-hole SourceWorkFocus #,reassociate-target-focus)))]
         [---------------- "commit-choice-answer"
          (#,dispatch-one
           #,returned-answer
           (in-hole SourceSpineContext #,commit-focus)
           (BigFrontierContinue
            (in-hole SourceSpineContext #,(r 'commit-target))))]
         [#,(transfer-where
             (r 'W-target)
             ((r 'choice-prefix) (r 'supply-outer))
             (r 'resume-unattached-target))
          ---------------- "resume-left-choice-success"
          (#,dispatch-one
           #,returned-answer
           (in-hole SourceWorkFocus #,resume-focus)
           (BigFrontierContinue
            (in-hole SourceWorkFocus #,(r 'W-target))))])
        (redex-parameter:define-extended-judgment-form*
         BASE-BIG-DISPATCH #,language
         #:mode (#,dispatch I I O)
         #:parameters ([dispatch-next #,dispatch-one]))
        (redex-parameter:define-extended-judgment-form*
         BASE-BIG-REFOCUS-FRONTIER #,language
         #:mode (#,base-refocus I O))
        ;; The negative fallback guard must be reconstructed in the exact
        ;; final language.  A host predicate closes over this feature's
        ;; intermediate language and therefore cannot recognize a commit
        ;; carrier whose residual contains syntax from a later feature.
        (redex-parameter:define-metafunction*
         #,language
         #,commit-frontier? : SourceF -> any
         [(#,commit-frontier?
           (in-hole SourceSpineContext #,(r 'commit-source)))
          #t]
         [(#,commit-frontier? SourceF_0) #f])
        (redex-parameter:define-judgment-form*
         #,language
         #:parameters
         ([fallback-refocus #,base-refocus]
          [#,commit-frontier-test #,commit-frontier?])
         #:mode (#,refocus I O)
         #:contract (#,refocus SourceF ControlNext)
         [---------------- "commit-choice-answer/classify"
          (#,refocus
           (in-hole SourceSpineContext #,(r 'commit-source))
           (BigControlContinue
            (BigFrontierControl
             #,(r 'commit-source) SourceSpineContext)))]
         [(where #f (#,commit-frontier-test SourceF_0))
          (fallback-refocus SourceF_0 ControlNext_0)
          ---------------- "non-commit/classify"
          (#,refocus SourceF_0 ControlNext_0)])
        (redex-parameter:define-extended-judgment-form*
         BASE-BIG-CONTROL-ONE #,language
         #:mode (#,control-one I O)
         #:parameters
         ([control-work-next #,dispatch-one]
          [control-frontier-refocus #,refocus])
         [(control-frontier-refocus
           (in-hole SourceSpineContext #,(r 'commit-target))
           ControlNext_1)
          ---------------- "commit-choice-answer/frontier"
          (#,control-one
           (BigFrontierControl
            #,(r 'commit-source) SourceSpineContext)
           ControlNext_1)])
        (redex-parameter:define-extended-judgment-form*
         BASE-BIG-CONTROL #,language
         #:mode (#,control I O)
         #:parameters ([control-next #,control-one]))
        (redex-parameter:define-extended-judgment-form*
         BASE-BIG-FRONTIER #,language
         #:mode (#,frontier I I O)
         #:parameters ([frontier-control #,control]))
        (redex-parameter:define-extended-judgment-form*
         BASE-BIG-RUN #,language
         #:mode (#,run I I O)
         #:parameters ([run-dispatch #,control]))
        (redex-parameter:define-extended-judgment-form*
         BASE-BIG-SETTLED #,language
         #:mode (#,settled I I O)
         #:parameters ([settled-dispatch #,control]))
        (redex-parameter:define-extended-judgment-form*
         BASE-BIG-DEAD #,language
         #:mode (#,dead I I O)
         #:parameters ([dead-dispatch #,control]))
        (redex-parameter:define-extended-judgment-form*
         BASE-BIG-FINAL #,language #:mode (#,final I O))
        (redex-parameter:define-judgment-form*
         #,language
         #:parameters
         ([evaluate-dispatch #,control]
          [evaluate-final #,refocus])
         #:mode (#,evaluate I O)
         #:contract (#,evaluate SourceF Big)
         [(evaluate-final SourceF_0 (BigControlDone Big_0))
          ----
          (#,evaluate SourceF_0 Big_0)]
         [(evaluate-final SourceF_0 (BigControlContinue Control_0))
          (evaluate-dispatch Control_0 Big_0)
          ----
          (#,evaluate SourceF_0 Big_0)])
        (redex-parameter:define-extended-judgment-form*
         BASE-PROMOTE #,language
         #:mode (#,promote I O)
         #:parameters
         ([promote-run #,run]
          [promote-frontier #,frontier]
          [promote-settled #,settled]
          [promote-dead #,dead]
          [promote-final #,final])))
       #,@diagnostics])

  (define (render-disjunction-Big-diagnostics name d phase-parameters)
    (define (r key) (hash-ref d key))
    (define language (r 'Big-language))
    (define readback (r 'Big-readback))
    (define spec-language (r 'Big-spec-language))
    (define initialize (r 'Big-initialize))
    (define close (r 'Big-close))
    (define flatten (r 'Big-flatten))
    (define evaluate-spec (r 'Big-evaluate-spec))
    (define unfold-square (r 'Big-unfold-square))
    (define closure-square (r 'Big-closure-square))
    (define root-square (r 'Big-root-square))
    (define D-decompose (r 'D-decompose))
    (define Z-refocus-phase (r 'Z-refocus-phase))
    (define M-machineize (r 'M-machineize))
    (define B-compress (r 'B-compress))
    (define B-step (r 'B-step))
    (define B-span-labels (r 'B-span-labels))
    (define Big-promote (r 'Big-promote))
    (define Big-evaluate (r 'Big-evaluate))
    (list
     #'#:diagnostic-parameters
     (phase-parameters "BIG" (r 'Big-phase) #t)
     #'#:diagnostics
     #`(Big-diagnostics
        #:readback #,readback #:spec-language #,spec-language
        #:initialize #,initialize #:close #,close #:flatten #,flatten
        #:evaluate-spec #,evaluate-spec
        #:unfold-square #,unfold-square
        #:closure-square #,closure-square #:root-square #,root-square)
     #'#:diagnostic-forms
     #`((module+ diagnostics
          (provide #,readback #,spec-language #,initialize #,close #,flatten
                   #,evaluate-spec #,unfold-square #,closure-square
                   #,root-square))
        (define-metafunction #,language
          #,readback : Big -> SourceF
          [(#,readback (BigFinal T)) T])
        (define-extended-language #,spec-language #,(r 'B-language)
          [Big (BigFinal T)]
          [BigNext (BigContinue SourceW SourceWorkFocus)
                   (BigFrontierContinue SourceF)
                   (BigDone Big)]
          [BTrace (TransitionSpan (... ...))])
        (define-judgment-form #,spec-language
          #:mode (#,initialize I O)
          #:contract (#,initialize SourceF B)
          [(#,D-decompose SourceF_0 D_0)
           (where Z_0 (#,Z-refocus-phase D_0))
           (where M_0 (#,M-machineize Z_0))
           (where B_0 (#,B-compress M_0))
           ---- (#,initialize SourceF_0 B_0)])
        (define-judgment-form #,spec-language
          #:mode (#,close I O O)
          #:contract (#,close B BTrace T)
          [---- (#,close (BFinal T) () T)]
          [(#,B-step B_0 TransitionSpan_0 B_1)
           (#,close B_1 (TransitionSpan_rest (... ...)) T_0)
           ----
           (#,close B_0
                    (TransitionSpan_0 TransitionSpan_rest (... ...))
                    T_0)])
        (define-metafunction #,spec-language
          #,flatten : BTrace -> LabelTrace
          [(#,flatten ()) ()]
          [(#,flatten (TransitionSpan_0 TransitionSpan_rest (... ...)))
           (RuleName_span (... ...) RuleName_rest (... ...))
           (where (RuleName_span (... ...))
                  (#,B-span-labels TransitionSpan_0))
           (where (RuleName_rest (... ...))
                  (#,flatten (TransitionSpan_rest (... ...))))])
        (define-judgment-form #,spec-language
          #:mode (#,evaluate-spec I O O)
          #:contract (#,evaluate-spec SourceF BTrace Big)
          [(#,initialize SourceF_0 B_0)
           (#,close B_0 BTrace_0 T_0)
           ---- (#,evaluate-spec SourceF_0 BTrace_0 (BigFinal T_0))])
        (define-judgment-form #,spec-language
          #:mode (#,unfold-square I O O O)
          #:contract (#,unfold-square B TransitionSpan B Big)
          [(#,B-step B_0 TransitionSpan_0 B_1)
           (#,Big-promote B_0 Big_0)
           (#,Big-promote B_1 Big_0)
           ---- (#,unfold-square B_0 TransitionSpan_0 B_1 Big_0)])
        (define-judgment-form #,spec-language
          #:mode (#,closure-square I O O)
          #:contract (#,closure-square B BTrace Big)
          [(#,close B_0 BTrace_0 T_0)
           (#,Big-promote B_0 (BigFinal T_0))
           ---- (#,closure-square B_0 BTrace_0 (BigFinal T_0))])
        (define-judgment-form #,spec-language
          #:mode (#,root-square I O O)
          #:contract (#,root-square SourceF BTrace Big)
          [(#,evaluate-spec SourceF_0 BTrace_0 Big_0)
           (#,Big-evaluate SourceF_0 Big_0)
           ---- (#,root-square SourceF_0 BTrace_0 Big_0)])))))

(define-syntax (render-disjunction-stage-extension/dependencies stx)
  (syntax-parse stx
    [(_ #:language _dependency-language:id
        #:redex-parameters dependency-parameters
        #:branch-copy _dependency-branch-copy:id
        #:R-work-raw _dependency-work-raw:id
        #:R-frontier-raw _dependency-frontier-raw:id
        #:R-allocation-raw _dependency-allocation-raw:id
        #:subst-goal dependency-subst:id
        #:subst-goal-open dependency-subst-open:id
        #:wf-root _dependency-wf-root:id
        #:wf-goal _dependency-wf-goal:id
        #:wf-answer _dependency-wf-answer:id
        #:wf-returned _dependency-wf-returned:id
        #:live-supply _dependency-live-supply:id
        #:failure-summary _dependency-failure-summary:id
        #:wf-work _dependency-wf-work:id
        #:wf-frontier _dependency-wf-frontier:id
        #:WF-open _dependency-wf-open
        #:carrier-view _dependency-carrier-view
        #:prefix-view
        [#:extend-premises _dependency-prefix-premises
         #:Q-empty _dependency-q-empty
         #:work-focus-support dependency-focus:id
         #:work-focus-support-open dependency-focus-open:id
         (~optional (~seq #:transfer-work _dependency-transfer-work))
         #:transfer-work-open _dependency-transfer-work-open
         #:transfer-work-host dependency-transfer-host:id
         #:Q-export-local _dependency-q-export-local
         #:Q-rebuild-local _dependency-q-rebuild-local]
        #:Q-open _dependency-q-open
        (~optional (~seq #:Q-context-open _dependency-q-context-open))
        #:extension-name name:id
        #:owned-source source:id)
     (render-disjunction-stage-extension
      stx #'name (lookup-source #'source)
      #'dependency-parameters
      #'dependency-subst #'dependency-subst-open
      #'dependency-focus #'dependency-focus-open
      #'dependency-transfer-host)]))

(define-syntax (define-generated-disjunction-stage-extension stx)
  (syntax-parse stx
    [(_ name:id
        #:source source:id
        (~optional
         (~seq #:dependencies-from dependencies:id)
         #:defaults ([dependencies #'source])))
     #'(dependencies
        #:visit-extension render-disjunction-stage-extension/dependencies
        #:extension-name name
        #:owned-source source)]))
