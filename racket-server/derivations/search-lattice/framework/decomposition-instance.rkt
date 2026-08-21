#lang racket

(require redex/reduction-semantics
         (for-syntax racket/base
                     syntax/parse))

(provide define-decomposition-instance)

;; Define the structural front half of one decomposition column.  The caller
;; supplies the source language's carrier/context nonterminals and the exact
;; grammatical partitions for this instance.  Those four partitions should be
;; syntax-disjoint when the instance claims unique decomposition; this shell
;; preserves every grammatical proof.  Semantic contract clauses live in the
;; instance module, independently of this shell.
(define-syntax (define-decomposition-instance stx)
  (syntax-parse stx
    [(_ #:source-language source-language:id
        #:decomposition-language decomposition-language:id
        #:work W:id
        #:frontier F:id
        #:work-focus WorkFocus:id
        #:spine-context SpineContext:id
        #:rule-names (rule-name-production ...)
        #:work-redexes (work-redex-production ...)
        #:frontier-redexes (frontier-redex-production ...)
        #:allocation-redexes (allocation-redex-production ...)
        #:terminals (terminal-production ...)
        #:plug-D plug-D:id
        #:plug-C plug-C:id
        #:contract-label contract-label:id
        #:decompose decompose:id)
     #'(begin
         (define-extended-language decomposition-language
           source-language
           [RuleName rule-name-production ...]
           [WR work-redex-production ...]
           [FR frontier-redex-production ...]
           [AR allocation-redex-production ...]
           [T terminal-production ...]
           [D (Final T)
              (DecWork WR WorkFocus)
              (DecFrontier FR SpineContext)
              (DecAllocate AR WorkFocus)]
           [C (ContractWork RuleName W WorkFocus)
              (ContractFrontier RuleName F SpineContext)])

         (define-metafunction decomposition-language
           plug-D : D -> F
           [(plug-D (Final T)) T]
           [(plug-D (DecWork WR WorkFocus))
            (in-hole WorkFocus WR)]
           [(plug-D (DecFrontier FR SpineContext))
            (in-hole SpineContext FR)]
           [(plug-D (DecAllocate AR WorkFocus))
            (in-hole WorkFocus AR)])

         (define-metafunction decomposition-language
           plug-C : C -> F
           [(plug-C (ContractWork RuleName W WorkFocus))
            (in-hole WorkFocus W)]
           [(plug-C (ContractFrontier RuleName F SpineContext))
            (in-hole SpineContext F)])

         (define-metafunction decomposition-language
           contract-label : C -> RuleName
           [(contract-label (ContractWork RuleName W WorkFocus)) RuleName]
           [(contract-label (ContractFrontier RuleName F SpineContext))
            RuleName])

         (define-judgment-form
           decomposition-language
           #:contract (decompose F D)
           #:mode (decompose I O)

           [------------------------------------------------ "decompose work redex"
            (decompose
             (in-hole WorkFocus WR)
             (DecWork WR WorkFocus))]

           [------------------------------------------------ "decompose frontier redex"
            (decompose
             (in-hole SpineContext FR)
             (DecFrontier FR SpineContext))]

           [------------------------------------------------ "decompose allocation redex"
            (decompose
             (in-hole WorkFocus AR)
             (DecAllocate AR WorkFocus))]

           [------------------------------------------------ "decompose terminal frontier"
            (decompose T (Final T))]))]))
