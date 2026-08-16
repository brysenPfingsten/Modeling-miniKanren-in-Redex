#lang racket

(require redex/reduction-semantics
         (for-syntax racket/base
                     syntax/parse))

(provide define-pk-machine-spec)

(define-syntax (define-pk-machine-spec stx)
  (syntax-parse stx
    [(_ #:machine-language machine-lang:id
        #:decompose decompose:id
        #:well-formed-frontier well-formed-frontier:id
        #:d->m d->m:id
        #:encode encode:id
        #:decode decode:id
        #:refocused-step refocused-step:id
        #:machine-step machine-step:id
        #:machine-steps machine-steps:id
        #:initial initial:id
        #:corresponds corresponds:id
        #:step-spec step-spec:id
        #:step-square step-square:id
        #:reachable reachable:id)
     #'(begin
         (define-metafunction machine-lang
           initial : F -> M
           [(initial F) (d->m D)
            (judgment-holds (decompose F D))])

         (define-judgment-form
           machine-lang
           #:contract (corresponds Z M)
           #:mode (corresponds I O)
           [(where M (encode Z))
            ------------------------------------------------ "Z/M structural correspondence"
            (corresponds Z M)])

         ;; Compositional presentation: transport a Z edge across the explicit
         ;; codec.  The direct M judgment is stated separately in the sibling
         ;; stage module.
         (define-judgment-form
           machine-lang
           #:contract (step-spec M ell M)
           #:mode (step-spec I O O)
           [(where Z_0 (decode M_0))
            (refocused-step Z_0 ell Z_1)
            (where M_1 (encode Z_1))
            ------------------------------------------------ "transported marked machine step"
            (step-spec M_0 ell M_1)])

         (define-judgment-form
           machine-lang
           #:contract (step-square Z ell Z M M)
           #:mode (step-square I O O O O)
           [(where M_0 (encode Z_0))
            (refocused-step Z_0 ell Z_1)
            (where M_1 (encode Z_1))
            (machine-step M_0 ell M_1)
            ------------------------------------------------ "commuting labeled Z/M square"
            (step-square Z_0 ell Z_1 M_0 M_1)])

         (define-judgment-form
           machine-lang
           #:contract (reachable F MLabels M)
           #:mode (reachable I O O)
           [(well-formed-frontier F)
            (where M_0 (initial F))
            (machine-steps M_0 MLabels M)
            ------------------------------------------------ "reachable marked machine with trace"
            (reachable F MLabels M)]))]))
