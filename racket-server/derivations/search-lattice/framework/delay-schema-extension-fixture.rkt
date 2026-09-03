#lang racket

(require redex/reduction-semantics
         (prefix-in redex-parameter: redex/parameter)
         "./core-source-schema.rkt"
         "./delay-schema-prefix-fixture.rkt"
         (for-syntax racket/base
                     racket/match
                     syntax/parse))

(provide delay-box-lang
         delay-box-red
         delay-box-successors
         wf-delay-box?
         q-export/delay-box
         q-rebuild/delay-box)

(begin-for-syntax
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
    (walk template)))

;; This fixture is intentionally a second, foreign source feature.  It lifts
;; the already-generated Delay source and contributes only Box's own grammar,
;; prefix-transfer, WF, and Q cases.  No Delay semantic clause is repeated.
(define-syntax (render-box-after-delay stx)
  (syntax-parse stx
    [(_ #:language base-language:id
        #:redex-parameters
        ([base-parameter-local:id base-parameter-default:id] ...)
        #:branch-copy _base-branch-copy:id
        #:R-work-raw base-work-raw:id
        #:R-frontier-raw base-frontier-raw:id
        #:R-allocation-raw base-allocation-raw:id
        #:subst-goal base-subst-goal:id
        #:subst-goal-open base-subst-goal-open:id
        #:wf-root base-wf-root:id
        #:wf-goal base-wf-goal:id
        #:wf-answer _base-wf-answer:id
        #:wf-returned _base-wf-returned:id
        #:live-supply base-live-supply:id
        #:failure-summary _base-failure-summary:id
        #:wf-work base-wf-work:id
        #:wf-frontier base-wf-frontier:id
        #:WF-open
        [#:goal-case base-wf-goal-case:id
         #:goal-tasks base-wf-goal-tasks:id
         #:live-case base-live-case:id
         #:node-case base-wf-node-case:id
         #:nodes base-wf-nodes:id]
        #:carrier-view
        [#:state _state-template
         #:answer _answer-template
         #:returned _returned-template
         #:work _work-template
         #:dead _dead-template
         #:conj _conj-template
         #:last _last-template
         #:more _more-template
         #:empty-supply empty-supply]
        #:prefix-view
        [#:extend-premises (prefix-premise ...)
         #:Q-empty _q-prefix-empty
         #:work-focus-support base-work-focus-prefix:id
         #:work-focus-support-open base-work-focus-prefix-open:id
         #:transfer-work base-transfer-work:id
         #:transfer-work-open base-transfer-work-open:id
         #:transfer-work-host _base-transfer-work-host:id
         #:Q-export-local q-export-local:id
         #:Q-rebuild-local q-rebuild-local:id]
        #:Q-open
        [#:work-export base-q-work-export-open:id
         #:work-support base-q-work-support-open:id
         #:work-rebuild base-q-work-rebuild-open:id
         #:frontier-export _base-q-frontier-export-open:id
         #:frontier-support _base-q-frontier-support-open:id
         #:frontier-rebuild _base-q-frontier-rebuild-open:id
         #:path-export base-q-path-export-open:id
         #:path-rebuild base-q-path-rebuild-open:id
         #:failure-export _base-q-failure-export:id
         #:failure-rebuild _base-q-failure-rebuild:id
         #:address-goal base-q-address-goal-open:id]
        #:Q-context-open
        [#:frontier-export base-q-frontier-export-context-open:id
         #:frontier-support base-q-frontier-support-context-open:id
         #:frontier-rebuild base-q-frontier-rebuild-context-open:id
         #:spine-export _base-q-spine-export-open:id
         #:spine-rebuild _base-q-spine-rebuild-open:id
         #:focus-shape _base-q-focus-shape-open:id
         #:focus-shape-rebuild _base-q-focus-shape-rebuild-open:id
         #:work-export-dependencies _base-q-work-export-dependencies-open:id
         #:frontier-export-dependencies
         _base-q-frontier-export-dependencies-open:id
         #:path-export-dependencies _base-q-path-export-dependencies-open:id
         #:path-rebuild-dependencies _base-q-path-rebuild-dependencies-open:id]
        #:extension
        [#:language extension-language:id
         #:relation extension-relation:id
         #:successors extension-successors:id
         #:wf-root extension-wf-root:id
         #:Q-export extension-q-export:id
         #:Q-rebuild extension-q-rebuild:id])
     #:do
     [(define (slot symbol)
        (datum->syntax
         #'extension-language
         symbol
         #'extension-language
         #'extension-language))
      (define supply-in-slot (slot 'supply_in))
      (define supply-local-slot (slot 'supply_local))
      (define supply-out-slot (slot 'supply_out))
      (define work-slot (slot 'W))]
     #:with supply-in* supply-in-slot
     #:with supply-local* supply-local-slot
     #:with supply-out* supply-out-slot
     #:with W* work-slot
     #:with live-supply-driver
     (render-selected-live-supply-driver
      #'extension-language
      #'live-supply/delay-box
      #'live-supply/delay-box/one)
     #:with (extension-prefix-premise ...)
     (for/list ([premise
                 (in-list
                  (syntax->list #'(prefix-premise ...)))])
       (instantiate-template
        premise
        (list (cons 'supply_in supply-in-slot)
              (cons 'supply_local supply-local-slot)
              (cons 'supply_out supply-out-slot))))
     #'(begin
         (define-extended-language extension-language base-language
           [W .... (Box supply W)]
           [WorkPath .... (Box supply WorkPath)])

         (define (owners-append/delay-box outer inner)
           (match* (outer inner)
             [(`(Owners ,outer-owner (... ...))
               `(Owners ,inner-owner (... ...)))
              `(Owners ,@outer-owner ,@inner-owner)]
             [(_ _)
              (error 'owners-append/delay-box
                     "expected two source prefixes, received ~e and ~e"
                     outer
                     inner)]))

         (define (subst-goal/open/delay-box recur goal substitutions)
           (base-subst-goal-open recur goal substitutions))

         (define (subst-goal/delay-box goal substitutions)
           (subst-goal/open/delay-box
            subst-goal/delay-box goal substitutions))

         (redex-parameter:define-extended-metafunction*
           base-subst-goal
           extension-language
           subst-goal/direct/delay-box : g alloc -> g
           [(subst-goal/direct/delay-box g alloc)
            ,(subst-goal/delay-box (term g) (term alloc))])

         (define (work-focus-prefix/open/delay-box focus support recur)
           (match focus
             [`(Box ,local ,inner)
              (match-define (list _provenance support-next)
                (q-export-local local support))
              (recur inner support-next)]
             [_
              (base-work-focus-prefix-open focus support recur)]))

         (define (work-focus-prefix/delay-box focus [support '()])
           (work-focus-prefix/open/delay-box
            focus support work-focus-prefix/delay-box))

         (redex-parameter:define-extended-metafunction*
           base-work-focus-prefix
           extension-language
           work-focus-prefix/direct/delay-box : WorkFocus support -> support
           [(work-focus-prefix/direct/delay-box WorkFocus support)
            ,(work-focus-prefix/delay-box
              (term WorkFocus)
              (term support))])

         (define (transfer-work-prefix/open/delay-box
                  prefix work extension)
           (match work
             [`(Box ,local ,inner)
              `(Box ,(owners-append/delay-box prefix local) ,inner)]
             [_
              (base-transfer-work-open prefix work extension)]))

         (define (transfer-work-prefix/delay-box prefix work)
           (transfer-work-prefix/open/delay-box
            prefix
            work
            (lambda (_prefix unsupported)
              (error 'transfer-work-prefix/delay-box
                     "expected extended source work, received ~e"
                     unsupported))))

         (redex-parameter:define-extended-metafunction*
           base-transfer-work
           extension-language
           transfer-work-prefix/direct/delay-box : any W -> W
           [(transfer-work-prefix/direct/delay-box any_0 W)
            ,(transfer-work-prefix/delay-box
              (term any_0)
              (term W))])

         (redex-parameter:define-extended-reduction-relation*
           delay-box-red/work-raw
           base-work-raw
           extension-language
           #:domain any)

         (redex-parameter:define-extended-reduction-relation*
           delay-box-red/frontier-raw
           base-frontier-raw
           extension-language
           #:domain any)

         (redex-parameter:define-extended-reduction-relation*
           delay-box-red/allocation-raw
           base-allocation-raw
           extension-language
           #:domain F)

         (define delay-box-red/work
           (context-closure
            delay-box-red/work-raw extension-language WorkFocus))

         (define delay-box-red/frontier
           (context-closure
            delay-box-red/frontier-raw extension-language SpineContext))

         (define extension-relation
           (extend-reduction-relation
            (union-reduction-relations
             delay-box-red/work
             delay-box-red/frontier
             delay-box-red/allocation-raw)
            extension-language
            #:domain F))

         (define (extension-successors frontier)
           (for/list ([named-step
                       (in-list
                        (apply-reduction-relation/tag-with-names
                         extension-relation
                         frontier))])
             (match-define (list name target) named-step)
             (list (string->symbol (~a name)) target)))

         (redex-parameter:define-extended-judgment-form*
           base-wf-goal-case
           extension-language
           #:mode (wf-delay-box?/goal-case I O))

         (redex-parameter:define-extended-judgment-form*
           base-wf-goal-tasks
           extension-language
           #:mode (wf-delay-box?/goal-tasks I)
           #:parameters ([wf-goal-next wf-delay-box?/goal-case]))

         (redex-parameter:define-extended-judgment-form*
           base-wf-goal
           extension-language
           #:mode (wf-delay-box?/goal I I I)
           #:parameters ([wf-goal-run wf-delay-box?/goal-tasks]))

         (redex-parameter:define-extended-judgment-form*
           base-live-case
           extension-language
           #:mode (live-supply/delay-box/one I I O)
           [extension-prefix-premise ...
            ----
            (live-supply/delay-box/one
             (Box supply-local* W*)
             supply-in*
             (LiveContinue W* supply-out*))])

         live-supply-driver

         (redex-parameter:define-extended-judgment-form*
           base-wf-node-case
           extension-language
           #:mode (wf-delay-box?/node-case I O)
           #:parameters
           ([wf-node-goal wf-delay-box?/goal]
            [wf-node-live live-supply/delay-box])
           [extension-prefix-premise ...
            ----
            (wf-delay-box?/node-case
             (WorkCheck (Box supply-local* W*) supply-in*)
             (NodeChecks (WorkCheck W* supply-out*)))])

         (redex-parameter:define-extended-judgment-form*
           base-wf-nodes
           extension-language
           #:mode (wf-delay-box?/nodes I)
           #:parameters ([wf-node-next wf-delay-box?/node-case]))

         (redex-parameter:define-extended-judgment-form*
           base-wf-work
           extension-language
           #:mode (wf-delay-box?/work I I)
           #:parameters ([wf-work-run wf-delay-box?/nodes]))

         (redex-parameter:define-extended-judgment-form*
           base-wf-frontier
           extension-language
           #:mode (wf-delay-box?/frontier I I)
           #:parameters ([wf-frontier-run wf-delay-box?/nodes]))

         (redex-parameter:define-extended-judgment-form*
           base-wf-root
           extension-language
           #:mode (extension-wf-root I)
           #:parameters ([wf-root-frontier wf-delay-box?/frontier]))

         (define (q-address-goal/open/delay-box recur goal support)
           (base-q-address-goal-open recur goal support))

         (define (q-address-goal/delay-box goal support)
           (q-address-goal/open/delay-box
            q-address-goal/delay-box goal support))

         (define (q-work-export/open/delay-box work support recur)
           (match work
             [`(Box ,local ,inner)
              (match-define (list provenance support-next)
                (q-export-local local support))
              `(q-box ,provenance ,(recur inner support-next))]
             [_
              (base-q-work-export-open work support recur)]))

         (define (q-work-export/delay-box work support)
           (q-work-export/open/delay-box
            work support q-work-export/delay-box))

         (define (q-work-support/open/delay-box neutral recur)
           (match neutral
             [`(q-box ,_provenance ,inner) (recur inner)]
             [_ (base-q-work-support-open neutral recur)]))

         (define (q-work-support/delay-box neutral)
           (q-work-support/open/delay-box
            neutral q-work-support/delay-box))

         (define (q-work-rebuild/open/delay-box
                  neutral support recur map-goal)
           (match neutral
             [`(q-box ,provenance ,inner)
              `(Box
                ,(q-rebuild-local provenance)
                ,(recur inner support))]
             [_
              (base-q-work-rebuild-open
               neutral support recur map-goal)]))

         (define (q-work-rebuild/delay-box neutral support)
           (q-work-rebuild/open/delay-box
            neutral
            support
            q-work-rebuild/delay-box
            q-address-goal/delay-box))

         (define (q-frontier-export/delay-box frontier support)
           (base-q-frontier-export-context-open
            frontier
            support
            q-work-export/delay-box
            q-frontier-export/delay-box))

         (define (q-frontier-support/delay-box neutral)
           (base-q-frontier-support-context-open
            neutral
            q-work-support/delay-box
            q-frontier-support/delay-box))

         (define (q-frontier-rebuild/delay-box neutral support)
           (base-q-frontier-rebuild-context-open
            neutral
            support
            q-work-rebuild/delay-box
            q-frontier-rebuild/delay-box))

         (define (extension-q-export frontier)
           (q-frontier-export/delay-box frontier (term empty-supply)))

         (define (extension-q-rebuild neutral)
           (q-frontier-rebuild/delay-box
            neutral
            (q-frontier-support/delay-box neutral))))]))

(delay-s-smoke-source
 #:visit-extension
 render-box-after-delay
 #:extension
 [#:language delay-box-lang
  #:relation delay-box-red
  #:successors delay-box-successors
  #:wf-root wf-delay-box?
  #:Q-export q-export/delay-box
  #:Q-rebuild q-rebuild/delay-box])
