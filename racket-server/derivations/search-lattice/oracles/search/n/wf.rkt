#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         (prefix-in core: "../../core/n/wf.rkt"))

(provide wf-g-oracle/search/n?
         live-next-oracle/search/n?
         wf-W-oracle/search/n?
         wf-F-oracle/search/n?
         wf-search-oracle/n?)

(check-redundancy #t)

(define-extended-judgment-form
  search-n-oracle-lang
  core:wf-g-oracle/n?
  #:mode (wf-g-oracle/search/n? I I I)
  #:contract (wf-g-oracle/search/n? g (x ...) next)

  [(wf-g-oracle/search/n? g (x_bound ...) next)
   ---------------------------------------------------- "suspended goal/search/n"
   (wf-g-oracle/search/n? (suspend g tag) (x_bound ...) next)]

  [(wf-g-oracle/search/n? g_1 (x_bound ...) next)
   (wf-g-oracle/search/n? g_2 (x_bound ...) next)
   ---------------------------------------------------- "disjunction goal/search/n"
   (wf-g-oracle/search/n? (g_1 ∨ g_2 tag) (x_bound ...) next)])

(define-judgment-form
  search-n-oracle-lang
  #:mode (live-next-oracle/search/n? I O)
  #:contract (live-next-oracle/search/n? W next)

  [---------------------------------------------------- "work exposes next/search/n"
   (live-next-oracle/search/n?
    (Work g (state next sub dis trail tag))
    next)]

  [---------------------------------------------------- "return exposes next/search/n"
   (live-next-oracle/search/n?
    (Returned (state next sub dis trail tag))
    next)]

  [---------------------------------------------------- "failure exposes next/search/n"
   (live-next-oracle/search/n? (Dead next) next)]

  [(live-next-oracle/search/n? W next)
   ---------------------------------------------------- "next through conjunction/search/n"
   (live-next-oracle/search/n? (Conj W g) next)]

  [(live-next-oracle/search/n? W next)
   ---------------------------------------------------- "next through pending/search/n"
   (live-next-oracle/search/n? (PendingDelay W) next)]

  [(live-next-oracle/search/n? W_left next)
   ---------------------------------------------------- "next through active choice/search/n"
   (live-next-oracle/search/n? (DisjL W_left W_right) next)])

(define-judgment-form
  search-n-oracle-lang
  #:mode (wf-W-oracle/search/n? I)
  #:contract (wf-W-oracle/search/n? W)

  [(core:wf-state-oracle/n? σ)
   (where next (core:state-next/n σ))
   (wf-g-oracle/search/n? g () next)
   ---------------------------------------------------- "work/search/n"
   (wf-W-oracle/search/n? (Work g σ))]

  [(core:wf-state-oracle/n? σ)
   ---------------------------------------------------- "returned/search/n"
   (wf-W-oracle/search/n? (Returned σ))]

  [---------------------------------------------------- "dead/search/n"
   (wf-W-oracle/search/n? (Dead next))]

  [(wf-W-oracle/search/n? W)
   (live-next-oracle/search/n? W next)
   (wf-g-oracle/search/n? g () next)
   ---------------------------------------------------- "conjunction/search/n"
   (wf-W-oracle/search/n? (Conj W g))]

  [(wf-W-oracle/search/n? W)
   ---------------------------------------------------- "pending delay/search/n"
   (wf-W-oracle/search/n? (PendingDelay W))]

  [(wf-W-oracle/search/n? W_1)
   (wf-W-oracle/search/n? W_2)
   ---------------------------------------------------- "active-left choice/search/n"
   (wf-W-oracle/search/n? (DisjL W_1 W_2))])

(define-judgment-form
  search-n-oracle-lang
  #:mode (wf-F-oracle/search/n? I)
  #:contract (wf-F-oracle/search/n? F)

  [(wf-W-oracle/search/n? W)
   ---------------------------------------------------- "unfinished frontier/search/n"
   (wf-F-oracle/search/n? (More W))]

  [(core:wf-A-oracle/n? A)
   ---------------------------------------------------- "last answer/search/n"
   (wf-F-oracle/search/n? (Last A))]

  [---------------------------------------------------- "done/search/n"
   (wf-F-oracle/search/n? (Done next))]

  [(wf-F-oracle/search/n? F)
   ---------------------------------------------------- "forced frontier/search/n"
   (wf-F-oracle/search/n? (Forced F))]

  [(core:wf-A-oracle/n? A)
   (wf-F-oracle/search/n? F)
   ---------------------------------------------------- "emitted frontier/search/n"
   (wf-F-oracle/search/n? (Emit A F))])

(define-judgment-form
  search-n-oracle-lang
  #:mode (wf-search-oracle/n? I)
  #:contract (wf-search-oracle/n? F)
  [(wf-F-oracle/search/n? F)
   ---------------------------------------------------- "Search N root"
   (wf-search-oracle/n? F)])
