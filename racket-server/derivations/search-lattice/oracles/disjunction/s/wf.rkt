#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         (prefix-in core: "../../core/s/wf.rkt"))

(provide wf-g-oracle/disjunction/s?
         wf-W-oracle/disjunction/s?
         wf-F-oracle/disjunction/s?
         wf-disjunction-oracle/s?)

(check-redundancy #t)

(define-extended-judgment-form
  disjunction-s-oracle-lang
  core:wf-g-oracle/s?
  #:mode (wf-g-oracle/disjunction/s? I I I)
  #:contract (wf-g-oracle/disjunction/s? g (x ...) intro)

  [(wf-g-oracle/disjunction/s? g_1 (x_bound ...) intro_visible)
   (wf-g-oracle/disjunction/s? g_2 (x_bound ...) intro_visible)
   ---------------------------------------------------- "disjunction goal/disjunction/s"
   (wf-g-oracle/disjunction/s?
    (g_1 ∨ g_2 tag)
    (x_bound ...)
    intro_visible)])

;; Work, Conj, and More are restated so their recursive premises use this
;; feature's goal/work judgments.  Returned, Dead, Last, and Done remain the
;; inherited core clauses.
(define-overriding-judgment-form
  disjunction-s-oracle-lang
  core:wf-W-oracle/s?
  #:mode (wf-W-oracle/disjunction/s? I I)
  #:contract (wf-W-oracle/disjunction/s? W intro)

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-g-oracle/disjunction/s? g () intro_body)
   (core:wf-state-oracle/s? σ intro_body)
   ---------------------------------------------------- "active work/s"
   (wf-W-oracle/disjunction/s? (Work owners g σ) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-W-oracle/disjunction/s? W intro_body)
   (wf-g-oracle/disjunction/s? g () intro_body)
   ---------------------------------------------------- "conjunction frame/s"
   (wf-W-oracle/disjunction/s?
    (Conj owners W g)
    intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-W-oracle/disjunction/s? W_1 intro_body)
   (wf-W-oracle/disjunction/s? W_2 intro_body)
   ---------------------------------------------------- "left-active choice/disjunction/s"
   (wf-W-oracle/disjunction/s?
    (DisjL owners W_1 W_2)
    intro_visible)])

(define-overriding-judgment-form
  disjunction-s-oracle-lang
  core:wf-F-oracle/s?
  #:mode (wf-F-oracle/disjunction/s? I I)
  #:contract (wf-F-oracle/disjunction/s? F intro)

  [(wf-W-oracle/disjunction/s? W intro_visible)
   ---------------------------------------------------- "unfinished frontier/s"
   (wf-F-oracle/disjunction/s? (More W) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (core:wf-A-oracle/s? A intro_body)
   (wf-F-oracle/disjunction/s? F intro_body)
   ---------------------------------------------------- "emitted frontier/disjunction/s"
   (wf-F-oracle/disjunction/s?
    (Emit owners A F)
    intro_visible)])

(define-judgment-form
  disjunction-s-oracle-lang
  #:mode (wf-disjunction-oracle/s? I)
  #:contract (wf-disjunction-oracle/s? F)
  [(wf-F-oracle/disjunction/s? F ())
   ---------------------------------------------------- "Disjunction S root"
   (wf-disjunction-oracle/s? F)])
