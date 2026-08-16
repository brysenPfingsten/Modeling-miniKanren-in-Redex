#lang racket

(require redex/reduction-semantics
         (only-in "./decomposition.rkt"
                  contract/redex
                  contract-label)
         "./labels.rkt"
         (only-in "./refocused.rkt"
                  redex-column-refocused-lang
                  non-outcome/redex))

(provide redex-column-machine-lang
         encode-ZM
         decode-MZ
         D->M
         M->D
         readback-M
         machine-refocus-query/direct
         machine-refocus/direct
         machine-step/direct
         machine-steps/direct
         machine-red/direct)

(check-redundancy #t)

;; The specialization result retains exactly two indexed control shapes.  Its
;; work alternatives are the exact focused image of Z/D, so every grammar-
;; admitted M is meaningful; the distinct M constructors make the conceptual
;; Z -> M arrow and its laws executable.
(define-extended-language redex-column-machine-lang
  redex-column-refocused-lang
  [M (MWork BR BF)
     (MWork LFR LF)
     (MWork LR WF)
     (MFrontier T FF)]
  [MQ (MQContract C)
      (MQFrontier F FF)
      (MQWork W WF)]
  [MLabels (ell ...)])

(define-metafunction redex-column-machine-lang
  encode-ZM : Z -> M
  [(encode-ZM (ZWork W WF)) (MWork W WF)]
  [(encode-ZM (ZFrontier T FF)) (MFrontier T FF)])

(define-metafunction redex-column-machine-lang
  decode-MZ : M -> Z
  [(decode-MZ (MWork W WF)) (ZWork W WF)]
  [(decode-MZ (MFrontier T FF)) (ZFrontier T FF)])

(define-metafunction redex-column-machine-lang
  D->M : D -> M
  [(D->M (DecWork W WF)) (MWork W WF)]
  [(D->M (DecFrontier T FF)) (MFrontier T FF)])

(define-metafunction redex-column-machine-lang
  M->D : M -> D
  [(M->D (MWork W WF)) (DecWork W WF)]
  [(M->D (MFrontier T FF)) (DecFrontier T FF)])

(define-metafunction redex-column-machine-lang
  readback-M : M -> F
  [(readback-M (MWork W WF)) (in-hole WF W)]
  [(readback-M (MFrontier T FF)) (in-hole FF T)])

;; This judgment is independently stated in M syntax.  It deliberately does
;; not call refocus-direct, refocused-step/direct, encode-ZM, or decode-MZ.
(define-judgment-form
  redex-column-machine-lang
  #:contract (machine-refocus-query/direct MQ M)
  #:mode (machine-refocus-query/direct I O)

  [(machine-refocus-query/direct (MQWork W WF) M)
   ---------------------------------------------------- "machine retained work contract"
   (machine-refocus-query/direct
    (MQContract (ContractWork ell W WF))
    M)]

  [(machine-refocus-query/direct (MQFrontier F FF) M)
   ---------------------------------------------------- "machine retained frontier contract"
   (machine-refocus-query/direct
    (MQContract (ContractFrontier ell F FF))
    M)]

  [(machine-refocus-query/direct
    (MQFrontier F (in-hole FF (Emit A hole)))
    M)
   ---------------------------------------------------- "machine through emit"
   (machine-refocus-query/direct (MQFrontier (Emit A F) FF) M)]

  [(machine-refocus-query/direct
    (MQFrontier F
                (in-hole FF
                         (FrontierFresh intro hole tag)))
    M)
   ---------------------------------------------------- "machine through frontier fresh"
   (machine-refocus-query/direct
    (MQFrontier (FrontierFresh intro F tag) FF)
    M)]

  [(machine-refocus-query/direct
    (MQFrontier F (in-hole FF (Forced hole)))
    M)
   ---------------------------------------------------- "machine through forced"
   (machine-refocus-query/direct (MQFrontier (Forced F) FF) M)]

  [(machine-refocus-query/direct
    (MQWork W (in-hole FF (More hole)))
    M)
   ---------------------------------------------------- "machine frontier More"
   (machine-refocus-query/direct (MQFrontier (More W) FF) M)]

  [---------------------------------------------------- "machine frontier terminal"
   (machine-refocus-query/direct
    (MQFrontier T FF)
    (MFrontier T FF))]

  [---------------------------------------------------- "machine More boundary"
   (machine-refocus-query/direct
    (MQWork BR BF)
    (MWork BR BF))]

  [---------------------------------------------------- "machine local WorkFresh redex"
   (machine-refocus-query/direct
    (MQWork LFR LF)
    (MWork LFR LF))]

  [---------------------------------------------------- "machine other local redex"
   (machine-refocus-query/direct
    (MQWork LR WF)
    (MWork LR WF))]

  [(non-outcome/redex W)
   (machine-refocus-query/direct
    (MQWork W
            (in-hole LF
                     (WorkFresh intro hole tag)))
    M)
   ---------------------------------------------------- "machine down through local work fresh"
   (machine-refocus-query/direct
    (MQWork (WorkFresh intro W tag) LF)
    M)]

  [(non-outcome/redex W)
   (machine-refocus-query/direct
    (MQWork W (in-hole WF (Conj hole g)))
    M)
   ---------------------------------------------------- "machine down through conjunction"
   (machine-refocus-query/direct (MQWork (Conj W g) WF) M)]

  [(non-outcome/redex W_1)
   (machine-refocus-query/direct
    (MQWork W_1 (in-hole WF (DisjL hole W_2)))
    M)
   ---------------------------------------------------- "machine down left choice"
   (machine-refocus-query/direct (MQWork (DisjL W_1 W_2) WF) M)]

  [(non-outcome/redex W_2)
   (machine-refocus-query/direct
    (MQWork W_2 (in-hole WF (DisjR W_1 hole)))
    M)
   ---------------------------------------------------- "machine down right choice"
   (machine-refocus-query/direct (MQWork (DisjR W_1 W_2) WF) M)]

  [(machine-refocus-query/direct
    (MQWork (in-hole WFrame R) WF)
    M)
   ---------------------------------------------------- "machine completed work up one frame"
   (machine-refocus-query/direct
    (MQWork R (in-hole WF WFrame))
    M)])

(define-judgment-form
  redex-column-machine-lang
  #:contract (machine-refocus/direct C M)
  #:mode (machine-refocus/direct I O)
  [(machine-refocus-query/direct (MQContract C) M)
   ---------------------------------------------------- "direct machine retained-context refocus"
   (machine-refocus/direct C M)])

(define-judgment-form
  redex-column-machine-lang
  #:contract (machine-step/direct M ell M)
  #:mode (machine-step/direct I O O)
  [(where D (M->D M_0))
   (contract/redex D C)
   (where ell (contract-label C))
   (machine-refocus/direct C M_1)
   ---------------------------------------------------- "direct marked machine step"
   (machine-step/direct M_0 ell M_1)])

(define-judgment-form
  redex-column-machine-lang
  #:contract (machine-steps/direct M MLabels M)
  #:mode (machine-steps/direct I O O)
  [---------------------------------------------------- "zero marked machine steps"
   (machine-steps/direct M () M)]
  [(machine-step/direct M_0 ell M_1)
   (machine-steps/direct M_1 (ell_rest ...) M_2)
   ---------------------------------------------------- "one or more marked machine steps"
   (machine-steps/direct M_0 (ell ell_rest ...) M_2)])

(define machine-red/direct
  (reduction-relation
   redex-column-machine-lang
   #:domain M
   [--> M_0 M_1
        (judgment-holds (machine-step/direct M_0 ell M_1))
        (computed-name (term (label->redex-name ell)))]))
