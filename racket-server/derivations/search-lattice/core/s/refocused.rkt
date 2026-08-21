#lang racket

(require redex/reduction-semantics
         "./decomposition.rkt")

(provide core-s-refocused-lang
         D->Z/s
         Z->D/s
         readback-Z/s
         refocus/spec/s
         refocus/direct/s
         refocused-step/spec/s
         refocused-step/direct/s)

(check-redundancy #t)

;; Z is deliberately a renamed, exactly D-shaped refocused carrier.  Keeping
;; the four cases visible records the codec instead of identifying D and Z by
;; a host-language convention.  Transition compression is a later stage.
(define-extended-language core-s-refocused-lang
  core-s-decomposition-lang
  [Z (ZFinal T)
     (ZWork WR WorkFocus)
     (ZFrontier FR SpineContext)
     (ZAllocate AR WorkFocus)]

  ;; Exactly the unfinished core paths: a local WR or AR, possibly below more
  ;; conjunction frames.  Returned and Dead are absent, so a conjunction with
  ;; a settled child is handled only by the WR base case.
  [OpenW WR
         AR
         (Conj owners OpenW g)])

(define-metafunction core-s-refocused-lang
  D->Z/s : D -> Z
  [(D->Z/s (Final T))
   (ZFinal T)]
  [(D->Z/s (DecWork WR WorkFocus))
   (ZWork WR WorkFocus)]
  [(D->Z/s (DecFrontier FR SpineContext))
   (ZFrontier FR SpineContext)]
  [(D->Z/s (DecAllocate AR WorkFocus))
   (ZAllocate AR WorkFocus)])

(define-metafunction core-s-refocused-lang
  Z->D/s : Z -> D
  [(Z->D/s (ZFinal T))
   (Final T)]
  [(Z->D/s (ZWork WR WorkFocus))
   (DecWork WR WorkFocus)]
  [(Z->D/s (ZFrontier FR SpineContext))
   (DecFrontier FR SpineContext)]
  [(Z->D/s (ZAllocate AR WorkFocus))
   (DecAllocate AR WorkFocus)])

;; Readback is stated directly on Z.  It is extensionally plug-D after the
;; inverse codec, but does not use that composite as its definition.
(define-metafunction core-s-refocused-lang
  readback-Z/s : Z -> F
  [(readback-Z/s (ZFinal T))
   T]
  [(readback-Z/s (ZWork WR WorkFocus))
   (in-hole WorkFocus WR)]
  [(readback-Z/s (ZFrontier FR SpineContext))
   (in-hole SpineContext FR)]
  [(readback-Z/s (ZAllocate AR WorkFocus))
   (in-hole WorkFocus AR)])

;; The slow refocusing specification deliberately reconstructs the source
;; frontier and invokes grammatical decomposition again.
(define-judgment-form
  core-s-refocused-lang
  #:contract (refocus/spec/s C Z)
  #:mode (refocus/spec/s I O)

  [(where F (plug-C/s C))
   (decompose/s F D)
   (where Z (D->Z/s D))
   ---------------------------------------------------- "plug and decompose refocus/S"
   (refocus/spec/s C Z)])

;; Direct refocusing traverses the current core WorkPath itself.  It neither
;; plugs a complete frontier nor calls decompose/s.  The OpenW restriction is
;; important: a Conj with Returned or Dead in its child is already a WR.
(define-judgment-form
  core-s-refocused-lang
  #:contract (refocus-work/direct/s W WorkFocus Z)
  #:mode (refocus-work/direct/s I I O)

  [---------------------------------------------------- "direct work redex/S"
   (refocus-work/direct/s WR WorkFocus (ZWork WR WorkFocus))]

  [---------------------------------------------------- "direct allocation redex/S"
   (refocus-work/direct/s AR WorkFocus (ZAllocate AR WorkFocus))]

  [(refocus-work/direct/s
    OpenW
    (in-hole WorkFocus (Conj owners hole g))
    Z)
   ---------------------------------------------------- "direct descend conjunction/S"
   (refocus-work/direct/s
    (Conj owners OpenW g)
    WorkFocus
    Z)]

  ;; A local success or failure turns the nearest pending conjunction frame
  ;; into the next redex.  The remaining outer frames stay separated.
  [---------------------------------------------------- "direct expose returned conjunction/S"
   (refocus-work/direct/s
    (Returned owners_inner σ)
    (in-hole WorkFocus
             (Conj owners_outer hole g))
    (ZWork
     (Conj owners_outer (Returned owners_inner σ) g)
     WorkFocus))]

  [---------------------------------------------------- "direct expose dead conjunction/S"
   (refocus-work/direct/s
    (Dead owners_inner)
    (in-hole WorkFocus
             (Conj owners_outer hole g))
    (ZWork
     (Conj owners_outer (Dead owners_inner) g)
     WorkFocus))]

  ;; SpineContext is just hole in core.  These two rules deliberately state
  ;; the current-core boundary rather than pretending to cover feature spines.
  [---------------------------------------------------- "direct returned frontier/S"
   (refocus-work/direct/s
    (Returned owners σ)
    (More hole)
    (ZFrontier (More (Returned owners σ)) hole))]

  [---------------------------------------------------- "direct dead frontier/S"
   (refocus-work/direct/s
    (Dead owners)
    (More hole)
    (ZFrontier (More (Dead owners)) hole))])

(define-judgment-form
  core-s-refocused-lang
  #:contract (refocus/direct/s C Z)
  #:mode (refocus/direct/s I O)

  [(refocus-work/direct/s W WorkFocus Z)
   ---------------------------------------------------- "direct contract-work refocus/S"
   (refocus/direct/s
    (ContractWork RuleName W WorkFocus)
    Z)]

  ;; Both core frontier contractions produce a terminal and core has no
  ;; nontrivial SpineContext.
  [---------------------------------------------------- "direct contract-frontier refocus/S"
   (refocus/direct/s
    (ContractFrontier RuleName T hole)
    (ZFinal T))])

(define-judgment-form
  core-s-refocused-lang
  #:contract (refocused-step/spec/s Z RuleName Z)
  #:mode (refocused-step/spec/s I O O)

  [(where D (Z->D/s Z_0))
   (contract/s D C)
   (where RuleName (contract-label/s C))
   (refocus/spec/s C Z_1)
   ---------------------------------------------------- "refocused step by specification/S"
   (refocused-step/spec/s Z_0 RuleName Z_1)])

(define-judgment-form
  core-s-refocused-lang
  #:contract (refocused-step/direct/s Z RuleName Z)
  #:mode (refocused-step/direct/s I O O)

  [(where D (Z->D/s Z_0))
   (contract/s D C)
   (where RuleName (contract-label/s C))
   (refocus/direct/s C Z_1)
   ---------------------------------------------------- "direct refocused step/S"
   (refocused-step/direct/s Z_0 RuleName Z_1)])

(module+ test
  (require rackunit)

  (define sigma/s
    (term (state () () () (label "state"))))
  (define owners/s (term (Owners)))

  (define root-return/s
    (term
     (ContractWork
      succeed
      (Returned ,owners/s ,sigma/s)
      (More hole))))
  (define one-frame-return/s
    (term
     (ContractWork
      succeed
      (Returned ,owners/s ,sigma/s)
      (More
       (Conj ,owners/s
             hole
             (fail (label "right")))))))
  (define two-frame-return/s
    (term
     (ContractWork
      succeed
      (Returned ,owners/s ,sigma/s)
      (More
       (Conj ,owners/s
             (Conj ,owners/s
                   hole
                   (fail (label "middle")))
             (succeed (label "outer")))))))

  (define root-dead/s
    (term
     (ContractWork
      fail
      (Dead ,owners/s)
      (More hole))))
  (define one-frame-dead/s
    (term
     (ContractWork
      fail
      (Dead ,owners/s)
      (More
       (Conj ,owners/s
             hole
             (fail (label "right")))))))
  (define two-frame-dead/s
    (term
     (ContractWork
      fail
      (Dead ,owners/s)
      (More
       (Conj ,owners/s
             (Conj ,owners/s
                   hole
                   (fail (label "middle")))
             (succeed (label "outer")))))))

  ;; These are local proof-shape checks, not a replacement for the matrix-wide
  ;; correspondence tests.  In particular, the one-frame witness would expose
  ;; any overlap between descending and the settled-Conj WR base case.
  (for ([contractum (in-list (list root-return/s
                                   one-frame-return/s
                                   two-frame-return/s
                                   root-dead/s
                                   one-frame-dead/s
                                   two-frame-dead/s))])
    (define spec-results
      (judgment-holds (refocus/spec/s ,contractum Z) Z))
    (define direct-results
      (judgment-holds (refocus/direct/s ,contractum Z) Z))
    (check-equal? direct-results spec-results)
    (check-equal? (length direct-results) 1)))
