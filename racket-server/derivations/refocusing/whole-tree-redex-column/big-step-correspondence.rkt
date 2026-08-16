#lang racket

(require redex/reduction-semantics
         "./big-step.rkt"
         "./big-step-spec.rkt"
         (only-in "./compressed.rkt"
                  compressed-step/direct))

(provide big-step-square
         big-step-unfold-square
         root-big-step-square)

(check-redundancy #t)

;; The conceptual B -> B-downarrow arrow.  Binding the same O in both
;; premises makes agreement an explicit Redex correspondence judgment; tests
;; separately compare complete output sets to establish preservation and
;; reflection on the reachable image.
(define-judgment-form
  redex-column-big-step-direct-lang
  #:contract (big-step-square B Spans O)
  #:mode (big-step-square I O O)
  [(compressed-big-step/spec B Spans O)
   (promote/direct B O)
   ---------------------------------------------------- "finite big-step square"
   (big-step-square B Spans O)])

;; One compressed edge removes exactly the head certificate from the strict
;; driver while leaving the direct promoted outcome invariant.
(define-judgment-form
  redex-column-big-step-direct-lang
  #:contract (big-step-unfold-square B Span B Spans O)
  #:mode (big-step-unfold-square I O O O O)
  [(compressed-step/direct B_0 Span B_1)
   (compressed-big-step/spec
    B_0
    (Span Span_rest ...)
    O)
   (compressed-big-step/spec B_1 (Span_rest ...) O)
   (promote/direct B_0 O)
   (promote/direct B_1 O)
   ---------------------------------------------------- "one-step fixed-point unfold"
   (big-step-unfold-square
    B_0
    Span
    B_1
    (Span_rest ...)
    O)])

;; Root evaluation is a separate composition: the specification initializes
;; B and drives it, while the direct artifact enters the fixed point from F
;; without constructing a compressed state.
(define-judgment-form
  redex-column-big-step-direct-lang
  #:contract (root-big-step-square F Spans O)
  #:mode (root-big-step-square I O O)
  [(big-step/spec F Spans O)
   (big-step/direct F O)
   ---------------------------------------------------- "root fixed-point square"
   (root-big-step-square F Spans O)])
