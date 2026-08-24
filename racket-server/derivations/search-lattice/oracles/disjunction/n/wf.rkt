#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         (prefix-in core: "../../core/n/wf.rkt"))

(provide wf-g-oracle/disjunction/n?
         live-next-oracle/disjunction/n?
         wf-W-oracle/disjunction/n?
         wf-F-oracle/disjunction/n?
         wf-disjunction-oracle/n?)

(check-redundancy #t)

(define-extended-judgment-form
  disjunction-n-oracle-lang
  core:wf-g-oracle/n?
  #:mode (wf-g-oracle/disjunction/n? I I I)
  #:contract (wf-g-oracle/disjunction/n? g (x ...) next)

  [(wf-g-oracle/disjunction/n? g_1 (x_bound ...) next)
   (wf-g-oracle/disjunction/n? g_2 (x_bound ...) next)
   ---------------------------------------------------- "disjunction goal/disjunction/n"
   (wf-g-oracle/disjunction/n?
    (g_1 ∨ g_2 tag)
    (x_bound ...)
    next)])

(define-judgment-form
  disjunction-n-oracle-lang
  #:mode (live-next-oracle/disjunction/n? I O)
  #:contract (live-next-oracle/disjunction/n? W next)

  [---------------------------------------------------- "work exposes next/n"
   (live-next-oracle/disjunction/n?
    (Work g (state next sub dis trail tag))
    next)]

  [---------------------------------------------------- "return exposes next/n"
   (live-next-oracle/disjunction/n?
    (Returned (state next sub dis trail tag))
    next)]

  [---------------------------------------------------- "failure exposes stored next/n"
   (live-next-oracle/disjunction/n? (Dead next) next)]

  [(live-next-oracle/disjunction/n? W next)
   ---------------------------------------------------- "next through conjunction/n"
   (live-next-oracle/disjunction/n? (Conj W g) next)]

  [(live-next-oracle/disjunction/n? W_left next)
   ---------------------------------------------------- "next through active choice/n"
   (live-next-oracle/disjunction/n?
    (DisjL W_left W_right)
    next)])

(define-judgment-form
  disjunction-n-oracle-lang
  #:mode (wf-W-oracle/disjunction/n? I)
  #:contract (wf-W-oracle/disjunction/n? W)

  [(core:wf-state-oracle/n? σ)
   (where next (core:state-next/n σ))
   (wf-g-oracle/disjunction/n? g () next)
   ---------------------------------------------------- "work/n"
   (wf-W-oracle/disjunction/n? (Work g σ))]

  [(core:wf-state-oracle/n? σ)
   ---------------------------------------------------- "returned work/n"
   (wf-W-oracle/disjunction/n? (Returned σ))]

  [---------------------------------------------------- "dead work retains next/n"
   (wf-W-oracle/disjunction/n? (Dead next))]

  [(wf-W-oracle/disjunction/n? W)
   (live-next-oracle/disjunction/n? W next)
   (wf-g-oracle/disjunction/n? g () next)
   ---------------------------------------------------- "conjunction under exposed next/n"
   (wf-W-oracle/disjunction/n? (Conj W g))]

  [(wf-W-oracle/disjunction/n? W_1)
   (wf-W-oracle/disjunction/n? W_2)
   ---------------------------------------------------- "left-active choice/disjunction/n"
   (wf-W-oracle/disjunction/n? (DisjL W_1 W_2))])

(define-judgment-form
  disjunction-n-oracle-lang
  #:mode (wf-F-oracle/disjunction/n? I)
  #:contract (wf-F-oracle/disjunction/n? F)

  [(wf-W-oracle/disjunction/n? W)
   ---------------------------------------------------- "unfinished frontier/n"
   (wf-F-oracle/disjunction/n? (More W))]

  [(core:wf-A-oracle/n? A)
   ---------------------------------------------------- "last answer/n"
   (wf-F-oracle/disjunction/n? (Last A))]

  [---------------------------------------------------- "done retains next/n"
   (wf-F-oracle/disjunction/n? (Done next))]

  [(core:wf-A-oracle/n? A)
   (wf-F-oracle/disjunction/n? F)
   ---------------------------------------------------- "emitted frontier/disjunction/n"
   (wf-F-oracle/disjunction/n? (Emit A F))])

(define-judgment-form
  disjunction-n-oracle-lang
  #:mode (wf-disjunction-oracle/n? I)
  #:contract (wf-disjunction-oracle/n? F)
  [(wf-F-oracle/disjunction/n? F)
   ---------------------------------------------------- "Disjunction N root"
   (wf-disjunction-oracle/n? F)])
