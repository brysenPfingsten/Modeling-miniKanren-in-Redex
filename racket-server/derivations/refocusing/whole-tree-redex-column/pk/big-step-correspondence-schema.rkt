#lang racket

(require redex/reduction-semantics)

(provide define-pk-big-step-correspondence)


(define-syntax-rule
  (define-pk-big-step-correspondence
    big-step-direct-lang
    compressed-step/direct
    compressed-big-step/spec
    promote/direct
    big-step/spec
    big-step/direct
    big-step-square
    big-step-unfold-square
    root-big-step-square)
  (begin
    (define-judgment-form
      big-step-direct-lang
      #:contract (big-step-square B Spans O)
      #:mode (big-step-square I O O)
      [(compressed-big-step/spec B Spans O)
       (promote/direct B O)
       ---------------------------------------------------- "finite big-step square"
       (big-step-square B Spans O)])

    (define-judgment-form
      big-step-direct-lang
      #:contract (big-step-unfold-square B Span B Spans O)
      #:mode (big-step-unfold-square I O O O O)
      [(compressed-step/direct B_0 Span B_1)
       (compressed-big-step/spec
        B_0
        (Span Span_rest (... ...))
        O)
       (compressed-big-step/spec B_1 (Span_rest (... ...)) O)
       (promote/direct B_0 O)
       (promote/direct B_1 O)
       ---------------------------------------------------- "one-step fixed-point unfold"
       (big-step-unfold-square
        B_0
        Span
        B_1
        (Span_rest (... ...))
        O)])

    (define-judgment-form
      big-step-direct-lang
      #:contract (root-big-step-square F Spans O)
      #:mode (root-big-step-square I O O)
      [(big-step/spec F Spans O)
       (big-step/direct F O)
       ---------------------------------------------------- "root fixed-point square"
       (root-big-step-square F Spans O)])))
