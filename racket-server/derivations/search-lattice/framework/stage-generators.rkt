#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: redex/parameter)
         (for-syntax racket/base
                     racket/list
                     racket/match
                     racket/syntax
                     syntax/parse))

(provide define-derivation-instance
         define-derivation-delta
         define-compression-policy
         define-decomposition-stage
         define-refocused-stage
         define-machine-isomorphism-stage
         define-compressed-stage
         define-fixed-point-stage)

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

  (struct rule-info (label site from to premises source) #:transparent)
  (struct redex-parameter-info (local default source) #:transparent)
  (struct instance-info
    (source-language
     redex-parameters
     work frontier settled work-focus spine-context environment
     run-productions nonallocation-run-productions
     dead-environment dead-term root-focus root-spine frames
     work-redexes frontier-redexes allocation-redexes terminals
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
      [((~datum dead) environment raw context)
       (list 'dead #'environment #'raw #'context)]
      [((~datum pop-settled) frame payload context)
       (list 'pop-settled #'frame #'payload #'context)]
      [((~datum pop-dead) frame environment raw context)
       (list 'pop-dead #'frame #'environment #'raw #'context)]
      [((~datum root-settled) payload spine)
       (list 'root-settled #'payload #'spine)]
      [((~datum root-dead) environment raw spine)
       (list 'root-dead #'environment #'raw #'spine)]
      [((~datum final) payload spine)
       (list 'final #'payload #'spine)]
      [_
       (raise-syntax-error
        #f
        "expected a run/push/settled/dead/pop/root/final control form"
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

  (define (validate-dead-controls rules canonical-environment canonical-dead)
    (for ([rule (in-list rules)])
      (for ([control (in-list (list (rule-info-from rule)
                                    (rule-info-to rule)))])
        (define maybe-environment/raw
          (match control
            [(list 'dead environment raw _context)
             (list environment raw)]
            [(list 'pop-dead _frame environment raw _context)
             (list environment raw)]
            [(list 'root-dead environment raw _spine)
             (list environment raw)]
            [_ #f]))
        (when maybe-environment/raw
          (match-define (list environment raw) maybe-environment/raw)
          (define expected
            (instantiate-one-binder
             canonical-dead canonical-environment environment))
          (unless (equal? (syntax->datum raw) expected)
            (raise-syntax-error
             #f
             "dead control disagrees with the instance's canonical dead view"
             (rule-info-source rule)))))))

  (define (validate-distinct-productions groups declaration)
    (for ([group (in-list groups)])
      (define datums (map syntax->datum group))
      (unless (= (length datums)
                 (length (remove-duplicates datums equal?)))
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

  ;; A descriptor and a later delta may be declared in different modules.
  ;; Their unbound local-slot spellings then carry different module scopes even
  ;; though they denote the same declared Redex parameter.  Recontextualize
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
          #:work work:id
          #:frontier frontier:id
          #:settled settled:id
          #:work-focus work-focus:id
          #:spine-context spine-context:id
          #:environment environment:id
          #:run-productions (run-production ...)
          #:nonallocation-run-productions (nonallocation-run-production ...)
          #:dead-view [dead-environment dead-term]
          #:root-focus root-focus
          #:root-spine root-spine
          #:frames (frame ...)
          #:work-redexes (work-redex ...)
          #:frontier-redexes (frontier-redex ...)
          #:allocation-redexes (allocation-redex ...)
          #:terminals (terminal ...)
          #:open-work-productions (open-work-production ...)
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
       (unless (= (length labels) (length (remove-duplicates labels)))
         (raise-syntax-error #f "duplicate semantic rule label" declaration))
       (validate-dead-controls rules #'dead-environment #'dead-term)
       (validate-distinct-productions
        (list (syntax->list #'(run-production ...))
              (syntax->list #'(nonallocation-run-production ...))
              (syntax->list #'(frame ...))
              (syntax->list #'(work-redex ...))
              (syntax->list #'(frontier-redex ...))
              (syntax->list #'(allocation-redex ...))
              (syntax->list #'(terminal ...))
              (syntax->list #'(open-work-production ...)))
        declaration)
       (instance-info
        #'source-language
        redex-parameters
        #'work
        #'frontier
        #'settled
        #'work-focus
        #'spine-context
        #'environment
        (syntax->list #'(run-production ...))
        (syntax->list #'(nonallocation-run-production ...))
        #'dead-environment
        #'dead-term
        #'root-focus
        #'root-spine
        (syntax->list #'(frame ...))
        (syntax->list #'(work-redex ...))
        (syntax->list #'(frontier-redex ...))
        (syntax->list #'(allocation-redex ...))
        (syntax->list #'(terminal ...))
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

  (define (redex-parameter-symbol parameter)
    (syntax-e (redex-parameter-info-local parameter)))

  (define (merge-redex-parameters base additions overrides declaration)
    (validate-redex-parameters additions declaration)
    (validate-redex-parameters overrides declaration)
    (define base-names (map redex-parameter-symbol base))
    (for ([addition (in-list additions)])
      (when (memq (redex-parameter-symbol addition) base-names)
        (raise-syntax-error
         #f
         "#:redex-parameters-add must introduce a fresh local identifier"
         (redex-parameter-info-source addition))))
    (for ([override (in-list overrides)])
      (unless (memq (redex-parameter-symbol override) base-names)
        (raise-syntax-error
         #f
         "#:redex-parameter-overrides must name an inherited local identifier"
         (redex-parameter-info-source override))))
    (define override-table
      (for/hash ([override (in-list overrides)])
        (values (redex-parameter-symbol override)
                (redex-parameter-info-default override))))
    (define merged
      (append
       (for/list ([parameter (in-list base)])
         (define replacement
           (hash-ref override-table
                     (redex-parameter-symbol parameter)
                     (lambda () #f)))
         (if replacement
             (redex-parameter-info
              (redex-parameter-info-local parameter)
              replacement
              declaration)
             parameter))
       additions))
    (validate-redex-parameters merged declaration)
    merged)

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
      [(pop-dead)
       (match-define (list _ frame _environment raw context) control)
       #`(DecWork (in-hole #,frame #,raw) #,context)]
      [(root-settled)
       (match-define (list _ payload spine) control)
       #`(DecFrontier (in-hole #,root-focus #,payload) #,spine)]
      [(root-dead)
       (match-define (list _ _environment raw spine) control)
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
      [(dead)
       (match-define (list _ _environment raw context) control)
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

  ;; Z and M have the same retained-context transition program under a
  ;; constructor renaming.  Rendering both from this one template is the
  ;; mechanical content of the explicit Z/M isomorphism stage.  This is
  ;; structural reification, not an additional semantic transformation.
  (define (render-retained-context-refocuser
           language carrier refocus-work refocus
           final-constructor work-constructor
           frontier-constructor allocate-constructor
           root-spine)
    (define carrier-var
      (format-id carrier "~a_0" (syntax-e carrier)))
    (with-syntax ([language language]
                  [carrier carrier]
                  [carrier-var carrier-var]
                  [refocus-work refocus-work]
                  [refocus refocus]
                  [final-constructor final-constructor]
                  [work-constructor work-constructor]
                  [frontier-constructor frontier-constructor]
                  [allocate-constructor allocate-constructor]
                  [root-spine root-spine])
      (list
       #'(define-judgment-form
           language
           #:contract (refocus-work SourceW SourceWorkFocus carrier)
           #:mode (refocus-work I I O)
           [----
            (refocus-work WR SourceWorkFocus
                          (work-constructor WR SourceWorkFocus))]
           [----
            (refocus-work AR SourceWorkFocus
                          (allocate-constructor AR SourceWorkFocus))]
           [(refocus-work
             OpenW
             (in-hole SourceWorkFocus Frame)
             carrier-var)
            ----
            (refocus-work
             (in-hole Frame OpenW)
             SourceWorkFocus
             carrier-var)]
           [----
            (refocus-work
             Settled
             (in-hole SourceWorkFocus Frame)
             (work-constructor
              (in-hole Frame Settled)
              SourceWorkFocus))]
           [----
            (refocus-work
             DeadW
             (in-hole SourceWorkFocus Frame)
             (work-constructor
              (in-hole Frame DeadW)
              SourceWorkFocus))]
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
       #'(define-judgment-form
           language
           #:contract (refocus C carrier)
           #:mode (refocus I O)
           [(refocus-work SourceW SourceWorkFocus carrier-var)
            ----
            (refocus
             (ContractWork RuleName SourceW SourceWorkFocus)
             carrier-var)]
           [----
            (refocus
             (ContractFrontier RuleName SourceF_0 root-spine)
             (final-constructor
              (in-hole root-spine SourceF_0)))]))))

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
      [(list 'dead environment _raw context)
       #`(BDead #,environment #,context)]
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
        [(dead) (fourth target)]))
    (define label (rule-info-label rule))
    (define premises (rule-info-premises rule))
    (define output
      (case expected-target
        [(settled) (second target)]
        [(dead) (second target)]))
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
        [(list 'pop-dead frame environment _raw context)
         (values environment #`(in-hole #,context #,frame))]
        [(list 'root-dead environment _raw spine)
         (values environment #`(in-hole #,spine #,root-focus))]))
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
      [(list 'pop-dead frame _environment raw context)
       (values raw #`(in-hole #,context #,frame))]
      [(list 'root-settled payload spine)
       (values payload #`(in-hole #,spine #,root-focus))]
      [(list 'root-dead _environment raw spine)
       (values raw #`(in-hole #,spine #,root-focus))]
      [_
       (error 'control->big-source "unsupported source control ~e" control)]))

  (define (control->big-premise control dispatch big)
    (match control
      [(list 'run payload context)
       #`(#,dispatch #,payload #,context #,big)]
      [(list 'push frame payload context)
       #`(#,dispatch #,payload (in-hole #,context #,frame) #,big)]
      [(list 'settled payload context)
       #`(#,dispatch #,payload #,context #,big)]
      [(list 'dead _environment raw context)
       #`(#,dispatch #,raw #,context #,big)]
      [(list 'final payload spine)
       #`(where #,big
                (BigFinal (in-hole #,spine #,payload)))]
      [_
       (error 'control->big-premise "unsupported target control ~e" control)]))

  (define (render-big-rule rule dispatch root-focus)
    (define-values (source context)
      (control->big-source (rule-info-from rule) root-focus))
    (define premises (rule-info-premises rule))
    (define big (datum->syntax dispatch 'Big_0))
    (define recursive-or-result
      (control->big-premise (rule-info-to rule) dispatch big))
    (with-syntax ([(premise ...) premises]
                  [recursive-or-result recursive-or-result]
                  [dispatch dispatch]
                  [source source]
                  [context context]
                  [big big])
      #'[premise ...
         recursive-or-result
         ----
         (dispatch source context big)]))

  (define (stage-definition stage-id kind instance artifacts policy)
    #`(define-syntax #,stage-id
        (stage-binding
         '#,kind
         (quote-syntax #,(instance-info-declaration instance))
         (quote-syntax #,artifacts)
         #,(if policy
               #`(quote-syntax #,(policy-info-declaration policy))
               #'#f)))))

(define-syntax (define-derivation-instance stx)
  (syntax-parse stx
    [(_ name:id . _)
     (parse-instance stx)
     #`(define-syntax name
         (instance-binding (quote-syntax #,stx)))]))

;; A delta is currently a compile-time premerge of one already-declared
;; semantic instance with augmentation-owned grammar partitions, frames, and
;; rules.  It emits no separately staged Redex extension; the visible stage
;; macros consume the merged instance exactly as they consume a base instance.
;; This is the whole-instance oracle route, not yet StageExtension composition.
(define-syntax (define-derivation-delta stx)
  (syntax-parse stx
    [(_ name:id
        #:from base-id:id
        #:source-language source-language:id
        (~optional
         (~seq #:redex-parameters-add
               ([redex-parameter-add-local:id
                 redex-parameter-add-default:id] ...))
         #:defaults ([(redex-parameter-add-local 1) '()]
                     [(redex-parameter-add-default 1) '()]))
        (~optional
         (~seq #:redex-parameter-overrides
               ([redex-parameter-override-local:id
                 redex-parameter-override-default:id] ...))
         #:defaults ([(redex-parameter-override-local 1) '()]
                     [(redex-parameter-override-default 1) '()]))
        #:run-productions-add (run-add ...)
        #:nonallocation-run-productions-add (nonallocation-run-add ...)
        #:frames-add (frame-add ...)
        #:work-redexes-add (work-redex-add ...)
        #:frontier-redexes-add (frontier-redex-add ...)
        #:allocation-redexes-add (allocation-redex-add ...)
        #:terminals-add (terminal-add ...)
        #:open-work-productions-add (open-work-add ...)
        #:rules-add (rule-add ...))
     (define base (lookup-instance #'base-id))
     (define redex-parameters
       (merge-redex-parameters
        (instance-info-redex-parameters base)
        (parse-redex-parameters
         (syntax->list #'(redex-parameter-add-local ...))
         (syntax->list #'(redex-parameter-add-default ...))
         stx)
        (parse-redex-parameters
         (syntax->list #'(redex-parameter-override-local ...))
         (syntax->list #'(redex-parameter-override-default ...))
         stx)
        stx))
     (define redex-parameter-declarations
       (for/list ([parameter (in-list redex-parameters)])
         #`[#,(redex-parameter-info-local parameter)
            #,(redex-parameter-info-default parameter)]))
     (define declaration
       #`(define-derivation-instance name
           #:source-language source-language
           #:redex-parameters (#,@redex-parameter-declarations)
           #:work #,(instance-info-work base)
           #:frontier #,(instance-info-frontier base)
           #:settled #,(instance-info-settled base)
           #:work-focus #,(instance-info-work-focus base)
           #:spine-context #,(instance-info-spine-context base)
           #:environment #,(instance-info-environment base)
           #:run-productions
           (#,@(instance-info-run-productions base) run-add ...)
           #:nonallocation-run-productions
           (#,@(instance-info-nonallocation-run-productions base)
            nonallocation-run-add ...)
           #:dead-view
           [#,(instance-info-dead-environment base)
            #,(instance-info-dead-term base)]
           #:root-focus #,(instance-info-root-focus base)
           #:root-spine #,(instance-info-root-spine base)
           #:frames (#,@(instance-info-frames base) frame-add ...)
           #:work-redexes
           (#,@(instance-info-work-redexes base) work-redex-add ...)
           #:frontier-redexes
           (#,@(instance-info-frontier-redexes base)
            frontier-redex-add ...)
           #:allocation-redexes
           (#,@(instance-info-allocation-redexes base)
            allocation-redex-add ...)
           #:terminals
           (#,@(instance-info-terminals base) terminal-add ...)
           #:open-work-productions
           (#,@(instance-info-open-work-productions base)
            open-work-add ...)
           #:rules
           (#,@(map rule-info-source (instance-info-rules base))
            rule-add ...)))
     (parse-instance declaration)
     #`(define-syntax name
         (instance-binding (quote-syntax #,declaration)))]))

(define-syntax (define-compression-policy stx)
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
       (unless (= (length labels)
                  (length (remove-duplicates labels)))
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

;; Only judgments into which semantic rule premises are rendered use the
;; redex/parameter starred form: D's contract, B's four helpers and direct
;; step, and Big's dispatch.  Structural judgments keep ordinary Redex
;; bindings because no source dependency needs reinterpretation there.
;;
;; The first stage emits the exact grammatical shell and renders every
;; semantic equation from the instance declaration once.  Subsequent stage
;; macros consume the same retained declaration through their stage binding.
(define-syntax (define-decomposition-stage stx)
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
     (define source-work (instance-info-work instance))
     (define source-frontier (instance-info-frontier instance))
     (define source-settled (instance-info-settled instance))
     (define source-work-focus (instance-info-work-focus instance))
     (define source-spine-context (instance-info-spine-context instance))
     (define redex-parameters (instance-info-redex-parameters instance))
     (define work-redexes (instance-info-work-redexes instance))
     (define frontier-redexes (instance-info-frontier-redexes instance))
     (define allocation-redexes (instance-info-allocation-redexes instance))
     (define terminals (instance-info-terminals instance))
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
                   [(terminal ...) terminals]
                   [(label ...) labels]
                   [(contract-rule ...) contract-rules]
                   [source-language source-language]
                   [source-work source-work]
                   [source-frontier source-frontier]
                   [source-settled source-settled]
                   [source-work-focus source-work-focus]
                   [source-spine-context source-spine-context]
                   [(redex-parameter-local ...)
                    (map redex-parameter-info-local redex-parameters)]
                   [(redex-parameter-default ...)
                    (map redex-parameter-info-default redex-parameters)]
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
             [SourceW source-work]
             [SourceF source-frontier]
             [SourceS source-settled]
             [SourceWorkFocus source-work-focus]
             [SourceSpineContext source-spine-context]
             [RuleName label ...]
             [WR work-redex ...]
             [FR frontier-redex ...]
             [AR allocation-redex ...]
             [T terminal ...]
             [D (Final T)
                (DecWork WR SourceWorkFocus)
                (DecFrontier FR SourceSpineContext)
                (DecAllocate AR SourceWorkFocus)]
             [C (ContractWork RuleName SourceW SourceWorkFocus)
                (ContractFrontier RuleName SourceF SourceSpineContext)])

           (define-metafunction decomposition-language
             plug-D : D -> SourceF
             [(plug-D (Final T)) T]
             [(plug-D (DecWork WR SourceWorkFocus))
              (in-hole SourceWorkFocus WR)]
             [(plug-D (DecFrontier FR SourceSpineContext))
              (in-hole SourceSpineContext FR)]
             [(plug-D (DecAllocate AR SourceWorkFocus))
              (in-hole SourceWorkFocus AR)])

           (define-metafunction decomposition-language
             plug-C : C -> SourceF
             [(plug-C (ContractWork RuleName SourceW SourceWorkFocus))
              (in-hole SourceWorkFocus SourceW)]
             [(plug-C (ContractFrontier RuleName SourceF SourceSpineContext))
              (in-hole SourceSpineContext SourceF)])

           (define-metafunction decomposition-language
             contract-label : C -> RuleName
             [(contract-label (ContractWork RuleName SourceW SourceWorkFocus)) RuleName]
             [(contract-label (ContractFrontier RuleName SourceF SourceSpineContext))
              RuleName])

           (define-judgment-form
             decomposition-language
             #:contract (decompose SourceF D)
             #:mode (decompose I O)
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

           (define-judgment-form
             decomposition-language
             #:contract (step D RuleName D)
             #:mode (step I O O)
             [(contract D_0 C)
              (where RuleName (contract-label C))
              (where SourceF_1 (plug-C C))
              (decompose SourceF_1 D_1)
              ----
              (step D_0 RuleName D_1)])))]))

;; Refocusing retains the decomposed carrier shape but replaces repeated
;; plug/decompose with the instance's declared frame/root algebra.  No source
;; constructors occur in this renderer: Frame, RootFocus, Settled, DeadW, and
;; OpenW are all instance-owned grammar partitions.
(define-syntax (define-refocused-stage stx)
  (syntax-parse stx
    [(_ stage-id:id
        #:from decomposition-stage-id:id
        #:language refocused-language:id
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
     (define settled (instance-info-settled instance))
     (define dead-term (instance-info-dead-term instance))
     (define root-focus (instance-info-root-focus instance))
     (define root-spine (instance-info-root-spine instance))
     (define frames (instance-info-frames instance))
     (define open-work-productions
       (instance-info-open-work-productions instance))
     (define artifacts
       #`(Z-artifacts
          #:language #, #'refocused-language
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
        root-spine))
     (with-syntax ([(run-production ...) run-productions]
                   [(frame ...) frames]
                   [(open-work-production ...) open-work-productions]
                   [settled settled]
                   [dead-term dead-term]
                   [root-focus root-focus]
                   [root-spine root-spine]
                   [decomposition-language decomposition-language]
                   [plug-C plug-C]
                   [decompose decompose]
                   [contract contract]
                   [contract-label contract-label]
                   [refocused-language #'refocused-language]
                   [D->Z #'D->Z]
                   [Z->D #'Z->D]
                   [readback #'readback]
                   [refocus-spec #'refocus-spec]
                   [refocus-work-direct #'refocus-work-direct]
                   [refocus-direct #'refocus-direct]
                   [step-spec #'step-spec]
                   [step-direct #'step-direct]
                   [(refocus-form ...) refocus-forms]
                   [stage-def stage-def])
       #'(begin
           stage-def
           (define-extended-language refocused-language
             decomposition-language
             [RunW run-production ...]
             [Settled settled]
             [DeadW dead-term]
             [Frame frame ...]
             [RootFocus root-focus]
             [OpenW WR AR open-work-production ...]
             [Z (ZFinal T)
                (ZWork WR SourceWorkFocus)
                (ZFrontier FR SourceSpineContext)
                (ZAllocate AR SourceWorkFocus)])

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

           (define-judgment-form
             refocused-language
             #:contract (step-direct Z RuleName Z)
             #:mode (step-direct I O O)
             [(where D_0 (Z->D Z_0))
              (contract D_0 C_0)
              (where RuleName (contract-label C_0))
              (refocus-direct C_0 Z_1)
              ----
              (step-direct Z_0 RuleName Z_1)])))]))

(define-syntax (define-machine-isomorphism-stage stx)
  (syntax-parse stx
    [(_ stage-id:id
        #:from refocused-stage-id:id
        #:language machine-language:id
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
       (refocused-language Z->D Z-step-direct
                           decomposition-language decompose
                           contract contract-label)
       (syntax-parse Z-artifacts
         [((~datum Z-artifacts)
           #:language language:id
           #:D->Z _D->Z:id
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
                  #'Z->D
                  #'Z-step-direct
                  #'D-language
                  #'decompose
                  #'contract
                  #'contract-label)]))
     (define root-spine (instance-info-root-spine instance))
     (define artifacts
       #`(M-artifacts
          #:language #, #'machine-language
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
        root-spine))
     (with-syntax ([refocused-language refocused-language]
                   [Z->D Z->D]
                   [Z-step-direct Z-step-direct]
                   [decompose decompose]
                   [contract contract]
                   [contract-label contract-label]
                   [machine-language #'machine-language]
                   [encode-ZM #'encode-ZM]
                   [decode-MZ #'decode-MZ]
                   [D->M #'D->M]
                   [M->D #'M->D]
                   [readback #'readback]
                   [refocus-work-direct #'refocus-work-direct]
                   [refocus-direct #'refocus-direct]
                   [step-direct #'step-direct]
                   [corresponds #'corresponds]
                   [step-spec #'step-spec]
                   [square #'square]
                   [(refocus-form ...) refocus-forms]
                   [stage-def stage-def])
       #'(begin
           stage-def
           (define-extended-language machine-language
             refocused-language
             [M (MFinal T)
                (MWork WR SourceWorkFocus)
                (MFrontier FR SourceSpineContext)
                (MAllocate AR SourceWorkFocus)])

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

           (define-judgment-form
             machine-language
             #:contract (step-direct M RuleName M)
             #:mode (step-direct I O O)
             [(where D_0 (M->D M_0))
              (contract D_0 C_0)
              (where RuleName (contract-label C_0))
              (refocus-direct C_0 M_1)
              ----
              (step-direct M_0 RuleName M_1)])

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

(define-syntax (define-compressed-stage stx)
  (syntax-parse stx
    [(_ stage-id:id
        #:from machine-stage-id:id
        #:policy policy-id:id
        #:language compressed-language:id
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
       (machine-language machine-step-direct D->M decompose)
       (syntax-parse M-artifacts
         [((~datum M-artifacts)
           #:language language:id
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
           #:decompose decompose:id
           #:contract _contract:id
           #:contract-label _contract-label:id)
          (values #'language
                  #'machine-step-direct
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
     (define root-work-focus
       (compose-context root-spine root-focus))
     (define settled-producer-clauses
       (map (lambda (rule)
              (render-producer-rule rule #'produce-settled 'settled))
            settled-producers))
     (define dead-producer-clauses
       (map (lambda (rule)
              (render-producer-rule rule #'produce-dead 'dead))
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
               '(pop-dead root-dead)
               root-focus))
            dead-followers))
     (define singleton-run-clauses
       (map (lambda (rule)
              (render-singleton-run-rule rule #'step-direct))
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
     (define environment (instance-info-environment instance))
     (define dead-environment (instance-info-dead-environment instance))
     (define dead-term (instance-info-dead-term instance))
     (define artifacts
       #`(B-artifacts
          #:language #, #'compressed-language
          #:encode-MB #, #'encode-MB
          #:decode-BM #, #'decode-BM
          #:readback #, #'readback
          #:span-labels #, #'span-labels
          #:step-direct #, #'step-direct
          #:replay #, #'replay
          #:step-spec #, #'step-spec
          #:square #, #'square
          #:M-language #,machine-language
          #:M-step-direct #,machine-step-direct
          #:D->M #,D->M
          #:decompose #,decompose))
     (define stage-def
       (stage-definition #'stage-id 'B instance artifacts policy))
     (with-syntax ([machine-language machine-language]
                   [machine-step-direct machine-step-direct]
                   [compressed-language #'compressed-language]
                   [encode-MB #'encode-MB]
                   [decode-BM #'decode-BM]
                   [readback #'readback]
                   [span-labels #'span-labels]
                   [produce-settled #'produce-settled]
                   [produce-dead #'produce-dead]
                   [advance-settled #'advance-settled]
                   [advance-dead #'advance-dead]
                   [step-direct #'step-direct]
                   [corresponds #'corresponds]
                   [replay #'replay]
                   [step-spec #'step-spec]
                   [square #'square]
                   [environment environment]
                   [dead-environment dead-environment]
                   [dead-term dead-term]
                   [root-spine root-spine]
                   [root-focus root-focus]
                   [root-work-focus root-work-focus]
                   [(redex-parameter-local ...)
                    (map redex-parameter-info-local redex-parameters)]
                   [(redex-parameter-default ...)
                    (map redex-parameter-info-default redex-parameters)]
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
                   [stage-def stage-def])
       #'(begin
           stage-def
           (define-extended-language compressed-language
             machine-language
             [Env environment]
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
                (BDead Env SourceWorkFocus)
                (BFinal T)]
             [TransitionSpan
              (transition-span RuleName)
              (transition-span RuleName RuleName)])

           (define-metafunction compressed-language
             encode-MB : M -> B
             [(encode-MB (MFinal T)) (BFinal T)]
             [(encode-MB (MAllocate AR SourceWorkFocus))
              (BRun AR SourceWorkFocus)]
             [(encode-MB (MWork NonAllocateRun SourceWorkFocus))
              (BRun NonAllocateRun SourceWorkFocus)]
             [(encode-MB
               (MWork (in-hole Frame Settled) SourceWorkFocus))
              (BSettled Settled (in-hole SourceWorkFocus Frame))]
             [(encode-MB
               (MWork (in-hole Frame dead-term) SourceWorkFocus))
              (BDead dead-environment
                     (in-hole SourceWorkFocus Frame))]
             [(encode-MB
               (MFrontier (in-hole root-focus Settled) root-spine))
              (BSettled Settled root-work-focus)]
             [(encode-MB
               (MFrontier (in-hole root-focus dead-term) root-spine))
              (BDead dead-environment root-work-focus)])

           (define-metafunction compressed-language
             decode-BM : B -> M
             [(decode-BM (BFinal T)) (MFinal T)]
             [(decode-BM (BRun AR SourceWorkFocus))
              (MAllocate AR SourceWorkFocus)]
             [(decode-BM (BRun NonAllocateRun SourceWorkFocus))
              (MWork NonAllocateRun SourceWorkFocus)]
             [(decode-BM
               (BSettled Settled
                         (in-hole SourceWorkFocus Frame)))
              (MWork (in-hole Frame Settled) SourceWorkFocus)]
             [(decode-BM (BSettled Settled root-work-focus))
              (MFrontier
               (in-hole root-focus Settled)
               root-spine)]
             [(decode-BM
               (BDead dead-environment
                      (in-hole SourceWorkFocus Frame)))
              (MWork (in-hole Frame dead-term) SourceWorkFocus)]
             [(decode-BM
               (BDead dead-environment root-work-focus))
              (MFrontier
               (in-hole root-focus dead-term)
               root-spine)])

           (define-metafunction compressed-language
             readback : B -> SourceF
             [(readback (BRun NonAllocateRun SourceWorkFocus))
              (in-hole SourceWorkFocus NonAllocateRun)]
             [(readback (BRun AR SourceWorkFocus))
              (in-hole SourceWorkFocus AR)]
             [(readback (BSettled Settled SourceWorkFocus))
              (in-hole SourceWorkFocus Settled)]
             [(readback (BDead dead-environment SourceWorkFocus))
              (in-hole SourceWorkFocus dead-term)]
             [(readback (BFinal T)) T])

           (define-metafunction compressed-language
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
              SourceW SourceWorkFocus DeadProducerName Env SourceWorkFocus)
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
             (advance-dead Env SourceWorkFocus DeadFollowerName B)
             dead-follower-clause ...)

           (redex-parameter:define-judgment-form*
             compressed-language
             #:parameters
             ([redex-parameter-local redex-parameter-default] ...)
             #:mode (step-direct I O O)
             #:contract (step-direct B TransitionSpan B)
             singleton-run-clause ...
             [(advance-settled
               Settled SourceWorkFocus SettledFollowerName B_1)
              ----
              (step-direct
               (BSettled Settled SourceWorkFocus)
               (transition-span SettledFollowerName)
               B_1)]
             [(advance-dead
               Env SourceWorkFocus DeadFollowerName B_1)
              ----
              (step-direct
               (BDead Env SourceWorkFocus)
               (transition-span DeadFollowerName)
               B_1)]
             [(produce-settled
               SourceW SourceWorkFocus_0
               SettledProducerName Settled SourceWorkFocus_1)
              (advance-settled
               Settled SourceWorkFocus_1 SettledFollowerName B_1)
              ----
              (step-direct
               (BRun SourceW SourceWorkFocus_0)
               (transition-span
                SettledProducerName SettledFollowerName)
               B_1)]
             [(produce-dead
               SourceW SourceWorkFocus_0 DeadProducerName Env SourceWorkFocus_1)
              (advance-dead
               Env SourceWorkFocus_1 DeadFollowerName B_1)
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
             [(where B_0 (encode-MB M_0))
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

(define-syntax (define-fixed-point-stage stx)
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
       (compressed-language encode-MB span-labels B-step-direct
                            D->M decompose)
       (syntax-parse B-artifacts
         [((~datum B-artifacts)
           #:language language:id
           #:encode-MB encode-MB:id
           #:decode-BM _decode-BM:id
           #:readback _readback:id
           #:span-labels span-labels:id
           #:step-direct step-direct:id
           #:replay _replay:id
           #:step-spec _step-spec:id
           #:square _square:id
           #:M-language _M-language:id
           #:M-step-direct _M-step-direct:id
           #:D->M D->M:id
           #:decompose decompose:id)
          (values #'language
                  #'encode-MB
                  #'span-labels
                  #'step-direct
                  #'D->M
                  #'decompose)]))
     (define source-language (instance-info-source-language instance))
     (define source-work (instance-info-work instance))
     (define source-frontier (instance-info-frontier instance))
     (define source-settled (instance-info-settled instance))
     (define source-work-focus (instance-info-work-focus instance))
     (define source-spine-context (instance-info-spine-context instance))
     (define redex-parameters (instance-info-redex-parameters instance))
     (define run-productions (instance-info-run-productions instance))
     (define environment (instance-info-environment instance))
     (define dead-environment (instance-info-dead-environment instance))
     (define dead-term (instance-info-dead-term instance))
     (define root-focus (instance-info-root-focus instance))
     (define root-work-focus
       (compose-context
        (instance-info-root-spine instance)
        root-focus))
     (define frames (instance-info-frames instance))
     (define terminals (instance-info-terminals instance))
     (define big-rules
       (map (lambda (rule)
              (render-big-rule
               rule #'dispatch root-focus))
            (instance-info-rules instance)))
     (define descent-clauses
       (for/list ([frame (in-list frames)])
         (with-syntax ([dispatch #'dispatch]
                       [frame frame])
           #'[(dispatch
               SourceW_0
               (in-hole SourceWorkFocus frame)
               Big_0)
              ----
              (dispatch
               (in-hole frame SourceW_0)
               SourceWorkFocus
               Big_0)])))
     (define artifacts
       #`(Big-artifacts
          #:language #, #'big-language
          #:readback #, #'readback
          #:dispatch #, #'dispatch
          #:run #, #'run
          #:settled #, #'settled-entry
          #:dead #, #'dead-entry
          #:final #, #'final-entry
          #:evaluate #, #'evaluate
          #:spec-language #, #'spec-language
          #:evaluate-spec #, #'evaluate-spec
          #:root-square #, #'root-square))
     (define stage-def
       (stage-definition #'stage-id 'Big instance artifacts #f))
     (with-syntax ([compressed-language compressed-language]
                   [encode-MB encode-MB]
                   [span-labels span-labels]
                   [B-step-direct B-step-direct]
                   [D->M D->M]
                   [decompose decompose]
                   [source-language source-language]
                   [source-work source-work]
                   [source-frontier source-frontier]
                   [source-settled source-settled]
                   [source-work-focus source-work-focus]
                   [source-spine-context source-spine-context]
                   [(redex-parameter-local ...)
                    (map redex-parameter-info-local redex-parameters)]
                   [(redex-parameter-default ...)
                    (map redex-parameter-info-default redex-parameters)]
                   [environment environment]
                   [dead-environment dead-environment]
                   [dead-term dead-term]
                   [root-focus root-focus]
                   [root-work-focus root-work-focus]
                   [(run-production ...) run-productions]
                   [(frame ...) frames]
                   [(terminal ...) terminals]
                   [(descent-clause ...) descent-clauses]
                   [(big-rule ...) big-rules]
                   [big-language #'big-language]
                   [readback #'readback]
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
                   [stage-def stage-def])
       #'(begin
           stage-def
           ;; This direct artifact extends the source language, not B.  Its
           ;; recursive clauses below contain no D/Z/M/B constructors or
           ;; stepper calls.
           (define-extended-language big-language
             source-language
             ;; Direct Big extends the source rather than D, so it repeats the
             ;; same descriptor-to-internal-category normalization locally.
             [SourceW source-work]
             [SourceF source-frontier]
             [SourceS source-settled]
             [SourceWorkFocus source-work-focus]
             [SourceSpineContext source-spine-context]
             [RunW run-production ...]
             [Settled SourceS]
             [Env environment]
             [DeadW dead-term]
             [Frame frame ...]
             [RootFocus root-focus]
             [RootWorkFocus root-work-focus]
             [T terminal ...]
             [Big (BigFinal T)])

           (define-metafunction big-language
             readback : Big -> SourceF
             [(readback (BigFinal T)) T])

           (redex-parameter:define-judgment-form*
             big-language
             #:parameters
             ([redex-parameter-local redex-parameter-default] ...)
             #:mode (dispatch I I O)
             #:contract (dispatch SourceW SourceWorkFocus Big)
             descent-clause ...
             big-rule ...)

           (define-judgment-form
             big-language
             #:contract (run RunW SourceWorkFocus Big)
             #:mode (run I I O)
             [(dispatch RunW SourceWorkFocus Big_0)
              ----
              (run RunW SourceWorkFocus Big_0)])

           (define-judgment-form
             big-language
             #:contract (settled-entry Settled SourceWorkFocus Big)
             #:mode (settled-entry I I O)
             [(dispatch Settled SourceWorkFocus Big_0)
              ----
              (settled-entry Settled SourceWorkFocus Big_0)])

           (define-judgment-form
             big-language
             #:contract (dead-entry Env SourceWorkFocus Big)
             #:mode (dead-entry I I O)
             [(dispatch dead-term SourceWorkFocus Big_0)
              ----
              (dead-entry dead-environment SourceWorkFocus Big_0)])

           (define-judgment-form
             big-language
             #:contract (final-entry T Big)
             #:mode (final-entry I O)
             [----
              (final-entry T (BigFinal T))])

           (define-judgment-form
             big-language
             #:contract (evaluate SourceF Big)
             #:mode (evaluate I O)
             [(dispatch SourceW_0 RootWorkFocus Big_0)
              ----
              (evaluate (in-hole RootWorkFocus SourceW_0) Big_0)]
             [(final-entry T Big_0)
              ----
              (evaluate T Big_0)])

           ;; The specification deliberately retains B and its exact span
           ;; trace; none of these forms is referenced by the direct driver.
           (define-extended-language spec-language
             compressed-language
             [Big (BigFinal T)]
             [BTrace (TransitionSpan (... ...))])

           (define-judgment-form
             spec-language
             #:contract (initialize SourceF B)
             #:mode (initialize I O)
             [(decompose SourceF_0 D_0)
              (where M_0 (D->M D_0))
              (where B_0 (encode-MB M_0))
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

           (define-judgment-form
             spec-language
             #:contract (promote B Big)
             #:mode (promote I O)
             [(run RunW SourceWorkFocus Big_0)
              ----
              (promote (BRun RunW SourceWorkFocus) Big_0)]
             [(settled-entry Settled SourceWorkFocus Big_0)
              ----
              (promote (BSettled Settled SourceWorkFocus) Big_0)]
             [(dead-entry Env SourceWorkFocus Big_0)
              ----
              (promote (BDead Env SourceWorkFocus) Big_0)]
             [(final-entry T Big_0)
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
