#lang racket

(require redex/reduction-semantics)

(provide define-pk-big-step-language)

;; The promoted outcome language is independently rebuilt from each instance
;; source language.  It repeats B only so the closure specification can state
;; its input; the direct evaluator does not import compression operations.
(define-syntax-rule
  (define-pk-big-step-language
    big-step-lang
    source-lang
    big-step-readback)
  (begin
    (define-extended-language big-step-lang
      source-lang
      [B (BRun NW WF)
         (BSettled SR WF)
         (BDead WF)
         (BDelay W WF)
         (BFinal T FF)]
      [Span (transition-span ell ell (... ...))]
      [Spans (Span (... ...))]
      [O (FinalResult T FF)])

    (define-metafunction big-step-lang
      big-step-readback : O -> F
      [(big-step-readback (FinalResult T FF))
       (in-hole FF T)])))
