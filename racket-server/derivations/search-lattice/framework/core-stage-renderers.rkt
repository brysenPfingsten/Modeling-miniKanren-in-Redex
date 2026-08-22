#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: redex/parameter)
         (for-syntax racket/base
                     racket/list
                     racket/match
                     racket/syntax
                     syntax/parse))

(provide define-selected-core-instance
         define-selected-compression-policy
         define-selected-decomposition-stage
         define-selected-refocused-stage
         define-selected-machine-isomorphism-stage
         define-selected-compressed-stage
         define-selected-fixed-point-stage
         define-selected-stage-extension
         apply-selected-stage-extension
         define-decomposition-representation-map
         define-refocused-representation-map
         define-machine-representation-map
         define-compressed-representation-map
         define-fixed-point-representation-map)

;; Redex declarations must be emitted at expansion time.  The bindings below
;; retain the original, lexically scoped declaration syntax so every later
;; stage can render ordinary Redex forms without inspecting a compiled
;; language or consulting a runtime registry.
(begin-for-syntax
  (struct instance-binding (declaration)
    #:property prop:procedure
    (lambda (_self use-stx)
      (raise-syntax-error
       #f
       "a derivation-instance identifier is valid only after #:from"
       use-stx)))

  (struct policy-binding (declaration)
    #:property prop:procedure
    (lambda (_self use-stx)
      (raise-syntax-error
       #f
       "a compression-policy identifier is valid only after #:policy"
       use-stx)))

  (struct stage-binding
    (kind instance-declaration artifact-declaration policy-declaration)
    #:property prop:procedure
    (lambda (_self use-stx)
      (raise-syntax-error
       #f
       "a derivation-stage identifier is valid only after #:from"
       use-stx)))

  (struct selected-stage-extension-binding (declaration)
    #:property prop:procedure
    (lambda (_self use-stx)
      (raise-syntax-error
       #f
       "a selected stage extension is valid only after #:extension"
       use-stx)))

  (struct rule-info (label site from to premises source) #:transparent)
  (struct redex-parameter-info (local default source) #:transparent)
  (struct instance-info
    (source-language
     redex-parameters
     runtime-variable
     state-view
     work frontier returned returned-view work-focus spine-context
     failure-summary
     run-productions nonallocation-run-productions
     failure-term terminal-success terminal-failure root-focus root-spine frames
     work-redexes frontier-redexes allocation-redexes
     open-work-productions rules declaration)
    #:transparent)
  (struct policy-info
    (settled-producers dead-producers settled-followers dead-followers
     singletons retained-observation maximum-span declaration)
    #:transparent)

  (define (parse-control control-stx)
    (syntax-parse control-stx
      [((~datum run) payload context)
       (list 'run #'payload #'context)]
      [((~datum push) frame payload context)
       (list 'push #'frame #'payload #'context)]
      [((~datum settled) payload context)
       (list 'settled #'payload #'context)]
      [((~datum failed) summary raw context)
       (list 'failed #'summary #'raw #'context)]
      [((~datum pop-settled) frame payload context)
       (list 'pop-settled #'frame #'payload #'context)]
      [((~datum pop-failed) frame summary raw context)
       (list 'pop-failed #'frame #'summary #'raw #'context)]
      [((~datum root-settled) payload spine)
       (list 'root-settled #'payload #'spine)]
      [((~datum root-failed) summary raw spine)
       (list 'root-failed #'summary #'raw #'spine)]
      [((~datum final) payload spine)
       (list 'final #'payload #'spine)]
      [_
       (raise-syntax-error
        #f
        "expected a run/push/settled/failed/pop/root/final control form"
        control-stx)]))

  (define (parse-rule rule-stx)
    (syntax-parse rule-stx
      [[label:id
        #:site site:id
        #:from from-control
        #:to to-control
        #:premises (premise ...)]
       (define site-symbol (syntax-e #'site))
       (unless (memq site-symbol '(work allocation frontier))
         (raise-syntax-error
          #f
          "rule site must be work, allocation, or frontier"
          #'site))
       (rule-info
        #'label
        site-symbol
        (parse-control #'from-control)
        (parse-control #'to-control)
        (syntax->list #'(premise ...))
        rule-stx)]))

  (define (instantiate-one-binder template binder replacement)
    (define binder-symbol (syntax-e binder))
    (define replacement-datum (syntax->datum replacement))
    (define (walk datum)
      (cond
        [(eq? datum binder-symbol) replacement-datum]
        [(pair? datum) (cons (walk (car datum)) (walk (cdr datum)))]
        [else datum]))
    (walk (syntax->datum template)))

  (define (validate-failure-controls rules canonical-summary canonical-failure)
    (for ([rule (in-list rules)])
      (for ([control (in-list (list (rule-info-from rule)
                                    (rule-info-to rule)))])
        (define maybe-summary/raw
          (match control
            [(list 'failed summary raw _context)
             (list summary raw)]
            [(list 'pop-failed _frame summary raw _context)
             (list summary raw)]
            [(list 'root-failed summary raw _spine)
             (list summary raw)]
            [_ #f]))
        (when maybe-summary/raw
          (match-define (list summary raw) maybe-summary/raw)
          (define expected
            (instantiate-one-binder
             canonical-failure canonical-summary summary))
          (unless (equal? (syntax->datum raw) expected)
            (raise-syntax-error
             #f
             "failed control disagrees with the failure-summary view"
             (rule-info-source rule)))))))

  (define (validate-distinct-productions groups declaration)
    (for ([group (in-list groups)])
      (define datums (map syntax->datum group))
      (when (check-duplicates datums equal?)
        (raise-syntax-error
         #f
         "semantic-instance grammar partitions must be duplicate-free"
         declaration))))

  (define (duplicate-identifier? identifiers same?)
    (for/or ([identifier (in-list identifiers)]
             [position (in-naturals)])
      (for/or ([earlier (in-list identifiers)]
               [earlier-position (in-naturals)]
               #:break (= earlier-position position))
        (same? identifier earlier))))

  (define (validate-redex-parameters parameters declaration)
    (define locals (map redex-parameter-info-local parameters))
    (when (duplicate-identifier?
           locals
           (lambda (left right)
             (eq? (syntax-e left) (syntax-e right))))
      (raise-syntax-error
       #f
       "Redex parameter local identifiers must be distinct"
       declaration)))

  (define (parse-redex-parameters locals defaults declaration)
    (define parameters
      (for/list ([local (in-list locals)]
                 [default (in-list defaults)])
        (redex-parameter-info local default declaration)))
    (validate-redex-parameters parameters declaration)
    parameters)

  ;; A selected source view and a post-generation extension may be declared in
  ;; different modules.  Their unbound local-slot spellings then carry
  ;; different module scopes even though they denote the same declared Redex
  ;; parameter.  Recontextualize
  ;; only call-head identifiers that name a slot; every argument identifier and
  ;; all host-escape syntax retain their original lexical context.  In
  ;; particular, side-condition bodies are Racket expressions and are opaque;
  ;; a same-spelled head in any other premise position is the declared slot,
  ;; even when a colliding host binding is visible in the declaration module.
  (define (canonicalize-redex-parameter-calls premise parameters)
    (define slots
      (for/hash ([parameter (in-list parameters)])
        (values (syntax-e (redex-parameter-info-local parameter))
                (redex-parameter-info-local parameter))))
    (define (opaque-host-form? datum)
      (and (pair? datum)
           (identifier? (car datum))
           (memq (syntax-e (car datum))
                 '(side-condition
                   side-condition/hidden
                   quote
                   quasiquote
                   syntax
                   quasisyntax
                   unquote
                   unquote-splicing
                   unsyntax
                   unsyntax-splicing))))
    (define (canonicalize identifier)
      (define slot (hash-ref slots (syntax-e identifier) (lambda () #f)))
      (if slot
          (datum->syntax slot
                         (syntax-e slot)
                         identifier
                         identifier)
          identifier))
    (define (walk-tail datum)
      (cond
        [(pair? datum)
         (cons (walk (car datum) #f)
               (walk-tail (cdr datum)))]
        [(syntax? datum) (walk datum #f)]
        [else datum]))
    (define (walk stx head?)
      (cond
        [(identifier? stx)
         (if head? (canonicalize stx) stx)]
        [else
         (define datum (syntax-e stx))
         (cond
           [(or (not (pair? datum))
                (opaque-host-form? datum))
            stx]
           [else
            (datum->syntax
             stx
             (cons (walk (car datum) #t)
                   (walk-tail (cdr datum)))
             stx
             stx)])]))
    (walk premise #f))

  (define (canonicalize-rule-redex-parameter-calls rule parameters)
    (struct-copy
     rule-info
     rule
     [premises
      (for/list ([premise (in-list (rule-info-premises rule))])
        (canonicalize-redex-parameter-calls premise parameters))]))

  (define (parse-instance declaration)
    (syntax-parse declaration
      [(_ _name:id
          #:source-language source-language:id
          (~optional
           (~seq #:redex-parameters
                 ([redex-parameter-local:id redex-parameter-default:id] ...))
           #:defaults ([(redex-parameter-local 1) '()]
                       [(redex-parameter-default 1) '()]))
          #:variable-view
          [#:runtime-variable runtime-variable:id]
          #:live-state-view
          [#:state state-view
           #:work work:id
           #:run-productions (run-production ...)
           #:nonallocation-run-productions (nonallocation-run-production ...)]
          #:returned-view
          [#:carrier returned:id
           #:materialized returned-view]
          #:failure-summary-view
          [#:carrier failure-summary:id
           #:materialized failure-term]
          #:terminal-view
          [#:frontier frontier:id
           #:success terminal-success
           #:failure terminal-failure]
          #:payload/context-view
          [#:work-focus work-focus:id
           #:spine-context spine-context:id
           #:root-focus root-focus
           #:root-spine root-spine
           #:frames (frame ...)
           #:work-redexes (work-redex ...)
           #:frontier-redexes (frontier-redex ...)
           #:allocation-redexes (allocation-redex ...)
           #:open-work-productions (open-work-production ...)]
          #:rules (rule ...))
       (define redex-parameters
         (parse-redex-parameters
          (syntax->list #'(redex-parameter-local ...))
          (syntax->list #'(redex-parameter-default ...))
          declaration))
       (define rules
         (for/list ([one-rule (in-list (syntax->list #'(rule ...)))])
           (canonicalize-rule-redex-parameter-calls
            (parse-rule one-rule)
            redex-parameters)))
       (define labels (map (lambda (rule) (syntax-e (rule-info-label rule)))
                           rules))
       (when (check-duplicates labels)
         (raise-syntax-error #f "duplicate semantic rule label" declaration))
       (validate-failure-controls rules #'failure-summary #'failure-term)
       (validate-distinct-productions
        (list (syntax->list #'(run-production ...))
              (syntax->list #'(nonallocation-run-production ...))
              (syntax->list #'(frame ...))
              (syntax->list #'(work-redex ...))
              (syntax->list #'(frontier-redex ...))
              (syntax->list #'(allocation-redex ...))
              (list #'terminal-success #'terminal-failure)
              (syntax->list #'(open-work-production ...)))
        declaration)
       (instance-info
        #'source-language
        redex-parameters
        #'runtime-variable
        #'state-view
        #'work
        #'frontier
        #'returned
        #'returned-view
        #'work-focus
        #'spine-context
        #'failure-summary
        (syntax->list #'(run-production ...))
        (syntax->list #'(nonallocation-run-production ...))
        #'failure-term
        #'terminal-success
        #'terminal-failure
        #'root-focus
        #'root-spine
        (syntax->list #'(frame ...))
        (syntax->list #'(work-redex ...))
        (syntax->list #'(frontier-redex ...))
        (syntax->list #'(allocation-redex ...))
        (syntax->list #'(open-work-production ...))
        rules
        declaration)]))

  (define (parse-policy declaration)
    (syntax-parse declaration
      [(_ _name:id
          #:settled-producers (settled-producer:id ...)
          #:dead-producers (dead-producer:id ...)
          #:settled-followers (settled-follower:id ...)
          #:dead-followers (dead-follower:id ...)
          #:singletons (singleton:id ...)
          #:retained-observation retained-observation:id
          #:maximum-span maximum-span:exact-positive-integer)
       (policy-info
        (syntax->list #'(settled-producer ...))
        (syntax->list #'(dead-producer ...))
        (syntax->list #'(settled-follower ...))
        (syntax->list #'(dead-follower ...))
        (syntax->list #'(singleton ...))
        #'retained-observation
        (syntax-e #'maximum-span)
        declaration)]))

  (define (lookup-instance identifier)
    (define value (syntax-local-value identifier (lambda () #f)))
    (cond
      [(instance-binding? value)
       (parse-instance (instance-binding-declaration value))]
      [(stage-binding? value)
       (parse-instance (stage-binding-instance-declaration value))]
      [else
       (raise-syntax-error #f "expected a derivation instance or stage" identifier)]))

  (define (lookup-policy identifier)
    (define value (syntax-local-value identifier (lambda () #f)))
    (unless (policy-binding? value)
      (raise-syntax-error #f "expected a compression policy" identifier))
    (parse-policy (policy-binding-declaration value)))

  (define (lookup-stage identifier expected-kind)
    (define value (syntax-local-value identifier (lambda () #f)))
    (unless (and (stage-binding? value)
                 (eq? (stage-binding-kind value) expected-kind))
      (raise-syntax-error
       #f
       (format "expected a ~a derivation stage" expected-kind)
       identifier))
    value)

  (define (control-kind control)
    (car control))

  (define (control->D-source rule root-focus)
    (define control (rule-info-from rule))
    (define site (rule-info-site rule))
    (case (control-kind control)
      [(run)
       (define payload (second control))
       (define context (third control))
       (if (eq? site 'allocation)
           #`(DecAllocate #,payload #,context)
           #`(DecWork #,payload #,context))]
      [(pop-settled)
       (match-define (list _ frame payload context) control)
       #`(DecWork (in-hole #,frame #,payload) #,context)]
      [(pop-failed)
       (match-define (list _ frame _summary raw context) control)
       #`(DecWork (in-hole #,frame #,raw) #,context)]
      [(root-settled)
       (match-define (list _ payload spine) control)
       #`(DecFrontier (in-hole #,root-focus #,payload) #,spine)]
      [(root-failed)
       (match-define (list _ _summary raw spine) control)
       #`(DecFrontier (in-hole #,root-focus #,raw) #,spine)]
      [else
       (raise-syntax-error
        #f
        "unsupported semantic-rule source control"
        (rule-info-source rule))]))

  (define (control->C-target rule label)
    (define control (rule-info-to rule))
    (case (control-kind control)
      [(run settled)
       (match-define (list _ payload context) control)
       #`(ContractWork #,label #,payload #,context)]
      [(push)
       (match-define (list _ frame payload context) control)
       #`(ContractWork #,label (in-hole #,frame #,payload) #,context)]
      [(failed)
       (match-define (list _ _summary raw context) control)
       #`(ContractWork #,label #,raw #,context)]
      [(final)
       (match-define (list _ payload spine) control)
       #`(ContractFrontier #,label #,payload #,spine)]
      [else
       (raise-syntax-error
        #f
        "unsupported semantic-rule target control"
        (rule-info-source rule))]))

  ;; Keeping the splicing helper separate makes the generated rule shape
  ;; testable without expanding Redex's own macros.
  (define (render-contract-rule rule root-focus contract-id)
    (define label (rule-info-label rule))
    (define source (control->D-source rule root-focus))
    (define target (control->C-target rule label))
    (define premises (rule-info-premises rule))
    (with-syntax ([(premise ...) premises]
                  [source source]
                  [target target]
                  [contract-id contract-id])
      #'[premise ...
         ----
         (contract-id source target)]))

  ;; Render a phase-native transition clause directly from the semantic
  ;; control equation.  Z and M use this route for their executable steppers;
  ;; neither clause converts its input through D.
  (define (control->phase-source rule
                                 work-constructor
                                 frontier-constructor
                                 allocate-constructor
                                 root-focus)
    (define control (rule-info-from rule))
    (define site (rule-info-site rule))
    (match control
      [(list 'run payload context)
       (if (eq? site 'allocation)
           #`(#,allocate-constructor #,payload #,context)
           #`(#,work-constructor #,payload #,context))]
      [(list 'pop-settled frame payload context)
       #`(#,work-constructor (in-hole #,frame #,payload) #,context)]
      [(list 'pop-failed frame _summary raw context)
       #`(#,work-constructor (in-hole #,frame #,raw) #,context)]
      [(list 'root-settled payload spine)
       #`(#,frontier-constructor
          (in-hole #,root-focus #,payload)
          #,spine)]
      [(list 'root-failed _summary raw spine)
       #`(#,frontier-constructor
          (in-hole #,root-focus #,raw)
          #,spine)]
      [_
       (raise-syntax-error
        #f
        "unsupported source control for a phase-native step"
        (rule-info-source rule))]))

  (define (render-native-step-rule rule
                                   carrier
                                   work-constructor
                                   frontier-constructor
                                   allocate-constructor
                                   final-constructor
                                   root-focus
                                   refocus-work-id
                                   step-id)
    (define source
      (control->phase-source
       rule
       work-constructor
       frontier-constructor
       allocate-constructor
       root-focus))
    (define label (rule-info-label rule))
    (define output
      (format-id carrier "~a_1" (syntax-e carrier)))
    (define refocus-premise
      (match (rule-info-to rule)
        [(list 'run payload context)
         #`(#,refocus-work-id #,payload #,context #,output)]
        [(list 'push frame payload context)
         #`(#,refocus-work-id
            #,payload
            (in-hole #,context #,frame)
            #,output)]
        [(list 'settled payload context)
         #`(#,refocus-work-id #,payload #,context #,output)]
        [(list 'failed _summary raw context)
         #`(#,refocus-work-id #,raw #,context #,output)]
        [(list 'final payload spine)
         #`(where #,output
                  (#,final-constructor
                   (in-hole #,spine #,payload)))]
        [_
         (raise-syntax-error
          #f
          "unsupported target control for a phase-native step"
          (rule-info-source rule))]))
    (define premises (rule-info-premises rule))
    (with-syntax ([(premise ...) premises]
                  [source source]
                  [label label]
                  [refocus-premise refocus-premise]
                  [output output]
                  [step-id step-id])
      #'[premise ...
         refocus-premise
         ----
         (step-id source label output)]))

  ;; Z and M have the same retained-context transition program under a
  ;; constructor renaming.  Rendering both from this one template is the
  ;; mechanical content of the explicit Z/M isomorphism stage.  This is
  ;; structural reification, not an additional semantic transformation.
  (define (render-retained-context-refocuser
           language carrier refocus-work refocus
           final-constructor work-constructor
           frontier-constructor allocate-constructor
           root-spine frames)
    (define carrier-var
      (format-id carrier "~a_0" (syntax-e carrier)))
    (define refocus-work-dependency
      (generate-temporary 'refocus-work-dependency))
    (define frame-refocus-clauses
      (if (null? frames)
          '()
          (list
           #`[(#,refocus-work
               OpenW
               (in-hole SourceWorkFocus Frame)
               #,carrier-var)
              ----
              (#,refocus-work
               (in-hole Frame OpenW)
               SourceWorkFocus
               #,carrier-var)]
           #`[----
              (#,refocus-work
               Settled
               (in-hole SourceWorkFocus Frame)
               (#,work-constructor
                (in-hole Frame Settled)
                SourceWorkFocus))]
           #`[----
              (#,refocus-work
               DeadW
               (in-hole SourceWorkFocus Frame)
               (#,work-constructor
                (in-hole Frame DeadW)
                SourceWorkFocus))])))
    (with-syntax ([language language]
                  [carrier carrier]
                  [carrier-var carrier-var]
                  [refocus-work refocus-work]
                  [refocus-work-dependency refocus-work-dependency]
                  [refocus refocus]
                  [final-constructor final-constructor]
                  [work-constructor work-constructor]
                  [frontier-constructor frontier-constructor]
                  [allocate-constructor allocate-constructor]
                  [root-spine root-spine])
      (with-syntax ([(frame-refocus-clause ...)
                     frame-refocus-clauses])
      (list
       #'(redex-parameter:define-judgment-form*
           language
           #:mode (refocus-work I I O)
           #:contract (refocus-work SourceW SourceWorkFocus carrier)
           [----
            (refocus-work WR SourceWorkFocus
                          (work-constructor WR SourceWorkFocus))]
           [----
            (refocus-work AR SourceWorkFocus
                          (allocate-constructor AR SourceWorkFocus))]
           frame-refocus-clause ...
           [----
            (refocus-work
             Settled
             (in-hole SourceSpineContext RootFocus)
             (frontier-constructor
              (in-hole RootFocus Settled)
              SourceSpineContext))]
           [----
            (refocus-work
             DeadW
             (in-hole SourceSpineContext RootFocus)
             (frontier-constructor
              (in-hole RootFocus DeadW)
              SourceSpineContext))])
       #'(redex-parameter:define-judgment-form*
           language
           #:parameters
           ([refocus-work-dependency refocus-work])
           #:mode (refocus I O)
           #:contract (refocus C carrier)
           [(refocus-work-dependency
             SourceW SourceWorkFocus carrier-var)
            ----
            (refocus
             (ContractWork RuleName SourceW SourceWorkFocus)
             carrier-var)]
           [----
            (refocus
             (ContractFrontier RuleName SourceF_0 root-spine)
             (final-constructor
              (in-hole root-spine SourceF_0)))])))))

  (define (label-symbol identifier)
    (syntax-e identifier))

  (define (compose-context outer inner)
    (define (replace-hole datum)
      (cond
        [(eq? datum 'hole) (syntax->datum inner)]
        [(pair? datum)
         (cons (replace-hole (car datum))
               (replace-hole (cdr datum)))]
        [else datum]))
    (datum->syntax outer
                   (replace-hole (syntax->datum outer))
                   outer
                   outer))

  (define (rules-for-labels instance identifiers who)
    (define by-label
      (for/hash ([rule (in-list (instance-info-rules instance))])
        (values (label-symbol (rule-info-label rule)) rule)))
    (for/list ([identifier (in-list identifiers)])
      (hash-ref
       by-label
       (label-symbol identifier)
       (lambda ()
         (raise-syntax-error
          #f
          (format "~a names an unknown semantic rule" who)
          identifier)))))

  (define (control->B-target control)
    (match control
      [(list 'run payload context)
       #`(BRun #,payload #,context)]
      [(list 'push frame payload context)
       #`(BRun #,payload (in-hole #,context #,frame))]
      [(list 'settled payload context)
       #`(BSettled #,payload #,context)]
      [(list 'failed failure-summary _raw context)
       #`(BDead #,failure-summary #,context)]
      [(list 'final payload _spine)
       (define spine (third control))
       #`(BFinal (in-hole #,spine #,payload))]
      [_
       (error 'control->B-target "unsupported target control ~e" control)]))

  (define (render-producer-rule rule judgment expected-target)
    (unless (eq? (control-kind (rule-info-from rule)) 'run)
      (raise-syntax-error
       #f
       "producer must start from run control"
       (rule-info-source rule)))
    (match-define (list 'run source source-context)
      (rule-info-from rule))
    (define target (rule-info-to rule))
    (unless (eq? (control-kind target) expected-target)
      (raise-syntax-error
       #f
       (format "producer must target ~a" expected-target)
       (rule-info-source rule)))
    (define target-context
      (case expected-target
        [(settled) (third target)]
        [(failed) (fourth target)]))
    (define label (rule-info-label rule))
    (define premises (rule-info-premises rule))
    (define output
      (case expected-target
        [(settled) (second target)]
        [(failed) (second target)]))
    (with-syntax ([(premise ...) premises]
                  [judgment judgment]
                  [source source]
                  [source-context source-context]
                  [label label]
                  [output output]
                  [target-context target-context])
      #'[premise ...
         ----
         (judgment
          source source-context label output target-context)]))

  (define (render-advance-rule rule judgment expected-source root-focus)
    (define source (rule-info-from rule))
    (unless (memq (control-kind source) expected-source)
      (raise-syntax-error
       #f
       "follower has the wrong control source"
       (rule-info-source rule)))
    (define label (rule-info-label rule))
    (define premises (rule-info-premises rule))
    (define target (control->B-target (rule-info-to rule)))
    (define-values (payload focus)
      (match source
        [(list 'pop-settled frame settled context)
         (values settled #`(in-hole #,context #,frame))]
        [(list 'root-settled settled spine)
         (values settled #`(in-hole #,spine #,root-focus))]
        [(list 'pop-failed frame failure-summary _raw context)
         (values failure-summary #`(in-hole #,context #,frame))]
        [(list 'root-failed failure-summary _raw spine)
         (values failure-summary #`(in-hole #,spine #,root-focus))]))
    (with-syntax ([(premise ...) premises]
                  [judgment judgment]
                  [payload payload]
                  [focus focus]
                  [label label]
                  [target target])
      #'[premise ...
         ----
         (judgment payload focus label target)]))

  (define (render-singleton-run-rule rule step-direct)
    (define source-control (rule-info-from rule))
    (unless (eq? (control-kind source-control) 'run)
      (raise-syntax-error
       #f
       "non-follower singleton must start from run control"
       (rule-info-source rule)))
    (match-define (list _ source context) source-control)
    (define target (control->B-target (rule-info-to rule)))
    (define label (rule-info-label rule))
    (define premises (rule-info-premises rule))
    (with-syntax ([(premise ...) premises]
                  [step-direct step-direct]
                  [source source]
                  [context context]
                  [target target]
                  [label label])
      #'[premise ...
         ----
         (step-direct
          (BRun source context)
          (transition-span label)
          target)]))

  (define (control->big-source control root-focus)
    (match control
      [(list 'run payload context)
       (values payload context)]
      [(list 'pop-settled frame payload context)
       (values payload #`(in-hole #,context #,frame))]
      [(list 'pop-failed frame _summary raw context)
       (values raw #`(in-hole #,context #,frame))]
      [(list 'root-settled payload spine)
       (values payload #`(in-hole #,spine #,root-focus))]
      [(list 'root-failed _summary raw spine)
       (values raw #`(in-hole #,spine #,root-focus))]
      [_
       (error 'control->big-source "unsupported source control ~e" control)]))

  (define (control->big-next control)
    (match control
      [(list 'run payload context)
       #`(BigContinue #,payload #,context)]
      [(list 'push frame payload context)
       #`(BigContinue #,payload (in-hole #,context #,frame))]
      [(list 'settled payload context)
       #`(BigContinue #,payload #,context)]
      [(list 'failed _summary raw context)
       #`(BigContinue #,raw #,context)]
      [(list 'final payload spine)
       #`(BigDone (BigFinal (in-hole #,spine #,payload)))]
      [_
       (error 'control->big-next "unsupported target control ~e" control)]))

  (define (render-big-rule rule dispatch-one root-focus)
    (define-values (source context)
      (control->big-source (rule-info-from rule) root-focus))
    (define premises (rule-info-premises rule))
    (define next (control->big-next (rule-info-to rule)))
    (with-syntax ([(premise ...) premises]
                  [dispatch-one dispatch-one]
                  [source source]
                  [context context]
                  [next next])
      #'[premise ...
         ----
         (dispatch-one source context next)]))

  (define selected-extension-opaque-heads
    '(quote quasiquote syntax quasisyntax))

  (define (instantiate-selected-extension-form form replacements)
    (define table
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
         (hash-ref table (syntax-e stx) (lambda () stx))]
        [else
         (define datum (syntax-e stx))
         (cond
           [(and (pair? datum)
                 (identifier? (car datum))
                 (memq (syntax-e (car datum))
                       selected-extension-opaque-heads))
            stx]
           [(pair? datum)
            (datum->syntax
             stx
             (cons (walk (car datum)) (walk-tail (cdr datum)))
             stx
             stx)]
           [else stx])]))
    (walk form))

  (define (lookup-selected-stage-extension identifier)
    (define value (syntax-local-value identifier (lambda () #f)))
    (unless (selected-stage-extension-binding? value)
      (raise-syntax-error
       #f
       "expected a selected stage extension"
       identifier))
    (selected-stage-extension-binding-declaration value))

  (define (stage-definition stage-id kind instance artifacts policy)
    #`(define-syntax #,stage-id
        (stage-binding
         '#,kind
         (quote-syntax #,(instance-info-declaration instance))
         (quote-syntax #,artifacts)
         #,(if policy
               #`(quote-syntax #,(policy-info-declaration policy))
               #'#f)))))

(define-syntax (define-selected-core-instance stx)
  (syntax-parse stx
    [(_ name:id . _)
     (parse-instance stx)
     #`(define-syntax name
         (instance-binding (quote-syntax #,stx)))]))

;; A StageExtension is a syntax-level collection of feature-owned extensions.
;; It cannot be applied until all five base stage bindings already exist.  The
;; feature forms refer to the documented BASE-* placeholders; application
;; substitutes only those identifiers and otherwise preserves lexical scope.
;; This composes with already-generated stage bindings.
;;
;; Redex parameter extensions are registered for one exact language.  A
;; feature with a widened dependency therefore defines its rule text once as
;; a reusable template and instantiates that template directly against the
;; base dependency in each feature stage language before lifting the inherited
;; stage artifact.  The lifted inherited rules then select the phase-local
;; dependency automatically; no inherited semantic rule is repeated.
;;
;; Common: BASE-SOURCE-LANGUAGE
;; D: BASE-D-LANGUAGE, BASE-D-PLUG, BASE-C-PLUG, BASE-CONTRACT-LABEL,
;;    BASE-DECOMPOSE, BASE-CONTRACT, BASE-D-STEP
;; Z: BASE-Z-LANGUAGE, BASE-REFOCUS-PHASE, BASE-Z-REFOCUS-WORK,
;;    BASE-Z-REFOCUS, BASE-Z-STEP
;; M: BASE-M-LANGUAGE, BASE-MACHINEIZE, BASE-M-REFOCUS-WORK,
;;    BASE-M-REFOCUS, BASE-M-STEP
;; B: BASE-B-LANGUAGE, BASE-COMPRESS, BASE-SPAN-LABELS,
;;    BASE-B-PRODUCE-SETTLED, BASE-B-PRODUCE-DEAD,
;;    BASE-B-ADVANCE-SETTLED, BASE-B-ADVANCE-DEAD,
;;    BASE-B-SINGLETON, BASE-B-STEP
;; Big: BASE-BIG-LANGUAGE, BASE-BIG-DISPATCH-ONE, BASE-BIG-DISPATCH,
;;      BASE-BIG-SPEC-LANGUAGE, BASE-BIG-RUN,
;;      BASE-BIG-SETTLED, BASE-BIG-DEAD, BASE-BIG-FINAL,
;;      BASE-BIG-EVALUATE, BASE-PROMOTE
(define-syntax (define-selected-stage-extension stx)
  (syntax-parse stx
    [(_ name:id
        #:D (D-form ...)
        #:Z (Z-form ...)
        #:M (M-form ...)
        #:B (B-form ...)
        #:Big (Big-form ...))
     #`(define-syntax name
         (selected-stage-extension-binding
          (quote-syntax #,stx)))]))

(define-syntax (apply-selected-stage-extension stx)
  (syntax-parse stx
    [(_ #:extension extension-id:id
        #:D D-stage-id:id
        #:Z Z-stage-id:id
        #:M M-stage-id:id
        #:B B-stage-id:id
        #:Big Big-stage-id:id)
     (define declaration
       (lookup-selected-stage-extension #'extension-id))
     (define D-stage (lookup-stage #'D-stage-id 'D))
     (define Z-stage (lookup-stage #'Z-stage-id 'Z))
     (define M-stage (lookup-stage #'M-stage-id 'M))
     (define B-stage (lookup-stage #'B-stage-id 'B))
     (define Big-stage (lookup-stage #'Big-stage-id 'Big))
     (define stage-ids
       (list #'D-stage-id #'Z-stage-id #'M-stage-id
             #'B-stage-id #'Big-stage-id))
     (define source-languages
       (for/list ([stage-id (in-list stage-ids)])
         (instance-info-source-language (lookup-instance stage-id))))
     (unless
         (for/and ([other (in-list (rest source-languages))])
           (free-identifier=? (first source-languages) other))
       (raise-syntax-error
        #f
        "all coordinates of a selected stage extension must share one row"
        stx))
     (define instance (lookup-instance #'D-stage-id))

     (define-values
       (D-language D-plug-D D-plug-C D-contract-label
                   D-decompose D-contract D-step)
       (syntax-parse (stage-binding-artifact-declaration D-stage)
         [((~datum D-artifacts)
           #:language language:id
           #:plug-D plug-D:id
           #:plug-C plug-C:id
           #:contract-label contract-label:id
           #:decompose decompose:id
           #:contract contract:id
           #:step step:id)
          (values #'language #'plug-D #'plug-C #'contract-label
                  #'decompose #'contract #'step)]))
     (define-values
       (Z-language Z-refocus-phase Z-refocus-work Z-refocus Z-step)
       (syntax-parse (stage-binding-artifact-declaration Z-stage)
         [((~datum Z-artifacts)
           #:language language:id
           #:refocus-phase refocus-phase:id
           #:D->Z _D->Z:id
           #:Z->D _Z->D:id
           #:readback _readback:id
           #:refocus-spec _refocus-spec:id
           #:refocus-work-direct refocus-work:id
           #:refocus-direct refocus:id
           #:step-spec _step-spec:id
           #:step-direct step:id
           . _tail)
          (values #'language #'refocus-phase #'refocus-work
                  #'refocus #'step)]))
     (define-values
       (M-language M-machineize M-refocus-work M-refocus M-step)
       (syntax-parse (stage-binding-artifact-declaration M-stage)
         [((~datum M-artifacts)
           #:language language:id
           #:machineize machineize:id
           #:encode-ZM _encode-ZM:id
           #:decode-MZ _decode-MZ:id
           #:D->M _D->M:id
           #:M->D _M->D:id
           #:readback _readback:id
           #:refocus-work-direct refocus-work:id
           #:refocus-direct refocus:id
           #:step-direct step:id
           . _tail)
          (values #'language #'machineize #'refocus-work
                  #'refocus #'step)]))
     (define-values
       (B-language B-compress B-span-labels
                   B-produce-settled B-produce-dead
                   B-advance-settled B-advance-dead
                   B-base-singleton B-step)
       (syntax-parse (stage-binding-artifact-declaration B-stage)
         [((~datum B-artifacts)
           #:language language:id
           #:compress compress:id
           #:encode-MB _encode-MB:id
           #:decode-BM _decode-BM:id
           #:readback _readback:id
           #:span-labels span-labels:id
           #:produce-settled produce-settled:id
           #:produce-dead produce-dead:id
           #:advance-settled advance-settled:id
           #:advance-dead advance-dead:id
           #:base-singleton base-singleton:id
           #:step-direct step:id
           . _tail)
          (values #'language #'compress #'span-labels
                  #'produce-settled #'produce-dead
                  #'advance-settled #'advance-dead
                  #'base-singleton #'step)]))
     (define-values
       (Big-language Big-dispatch-one Big-dispatch
                     Big-run Big-settled Big-dead
                     Big-final Big-evaluate Big-spec-language Big-promote)
       (syntax-parse (stage-binding-artifact-declaration Big-stage)
         [((~datum Big-artifacts)
           #:language language:id
           #:readback _readback:id
           #:dispatch-one dispatch-one:id
           #:dispatch dispatch:id
           #:run run:id
           #:settled settled:id
           #:dead dead:id
           #:final final:id
           #:evaluate evaluate:id
           #:spec-language spec-language:id
           #:promote promote:id
           . _tail)
          (values #'language #'dispatch-one #'dispatch
                  #'run #'settled #'dead
                  #'final #'evaluate #'spec-language #'promote)]))

     (define replacements
       (list
        (cons 'BASE-SOURCE-LANGUAGE
              (instance-info-source-language instance))
        (cons 'BASE-D-LANGUAGE D-language)
        (cons 'BASE-D-PLUG D-plug-D)
        (cons 'BASE-C-PLUG D-plug-C)
        (cons 'BASE-CONTRACT-LABEL D-contract-label)
        (cons 'BASE-DECOMPOSE D-decompose)
        (cons 'BASE-CONTRACT D-contract)
        (cons 'BASE-D-STEP D-step)
        (cons 'BASE-Z-LANGUAGE Z-language)
        (cons 'BASE-REFOCUS-PHASE Z-refocus-phase)
        (cons 'BASE-Z-REFOCUS-WORK Z-refocus-work)
        (cons 'BASE-Z-REFOCUS Z-refocus)
        (cons 'BASE-Z-STEP Z-step)
        (cons 'BASE-M-LANGUAGE M-language)
        (cons 'BASE-MACHINEIZE M-machineize)
        (cons 'BASE-M-REFOCUS-WORK M-refocus-work)
        (cons 'BASE-M-REFOCUS M-refocus)
        (cons 'BASE-M-STEP M-step)
        (cons 'BASE-B-LANGUAGE B-language)
        (cons 'BASE-COMPRESS B-compress)
        (cons 'BASE-SPAN-LABELS B-span-labels)
        (cons 'BASE-B-PRODUCE-SETTLED B-produce-settled)
        (cons 'BASE-B-PRODUCE-DEAD B-produce-dead)
        (cons 'BASE-B-ADVANCE-SETTLED B-advance-settled)
        (cons 'BASE-B-ADVANCE-DEAD B-advance-dead)
        (cons 'BASE-B-SINGLETON B-base-singleton)
        (cons 'BASE-B-STEP B-step)
        (cons 'BASE-BIG-LANGUAGE Big-language)
        (cons 'BASE-BIG-DISPATCH-ONE Big-dispatch-one)
        (cons 'BASE-BIG-DISPATCH Big-dispatch)
        (cons 'BASE-BIG-SPEC-LANGUAGE Big-spec-language)
        (cons 'BASE-BIG-RUN Big-run)
        (cons 'BASE-BIG-SETTLED Big-settled)
        (cons 'BASE-BIG-DEAD Big-dead)
        (cons 'BASE-BIG-FINAL Big-final)
        (cons 'BASE-BIG-EVALUATE Big-evaluate)
        (cons 'BASE-PROMOTE Big-promote)))
     (define forms
       (syntax-parse declaration
         [(_ _name:id
             #:D (D-form ...)
             #:Z (Z-form ...)
             #:M (M-form ...)
             #:B (B-form ...)
             #:Big (Big-form ...))
          (append
           (syntax->list #'(D-form ...))
           (syntax->list #'(Z-form ...))
           (syntax->list #'(M-form ...))
           (syntax->list #'(B-form ...))
           (syntax->list #'(Big-form ...)))]))
     #`(begin
         #,@(for/list ([form (in-list forms)])
              (instantiate-selected-extension-form form replacements)))]))

(define-syntax (define-selected-compression-policy stx)
  (syntax-parse stx
    [(_ name:id . _)
     (define policy (parse-policy stx))
     (unless (= (policy-info-maximum-span policy) 2)
       (raise-syntax-error
        #f
        "the current bounded compressor requires #:maximum-span 2"
        stx))
     (unless (eq? (syntax-e (policy-info-retained-observation policy))
                  'rule-labels)
       (raise-syntax-error
        #f
        "the current compressor retains exact rule-label traces"
        (policy-info-retained-observation policy)))
     (define groups
       (list (policy-info-settled-producers policy)
             (policy-info-dead-producers policy)
             (policy-info-settled-followers policy)
             (policy-info-dead-followers policy)
             (policy-info-singletons policy)))
     (for ([group (in-list groups)])
       (define labels (map label-symbol group))
       (when (check-duplicates labels)
         (raise-syntax-error
          #f
          "compression-policy lists must be duplicate-free"
          stx)))
     (define settled-producers
       (map label-symbol (policy-info-settled-producers policy)))
     (define dead-producers
       (map label-symbol (policy-info-dead-producers policy)))
     (define settled-followers
       (map label-symbol (policy-info-settled-followers policy)))
     (define dead-followers
       (map label-symbol (policy-info-dead-followers policy)))
     (define singletons
       (map label-symbol (policy-info-singletons policy)))
     (define (overlap? left right)
       (ormap (lambda (label) (memq label right)) left))
     (when (or (overlap? settled-producers dead-producers)
               (overlap? settled-followers dead-followers)
               (overlap? (append settled-producers dead-producers)
                         singletons))
       (raise-syntax-error
        #f
        (string-append
         "settled/dead classes must be disjoint, and producers cannot "
         "also be singletons")
        stx))
     (unless (andmap (lambda (label) (memq label singletons))
                     (append settled-followers dead-followers))
       (raise-syntax-error
        #f
        "every follower must also be classified as a singleton"
        stx))
     #`(define-syntax name
         (policy-binding (quote-syntax #,stx)))]))

;; Every definition that an independently staged feature may widen is
;; liftable.  Semantic judgments retain source dependency slots, while the
;; structural phase arrows and drivers retain slots for their phase-local
;; contract, refocuser, compressor, or dispatcher dependencies.
;;
;; The first stage emits the exact grammatical shell and renders every
;; semantic equation from the instance declaration once.  Subsequent stage
;; macros consume the same retained declaration through their stage binding.
(define-syntax (define-selected-decomposition-stage stx)
  (syntax-parse stx
    [(_ stage-id:id
        #:from instance-id:id
        #:language decomposition-language:id
        #:plug-D plug-D:id
        #:plug-C plug-C:id
        #:contract-label contract-label:id
        #:decompose decompose:id
        #:contract contract:id
        #:step step:id)
     (define instance (lookup-instance #'instance-id))
     (define source-language (instance-info-source-language instance))
     (define source-runtime-variable
       (instance-info-runtime-variable instance))
     (define source-state-view (instance-info-state-view instance))
     (define source-work (instance-info-work instance))
     (define source-frontier (instance-info-frontier instance))
     (define source-settled (instance-info-returned instance))
     (define source-returned-view
       (instance-info-returned-view instance))
     (define source-failure-view
       (instance-info-failure-term instance))
     (define terminal-success
       (instance-info-terminal-success instance))
     (define terminal-failure
       (instance-info-terminal-failure instance))
     (define source-work-focus (instance-info-work-focus instance))
     (define source-spine-context (instance-info-spine-context instance))
     (define redex-parameters (instance-info-redex-parameters instance))
     (define work-redexes (instance-info-work-redexes instance))
     (define frontier-redexes (instance-info-frontier-redexes instance))
     (define allocation-redexes (instance-info-allocation-redexes instance))
     (define labels (map rule-info-label (instance-info-rules instance)))
     (define contract-rules
       (map (lambda (rule)
              (render-contract-rule
               rule
               (instance-info-root-focus instance)
               #'contract))
            (instance-info-rules instance)))
     (define artifacts
       #`(D-artifacts
          #:language #, #'decomposition-language
          #:plug-D #, #'plug-D
          #:plug-C #, #'plug-C
          #:contract-label #, #'contract-label
          #:decompose #, #'decompose
          #:contract #, #'contract
          #:step #, #'step))
     (define stage-def
       (stage-definition #'stage-id 'D instance artifacts #f))
     (with-syntax ([(work-redex ...) work-redexes]
                   [(frontier-redex ...) frontier-redexes]
                   [(allocation-redex ...) allocation-redexes]
                   [(label ...) labels]
                   [(contract-rule ...) contract-rules]
                   [source-language source-language]
                   [source-runtime-variable source-runtime-variable]
                   [source-state-view source-state-view]
                   [source-work source-work]
                   [source-frontier source-frontier]
                   [source-settled source-settled]
                   [source-returned-view source-returned-view]
                   [source-failure-view source-failure-view]
                   [terminal-success terminal-success]
                   [terminal-failure terminal-failure]
                   [source-work-focus source-work-focus]
                   [source-spine-context source-spine-context]
                   [(redex-parameter-local ...)
                    (map redex-parameter-info-local redex-parameters)]
                   [(redex-parameter-default ...)
                    (map redex-parameter-info-default redex-parameters)]
                   [(step-contract step-contract-label
                                   step-plug-C step-decompose)
                    (generate-temporaries
                     '(step-contract step-contract-label
                       step-plug-C step-decompose))]
                   [decomposition-language #'decomposition-language]
                   [plug-D #'plug-D]
                   [plug-C #'plug-C]
                   [contract-label #'contract-label]
                   [decompose #'decompose]
                   [contract #'contract]
                   [step #'step]
                   [stage-def stage-def])
       #'(begin
           stage-def
           (define-extended-language decomposition-language
             source-language
             ;; Normalize arbitrary instance-owned carrier names once.  Every
             ;; later generated stage inherits these internal categories.
             [SourceRuntimeVariable source-runtime-variable]
             [SourceState source-state-view]
             [SourceW source-work]
             [SourceF source-frontier]
             [SourceS source-settled]
             [SourceReturnedView source-returned-view]
             [SourceFailureView source-failure-view]
             [SourceTerminalSuccess terminal-success]
             [SourceTerminalFailure terminal-failure]
             [SourceWorkFocus source-work-focus]
             [SourceSpineContext source-spine-context]
             [RuleName label ...]
             [WR work-redex ...]
             [FR frontier-redex ...]
             [AR allocation-redex ...]
             [T SourceTerminalSuccess SourceTerminalFailure]
             [D (Final T)
                (DecWork WR SourceWorkFocus)
                (DecFrontier FR SourceSpineContext)
                (DecAllocate AR SourceWorkFocus)]
             [C (ContractWork RuleName SourceW SourceWorkFocus)
                (ContractFrontier RuleName SourceF SourceSpineContext)])

           (redex-parameter:define-metafunction*
             decomposition-language
             plug-D : D -> SourceF
             [(plug-D (Final T)) T]
             [(plug-D (DecWork WR SourceWorkFocus))
              (in-hole SourceWorkFocus WR)]
             [(plug-D (DecFrontier FR SourceSpineContext))
              (in-hole SourceSpineContext FR)]
             [(plug-D (DecAllocate AR SourceWorkFocus))
              (in-hole SourceWorkFocus AR)])

           (redex-parameter:define-metafunction*
             decomposition-language
             plug-C : C -> SourceF
             [(plug-C (ContractWork RuleName SourceW SourceWorkFocus))
              (in-hole SourceWorkFocus SourceW)]
             [(plug-C (ContractFrontier RuleName SourceF SourceSpineContext))
              (in-hole SourceSpineContext SourceF)])

           (redex-parameter:define-metafunction*
             decomposition-language
             contract-label : C -> RuleName
             [(contract-label (ContractWork RuleName SourceW SourceWorkFocus)) RuleName]
             [(contract-label (ContractFrontier RuleName SourceF SourceSpineContext))
              RuleName])

           (redex-parameter:define-judgment-form*
             decomposition-language
             #:mode (decompose I O)
             #:contract (decompose SourceF D)
             [---- (decompose (in-hole SourceWorkFocus WR)
                              (DecWork WR SourceWorkFocus))]
             [---- (decompose (in-hole SourceSpineContext FR)
                              (DecFrontier FR SourceSpineContext))]
             [---- (decompose (in-hole SourceWorkFocus AR)
                              (DecAllocate AR SourceWorkFocus))]
             [---- (decompose T (Final T))])

           (redex-parameter:define-judgment-form*
             decomposition-language
             #:parameters
             ([redex-parameter-local redex-parameter-default] ...)
             #:mode (contract I O)
             #:contract (contract D C)
             contract-rule ...)

           (redex-parameter:define-judgment-form*
             decomposition-language
             #:parameters
             ([step-contract contract]
              [step-contract-label contract-label]
              [step-plug-C plug-C]
              [step-decompose decompose])
             #:mode (step I O O)
             #:contract (step D RuleName D)
             [(step-contract D_0 C)
              (where RuleName (step-contract-label C))
              (where SourceF_1 (step-plug-C C))
              (step-decompose SourceF_1 D_1)
              ----
              (step D_0 RuleName D_1)])))]))

;; Refocusing retains the decomposed carrier shape but replaces repeated
;; plug/decompose with the instance's declared frame/root algebra.  No source
;; constructors occur in this renderer: Frame, RootFocus, Settled, DeadW, and
;; OpenW are all instance-owned grammar partitions.
(define-syntax (define-selected-refocused-stage stx)
  (syntax-parse stx
    [(_ stage-id:id
        #:from decomposition-stage-id:id
        #:language refocused-language:id
        #:refocus-phase refocus-phase:id
        #:D->Z D->Z:id
        #:Z->D Z->D:id
        #:readback readback:id
        #:refocus-spec refocus-spec:id
        #:refocus-work-direct refocus-work-direct:id
        #:refocus-direct refocus-direct:id
        #:step-spec step-spec:id
        #:step-direct step-direct:id)
     (define decomposition-stage
       (lookup-stage #'decomposition-stage-id 'D))
     (define instance (lookup-instance #'decomposition-stage-id))
     (define D-artifacts
       (stage-binding-artifact-declaration decomposition-stage))
     (define-values
       (decomposition-language plug-C decompose contract contract-label)
       (syntax-parse D-artifacts
         [((~datum D-artifacts)
           #:language language:id
           #:plug-D _plug-D:id
           #:plug-C plug-C:id
           #:contract-label contract-label:id
           #:decompose decompose:id
           #:contract contract:id
           #:step _step:id)
          (values #'language
                  #'plug-C
                  #'decompose
                  #'contract
                  #'contract-label)]))
     (define run-productions (instance-info-run-productions instance))
     (define redex-parameters (instance-info-redex-parameters instance))
     (define root-focus (instance-info-root-focus instance))
     (define root-spine (instance-info-root-spine instance))
     (define frames (instance-info-frames instance))
     (define open-work-productions
       (instance-info-open-work-productions instance))
     (define frame-categories
       (if (null? frames)
           '()
           (list #`[Frame #,@frames])))
     (define artifacts
       #`(Z-artifacts
          #:language #, #'refocused-language
          #:refocus-phase #, #'refocus-phase
          #:D->Z #, #'D->Z
          #:Z->D #, #'Z->D
          #:readback #, #'readback
          #:refocus-spec #, #'refocus-spec
          #:refocus-work-direct #, #'refocus-work-direct
          #:refocus-direct #, #'refocus-direct
          #:step-spec #, #'step-spec
          #:step-direct #, #'step-direct
          #:D-language #,decomposition-language
          #:decompose #,decompose
          #:contract #,contract
          #:contract-label #,contract-label))
     (define stage-def
       (stage-definition #'stage-id 'Z instance artifacts #f))
     (define refocus-forms
       (render-retained-context-refocuser
        #'refocused-language
        #'Z
        #'refocus-work-direct
        #'refocus-direct
        #'ZFinal
        #'ZWork
        #'ZFrontier
        #'ZAllocate
        root-spine
        frames))
     (define step-refocus-work
       (generate-temporary 'step-refocus-work))
     (define native-step-clauses
       (for/list ([rule (in-list (instance-info-rules instance))])
         (render-native-step-rule
          rule
          #'Z
          #'ZWork
          #'ZFrontier
          #'ZAllocate
          #'ZFinal
          root-focus
          step-refocus-work
          #'step-direct)))
     (with-syntax ([(run-production ...) run-productions]
                   [(frame ...) frames]
                   [(frame-category ...) frame-categories]
                   [(open-work-production ...) open-work-productions]
                   [root-focus root-focus]
                   [root-spine root-spine]
                   [(redex-parameter-local ...)
                    (map redex-parameter-info-local redex-parameters)]
                   [(redex-parameter-default ...)
                    (map redex-parameter-info-default redex-parameters)]
                   [decomposition-language decomposition-language]
                   [plug-C plug-C]
                   [decompose decompose]
                   [contract contract]
                   [contract-label contract-label]
                   [refocused-language #'refocused-language]
                   [refocus-phase #'refocus-phase]
                   [D->Z #'D->Z]
                   [Z->D #'Z->D]
                   [readback #'readback]
                   [refocus-spec #'refocus-spec]
                   [refocus-work-direct #'refocus-work-direct]
                   [refocus-direct #'refocus-direct]
                   [step-spec #'step-spec]
                   [step-direct #'step-direct]
                   [step-refocus-work step-refocus-work]
                   [(refocus-form ...) refocus-forms]
                   [(native-step-clause ...) native-step-clauses]
                   [stage-def stage-def])
       #'(begin
           stage-def
           (define-extended-language refocused-language
             decomposition-language
             [RunW run-production ...]
             [Settled SourceReturnedView]
             [DeadW SourceFailureView]
             frame-category ...
             [RootFocus root-focus]
             [OpenW WR AR open-work-production ...]
             [Z (ZFinal T)
                (ZWork WR SourceWorkFocus)
                (ZFrontier FR SourceSpineContext)
                (ZAllocate AR SourceWorkFocus)])

           (redex-parameter:define-metafunction*
             refocused-language
             refocus-phase : D -> Z
             [(refocus-phase (Final T)) (ZFinal T)]
             [(refocus-phase (DecWork WR SourceWorkFocus))
              (ZWork WR SourceWorkFocus)]
             [(refocus-phase (DecFrontier FR SourceSpineContext))
              (ZFrontier FR SourceSpineContext)]
             [(refocus-phase (DecAllocate AR SourceWorkFocus))
              (ZAllocate AR SourceWorkFocus)])

           ;; D/Z conversion is retained as a secondary diagnostic.  The
           ;; phase transformation used by commuting laws is `refocus-phase`.
           (define-metafunction refocused-language
             D->Z : D -> Z
             [(D->Z (Final T)) (ZFinal T)]
             [(D->Z (DecWork WR SourceWorkFocus))
              (ZWork WR SourceWorkFocus)]
             [(D->Z (DecFrontier FR SourceSpineContext))
              (ZFrontier FR SourceSpineContext)]
             [(D->Z (DecAllocate AR SourceWorkFocus))
              (ZAllocate AR SourceWorkFocus)])

           (define-metafunction refocused-language
             Z->D : Z -> D
             [(Z->D (ZFinal T)) (Final T)]
             [(Z->D (ZWork WR SourceWorkFocus))
              (DecWork WR SourceWorkFocus)]
             [(Z->D (ZFrontier FR SourceSpineContext))
              (DecFrontier FR SourceSpineContext)]
             [(Z->D (ZAllocate AR SourceWorkFocus))
              (DecAllocate AR SourceWorkFocus)])

           (define-metafunction refocused-language
             readback : Z -> SourceF
             [(readback (ZFinal T)) T]
             [(readback (ZWork WR SourceWorkFocus))
              (in-hole SourceWorkFocus WR)]
             [(readback (ZFrontier FR SourceSpineContext))
              (in-hole SourceSpineContext FR)]
             [(readback (ZAllocate AR SourceWorkFocus))
              (in-hole SourceWorkFocus AR)])

           (define-judgment-form
             refocused-language
             #:contract (refocus-spec C Z)
             #:mode (refocus-spec I O)
             [(where SourceF_0 (plug-C C))
              (decompose SourceF_0 D_0)
              (where Z_0 (D->Z D_0))
              ----
              (refocus-spec C Z_0)])

           refocus-form ...

           (define-judgment-form
             refocused-language
             #:contract (step-spec Z RuleName Z)
             #:mode (step-spec I O O)
             [(where D_0 (Z->D Z_0))
              (contract D_0 C_0)
              (where RuleName (contract-label C_0))
              (refocus-spec C_0 Z_1)
              ----
              (step-spec Z_0 RuleName Z_1)])

           (redex-parameter:define-judgment-form*
             refocused-language
             #:parameters
             ([redex-parameter-local redex-parameter-default] ...
              [step-refocus-work refocus-work-direct])
             #:mode (step-direct I O O)
             #:contract (step-direct Z RuleName Z)
             native-step-clause ...)))]))

(define-syntax (define-selected-machine-isomorphism-stage stx)
  (syntax-parse stx
    [(_ stage-id:id
        #:from refocused-stage-id:id
        #:language machine-language:id
        #:machineize machineize:id
        #:encode-ZM encode-ZM:id
        #:decode-MZ decode-MZ:id
        #:D->M D->M:id
        #:M->D M->D:id
        #:readback readback:id
        #:refocus-work-direct refocus-work-direct:id
        #:refocus-direct refocus-direct:id
        #:step-direct step-direct:id
        #:corresponds corresponds:id
        #:step-spec step-spec:id
        #:square square:id)
     (define refocused-stage
       (lookup-stage #'refocused-stage-id 'Z))
     (define instance (lookup-instance #'refocused-stage-id))
     (define Z-artifacts
       (stage-binding-artifact-declaration refocused-stage))
     (define-values
       (refocused-language refocus-phase D->Z Z->D Z-step-direct
                           decomposition-language decompose
                           contract contract-label)
       (syntax-parse Z-artifacts
         [((~datum Z-artifacts)
           #:language language:id
           #:refocus-phase refocus-phase:id
           #:D->Z D->Z:id
           #:Z->D Z->D:id
           #:readback _readback:id
           #:refocus-spec _refocus-spec:id
           #:refocus-work-direct _refocus-work-direct:id
           #:refocus-direct _refocus-direct:id
           #:step-spec _step-spec:id
           #:step-direct Z-step-direct:id
           #:D-language D-language:id
           #:decompose decompose:id
           #:contract contract:id
           #:contract-label contract-label:id)
          (values #'language
                  #'refocus-phase
                  #'D->Z
                  #'Z->D
                  #'Z-step-direct
                  #'D-language
                  #'decompose
                  #'contract
                  #'contract-label)]))
     (define root-spine (instance-info-root-spine instance))
     (define root-focus (instance-info-root-focus instance))
     (define frames (instance-info-frames instance))
     (define redex-parameters (instance-info-redex-parameters instance))
     (define artifacts
       #`(M-artifacts
          #:language #, #'machine-language
          #:machineize #, #'machineize
          #:encode-ZM #, #'encode-ZM
          #:decode-MZ #, #'decode-MZ
          #:D->M #, #'D->M
          #:M->D #, #'M->D
          #:readback #, #'readback
          #:refocus-work-direct #, #'refocus-work-direct
          #:refocus-direct #, #'refocus-direct
          #:step-direct #, #'step-direct
          #:corresponds #, #'corresponds
          #:step-spec #, #'step-spec
          #:square #, #'square
          #:Z-language #,refocused-language
          #:Z-step-direct #,Z-step-direct
          #:D-language #,decomposition-language
          #:refocus-phase #,refocus-phase
          #:D->Z #,D->Z
          #:decompose #,decompose
          #:contract #,contract
          #:contract-label #,contract-label))
     (define stage-def
       (stage-definition #'stage-id 'M instance artifacts #f))
     (define refocus-forms
       (render-retained-context-refocuser
        #'machine-language
        #'M
        #'refocus-work-direct
        #'refocus-direct
        #'MFinal
        #'MWork
        #'MFrontier
        #'MAllocate
        root-spine
        frames))
     (define step-refocus-work
       (generate-temporary 'step-refocus-work))
     (define native-step-clauses
       (for/list ([rule (in-list (instance-info-rules instance))])
         (render-native-step-rule
          rule
          #'M
          #'MWork
          #'MFrontier
          #'MAllocate
          #'MFinal
          root-focus
          step-refocus-work
          #'step-direct)))
     (with-syntax ([refocused-language refocused-language]
                   [Z->D Z->D]
                   [Z-step-direct Z-step-direct]
                   [decompose decompose]
                   [contract contract]
                   [contract-label contract-label]
                   [machine-language #'machine-language]
                   [(redex-parameter-local ...)
                    (map redex-parameter-info-local redex-parameters)]
                   [(redex-parameter-default ...)
                    (map redex-parameter-info-default redex-parameters)]
                   [machineize #'machineize]
                   [encode-ZM #'encode-ZM]
                   [decode-MZ #'decode-MZ]
                   [D->M #'D->M]
                   [M->D #'M->D]
                   [readback #'readback]
                   [refocus-work-direct #'refocus-work-direct]
                   [refocus-direct #'refocus-direct]
                   [step-direct #'step-direct]
                   [step-refocus-work step-refocus-work]
                   [corresponds #'corresponds]
                   [step-spec #'step-spec]
                   [square #'square]
                   [(refocus-form ...) refocus-forms]
                   [(native-step-clause ...) native-step-clauses]
                   [stage-def stage-def])
       #'(begin
           stage-def
           (define-extended-language machine-language
             refocused-language
             [M (MFinal T)
                (MWork WR SourceWorkFocus)
                (MFrontier FR SourceSpineContext)
                (MAllocate AR SourceWorkFocus)])

           (redex-parameter:define-metafunction*
             machine-language
             machineize : Z -> M
             [(machineize (ZFinal T)) (MFinal T)]
             [(machineize (ZWork WR SourceWorkFocus))
              (MWork WR SourceWorkFocus)]
             [(machineize (ZFrontier FR SourceSpineContext))
              (MFrontier FR SourceSpineContext)]
             [(machineize (ZAllocate AR SourceWorkFocus))
              (MAllocate AR SourceWorkFocus)])

           ;; The explicit Z/M carrier isomorphism is retained separately as
           ;; a diagnostic.  `machineize` above is the phase transformation.
           (define-metafunction machine-language
             encode-ZM : Z -> M
             [(encode-ZM (ZFinal T)) (MFinal T)]
             [(encode-ZM (ZWork WR SourceWorkFocus))
              (MWork WR SourceWorkFocus)]
             [(encode-ZM (ZFrontier FR SourceSpineContext))
              (MFrontier FR SourceSpineContext)]
             [(encode-ZM (ZAllocate AR SourceWorkFocus))
              (MAllocate AR SourceWorkFocus)])

           (define-metafunction machine-language
             decode-MZ : M -> Z
             [(decode-MZ (MFinal T)) (ZFinal T)]
             [(decode-MZ (MWork WR SourceWorkFocus))
              (ZWork WR SourceWorkFocus)]
             [(decode-MZ (MFrontier FR SourceSpineContext))
              (ZFrontier FR SourceSpineContext)]
             [(decode-MZ (MAllocate AR SourceWorkFocus))
              (ZAllocate AR SourceWorkFocus)])

           (define-metafunction machine-language
             D->M : D -> M
             [(D->M (Final T)) (MFinal T)]
             [(D->M (DecWork WR SourceWorkFocus))
              (MWork WR SourceWorkFocus)]
             [(D->M (DecFrontier FR SourceSpineContext))
              (MFrontier FR SourceSpineContext)]
             [(D->M (DecAllocate AR SourceWorkFocus))
              (MAllocate AR SourceWorkFocus)])

           (define-metafunction machine-language
             M->D : M -> D
             [(M->D (MFinal T)) (Final T)]
             [(M->D (MWork WR SourceWorkFocus))
              (DecWork WR SourceWorkFocus)]
             [(M->D (MFrontier FR SourceSpineContext))
              (DecFrontier FR SourceSpineContext)]
             [(M->D (MAllocate AR SourceWorkFocus))
              (DecAllocate AR SourceWorkFocus)])

           (define-metafunction machine-language
             readback : M -> SourceF
             [(readback (MFinal T)) T]
             [(readback (MWork WR SourceWorkFocus))
              (in-hole SourceWorkFocus WR)]
             [(readback (MFrontier FR SourceSpineContext))
              (in-hole SourceSpineContext FR)]
             [(readback (MAllocate AR SourceWorkFocus))
              (in-hole SourceWorkFocus AR)])

           refocus-form ...

           (redex-parameter:define-judgment-form*
             machine-language
             #:parameters
             ([redex-parameter-local redex-parameter-default] ...
              [step-refocus-work refocus-work-direct])
             #:mode (step-direct I O O)
             #:contract (step-direct M RuleName M)
             native-step-clause ...)

           (define-judgment-form
             machine-language
             #:contract (corresponds Z M)
             #:mode (corresponds I O)
             [(where M_0 (encode-ZM Z_0))
              ----
              (corresponds Z_0 M_0)])

           (define-judgment-form
             machine-language
             #:contract (step-spec M RuleName M)
             #:mode (step-spec I O O)
             [(where Z_0 (decode-MZ M_0))
              (Z-step-direct Z_0 RuleName Z_1)
              (where M_1 (encode-ZM Z_1))
              ----
              (step-spec M_0 RuleName M_1)])

           (define-judgment-form
             machine-language
             #:contract (square Z RuleName Z M M)
             #:mode (square I O O O O)
             [(where M_0 (encode-ZM Z_0))
              (Z-step-direct Z_0 RuleName Z_1)
              (where M_1 (encode-ZM Z_1))
              (step-direct M_0 RuleName M_1)
              ----
              (square Z_0 RuleName Z_1 M_0 M_1)])))]))

(define-syntax (define-selected-compressed-stage stx)
  (syntax-parse stx
    [(_ stage-id:id
        #:from machine-stage-id:id
        #:policy policy-id:id
        #:language compressed-language:id
        #:compress compress:id
        #:encode-MB encode-MB:id
        #:decode-BM decode-BM:id
        #:readback readback:id
        #:span-labels span-labels:id
        #:produce-settled produce-settled:id
        #:produce-dead produce-dead:id
        #:advance-settled advance-settled:id
        #:advance-dead advance-dead:id
        #:step-direct step-direct:id
        #:corresponds corresponds:id
        #:replay replay:id
        #:step-spec step-spec:id
        #:square square:id)
     (define machine-stage (lookup-stage #'machine-stage-id 'M))
     (define instance (lookup-instance #'machine-stage-id))
     (define policy (lookup-policy #'policy-id))
     (define M-artifacts
       (stage-binding-artifact-declaration machine-stage))
     (define-values
       (machine-language machine-step-direct machineize
                         refocus-phase D->Z D->M decompose)
       (syntax-parse M-artifacts
         [((~datum M-artifacts)
           #:language language:id
           #:machineize machineize:id
           #:encode-ZM _encode-ZM:id
           #:decode-MZ _decode-MZ:id
           #:D->M D->M:id
           #:M->D _M->D:id
           #:readback _readback:id
           #:refocus-work-direct _refocus-work-direct:id
           #:refocus-direct _refocus-direct:id
           #:step-direct machine-step-direct:id
           #:corresponds _corresponds:id
           #:step-spec _step-spec:id
           #:square _square:id
           #:Z-language _Z-language:id
           #:Z-step-direct _Z-step-direct:id
           #:D-language _D-language:id
           #:refocus-phase refocus-phase:id
           #:D->Z D->Z:id
           #:decompose decompose:id
           #:contract _contract:id
           #:contract-label _contract-label:id)
          (values #'language
                  #'machine-step-direct
                  #'machineize
                  #'refocus-phase
                  #'D->Z
                  #'D->M
                  #'decompose)]))
     (define settled-producers
       (rules-for-labels
        instance
        (policy-info-settled-producers policy)
        "settled producer policy"))
     (define dead-producers
       (rules-for-labels
        instance
        (policy-info-dead-producers policy)
        "dead producer policy"))
     (define settled-followers
       (rules-for-labels
        instance
        (policy-info-settled-followers policy)
        "settled follower policy"))
     (define dead-followers
       (rules-for-labels
        instance
        (policy-info-dead-followers policy)
        "dead follower policy"))
     (define singleton-rules
       (rules-for-labels
        instance
        (policy-info-singletons policy)
        "singleton policy"))
     (define follower-labels
       (map label-symbol
            (append (policy-info-settled-followers policy)
                    (policy-info-dead-followers policy))))
     (define singleton-run-rules
       (filter
        (lambda (rule)
          (not (memq (label-symbol (rule-info-label rule)) follower-labels)))
        singleton-rules))
     (define base-singleton
       (format-id #'step-direct
                  "~a/base-singleton"
                  (syntax-e #'step-direct)))
     (define classified-labels
       (map label-symbol
            (append (policy-info-settled-producers policy)
                    (policy-info-dead-producers policy)
                    (policy-info-singletons policy))))
     (define instance-labels
       (map (lambda (rule) (label-symbol (rule-info-label rule)))
            (instance-info-rules instance)))
     (unless (equal? (sort classified-labels symbol<?)
                     (sort instance-labels symbol<?))
       (raise-syntax-error
        #f
        "compression policy must classify every semantic rule exactly"
        stx))
     (define root-spine (instance-info-root-spine instance))
     (define root-focus (instance-info-root-focus instance))
     (define frames (instance-info-frames instance))
     (define root-work-focus
       (compose-context root-spine root-focus))
     (define settled-producer-clauses
       (map (lambda (rule)
              (render-producer-rule rule #'produce-settled 'settled))
            settled-producers))
     (define dead-producer-clauses
       (map (lambda (rule)
              (render-producer-rule rule #'produce-dead 'failed))
            dead-producers))
     (define settled-follower-clauses
       (map (lambda (rule)
              (render-advance-rule
               rule
               #'advance-settled
               '(pop-settled root-settled)
               root-focus))
            settled-followers))
     (define dead-follower-clauses
       (map (lambda (rule)
              (render-advance-rule
               rule
               #'advance-dead
               '(pop-failed root-failed)
               root-focus))
            dead-followers))
     (define singleton-run-clauses
       (map (lambda (rule)
              (render-singleton-run-rule rule base-singleton))
            singleton-run-rules))
     (define settled-producer-labels
       (policy-info-settled-producers policy))
     (define dead-producer-labels
       (policy-info-dead-producers policy))
     (define settled-follower-labels
       (policy-info-settled-followers policy))
     (define dead-follower-labels
       (policy-info-dead-followers policy))
     (define singleton-labels (policy-info-singletons policy))
     (define nonallocation-run-productions
       (instance-info-nonallocation-run-productions instance))
     (define redex-parameters (instance-info-redex-parameters instance))
     (define failure-summary (instance-info-failure-summary instance))
     (define failure-term (instance-info-failure-term instance))
     (define compress-frame-clauses
       (if (null? frames)
           '()
           (list
            #`[(#,#'compress
                (MWork (in-hole Frame Settled) SourceWorkFocus))
               (BSettled Settled (in-hole SourceWorkFocus Frame))]
            #`[(#,#'compress
                (MWork (in-hole Frame #,failure-term) SourceWorkFocus))
               (BDead #,failure-summary
                      (in-hole SourceWorkFocus Frame))])))
     (define encode-frame-clauses
       (if (null? frames)
           '()
           (list
            #`[(#,#'encode-MB
                (MWork (in-hole Frame Settled) SourceWorkFocus))
               (BSettled Settled (in-hole SourceWorkFocus Frame))]
            #`[(#,#'encode-MB
                (MWork (in-hole Frame #,failure-term) SourceWorkFocus))
               (BDead #,failure-summary
                      (in-hole SourceWorkFocus Frame))])))
     (define decode-frame-clauses
       (if (null? frames)
           '()
           (list
            #`[(#,#'decode-BM
                (BSettled Settled
                          (in-hole SourceWorkFocus Frame)))
               (MWork (in-hole Frame Settled) SourceWorkFocus)]
            #`[(#,#'decode-BM
                (BDead #,failure-summary
                       (in-hole SourceWorkFocus Frame)))
               (MWork (in-hole Frame #,failure-term)
                      SourceWorkFocus)])))
     (define artifacts
       #`(B-artifacts
          #:language #, #'compressed-language
          #:compress #, #'compress
          #:encode-MB #, #'encode-MB
          #:decode-BM #, #'decode-BM
          #:readback #, #'readback
          #:span-labels #, #'span-labels
          #:produce-settled #, #'produce-settled
          #:produce-dead #, #'produce-dead
          #:advance-settled #, #'advance-settled
          #:advance-dead #, #'advance-dead
          #:base-singleton #,base-singleton
          #:step-direct #, #'step-direct
          #:replay #, #'replay
          #:step-spec #, #'step-spec
          #:square #, #'square
          #:M-language #,machine-language
          #:M-step-direct #,machine-step-direct
          #:machineize #,machineize
          #:refocus-phase #,refocus-phase
          #:D->Z #,D->Z
          #:D->M #,D->M
          #:decompose #,decompose))
     (define stage-def
       (stage-definition #'stage-id 'B instance artifacts policy))
     (with-syntax ([machine-language machine-language]
                   [machine-step-direct machine-step-direct]
                   [compressed-language #'compressed-language]
                   [compress #'compress]
                   [encode-MB #'encode-MB]
                   [decode-BM #'decode-BM]
                   [readback #'readback]
                   [span-labels #'span-labels]
                   [produce-settled #'produce-settled]
                   [produce-dead #'produce-dead]
                   [advance-settled #'advance-settled]
                   [advance-dead #'advance-dead]
                   [base-singleton base-singleton]
                   [step-direct #'step-direct]
                   [corresponds #'corresponds]
                   [replay #'replay]
                   [step-spec #'step-spec]
                   [square #'square]
                   [failure-summary failure-summary]
                   [failure-term failure-term]
                   [root-spine root-spine]
                   [root-focus root-focus]
                   [root-work-focus root-work-focus]
                   [(redex-parameter-local ...)
                    (map redex-parameter-info-local redex-parameters)]
                   [(redex-parameter-default ...)
                    (map redex-parameter-info-default redex-parameters)]
                   [(singleton-advance-settled singleton-advance-dead
                                                step-produce-settled
                                                step-produce-dead
                                                step-base-advance-settled
                                                step-base-advance-dead
                                                step-singleton)
                    (generate-temporaries
                     '(singleton-advance-settled singleton-advance-dead
                       step-produce-settled step-produce-dead
                       step-base-advance-settled step-base-advance-dead
                       step-singleton))]
                   [(nonallocation-run-production ...)
                    nonallocation-run-productions]
                   [(settled-producer-label ...) settled-producer-labels]
                   [(dead-producer-label ...) dead-producer-labels]
                   [(settled-follower-label ...) settled-follower-labels]
                   [(dead-follower-label ...) dead-follower-labels]
                   [(singleton-label ...) singleton-labels]
                   [(settled-producer-clause ...) settled-producer-clauses]
                   [(dead-producer-clause ...) dead-producer-clauses]
                   [(settled-follower-clause ...) settled-follower-clauses]
                   [(dead-follower-clause ...) dead-follower-clauses]
                   [(singleton-run-clause ...) singleton-run-clauses]
                   [(compress-frame-clause ...) compress-frame-clauses]
                   [(encode-frame-clause ...) encode-frame-clauses]
                   [(decode-frame-clause ...) decode-frame-clauses]
                   [stage-def stage-def])
       #'(begin
           stage-def
           (define-extended-language compressed-language
             machine-language
             [FailureSummary failure-summary]
             [NonAllocateRun nonallocation-run-production ...]
             [SettledProducerName settled-producer-label ...]
             [DeadProducerName dead-producer-label ...]
             [SettledFollowerName settled-follower-label ...]
             [DeadFollowerName dead-follower-label ...]
             [SingletonRuleName singleton-label ...]
             [LabelTrace (RuleName (... ...))]
             [B (BRun NonAllocateRun SourceWorkFocus)
                (BRun AR SourceWorkFocus)
                (BSettled Settled SourceWorkFocus)
                (BDead FailureSummary SourceWorkFocus)
                (BFinal T)]
             [TransitionSpan
              (transition-span RuleName)
              (transition-span RuleName RuleName)])

           (redex-parameter:define-metafunction*
             compressed-language
             compress : M -> B
             [(compress (MFinal T)) (BFinal T)]
             [(compress (MAllocate AR SourceWorkFocus))
              (BRun AR SourceWorkFocus)]
             [(compress (MWork NonAllocateRun SourceWorkFocus))
              (BRun NonAllocateRun SourceWorkFocus)]
             compress-frame-clause ...
             [(compress
               (MFrontier (in-hole root-focus Settled) root-spine))
              (BSettled Settled root-work-focus)]
             [(compress
               (MFrontier (in-hole root-focus failure-term) root-spine))
              (BDead failure-summary root-work-focus)])

           ;; The M/B codec is diagnostic; `compress` is the phase transform.
           (define-metafunction compressed-language
             encode-MB : M -> B
             [(encode-MB (MFinal T)) (BFinal T)]
             [(encode-MB (MAllocate AR SourceWorkFocus))
              (BRun AR SourceWorkFocus)]
             [(encode-MB (MWork NonAllocateRun SourceWorkFocus))
              (BRun NonAllocateRun SourceWorkFocus)]
             encode-frame-clause ...
             [(encode-MB
               (MFrontier (in-hole root-focus Settled) root-spine))
              (BSettled Settled root-work-focus)]
             [(encode-MB
               (MFrontier (in-hole root-focus failure-term) root-spine))
              (BDead failure-summary root-work-focus)])

           (define-metafunction compressed-language
             decode-BM : B -> M
             [(decode-BM (BFinal T)) (MFinal T)]
             [(decode-BM (BRun AR SourceWorkFocus))
              (MAllocate AR SourceWorkFocus)]
             [(decode-BM (BRun NonAllocateRun SourceWorkFocus))
              (MWork NonAllocateRun SourceWorkFocus)]
             decode-frame-clause ...
             [(decode-BM (BSettled Settled root-work-focus))
              (MFrontier
               (in-hole root-focus Settled)
               root-spine)]
             [(decode-BM
               (BDead failure-summary root-work-focus))
              (MFrontier
               (in-hole root-focus failure-term)
               root-spine)])

           (define-metafunction compressed-language
             readback : B -> SourceF
             [(readback (BRun NonAllocateRun SourceWorkFocus))
              (in-hole SourceWorkFocus NonAllocateRun)]
             [(readback (BRun AR SourceWorkFocus))
              (in-hole SourceWorkFocus AR)]
             [(readback (BSettled Settled SourceWorkFocus))
              (in-hole SourceWorkFocus Settled)]
             [(readback (BDead failure-summary SourceWorkFocus))
              (in-hole SourceWorkFocus failure-term)]
             [(readback (BFinal T)) T])

           (redex-parameter:define-metafunction*
             compressed-language
             span-labels : TransitionSpan -> LabelTrace
             [(span-labels (transition-span RuleName_0))
              (RuleName_0)]
             [(span-labels
               (transition-span RuleName_0 RuleName_1))
              (RuleName_0 RuleName_1)])

           (redex-parameter:define-judgment-form*
             compressed-language
             #:parameters
             ([redex-parameter-local redex-parameter-default] ...)
             #:mode (produce-settled I I O O O)
             #:contract
             (produce-settled
              SourceW SourceWorkFocus SettledProducerName Settled SourceWorkFocus)
             settled-producer-clause ...)

           (redex-parameter:define-judgment-form*
             compressed-language
             #:parameters
             ([redex-parameter-local redex-parameter-default] ...)
             #:mode (produce-dead I I O O O)
             #:contract
             (produce-dead
              SourceW SourceWorkFocus DeadProducerName FailureSummary SourceWorkFocus)
             dead-producer-clause ...)

           (redex-parameter:define-judgment-form*
             compressed-language
             #:parameters
             ([redex-parameter-local redex-parameter-default] ...)
             #:mode (advance-settled I I O O)
             #:contract
             (advance-settled
              Settled SourceWorkFocus SettledFollowerName B)
             settled-follower-clause ...)

           (redex-parameter:define-judgment-form*
             compressed-language
             #:parameters
             ([redex-parameter-local redex-parameter-default] ...)
             #:mode (advance-dead I I O O)
             #:contract
             (advance-dead FailureSummary SourceWorkFocus DeadFollowerName B)
             dead-follower-clause ...)

           (redex-parameter:define-judgment-form*
             compressed-language
             #:parameters
             ([redex-parameter-local redex-parameter-default] ...
              [singleton-advance-settled advance-settled]
              [singleton-advance-dead advance-dead])
             #:mode (base-singleton I O O)
             #:contract (base-singleton B TransitionSpan B)
             singleton-run-clause ...
             [(singleton-advance-settled
               Settled SourceWorkFocus SettledFollowerName B_1)
              ----
              (base-singleton
               (BSettled Settled SourceWorkFocus)
               (transition-span SettledFollowerName)
               B_1)]
             [(singleton-advance-dead
               FailureSummary SourceWorkFocus DeadFollowerName B_1)
              ----
              (base-singleton
               (BDead FailureSummary SourceWorkFocus)
               (transition-span DeadFollowerName)
               B_1)])

           (redex-parameter:define-judgment-form*
             compressed-language
             #:parameters
             ([step-produce-settled produce-settled]
              [step-produce-dead produce-dead]
              [step-base-advance-settled advance-settled]
              [step-base-advance-dead advance-dead]
              [step-singleton base-singleton])
             #:mode (step-direct I O O)
             #:contract (step-direct B TransitionSpan B)
             [(step-singleton B_0 TransitionSpan_0 B_1)
              ----
              (step-direct
               B_0
               TransitionSpan_0
               B_1)]
             [(step-produce-settled
               SourceW SourceWorkFocus_0
               SettledProducerName Settled SourceWorkFocus_1)
              (step-base-advance-settled
               Settled SourceWorkFocus_1 SettledFollowerName B_1)
              ----
              (step-direct
               (BRun SourceW SourceWorkFocus_0)
               (transition-span
                SettledProducerName SettledFollowerName)
               B_1)]
             [(step-produce-dead
               SourceW SourceWorkFocus_0 DeadProducerName FailureSummary SourceWorkFocus_1)
              (step-base-advance-dead
               FailureSummary SourceWorkFocus_1 DeadFollowerName B_1)
              ----
              (step-direct
               (BRun SourceW SourceWorkFocus_0)
               (transition-span
                DeadProducerName DeadFollowerName)
               B_1)])

           (define-judgment-form
             compressed-language
             #:contract (corresponds M B)
             #:mode (corresponds I O)
             [(where B_0 (compress M_0))
              ----
              (corresponds M_0 B_0)])

           (define-judgment-form
             compressed-language
             #:contract (replay M TransitionSpan M)
             #:mode (replay I O O)
             [(machine-step-direct
               M_0 SingletonRuleName M_1)
              ----
              (replay
               M_0
               (transition-span SingletonRuleName)
               M_1)]
             [(machine-step-direct
               M_0 SettledProducerName M_1)
              (machine-step-direct
               M_1 SettledFollowerName M_2)
              ----
              (replay
               M_0
               (transition-span
                SettledProducerName SettledFollowerName)
               M_2)]
             [(machine-step-direct
               M_0 DeadProducerName M_1)
              (machine-step-direct
               M_1 DeadFollowerName M_2)
              ----
              (replay
               M_0
               (transition-span
                DeadProducerName DeadFollowerName)
               M_2)])

           (define-judgment-form
             compressed-language
             #:contract (step-spec B TransitionSpan B)
             #:mode (step-spec I O O)
             [(where M_0 (decode-BM B_0))
              (replay M_0 TransitionSpan M_1)
              (where B_1 (encode-MB M_1))
              ----
              (step-spec B_0 TransitionSpan B_1)])

           (define-judgment-form
             compressed-language
             #:contract (square B TransitionSpan B M M)
             #:mode (square I O O O O)
             [(where M_0 (decode-BM B_0))
              (replay M_0 TransitionSpan M_1)
              (where B_1 (encode-MB M_1))
              (step-direct B_0 TransitionSpan B_1)
              ----
              (square B_0 TransitionSpan B_1 M_0 M_1)])))]))

(define-syntax (define-selected-fixed-point-stage stx)
  (syntax-parse stx
    [(_ stage-id:id
        #:from compressed-stage-id:id
        #:language big-language:id
        #:readback readback:id
        #:dispatch dispatch:id
        #:run run:id
        #:settled settled-entry:id
        #:dead dead-entry:id
        #:final final-entry:id
        #:evaluate evaluate:id
        #:spec-language spec-language:id
        #:initialize initialize:id
        #:close close:id
        #:flatten flatten:id
        #:promote promote:id
        #:evaluate-spec evaluate-spec:id
        #:unfold-square unfold-square:id
        #:closure-square closure-square:id
        #:root-square root-square:id)
     (define compressed-stage
       (lookup-stage #'compressed-stage-id 'B))
     (define instance (lookup-instance #'compressed-stage-id))
     (define B-artifacts
       (stage-binding-artifact-declaration compressed-stage))
     (define-values
       (compressed-language compress encode-MB span-labels B-step-direct
                            machineize refocus-phase D->Z D->M decompose)
       (syntax-parse B-artifacts
         [((~datum B-artifacts)
           #:language language:id
           #:compress compress:id
           #:encode-MB encode-MB:id
           #:decode-BM _decode-BM:id
           #:readback _readback:id
           #:span-labels span-labels:id
           #:produce-settled _produce-settled:id
           #:produce-dead _produce-dead:id
           #:advance-settled _advance-settled:id
           #:advance-dead _advance-dead:id
           #:base-singleton _base-singleton:id
           #:step-direct step-direct:id
           #:replay _replay:id
           #:step-spec _step-spec:id
           #:square _square:id
           #:M-language _M-language:id
           #:M-step-direct _M-step-direct:id
           #:machineize machineize:id
           #:refocus-phase refocus-phase:id
           #:D->Z D->Z:id
           #:D->M D->M:id
           #:decompose decompose:id)
          (values #'language
                  #'compress
                  #'encode-MB
                  #'span-labels
                  #'step-direct
                  #'machineize
                  #'refocus-phase
                  #'D->Z
                  #'D->M
                  #'decompose)]))
     (define source-language (instance-info-source-language instance))
     (define source-runtime-variable
       (instance-info-runtime-variable instance))
     (define source-state-view (instance-info-state-view instance))
     (define source-work (instance-info-work instance))
     (define source-frontier (instance-info-frontier instance))
     (define source-settled (instance-info-returned instance))
     (define source-returned-view
       (instance-info-returned-view instance))
     (define source-work-focus (instance-info-work-focus instance))
     (define source-spine-context (instance-info-spine-context instance))
     (define redex-parameters (instance-info-redex-parameters instance))
     (define run-productions (instance-info-run-productions instance))
     (define failure-summary (instance-info-failure-summary instance))
     (define failure-term (instance-info-failure-term instance))
     (define terminal-success
       (instance-info-terminal-success instance))
     (define terminal-failure
       (instance-info-terminal-failure instance))
     (define root-focus (instance-info-root-focus instance))
     (define root-work-focus
       (compose-context
        (instance-info-root-spine instance)
        root-focus))
     (define frames (instance-info-frames instance))
     (define dispatch-one
       (format-id #'dispatch
                  "~a/one"
                  (syntax-e #'dispatch)))
     (define frame-categories
       (if (null? frames)
           '()
           (list #`[Frame #,@frames])))
     (define dispatch-one-descent-clauses
       (if (null? frames)
           '()
           (list
            #`[----
               (#,dispatch-one
                (in-hole Frame SourceW_0)
                SourceWorkFocus
                (BigContinue
                 SourceW_0
                 (in-hole SourceWorkFocus Frame)))])))
     (define big-rules
       (map (lambda (rule)
              (render-big-rule
               rule dispatch-one root-focus))
            (instance-info-rules instance)))
     (define artifacts
       #`(Big-artifacts
          #:language #, #'big-language
          #:readback #, #'readback
          #:dispatch-one #,dispatch-one
          #:dispatch #, #'dispatch
          #:run #, #'run
          #:settled #, #'settled-entry
          #:dead #, #'dead-entry
          #:final #, #'final-entry
          #:evaluate #, #'evaluate
          #:spec-language #, #'spec-language
          #:promote #, #'promote
          #:evaluate-spec #, #'evaluate-spec
          #:root-square #, #'root-square))
     (define stage-def
       (stage-definition #'stage-id 'Big instance artifacts #f))
     (with-syntax ([compressed-language compressed-language]
                   [compress compress]
                   [encode-MB encode-MB]
                   [span-labels span-labels]
                   [B-step-direct B-step-direct]
                   [machineize machineize]
                   [refocus-phase refocus-phase]
                   [D->Z D->Z]
                   [D->M D->M]
                   [decompose decompose]
                   [source-language source-language]
                   [source-runtime-variable source-runtime-variable]
                   [source-state-view source-state-view]
                   [source-work source-work]
                   [source-frontier source-frontier]
                   [source-settled source-settled]
                   [source-returned-view source-returned-view]
                   [source-work-focus source-work-focus]
                   [source-spine-context source-spine-context]
                   [(redex-parameter-local ...)
                    (map redex-parameter-info-local redex-parameters)]
                   [(redex-parameter-default ...)
                    (map redex-parameter-info-default redex-parameters)]
                   [failure-summary failure-summary]
                   [failure-term failure-term]
                   [terminal-success terminal-success]
                   [terminal-failure terminal-failure]
                   [root-focus root-focus]
                   [root-work-focus root-work-focus]
                   [(run-production ...) run-productions]
                   [(frame ...) frames]
                   [(frame-category ...) frame-categories]
                   [(dispatch-one-descent-clause ...)
                    dispatch-one-descent-clauses]
                   [(big-rule ...) big-rules]
                   [big-language #'big-language]
                   [readback #'readback]
                   [dispatch-one dispatch-one]
                   [dispatch #'dispatch]
                   [run #'run]
                   [settled-entry #'settled-entry]
                   [dead-entry #'dead-entry]
                   [final-entry #'final-entry]
                   [evaluate #'evaluate]
                   [spec-language #'spec-language]
                   [initialize #'initialize]
                   [close #'close]
                   [flatten #'flatten]
                   [promote #'promote]
                   [evaluate-spec #'evaluate-spec]
                   [unfold-square #'unfold-square]
                   [closure-square #'closure-square]
                   [root-square #'root-square]
                   [(dispatch-next
                     run-dispatch settled-dispatch dead-dispatch
                     evaluate-dispatch evaluate-final
                     promote-run promote-settled promote-dead promote-final)
                    (generate-temporaries
                     '(dispatch-next
                       run-dispatch settled-dispatch dead-dispatch
                       evaluate-dispatch evaluate-final
                       promote-run promote-settled promote-dead promote-final))]
                   [stage-def stage-def])
       #'(begin
           stage-def
           ;; This direct artifact extends the source language, not B.  Its
           ;; recursive clauses below contain no D/Z/M/B constructors or
           ;; stepper calls.
           (define-extended-language big-language
             source-language
             ;; Direct Big extends the source rather than D, so it repeats the
             ;; same selected-view-to-internal-category normalization locally.
             [SourceRuntimeVariable source-runtime-variable]
             [SourceState source-state-view]
             [SourceW source-work]
             [SourceF source-frontier]
             [SourceS source-settled]
             [SourceReturnedView source-returned-view]
             [SourceFailureView failure-term]
             [SourceTerminalSuccess terminal-success]
             [SourceTerminalFailure terminal-failure]
             [SourceWorkFocus source-work-focus]
             [SourceSpineContext source-spine-context]
             [RunW run-production ...]
             [Settled SourceReturnedView]
             [FailureSummary failure-summary]
             [DeadW SourceFailureView]
             frame-category ...
             [RootFocus root-focus]
             [RootWorkFocus root-work-focus]
             [T SourceTerminalSuccess SourceTerminalFailure]
             [Big (BigFinal T)]
             [BigNext (BigContinue SourceW SourceWorkFocus)
                      (BigDone Big)])

           (define-metafunction big-language
             readback : Big -> SourceF
             [(readback (BigFinal T)) T])

           (redex-parameter:define-judgment-form*
             big-language
             #:parameters
             ([redex-parameter-local redex-parameter-default] ...)
             #:mode (dispatch-one I I O)
             #:contract (dispatch-one SourceW SourceWorkFocus BigNext)
             dispatch-one-descent-clause ...
             big-rule ...)

           (redex-parameter:define-judgment-form*
             big-language
             #:parameters
             ([dispatch-next dispatch-one])
             #:mode (dispatch I I O)
             #:contract (dispatch SourceW SourceWorkFocus Big)
             [(dispatch-next
               SourceW_0 SourceWorkFocus_0 (BigDone Big_0))
              ----
              (dispatch SourceW_0 SourceWorkFocus_0 Big_0)]
             [(dispatch-next
               SourceW_0 SourceWorkFocus_0
               (BigContinue SourceW_1 SourceWorkFocus_1))
              (dispatch SourceW_1 SourceWorkFocus_1 Big_0)
              ----
              (dispatch SourceW_0 SourceWorkFocus_0 Big_0)])

           (redex-parameter:define-judgment-form*
             big-language
             #:parameters ([run-dispatch dispatch])
             #:mode (run I I O)
             #:contract (run RunW SourceWorkFocus Big)
             [(run-dispatch RunW SourceWorkFocus Big_0)
              ----
              (run RunW SourceWorkFocus Big_0)])

           (redex-parameter:define-judgment-form*
             big-language
             #:parameters ([settled-dispatch dispatch])
             #:mode (settled-entry I I O)
             #:contract (settled-entry Settled SourceWorkFocus Big)
             [(settled-dispatch Settled SourceWorkFocus Big_0)
              ----
              (settled-entry Settled SourceWorkFocus Big_0)])

           (redex-parameter:define-judgment-form*
             big-language
             #:parameters ([dead-dispatch dispatch])
             #:mode (dead-entry I I O)
             #:contract (dead-entry FailureSummary SourceWorkFocus Big)
             [(dead-dispatch failure-term SourceWorkFocus Big_0)
              ----
              (dead-entry failure-summary SourceWorkFocus Big_0)])

           (redex-parameter:define-judgment-form*
             big-language
             #:mode (final-entry I O)
             #:contract (final-entry T Big)
             [----
              (final-entry T (BigFinal T))])

           (redex-parameter:define-judgment-form*
             big-language
             #:parameters
             ([evaluate-dispatch dispatch]
              [evaluate-final final-entry])
             #:mode (evaluate I O)
             #:contract (evaluate SourceF Big)
             [(evaluate-dispatch SourceW_0 RootWorkFocus Big_0)
              ----
              (evaluate (in-hole RootWorkFocus SourceW_0) Big_0)]
             [(evaluate-final T Big_0)
              ----
              (evaluate T Big_0)])

           ;; The specification deliberately retains B and its exact span
           ;; trace; none of these forms is referenced by the direct driver.
           (define-extended-language spec-language
             compressed-language
             [Big (BigFinal T)]
             [BigNext (BigContinue SourceW SourceWorkFocus)
                      (BigDone Big)]
             [BTrace (TransitionSpan (... ...))])

           (define-judgment-form
             spec-language
             #:contract (initialize SourceF B)
             #:mode (initialize I O)
             [(decompose SourceF_0 D_0)
              (where Z_0 (refocus-phase D_0))
              (where M_0 (machineize Z_0))
              (where B_0 (compress M_0))
              ----
              (initialize SourceF_0 B_0)])

           (define-judgment-form
             spec-language
             #:contract (close B BTrace T)
             #:mode (close I O O)
             [----
              (close (BFinal T) () T)]
             [(B-step-direct B_0 TransitionSpan_0 B_1)
              (close
               B_1
               (TransitionSpan_rest (... ...))
               T_0)
              ----
              (close
               B_0
               (TransitionSpan_0
                TransitionSpan_rest (... ...))
               T_0)])

           (define-metafunction spec-language
             flatten : BTrace -> LabelTrace
             [(flatten ()) ()]
             [(flatten
               (TransitionSpan_0 TransitionSpan_rest (... ...)))
              (RuleName_span (... ...)
               RuleName_rest (... ...))
              (where (RuleName_span (... ...))
                     (span-labels TransitionSpan_0))
              (where (RuleName_rest (... ...))
                     (flatten
                      (TransitionSpan_rest (... ...))))])

           (redex-parameter:define-judgment-form*
             spec-language
             #:parameters
             ([promote-run run]
              [promote-settled settled-entry]
              [promote-dead dead-entry]
              [promote-final final-entry])
             #:mode (promote I O)
             #:contract (promote B Big)
             [(promote-run RunW SourceWorkFocus Big_0)
              ----
              (promote (BRun RunW SourceWorkFocus) Big_0)]
             [(promote-settled Settled SourceWorkFocus Big_0)
              ----
              (promote (BSettled Settled SourceWorkFocus) Big_0)]
             [(promote-dead FailureSummary SourceWorkFocus Big_0)
              ----
              (promote (BDead FailureSummary SourceWorkFocus) Big_0)]
             [(promote-final T Big_0)
              ----
              (promote (BFinal T) Big_0)])

           (define-judgment-form
             spec-language
             #:contract (evaluate-spec SourceF BTrace Big)
             #:mode (evaluate-spec I O O)
             [(initialize SourceF_0 B_0)
              (close B_0 BTrace_0 T_0)
              ----
              (evaluate-spec SourceF_0 BTrace_0 (BigFinal T_0))])

           (define-judgment-form
             spec-language
             #:contract
             (unfold-square B TransitionSpan B Big)
             #:mode (unfold-square I O O O)
             [(B-step-direct B_0 TransitionSpan_0 B_1)
              (promote B_0 Big_0)
              (promote B_1 Big_0)
              ----
              (unfold-square
               B_0 TransitionSpan_0 B_1 Big_0)])

           (define-judgment-form
             spec-language
             #:contract (closure-square B BTrace Big)
             #:mode (closure-square I O O)
             [(close B_0 BTrace_0 T_0)
              (promote B_0 (BigFinal T_0))
              ----
              (closure-square
               B_0 BTrace_0 (BigFinal T_0))])

           (define-judgment-form
             spec-language
             #:contract (root-square SourceF BTrace Big)
             #:mode (root-square I O O)
             [(evaluate-spec SourceF_0 BTrace_0 Big_0)
              (evaluate SourceF_0 Big_0)
              ----
              (root-square SourceF_0 BTrace_0 Big_0)])))]))

;; Each representation-map macro belongs to one stage transformer and emits
;; that phase's direct map plus its primary transformation square.  The maps
;; consume the joint representation views supplied by the source layer; no
;; clause decodes through an earlier coordinate.

(define-syntax (define-decomposition-representation-map stx)
  (syntax-parse stx
    [(_ #:source source-stage:id
        #:target target-stage:id
        #:Q-R Q-R:id
        #:Q-focus Q-focus:id
        #:Q-root-focus Q-root-focus:id
        #:Q-terminal Q-terminal:id
        #:Q-D Q-D:id
        #:commutes commutes:id)
     (define source-binding (lookup-stage #'source-stage 'D))
     (define target-binding (lookup-stage #'target-stage 'D))
     (define (decompose-id binding)
       (syntax-parse (stage-binding-artifact-declaration binding)
         [((~datum D-artifacts)
           #:language _language:id
           #:plug-D _plug-D:id
           #:plug-C _plug-C:id
           #:contract-label _contract-label:id
           #:decompose decompose:id
           #:contract _contract:id
           #:step _step:id)
          #'decompose]))
     (with-syntax ([source-decompose (decompose-id source-binding)]
                   [target-decompose (decompose-id target-binding)]
                   [(map-pair proof-outputs multiset=?)
                    (generate-temporaries
                     '(map-pair proof-outputs multiset=?))])
       #'(begin
           (define (map-pair who mapper payload context)
             (match (mapper payload context)
               [(list target-payload target-context)
                (values target-payload target-context)]
               [other
                (error who
                       "representation view returned ~e, expected two values"
                       other)]))

           (define (proof-outputs derivations)
             (for/list ([derivation (in-list derivations)])
               (last (derivation-term derivation))))

           (define (multiset=? left right)
             (and (= (length left) (length right))
                  (equal? (sort left string<? #:key ~s)
                          (sort right string<? #:key ~s))))

           (define (Q-D decomposition)
             (match decomposition
               [`(Final ,terminal)
                `(Final ,(Q-terminal terminal))]
               [`(DecWork ,payload ,context)
                (define-values (target-payload target-context)
                  (map-pair 'Q-D Q-focus payload context))
                `(DecWork ,target-payload ,target-context)]
               [`(DecFrontier ,payload ,context)
                (define-values (target-payload target-context)
                  (map-pair 'Q-D Q-root-focus payload context))
                `(DecFrontier ,target-payload ,target-context)]
               [`(DecAllocate ,payload ,context)
                (define-values (target-payload target-context)
                  (map-pair 'Q-D Q-focus payload context))
                `(DecAllocate ,target-payload ,target-context)]
               [other
                (error 'Q-D "expected a D carrier, received ~e" other)]))

           (define (commutes frontier)
             (define source-results
               (proof-outputs
                (build-derivations
                 (source-decompose ,frontier D))))
             (define target-frontier (Q-R frontier))
             (define target-results
               (proof-outputs
                (build-derivations
                 (target-decompose ,target-frontier D))))
             (multiset=?
              (map Q-D source-results)
              target-results))))]))

(define-syntax (define-refocused-representation-map stx)
  (syntax-parse stx
    [(_ #:source source-stage:id
        #:target target-stage:id
        #:Q-D Q-D:id
        #:Q-focus Q-focus:id
        #:Q-root-focus Q-root-focus:id
        #:Q-terminal Q-terminal:id
        #:Q-Z Q-Z:id
        #:commutes commutes:id)
     (define (phase-id stage-id)
       (define binding (lookup-stage stage-id 'Z))
       (syntax-parse (stage-binding-artifact-declaration binding)
         [((~datum Z-artifacts)
           #:language _language:id
           #:refocus-phase phase:id
           . _tail)
          #'phase]))
     (with-syntax ([source-phase (phase-id #'source-stage)]
                   [target-phase (phase-id #'target-stage)]
                   [(map-pair)
                    (generate-temporaries '(map-pair))])
       #'(begin
           (define (map-pair who mapper payload context)
             (match (mapper payload context)
               [(list target-payload target-context)
                (values target-payload target-context)]
               [other
                (error who
                       "representation view returned ~e, expected two values"
                       other)]))

           (define (Q-Z refocused)
             (match refocused
               [`(ZFinal ,terminal)
                `(ZFinal ,(Q-terminal terminal))]
               [`(ZWork ,payload ,context)
                (define-values (target-payload target-context)
                  (map-pair 'Q-Z Q-focus payload context))
                `(ZWork ,target-payload ,target-context)]
               [`(ZFrontier ,payload ,context)
                (define-values (target-payload target-context)
                  (map-pair 'Q-Z Q-root-focus payload context))
                `(ZFrontier ,target-payload ,target-context)]
               [`(ZAllocate ,payload ,context)
                (define-values (target-payload target-context)
                  (map-pair 'Q-Z Q-focus payload context))
                `(ZAllocate ,target-payload ,target-context)]
               [other
                (error 'Q-Z "expected a Z carrier, received ~e" other)]))

           (define (commutes decomposition)
             (define source-result
               (term (source-phase ,decomposition)))
             (define target-input (Q-D decomposition))
             (define target-result
               (term (target-phase ,target-input)))
             (equal? (Q-Z source-result) target-result))))]))

(define-syntax (define-machine-representation-map stx)
  (syntax-parse stx
    [(_ #:source source-stage:id
        #:target target-stage:id
        #:Q-Z Q-Z:id
        #:Q-focus Q-focus:id
        #:Q-root-focus Q-root-focus:id
        #:Q-terminal Q-terminal:id
        #:Q-M Q-M:id
        #:commutes commutes:id)
     (define (phase-id stage-id)
       (define binding (lookup-stage stage-id 'M))
       (syntax-parse (stage-binding-artifact-declaration binding)
         [((~datum M-artifacts)
           #:language _language:id
           #:machineize phase:id
           . _tail)
          #'phase]))
     (with-syntax ([source-phase (phase-id #'source-stage)]
                   [target-phase (phase-id #'target-stage)]
                   [(map-pair)
                    (generate-temporaries '(map-pair))])
       #'(begin
           (define (map-pair who mapper payload context)
             (match (mapper payload context)
               [(list target-payload target-context)
                (values target-payload target-context)]
               [other
                (error who
                       "representation view returned ~e, expected two values"
                       other)]))

           (define (Q-M machine)
             (match machine
               [`(MFinal ,terminal)
                `(MFinal ,(Q-terminal terminal))]
               [`(MWork ,payload ,context)
                (define-values (target-payload target-context)
                  (map-pair 'Q-M Q-focus payload context))
                `(MWork ,target-payload ,target-context)]
               [`(MFrontier ,payload ,context)
                (define-values (target-payload target-context)
                  (map-pair 'Q-M Q-root-focus payload context))
                `(MFrontier ,target-payload ,target-context)]
               [`(MAllocate ,payload ,context)
                (define-values (target-payload target-context)
                  (map-pair 'Q-M Q-focus payload context))
                `(MAllocate ,target-payload ,target-context)]
               [other
                (error 'Q-M "expected an M carrier, received ~e" other)]))

           (define (commutes refocused)
             (define source-result
               (term (source-phase ,refocused)))
             (define target-input (Q-Z refocused))
             (define target-result
               (term (target-phase ,target-input)))
             (equal? (Q-M source-result) target-result))))]))

(define-syntax (define-compressed-representation-map stx)
  (syntax-parse stx
    [(_ #:source source-stage:id
        #:target target-stage:id
        #:Q-M Q-M:id
        #:Q-focus Q-focus:id
        #:Q-failure-focus Q-failure-focus:id
        #:Q-terminal Q-terminal:id
        #:Q-B Q-B:id
        #:commutes commutes:id)
     (define (phase-id stage-id)
       (define binding (lookup-stage stage-id 'B))
       (syntax-parse (stage-binding-artifact-declaration binding)
         [((~datum B-artifacts)
           #:language _language:id
           #:compress phase:id
           . _tail)
          #'phase]))
     (with-syntax ([source-phase (phase-id #'source-stage)]
                   [target-phase (phase-id #'target-stage)]
                   [(map-pair)
                    (generate-temporaries '(map-pair))])
       #'(begin
           (define (map-pair who mapper payload context)
             (match (mapper payload context)
               [(list target-payload target-context)
                (values target-payload target-context)]
               [other
                (error who
                       "representation view returned ~e, expected two values"
                       other)]))

           (define (Q-B compressed)
             (match compressed
               [`(BFinal ,terminal)
                `(BFinal ,(Q-terminal terminal))]
               [`(BRun ,payload ,context)
                (define-values (target-payload target-context)
                  (map-pair 'Q-B Q-focus payload context))
                `(BRun ,target-payload ,target-context)]
               [`(BSettled ,payload ,context)
                (define-values (target-payload target-context)
                  (map-pair 'Q-B Q-focus payload context))
                `(BSettled ,target-payload ,target-context)]
               [`(BDead ,summary ,context)
                (define-values (target-summary target-context)
                  (map-pair
                   'Q-B Q-failure-focus summary context))
                `(BDead ,target-summary ,target-context)]
               [other
                (error 'Q-B "expected a B carrier, received ~e" other)]))

           (define (commutes machine)
             (define source-result
               (term (source-phase ,machine)))
             (define target-input (Q-M machine))
             (define target-result
               (term (target-phase ,target-input)))
             (equal? (Q-B source-result) target-result))))]))

(define-syntax (define-fixed-point-representation-map stx)
  (syntax-parse stx
    [(_ #:source source-stage:id
        #:target target-stage:id
        #:Q-B Q-B:id
        #:Q-terminal Q-terminal:id
        #:Q-Big Q-Big:id
        #:commutes commutes:id)
     (define (phase-id stage-id)
       (define binding (lookup-stage stage-id 'Big))
       (syntax-parse (stage-binding-artifact-declaration binding)
         [((~datum Big-artifacts)
           #:language _language:id
           #:readback _readback:id
           #:dispatch-one _dispatch-one:id
           #:dispatch _dispatch:id
           #:run _run:id
           #:settled _settled:id
           #:dead _dead:id
           #:final _final:id
           #:evaluate _evaluate:id
           #:spec-language _spec-language:id
           #:promote promote:id
           . _tail)
          #'promote]))
     (with-syntax ([source-phase (phase-id #'source-stage)]
                   [target-phase (phase-id #'target-stage)]
                   [(proof-outputs multiset=?)
                    (generate-temporaries
                     '(proof-outputs multiset=?))])
       #'(begin
           (define (proof-outputs derivations)
             (for/list ([derivation (in-list derivations)])
               (last (derivation-term derivation))))

           (define (multiset=? left right)
             (and (= (length left) (length right))
                  (equal? (sort left string<? #:key ~s)
                          (sort right string<? #:key ~s))))

           (define (Q-Big big)
             (match big
               [`(BigFinal ,terminal)
                `(BigFinal ,(Q-terminal terminal))]
               [other
                (error 'Q-Big
                       "expected a Big carrier, received ~e"
                       other)]))

           (define (commutes compressed)
             (define source-results
               (proof-outputs
                (build-derivations
                 (source-phase ,compressed Big))))
             (define target-input (Q-B compressed))
             (define target-results
               (proof-outputs
                (build-derivations
                 (target-phase ,target-input Big))))
             (multiset=?
              (map Q-Big source-results)
              target-results))))]))
