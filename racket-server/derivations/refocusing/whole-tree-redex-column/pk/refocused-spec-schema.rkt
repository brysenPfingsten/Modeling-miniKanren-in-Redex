#lang racket

(require redex/reduction-semantics
         (for-syntax racket/base
                     syntax/parse))

(provide define-pk-refocused-spec)

;; The slow presentation is parameterized only by the preceding arrow and the
;; direct refocused step.  It deliberately reconstructs a root before invoking
;; decomposition, making the fusion equation executable for each K instance.
(define-syntax (define-pk-refocused-spec stx)
  (syntax-parse stx
    [(_ #:refocused-language refocused-lang:id
        #:decompose decompose:id
        #:contract contract:id
        #:contract-label contract-label:id
        #:plug-contract plug-contract:id
        #:well-formed-frontier well-formed-frontier:id
        #:d->z d->z:id
        #:z->d z->d:id
        #:direct-steps direct-steps:id
        #:initial initial:id
        #:refocus-spec refocus-spec:id
        #:step-spec step-spec:id
        #:reachable reachable:id)
     #'(begin
         (define-metafunction refocused-lang
           initial : F -> Z
           [(initial F) (d->z D)
            (judgment-holds (decompose F D))])

         (define-judgment-form
           refocused-lang
           #:contract (refocus-spec C Z)
           #:mode (refocus-spec I O)
           [(where F (plug-contract C))
            (decompose F D)
            (where Z (d->z D))
            ------------------------------------------------ "plug then redecompose specification"
            (refocus-spec C Z)])

         (define-judgment-form
           refocused-lang
           #:contract (step-spec Z ell Z)
           #:mode (step-spec I O O)
           [(where D (z->d Z_0))
            (contract D C)
            (where ell (contract-label C))
            (refocus-spec C Z_1)
            ------------------------------------------------ "slow refocused step specification"
            (step-spec Z_0 ell Z_1)])

         (define-judgment-form
           refocused-lang
           #:contract (reachable F ZLabels Z)
           #:mode (reachable I O O)
           [(well-formed-frontier F)
            (where Z_0 (initial F))
            (direct-steps Z_0 ZLabels Z)
            ------------------------------------------------ "reachable refocused state with trace"
            (reachable F ZLabels Z)]))]))
