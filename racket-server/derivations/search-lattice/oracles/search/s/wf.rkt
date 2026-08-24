#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         (prefix-in core: "../../core/s/wf.rkt"))

(provide wf-g-oracle/search/s?
         wf-W-oracle/search/s?
         wf-F-oracle/search/s?
         wf-search-oracle/s?)

(check-redundancy #t)

(define-extended-judgment-form
  search-s-oracle-lang
  core:wf-g-oracle/s?
  #:mode (wf-g-oracle/search/s? I I I)
  #:contract (wf-g-oracle/search/s? g (x ...) intro)

  [(wf-g-oracle/search/s? g (x_bound ...) intro_visible)
   ---------------------------------------------------- "suspended goal/search/s"
   (wf-g-oracle/search/s?
    (suspend g tag)
    (x_bound ...)
    intro_visible)]

  [(wf-g-oracle/search/s? g_1 (x_bound ...) intro_visible)
   (wf-g-oracle/search/s? g_2 (x_bound ...) intro_visible)
   ---------------------------------------------------- "disjunction goal/search/s"
   (wf-g-oracle/search/s?
    (g_1 ∨ g_2 tag)
    (x_bound ...)
    intro_visible)])

;; These clauses are the transitive union of core, Delay, and Disjunction WF.
;; There is deliberately no Search-owned constructor clause.
(define-judgment-form
  search-s-oracle-lang
  #:mode (wf-W-oracle/search/s? I I)
  #:contract (wf-W-oracle/search/s? W intro)

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-g-oracle/search/s? g () intro_body)
   (core:wf-state-oracle/s? σ intro_body)
   ---------------------------------------------------- "active work/search/s"
   (wf-W-oracle/search/s? (Work owners g σ) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (core:wf-state-oracle/s? σ intro_body)
   ---------------------------------------------------- "returned work/search/s"
   (wf-W-oracle/search/s? (Returned owners σ) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   ---------------------------------------------------- "dead work/search/s"
   (wf-W-oracle/search/s? (Dead owners) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-W-oracle/search/s? W intro_body)
   (wf-g-oracle/search/s? g () intro_body)
   ---------------------------------------------------- "conjunction frame/search/s"
   (wf-W-oracle/search/s? (Conj owners W g) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-W-oracle/search/s? W intro_body)
   ---------------------------------------------------- "pending delay/search/s"
   (wf-W-oracle/search/s? (PendingDelay owners W) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-W-oracle/search/s? W_1 intro_body)
   (wf-W-oracle/search/s? W_2 intro_body)
   ---------------------------------------------------- "active-left choice/search/s"
   (wf-W-oracle/search/s? (DisjL owners W_1 W_2) intro_visible)])

(define-judgment-form
  search-s-oracle-lang
  #:mode (wf-F-oracle/search/s? I I)
  #:contract (wf-F-oracle/search/s? F intro)

  [(wf-W-oracle/search/s? W intro_visible)
   ---------------------------------------------------- "unfinished frontier/search/s"
   (wf-F-oracle/search/s? (More W) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   ---------------------------------------------------- "failed terminal/search/s"
   (wf-F-oracle/search/s? (Done owners) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (core:wf-A-oracle/s? A intro_body)
   ---------------------------------------------------- "successful terminal/search/s"
   (wf-F-oracle/search/s? (Last owners A) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-F-oracle/search/s? F intro_body)
   ---------------------------------------------------- "forced frontier/search/s"
   (wf-F-oracle/search/s? (Forced owners F) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (core:wf-A-oracle/s? A intro_body)
   (wf-F-oracle/search/s? F intro_body)
   ---------------------------------------------------- "emitted frontier/search/s"
   (wf-F-oracle/search/s? (Emit owners A F) intro_visible)])

(define-judgment-form
  search-s-oracle-lang
  #:mode (wf-search-oracle/s? I)
  #:contract (wf-search-oracle/s? F)
  [(wf-F-oracle/search/s? F ())
   ---------------------------------------------------- "Search S root"
   (wf-search-oracle/s? F)])
