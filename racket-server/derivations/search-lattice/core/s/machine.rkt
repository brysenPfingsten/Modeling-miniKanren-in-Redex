#lang racket

(require redex/reduction-semantics
         (only-in "./decomposition.rkt"
                  contract/s
                  contract-label/s)
         "./refocused.rkt")

(provide core-s-machine-lang
         encode-ZM/s
         decode-MZ/s
         D->M/s
         M->D/s
         readback-M/s
         machine-refocus-work/direct/s
         machine-refocus/direct/s
         machine-step/direct/s
         machine-steps/direct/s
         machine-red/direct/s)

(check-redundancy #t)

;; Transition specialization leaves the public carrier shape unchanged.  M is
;; nevertheless a distinct Redex artifact: its direct refocuser below repeats
;; the retained-context equations in M syntax and never calls the Z refocuser,
;; Z stepper, or either Z/M codec.
(define-extended-language core-s-machine-lang
  core-s-refocused-lang
  [M (MFinal T)
     (MWork WR WorkFocus)
     (MFrontier FR SpineContext)
     (MAllocate AR WorkFocus)]

  ;; Private derivation program points.  MOpenW is stated independently of Z's
  ;; OpenW partition so the direct machine refocuser owns its control cases.
  [MOpenW WR
          AR
          (Conj owners MOpenW g)]

  [MLabels (RuleName ...)])

(define-metafunction core-s-machine-lang
  encode-ZM/s : Z -> M
  [(encode-ZM/s (ZFinal T))
   (MFinal T)]
  [(encode-ZM/s (ZWork WR WorkFocus))
   (MWork WR WorkFocus)]
  [(encode-ZM/s (ZFrontier FR SpineContext))
   (MFrontier FR SpineContext)]
  [(encode-ZM/s (ZAllocate AR WorkFocus))
   (MAllocate AR WorkFocus)])

(define-metafunction core-s-machine-lang
  decode-MZ/s : M -> Z
  [(decode-MZ/s (MFinal T))
   (ZFinal T)]
  [(decode-MZ/s (MWork WR WorkFocus))
   (ZWork WR WorkFocus)]
  [(decode-MZ/s (MFrontier FR SpineContext))
   (ZFrontier FR SpineContext)]
  [(decode-MZ/s (MAllocate AR WorkFocus))
   (ZAllocate AR WorkFocus)])

(define-metafunction core-s-machine-lang
  D->M/s : D -> M
  [(D->M/s (Final T))
   (MFinal T)]
  [(D->M/s (DecWork WR WorkFocus))
   (MWork WR WorkFocus)]
  [(D->M/s (DecFrontier FR SpineContext))
   (MFrontier FR SpineContext)]
  [(D->M/s (DecAllocate AR WorkFocus))
   (MAllocate AR WorkFocus)])

(define-metafunction core-s-machine-lang
  M->D/s : M -> D
  [(M->D/s (MFinal T))
   (Final T)]
  [(M->D/s (MWork WR WorkFocus))
   (DecWork WR WorkFocus)]
  [(M->D/s (MFrontier FR SpineContext))
   (DecFrontier FR SpineContext)]
  [(M->D/s (MAllocate AR WorkFocus))
   (DecAllocate AR WorkFocus)])

;; Readback is direct on M rather than an abbreviation through either codec.
(define-metafunction core-s-machine-lang
  readback-M/s : M -> F
  [(readback-M/s (MFinal T))
   T]
  [(readback-M/s (MWork WR WorkFocus))
   (in-hole WorkFocus WR)]
  [(readback-M/s (MFrontier FR SpineContext))
   (in-hole SpineContext FR)]
  [(readback-M/s (MAllocate AR WorkFocus))
   (in-hole WorkFocus AR)])

;; Independently specialized retained-context refocusing.  These clauses are
;; deliberately not factored through refocus-work/direct/s.
(define-judgment-form
  core-s-machine-lang
  #:contract (machine-refocus-work/direct/s W WorkFocus M)
  #:mode (machine-refocus-work/direct/s I I O)

  [---------------------------------------------------- "machine work redex/S"
   (machine-refocus-work/direct/s
    WR
    WorkFocus
    (MWork WR WorkFocus))]

  [---------------------------------------------------- "machine allocation redex/S"
   (machine-refocus-work/direct/s
    AR
    WorkFocus
    (MAllocate AR WorkFocus))]

  [(machine-refocus-work/direct/s
    MOpenW
    (in-hole WorkFocus (Conj owners hole g))
    M)
   ---------------------------------------------------- "machine descend conjunction/S"
   (machine-refocus-work/direct/s
    (Conj owners MOpenW g)
    WorkFocus
    M)]

  [---------------------------------------------------- "machine expose returned conjunction/S"
   (machine-refocus-work/direct/s
    (Returned owners_inner σ)
    (in-hole WorkFocus
             (Conj owners_outer hole g))
    (MWork
     (Conj owners_outer (Returned owners_inner σ) g)
     WorkFocus))]

  [---------------------------------------------------- "machine expose dead conjunction/S"
   (machine-refocus-work/direct/s
    (Dead owners_inner)
    (in-hole WorkFocus
             (Conj owners_outer hole g))
    (MWork
     (Conj owners_outer (Dead owners_inner) g)
     WorkFocus))]

  [---------------------------------------------------- "machine returned frontier/S"
   (machine-refocus-work/direct/s
    (Returned owners σ)
    (More hole)
    (MFrontier (More (Returned owners σ)) hole))]

  [---------------------------------------------------- "machine dead frontier/S"
   (machine-refocus-work/direct/s
    (Dead owners)
    (More hole)
    (MFrontier (More (Dead owners)) hole))])

(define-judgment-form
  core-s-machine-lang
  #:contract (machine-refocus/direct/s C M)
  #:mode (machine-refocus/direct/s I O)

  [(machine-refocus-work/direct/s W WorkFocus M)
   ---------------------------------------------------- "machine retained work context/S"
   (machine-refocus/direct/s
    (ContractWork RuleName W WorkFocus)
    M)]

  ;; Core has no nontrivial SpineContext, and both frontier contractions return
  ;; a terminal T.
  [---------------------------------------------------- "machine terminal frontier/S"
   (machine-refocus/direct/s
    (ContractFrontier RuleName T hole)
    (MFinal T))])

(define-judgment-form
  core-s-machine-lang
  #:contract (machine-step/direct/s M RuleName M)
  #:mode (machine-step/direct/s I O O)

  [(where D (M->D/s M_0))
   (contract/s D C)
   (where RuleName (contract-label/s C))
   (machine-refocus/direct/s C M_1)
   ---------------------------------------------------- "direct exact machine step/S"
   (machine-step/direct/s M_0 RuleName M_1)])

(define-judgment-form
  core-s-machine-lang
  #:contract (machine-steps/direct/s M MLabels M)
  #:mode (machine-steps/direct/s I O O)

  [---------------------------------------------------- "zero exact machine steps/S"
   (machine-steps/direct/s M () M)]

  [(machine-step/direct/s M_0 RuleName M_1)
   (machine-steps/direct/s
    M_1
    (RuleName_rest ...)
    M_2)
   ---------------------------------------------------- "one or more exact machine steps/S"
   (machine-steps/direct/s
    M_0
    (RuleName RuleName_rest ...)
    M_2)])

(define-metafunction core-s-machine-lang
  rule-name->string/s : RuleName -> string
  [(rule-name->string/s RuleName)
   ,(symbol->string (term RuleName))])

;; This relation is only a named visualization/trace projection; the judgment
;; above is the authoritative direct artifact.
(define machine-red/direct/s
  (reduction-relation
   core-s-machine-lang
   #:domain M
   [--> M_0 M_1
        (judgment-holds
         (machine-step/direct/s M_0 RuleName M_1))
        (computed-name
         (term (rule-name->string/s RuleName)))]))

(module+ test
  (require rackunit)

  (define sigma/s
    (term (state () () () (label "state"))))

  (define z-cases/s
    (list
     (term (ZFinal (Done (Owners))))
     (term
      (ZWork
       (Work (Owners) (succeed (label "yes")) ,sigma/s)
       (More hole)))
     (term
      (ZFrontier
       (More (Returned (Owners) ,sigma/s))
       hole))
     (term
      (ZAllocate
       (Work
        (Owners)
        (∃ (x:q) (succeed (label "body")) (label "fresh"))
        ,sigma/s)
       (More hole)))))

  (for ([z (in-list z-cases/s)])
    (define machine (term (encode-ZM/s ,z)))
    (check-true (redex-match? core-s-machine-lang M machine))
    (check-equal? (term (decode-MZ/s ,machine)) z)
    (check-equal? (term (readback-M/s ,machine))
                  (term (readback-Z/s ,z))))

  (define succeed-machine/s
    (term
     (MWork
      (Work (Owners) (succeed (label "yes")) ,sigma/s)
      (More hole))))

  (define direct-proofs/s
    (build-derivations
     (machine-step/direct/s
      ,succeed-machine/s
      RuleName
      M_next)))

  (check-equal? (length direct-proofs/s) 1)
  (check-equal?
   (judgment-holds
    (machine-step/direct/s
     ,succeed-machine/s
     RuleName
     M_next)
    (RuleName M_next))
   (list
    (term
     (succeed
      (MFrontier
       (More (Returned (Owners) ,sigma/s))
       hole)))))

  (check-equal?
   (length
    (build-derivations
     (machine-step/direct/s
      (MFinal (Done (Owners)))
      RuleName
      M_next)))
   0))
