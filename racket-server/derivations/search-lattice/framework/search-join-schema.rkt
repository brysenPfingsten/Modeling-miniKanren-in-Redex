#lang racket

(require "./core-stage-schema.rkt"
         (for-syntax racket/base
                     syntax/parse))

(provide define-generated-search-join-source
         define-generated-search-join-stage-extension)

;; Search is the policy-neutral join of the already assembled Delay and
;; Disjunction features.  It owns no carrier and no reduction clause.  The
;; binding below is nevertheless explicit: descendants consume Search (rather
;; than silently treating the last-applied child as Search), and tests can ask
;; which zero-rule boundary was installed.
(begin-for-syntax
  (struct search-join-source-binding (base)
    #:property prop:procedure
    (lambda (self use-stx)
      (define base (search-join-source-binding-base self))
      (syntax-parse use-stx
        [(_ #:visit-search-join visitor:id argument ...)
         #`(visitor #:base #,base #:owned-rule-labels () argument ...)]
        [(_ argument ...)
         #`(#,base argument ...)]))))

(define-syntax (render-search-join-stage-extension stx)
  (syntax-parse stx
    [(_ #:language _language:id
        #:redex-parameters _redex-parameters
        #:branch-copy _branch-copy:id
        #:R-work-raw _work-raw:id
        #:R-frontier-raw _frontier-raw:id
        #:R-allocation-raw _allocation-raw:id
        #:subst-goal _subst-goal:id
        #:subst-goal-open _subst-goal-open:id
        #:wf-root _wf-root:id
        #:wf-goal _wf-goal:id
        #:wf-answer _wf-answer:id
        #:wf-returned _wf-returned:id
        #:live-supply _live-supply:id
        #:failure-summary _failure-summary:id
        #:wf-work _wf-work:id
        #:wf-frontier _wf-frontier:id
        #:WF-open _wf-open
        #:carrier-view _carrier-view
        #:prefix-view _prefix-view
        #:Q-open _q-open
        (~optional (~seq #:Q-context-open _q-context-open))
        #:extension-name extension-name:id)
     #'(define-selected-stage-extension extension-name
         #:identity
         #:feature-singletons ())]))

(define-syntax (define-generated-search-join-source stx)
  (syntax-parse stx
    [(_ name:id
        #:base base-source:id
        #:owned-rule-labels ())
     #'(define-syntax name
         (search-join-source-binding (quote-syntax base-source)))]))

(define-syntax (define-generated-search-join-stage-extension stx)
  (syntax-parse stx
    [(_ name:id #:source source:id)
     #'(source
        #:visit-extension render-search-join-stage-extension
        #:extension-name name)]))
