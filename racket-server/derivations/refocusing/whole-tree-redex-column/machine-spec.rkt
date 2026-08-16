#lang racket

(require redex/reduction-semantics
         "./decomposition.rkt"
         "./machine.rkt"
         "./refocused.rkt")

(provide initial-M
         machine-corresponds
         machine-step/spec
         ZM-step-square
         reachable-machine/via)

(define-metafunction redex-column-machine-lang
  initial-M : F -> M
  [(initial-M F) (D->M (decompose-one F))])

(define-judgment-form
  redex-column-machine-lang
  #:contract (machine-corresponds Z M)
  #:mode (machine-corresponds I O)
  [(where M (encode-ZM Z))
   ---------------------------------------------------- "Z/M structural correspondence"
   (machine-corresponds Z M)])

;; Compositional presentation obtained by transporting the direct refocused
;; step across the explicit codec.
(define-judgment-form
  redex-column-machine-lang
  #:contract (machine-step/spec M ell M)
  #:mode (machine-step/spec I O O)
  [(where Z_0 (decode-MZ M_0))
   (refocused-step/direct Z_0 ell Z_1)
   (where M_1 (encode-ZM Z_1))
   ---------------------------------------------------- "transported marked machine step"
   (machine-step/spec M_0 ell M_1)])

(define-judgment-form
  redex-column-machine-lang
  #:contract (ZM-step-square Z ell Z M M)
  #:mode (ZM-step-square I O O O O)
  [(where M_0 (encode-ZM Z_0))
   (refocused-step/direct Z_0 ell Z_1)
   (where M_1 (encode-ZM Z_1))
   (machine-step/direct M_0 ell M_1)
   ---------------------------------------------------- "commuting labeled Z/M square"
   (ZM-step-square Z_0 ell Z_1 M_0 M_1)])

(define-judgment-form
  redex-column-machine-lang
  #:contract (reachable-machine/via F MLabels M)
  #:mode (reachable-machine/via I O O)
  [(where M_0 (initial-M F))
   (machine-steps/direct M_0 MLabels M)
   ---------------------------------------------------- "reachable marked machine with trace"
   (reachable-machine/via F MLabels M)])

