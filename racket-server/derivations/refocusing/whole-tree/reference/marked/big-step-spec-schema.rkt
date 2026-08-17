#lang racket

(require redex/reduction-semantics)

(provide define-pk-big-step-spec)

;; This macro is intentionally separate from the direct promoted schema. It
;; obtains the specification only by closing the preceding compressed step.
(define-syntax-rule
  (define-pk-big-step-spec
    big-step-lang
    compressed-step/direct
    initial-compressed/direct
    wf-frontier/K
    compressed-big-step/spec
    compressed-big-step-result/spec
    big-step/spec
    big-step-result/spec)
  (begin
    (define-judgment-form
      big-step-lang
      #:contract (compressed-big-step/spec B Spans O)
      #:mode (compressed-big-step/spec I O O)

      [---------------------------------------------------- "big-step spec final"
       (compressed-big-step/spec
        (BFinal T FF)
        ()
        (FinalResult T FF))]

      [(compressed-step/direct B_0 Span B_1)
       (compressed-big-step/spec B_1 (Span_rest (... ...)) O)
       ---------------------------------------------------- "big-step spec step"
       (compressed-big-step/spec
        B_0
        (Span Span_rest (... ...))
        O)])

    (define-judgment-form
      big-step-lang
      #:contract (compressed-big-step-result/spec B O)
      #:mode (compressed-big-step-result/spec I O)
      [(compressed-big-step/spec B Spans O)
       ---------------------------------------------------- "project big-step spec"
       (compressed-big-step-result/spec B O)])

    (define-judgment-form
      big-step-lang
      #:contract (big-step/spec F Spans O)
      #:mode (big-step/spec I O O)

      [(wf-frontier/K F)
       (initial-compressed/direct F B)
       (compressed-big-step/spec B Spans O)
       ---------------------------------------------------- "big-step spec root"
       (big-step/spec F Spans O)])

    (define-judgment-form
      big-step-lang
      #:contract (big-step-result/spec F O)
      #:mode (big-step-result/spec I O)
      [(big-step/spec F Spans O)
       ---------------------------------------------------- "project root big-step spec"
       (big-step-result/spec F O)])))
