#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         (prefix-in core: "../../core/e/wf.rkt"))

(provide wf-g-oracle/disjunction/e?
         live-support-oracle/disjunction/e?
         wf-W-oracle/disjunction/e?
         wf-F-oracle/disjunction/e?
         wf-disjunction-oracle/e?)

(check-redundancy #t)

(define-extended-judgment-form
  disjunction-e-oracle-lang
  core:wf-g-oracle/e?
  #:mode (wf-g-oracle/disjunction/e? I I I)
  #:contract (wf-g-oracle/disjunction/e? g (x ...) support)

  [(wf-g-oracle/disjunction/e? g_1 (x_bound ...) support)
   (wf-g-oracle/disjunction/e? g_2 (x_bound ...) support)
   ---------------------------------------------------- "disjunction goal/disjunction/e"
   (wf-g-oracle/disjunction/e?
    (g_1 ∨ g_2 tag)
    (x_bound ...)
    support)])

;; Only the left child is active, so it alone exposes the allocation support
;; used by a surrounding active-path frame.
(define-judgment-form
  disjunction-e-oracle-lang
  #:mode (live-support-oracle/disjunction/e? I O)
  #:contract (live-support-oracle/disjunction/e? W support)

  [---------------------------------------------------- "work exposes state support/e"
   (live-support-oracle/disjunction/e?
    (Work g (state support sub dis trail tag))
    support)]

  [---------------------------------------------------- "return exposes state support/e"
   (live-support-oracle/disjunction/e?
    (Returned (state support sub dis trail tag))
    support)]

  [---------------------------------------------------- "failure exposes stored support/e"
   (live-support-oracle/disjunction/e? (Dead support) support)]

  [(live-support-oracle/disjunction/e? W support)
   ---------------------------------------------------- "support through conjunction/e"
   (live-support-oracle/disjunction/e? (Conj W g) support)]

  [(live-support-oracle/disjunction/e? W_left support)
   ---------------------------------------------------- "support through active choice/e"
   (live-support-oracle/disjunction/e?
    (DisjL W_left W_right)
    support)])

(define-judgment-form
  disjunction-e-oracle-lang
  #:mode (wf-W-oracle/disjunction/e? I)
  #:contract (wf-W-oracle/disjunction/e? W)

  [(core:wf-state-oracle/e? σ)
   (where support (core:state-support/e σ))
   (wf-g-oracle/disjunction/e? g () support)
   ---------------------------------------------------- "work/e"
   (wf-W-oracle/disjunction/e? (Work g σ))]

  [(core:wf-state-oracle/e? σ)
   ---------------------------------------------------- "returned work/e"
   (wf-W-oracle/disjunction/e? (Returned σ))]

  [(core:wf-support-oracle/e? support)
   ---------------------------------------------------- "dead work retains support/e"
   (wf-W-oracle/disjunction/e? (Dead support))]

  [(wf-W-oracle/disjunction/e? W)
   (live-support-oracle/disjunction/e? W support)
   (wf-g-oracle/disjunction/e? g () support)
   ---------------------------------------------------- "conjunction under exposed support/e"
   (wf-W-oracle/disjunction/e? (Conj W g))]

  [(wf-W-oracle/disjunction/e? W_1)
   (wf-W-oracle/disjunction/e? W_2)
   ---------------------------------------------------- "left-active choice/disjunction/e"
   (wf-W-oracle/disjunction/e? (DisjL W_1 W_2))])

(define-judgment-form
  disjunction-e-oracle-lang
  #:mode (wf-F-oracle/disjunction/e? I)
  #:contract (wf-F-oracle/disjunction/e? F)

  [(wf-W-oracle/disjunction/e? W)
   ---------------------------------------------------- "unfinished frontier/e"
   (wf-F-oracle/disjunction/e? (More W))]

  [(core:wf-A-oracle/e? A)
   ---------------------------------------------------- "last answer/e"
   (wf-F-oracle/disjunction/e? (Last A))]

  [(core:wf-support-oracle/e? support)
   ---------------------------------------------------- "done retains support/e"
   (wf-F-oracle/disjunction/e? (Done support))]

  [(core:wf-A-oracle/e? A)
   (wf-F-oracle/disjunction/e? F)
   ---------------------------------------------------- "emitted frontier/disjunction/e"
   (wf-F-oracle/disjunction/e? (Emit A F))])

(define-judgment-form
  disjunction-e-oracle-lang
  #:mode (wf-disjunction-oracle/e? I)
  #:contract (wf-disjunction-oracle/e? F)
  [(wf-F-oracle/disjunction/e? F)
   ---------------------------------------------------- "Disjunction E root"
   (wf-disjunction-oracle/e? F)])
