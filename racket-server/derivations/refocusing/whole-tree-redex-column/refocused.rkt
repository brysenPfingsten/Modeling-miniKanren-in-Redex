#lang racket

(require redex/reduction-semantics
         (only-in "./decomposition.rkt"
                  redex-column-decomposition-lang
                  contract/redex
                  contract-label)
         "./labels.rkt")

(provide redex-column-refocused-lang
         non-outcome/redex
         refocus-query/direct
         refocus-direct
         D->Z
         Z->D
         readback-Z
         refocused-step/direct
         refocused-steps/direct
         refocused-image
         refocused-red/direct)

(check-redundancy #t)

(define-extended-language redex-column-refocused-lang
  redex-column-decomposition-lang
  [R S
     Dead
     (PendingDelay W)
     SC]
  ;; Z is exactly the image of D.  The single ZWork constructor has three
  ;; grammar-indexed alternatives rather than admitting arbitrary unfocused
  ;; W/context pairs.
  [Z (ZWork BR BF)
     (ZWork LFR LF)
     (ZWork LR WF)
     (ZFrontier T FF)]
  ;; Q is derivation-program-point syntax for one mutually recursive Redex
  ;; judgment.  It is not an operational machine state.
  [Q (QContract C)
     (QFrontier F FF)
     (QWork W WF)]
  [ZLabels (ell ...)])

;; Executable complement of the completed-work class R.  It is used only to
;; make the downward refocusing clauses disjoint from redex/outcome clauses.
;; The judgment examines source syntax; no host predicate selects control.
(define-judgment-form
  redex-column-refocused-lang
  #:contract (non-outcome/redex W)
  #:mode (non-outcome/redex I)

  [---------------------------------------------------- "atomic work is non-outcome"
   (non-outcome/redex (Work g st))]

  [(non-outcome/redex W)
   ---------------------------------------------------- "unfinished fresh is non-outcome"
   (non-outcome/redex (WorkFresh intro W tag))]
  [---------------------------------------------------- "dead fresh redex is non-outcome"
   (non-outcome/redex (WorkFresh intro Dead tag))]
  [---------------------------------------------------- "delayed fresh redex is non-outcome"
   (non-outcome/redex (WorkFresh intro (PendingDelay W) tag))]
  [---------------------------------------------------- "choice fresh redex is non-outcome"
   (non-outcome/redex (WorkFresh intro SC tag))]

  [---------------------------------------------------- "conjunction is non-outcome"
   (non-outcome/redex (Conj W g))]

  [(non-outcome/redex W_1)
   ---------------------------------------------------- "unfinished left choice is non-outcome"
   (non-outcome/redex (DisjL W_1 W_2))]
  [---------------------------------------------------- "dead left choice is non-outcome"
   (non-outcome/redex (DisjL Dead W))]
  [---------------------------------------------------- "delayed left choice is non-outcome"
   (non-outcome/redex (DisjL (PendingDelay W_1) W_2))]
  [---------------------------------------------------- "nested left choice is non-outcome"
   (non-outcome/redex (DisjL SC W))]

  [(non-outcome/redex W_2)
   ---------------------------------------------------- "unfinished right choice is non-outcome"
   (non-outcome/redex (DisjR W_1 W_2))]
  [---------------------------------------------------- "dead right choice is non-outcome"
   (non-outcome/redex (DisjR W Dead))]
  [---------------------------------------------------- "delayed right choice is non-outcome"
   (non-outcome/redex (DisjR W_1 (PendingDelay W_2)))]
  [---------------------------------------------------- "nested right choice is non-outcome"
   (non-outcome/redex (DisjR W SC))])

(define-metafunction redex-column-refocused-lang
  D->Z : D -> Z
  [(D->Z (DecWork W WF)) (ZWork W WF)]
  [(D->Z (DecFrontier T FF)) (ZFrontier T FF)])

(define-metafunction redex-column-refocused-lang
  Z->D : Z -> D
  [(Z->D (ZWork W WF)) (DecWork W WF)]
  [(Z->D (ZFrontier T FF)) (DecFrontier T FF)])

(define-metafunction redex-column-refocused-lang
  readback-Z : Z -> F
  [(readback-Z (ZWork W WF)) (in-hole WF W)]
  [(readback-Z (ZFrontier T FF)) (in-hole FF T)])

;; The direct refocuser is one self-recursive Redex judgment so that all four
;; dispatchers can call each other without host functions or forward-reference
;; issues.  Actual-hole contexts are extended with in-hole.
(define-judgment-form
  redex-column-refocused-lang
  #:contract (refocus-query/direct Q Z)
  #:mode (refocus-query/direct I O)

  [(refocus-query/direct (QWork W WF) Z)
   ---------------------------------------------------- "refocus retained work contract"
   (refocus-query/direct
    (QContract (ContractWork ell W WF))
    Z)]

  [(refocus-query/direct (QFrontier F FF) Z)
   ---------------------------------------------------- "refocus retained frontier contract"
   (refocus-query/direct
    (QContract (ContractFrontier ell F FF))
    Z)]

  [(refocus-query/direct
    (QFrontier F (in-hole FF (Emit A hole)))
    Z)
   ---------------------------------------------------- "refocus through emit"
   (refocus-query/direct (QFrontier (Emit A F) FF) Z)]

  [(refocus-query/direct
    (QFrontier F
               (in-hole FF
                        (FrontierFresh intro hole tag)))
    Z)
   ---------------------------------------------------- "refocus through frontier fresh"
   (refocus-query/direct
    (QFrontier (FrontierFresh intro F tag) FF)
    Z)]

  [(refocus-query/direct
    (QFrontier F (in-hole FF (Forced hole)))
    Z)
   ---------------------------------------------------- "refocus through forced"
   (refocus-query/direct (QFrontier (Forced F) FF) Z)]

  [(refocus-query/direct
    (QWork W (in-hole FF (More hole)))
    Z)
   ---------------------------------------------------- "refocus frontier More"
   (refocus-query/direct (QFrontier (More W) FF) Z)]

  [---------------------------------------------------- "refocus frontier terminal"
   (refocus-query/direct (QFrontier T FF) (ZFrontier T FF))]

  ;; More-boundary priority and branch locality are properties of complete
  ;; W-to-F contexts.  BF and LF are disjoint grammar refinements of WF.
  [---------------------------------------------------- "refocus More boundary"
   (refocus-query/direct
    (QWork BR BF)
    (ZWork BR BF))]

  [---------------------------------------------------- "refocus local WorkFresh redex"
   (refocus-query/direct
    (QWork LFR LF)
    (ZWork LFR LF))]

  [---------------------------------------------------- "refocus other local redex"
   (refocus-query/direct
    (QWork LR WF)
    (ZWork LR WF))]

  ;; Descend by moving exactly one W frame from the term into the complete
  ;; W-to-F context.  WorkFresh has a separate LF-only clause: this makes a
  ;; WorkFresh immediately below More ineligible to descend, so the BF rule
  ;; above has grammatical priority without constructing an ill-sorted query.
  [(non-outcome/redex W)
   (refocus-query/direct
    (QWork W
           (in-hole LF
                    (WorkFresh intro hole tag)))
    Z)
   ---------------------------------------------------- "refocus down through local work fresh"
   (refocus-query/direct
    (QWork (WorkFresh intro W tag) LF)
    Z)]

  [(non-outcome/redex W)
   (refocus-query/direct
    (QWork W (in-hole WF (Conj hole g)))
    Z)
   ---------------------------------------------------- "refocus down through conjunction"
   (refocus-query/direct (QWork (Conj W g) WF) Z)]

  [(non-outcome/redex W_1)
   (refocus-query/direct
    (QWork W_1 (in-hole WF (DisjL hole W_2)))
    Z)
   ---------------------------------------------------- "refocus down left choice"
   (refocus-query/direct (QWork (DisjL W_1 W_2) WF) Z)]

  [(non-outcome/redex W_2)
   (refocus-query/direct
    (QWork W_2 (in-hole WF (DisjR W_1 hole)))
    Z)
   ---------------------------------------------------- "refocus down right choice"
   (refocus-query/direct (QWork (DisjR W_1 W_2) WF) Z)]

  ;; Completed work moves in the other direction.  WFrame is exactly one
  ;; frame, so this inverse decomposition exposes the frame adjacent to the
  ;; hole uniquely; no QResume control form is needed.
  [(refocus-query/direct
    (QWork (in-hole WFrame R) WF)
    Z)
   ---------------------------------------------------- "refocus completed work up one frame"
   (refocus-query/direct
    (QWork R (in-hole WF WFrame))
    Z)])

(define-judgment-form
  redex-column-refocused-lang
  #:contract (refocus-direct C Z)
  #:mode (refocus-direct I O)
  [(refocus-query/direct (QContract C) Z)
   ---------------------------------------------------- "direct retained-context refocus"
   (refocus-direct C Z)])

(define-judgment-form
  redex-column-refocused-lang
  #:contract (refocused-step/direct Z ell Z)
  #:mode (refocused-step/direct I O O)
  [(where D (Z->D Z_0))
   (contract/redex D C)
   (where ell (contract-label C))
   (refocus-direct C Z_1)
   ---------------------------------------------------- "refocused step direct"
   (refocused-step/direct Z_0 ell Z_1)])

(define-judgment-form
  redex-column-refocused-lang
  #:contract (refocused-steps/direct Z ZLabels Z)
  #:mode (refocused-steps/direct I O O)
  [---------------------------------------------------- "zero refocused steps"
   (refocused-steps/direct Z () Z)]
  [(refocused-step/direct Z_0 ell Z_1)
   (refocused-steps/direct Z_1 (ell_rest ...) Z_2)
   ---------------------------------------------------- "one or more refocused steps"
   (refocused-steps/direct Z_0 (ell ell_rest ...) Z_2)])

(define-judgment-form
  redex-column-refocused-lang
  #:contract (refocused-image D Z)
  #:mode (refocused-image I O)
  [(where Z (D->Z D))
   ---------------------------------------------------- "refocused structural image"
   (refocused-image D Z)])

;; A named reduction relation projection supports traces and complete named
;; successor queries.  Rule selection and successor construction occur in the
;; direct Redex judgment above; the computed name projects its first-class mark.
(define refocused-red/direct
  (reduction-relation
   redex-column-refocused-lang
   #:domain Z
   [--> Z_0 Z_1
        (judgment-holds (refocused-step/direct Z_0 ell Z_1))
        (computed-name (term (label->redex-name ell)))]))
