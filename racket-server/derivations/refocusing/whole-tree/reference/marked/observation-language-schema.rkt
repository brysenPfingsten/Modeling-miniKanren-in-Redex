#lang racket

(require redex/reduction-semantics)

(provide define-pk-observation-language)

;; Observation syntax is deliberately outside the operational carrier.  In
;; particular, FTail and FF are grammatical result indices for a derived view;
;; they are not tags stored in source or machine states.
(define-syntax-rule
  (define-pk-observation-language language-id source-language-id)
  (define-extended-language language-id
    source-language-id
    [FTail (More W) Done (Last A)]
    [ScopeOwner (Owner intro tag)]
    [SA (ScopedAnswer kst (ScopeOwner (... ...)))]
    [FrontierEvent (FrontierFreshEvent intro tag)
                   (EmitEvent A)
                   ForcedEvent]
    [ForceEvent ForcedEvent]
    [AllocationEvent (AllocateEvent tag lexical intro)]
    [Labels (ell (... ...))]
    [TraceEdge (Edge F ell F)]
    [Trace (TraceEdge (... ...))]
    [n natural]))
