#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         (prefix-in core: "../../core/e/wf.rkt"))

(provide wf-g-oracle/search/e?
         live-support-oracle/search/e?
         wf-W-oracle/search/e?
         wf-F-oracle/search/e?
         wf-search-oracle/e?)

(check-redundancy #t)

(define-extended-judgment-form
  search-e-oracle-lang
  core:wf-g-oracle/e?
  #:mode (wf-g-oracle/search/e? I I I)
  #:contract (wf-g-oracle/search/e? g (x ...) support)

  [(wf-g-oracle/search/e? g (x_bound ...) support)
   ---------------------------------------------------- "suspended goal/search/e"
   (wf-g-oracle/search/e? (suspend g tag) (x_bound ...) support)]

  [(wf-g-oracle/search/e? g_1 (x_bound ...) support)
   (wf-g-oracle/search/e? g_2 (x_bound ...) support)
   ---------------------------------------------------- "disjunction goal/search/e"
   (wf-g-oracle/search/e? (g_1 ∨ g_2 tag) (x_bound ...) support)])

;; Only the active-left child contributes the supply for an enclosing frame;
;; PendingDelay preserves that supply without becoming a WorkPath context.
(define-judgment-form
  search-e-oracle-lang
  #:mode (live-support-oracle/search/e? I O)
  #:contract (live-support-oracle/search/e? W support)

  [---------------------------------------------------- "work exposes support/search/e"
   (live-support-oracle/search/e?
    (Work g (state support sub dis trail tag))
    support)]

  [---------------------------------------------------- "return exposes support/search/e"
   (live-support-oracle/search/e?
    (Returned (state support sub dis trail tag))
    support)]

  [---------------------------------------------------- "failure exposes support/search/e"
   (live-support-oracle/search/e? (Dead support) support)]

  [(live-support-oracle/search/e? W support)
   ---------------------------------------------------- "support through conjunction/search/e"
   (live-support-oracle/search/e? (Conj W g) support)]

  [(live-support-oracle/search/e? W support)
   ---------------------------------------------------- "support through pending/search/e"
   (live-support-oracle/search/e? (PendingDelay W) support)]

  [(live-support-oracle/search/e? W_left support)
   ---------------------------------------------------- "support through active choice/search/e"
   (live-support-oracle/search/e? (DisjL W_left W_right) support)])

(define-judgment-form
  search-e-oracle-lang
  #:mode (wf-W-oracle/search/e? I)
  #:contract (wf-W-oracle/search/e? W)

  [(core:wf-state-oracle/e? σ)
   (where support (core:state-support/e σ))
   (wf-g-oracle/search/e? g () support)
   ---------------------------------------------------- "work/search/e"
   (wf-W-oracle/search/e? (Work g σ))]

  [(core:wf-state-oracle/e? σ)
   ---------------------------------------------------- "returned/search/e"
   (wf-W-oracle/search/e? (Returned σ))]

  [(core:wf-support-oracle/e? support)
   ---------------------------------------------------- "dead/search/e"
   (wf-W-oracle/search/e? (Dead support))]

  [(wf-W-oracle/search/e? W)
   (live-support-oracle/search/e? W support)
   (wf-g-oracle/search/e? g () support)
   ---------------------------------------------------- "conjunction/search/e"
   (wf-W-oracle/search/e? (Conj W g))]

  [(wf-W-oracle/search/e? W)
   ---------------------------------------------------- "pending delay/search/e"
   (wf-W-oracle/search/e? (PendingDelay W))]

  [(wf-W-oracle/search/e? W_1)
   (wf-W-oracle/search/e? W_2)
   ---------------------------------------------------- "active-left choice/search/e"
   (wf-W-oracle/search/e? (DisjL W_1 W_2))])

(define-judgment-form
  search-e-oracle-lang
  #:mode (wf-F-oracle/search/e? I)
  #:contract (wf-F-oracle/search/e? F)

  [(wf-W-oracle/search/e? W)
   ---------------------------------------------------- "unfinished frontier/search/e"
   (wf-F-oracle/search/e? (More W))]

  [(core:wf-A-oracle/e? A)
   ---------------------------------------------------- "last answer/search/e"
   (wf-F-oracle/search/e? (Last A))]

  [(core:wf-support-oracle/e? support)
   ---------------------------------------------------- "done/search/e"
   (wf-F-oracle/search/e? (Done support))]

  [(wf-F-oracle/search/e? F)
   ---------------------------------------------------- "forced frontier/search/e"
   (wf-F-oracle/search/e? (Forced F))]

  [(core:wf-A-oracle/e? A)
   (wf-F-oracle/search/e? F)
   ---------------------------------------------------- "emitted frontier/search/e"
   (wf-F-oracle/search/e? (Emit A F))])

(define-judgment-form
  search-e-oracle-lang
  #:mode (wf-search-oracle/e? I)
  #:contract (wf-search-oracle/e? F)
  [(wf-F-oracle/search/e? F)
   ---------------------------------------------------- "Search E root"
   (wf-search-oracle/e? F)])
