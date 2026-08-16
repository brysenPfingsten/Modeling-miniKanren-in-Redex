#lang racket

(require redex/reduction-semantics
         (only-in "./language.rkt"
                  redex-column-source-lang))

(provide redex-column-big-step-lang
         big-step-readback)

(check-redundancy #t)

;; A promoted result retains the grammatical category of its payload: T is a
;; terminal frontier fragment and FF is an F-to-F actual-hole context.  No
;; reified W/F tag or dynamic compatibility condition is needed.
(define-extended-language redex-column-big-step-lang
  redex-column-source-lang
  [T Done (Last A)]
  [SR S SC]
  [NW (Work g st)
      (WorkFresh intro NW tag)
      (WorkFresh intro Dead tag)
      (WorkFresh intro (PendingDelay W) tag)
      (WorkFresh intro SC tag)
      (Conj W g)
      (DisjL NW W)
      (DisjL Dead W)
      (DisjL (PendingDelay W) W)
      (DisjL SC W)
      (DisjR W NW)
      (DisjR W Dead)
      (DisjR W (PendingDelay W))
      (DisjR W SC)]
  ;; B and Span are present solely so the specification module can state the
  ;; preceding-stage closure in this shared outcome language.  The direct
  ;; module imports no compressed operational artifact and never mentions
  ;; either category in a rule.
  [B (BRun NW WF)
     (BSettled SR WF)
     (BDead WF)
     (BDelay W WF)
     (BFinal T FF)]
  [Span (transition-span ell ell ...)]
  [Spans (Span ...)]
  [O (FinalResult T FF)])

(define-metafunction redex-column-big-step-lang
  big-step-readback : O -> F
  [(big-step-readback (FinalResult T FF))
   (in-hole FF T)])
