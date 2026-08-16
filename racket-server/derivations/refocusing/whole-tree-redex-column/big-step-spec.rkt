#lang racket

(require redex/reduction-semantics
         "./big-step-language.rkt"
         (only-in "./compressed.rkt"
                  compressed-step/direct
                  initial-compressed/direct)
         (only-in "./kernel-toy.rkt"
                  wf-frontier/toy))

(provide compressed-big-step/spec
         compressed-big-step-result/spec
         big-step/spec
         big-step-result/spec)

(check-redundancy #t)

;; The specification is the strict compressed driver.  Its only base case is
;; an already-terminal compressed state; every other finite derivation must
;; expose one nonempty certified compressed step before recurring.
(define-judgment-form
  redex-column-big-step-lang
  #:contract (compressed-big-step/spec B Spans O)
  #:mode (compressed-big-step/spec I O O)

  [---------------------------------------------------- "big-step spec final"
   (compressed-big-step/spec
    (BFinal T FF)
    ()
    (FinalResult T FF))]

  [(compressed-step/direct B_0 Span B_1)
   (compressed-big-step/spec
    B_1
    (Span_rest ...)
    O)
   ---------------------------------------------------- "big-step spec step"
   (compressed-big-step/spec
    B_0
    (Span Span_rest ...)
    O)])

(define-judgment-form
  redex-column-big-step-lang
  #:contract (compressed-big-step-result/spec B O)
  #:mode (compressed-big-step-result/spec I O)
  [(compressed-big-step/spec B Spans O)
   ---------------------------------------------------- "project big-step spec"
   (compressed-big-step-result/spec B O)])

;; Root evaluation is composition with the direct compressed initializer.
(define-judgment-form
  redex-column-big-step-lang
  #:contract (big-step/spec F Spans O)
  #:mode (big-step/spec I O O)

  [(wf-frontier/toy F)
   (initial-compressed/direct F B)
   (compressed-big-step/spec B Spans O)
   ---------------------------------------------------- "big-step spec root"
   (big-step/spec F Spans O)])

(define-judgment-form
  redex-column-big-step-lang
  #:contract (big-step-result/spec F O)
  #:mode (big-step-result/spec I O)
  [(big-step/spec F Spans O)
   ---------------------------------------------------- "project root big-step spec"
   (big-step-result/spec F O)])
