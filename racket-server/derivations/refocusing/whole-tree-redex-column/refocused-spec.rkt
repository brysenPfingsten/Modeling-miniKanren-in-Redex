#lang racket

(require redex/reduction-semantics
         "./decomposition.rkt"
         "./refocused.rkt")

(provide initial-Z
         refocus-spec
         refocused-step/spec
         reachable-refocused/via)

;; Initialization is intentionally outside the direct transition module.  Its
;; one root decomposition is bound by the relational judgment-backed
;; decompose-one metafunction.
(define-metafunction redex-column-refocused-lang
  initial-Z : F -> Z
  [(initial-Z F) (D->Z (decompose-one F))])

;; Slow specification: reconstruct the complete contractum and invoke the root
;; decomposition judgment.  The explicit D->Z map makes the stage boundary
;; visible even though the indexed payloads are shape-isomorphic.
(define-judgment-form
  redex-column-refocused-lang
  #:contract (refocus-spec C Z)
  #:mode (refocus-spec I O)
  [(where F (plug-C C))
   (decompose/redex F D)
   (where Z (D->Z D))
   ---------------------------------------------------- "plug then redecompose specification"
   (refocus-spec C Z)])

(define-judgment-form
  redex-column-refocused-lang
  #:contract (refocused-step/spec Z ell Z)
  #:mode (refocused-step/spec I O O)
  [(where D (Z->D Z_0))
   (contract/redex D C)
   (where ell (contract-label C))
   (refocus-spec C Z_1)
   ---------------------------------------------------- "refocused step specification"
   (refocused-step/spec Z_0 ell Z_1)])

(define-judgment-form
  redex-column-refocused-lang
  #:contract (reachable-refocused/via F ZLabels Z)
  #:mode (reachable-refocused/via I O O)
  [(where Z_0 (initial-Z F))
   (refocused-steps/direct Z_0 ZLabels Z)
   ---------------------------------------------------- "reachable refocused state with trace"
   (reachable-refocused/via F ZLabels Z)])

