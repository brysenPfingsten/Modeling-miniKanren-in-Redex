#lang racket

(require redex/reduction-semantics
         (only-in "../../../../src/search-lattice/wf/kernel-base.rkt"
                  lvars-fresh-extension?
                  wf-state?
                  wf-term?)
         "./language.rkt")

(provide wf-support/e?
         wf-goal/e?
         wf-answer/e?
         wf-settled/e?
         wf-work/e?
         wf-frontier/e?
         wf-cfg/e?)

(check-redundancy #t)

;; E stores cumulative support.  The incoming environment must therefore be
;; an exact prefix of the stored Support; the stored value, not a second
;; append, is passed to the carrier payload.
(define-judgment-form
  core-e-lang
  #:contract (wf-support/e? support intro intro)
  #:mode (wf-support/e? I I O)
  [(lvars-fresh-extension? (u_new ...) (u_visible ...))
   ---------------------------------------------------- "well-formed erased support"
   (wf-support/e?
    (Support u_visible ... u_new ...)
    (u_visible ...)
    (u_visible ... u_new ...))])

(define-judgment-form
  core-e-lang
  #:contract (wf-goal/e? g (x ...) intro)
  #:mode (wf-goal/e? I I I)

  [---------------------------------------------------- "wf succeed/e"
   (wf-goal/e? (succeed tag) (x_bound ...) intro_visible)]

  [---------------------------------------------------- "wf fail/e"
   (wf-goal/e? (fail tag) (x_bound ...) intro_visible)]

  [(wf-term? t_1 (x_bound ...) intro_visible)
   (wf-term? t_2 (x_bound ...) intro_visible)
   ---------------------------------------------------- "wf unification/e"
   (wf-goal/e?
    (t_1 =? t_2 tag)
    (x_bound ...)
    intro_visible)]

  [(wf-term? t_1 (x_bound ...) intro_visible)
   (wf-term? t_2 (x_bound ...) intro_visible)
   ---------------------------------------------------- "wf disequality/e"
   (wf-goal/e?
    (t_1 != t_2 tag)
    (x_bound ...)
    intro_visible)]

  [(wf-goal/e?
    g
    (x_fresh ... x_bound ...)
    intro_visible)
   ---------------------------------------------------- "wf fresh/e"
   (wf-goal/e?
    (∃ (x_fresh ...) g tag)
    (x_bound ...)
    intro_visible)]

  [(wf-goal/e? g_1 (x_bound ...) intro_visible)
   (wf-goal/e? g_2 (x_bound ...) intro_visible)
   ---------------------------------------------------- "wf conjunction/e"
   (wf-goal/e?
    (g_1 ∧ g_2 tag)
    (x_bound ...)
    intro_visible)])

(define-judgment-form
  core-e-lang
  #:contract (wf-answer/e? A intro)
  #:mode (wf-answer/e? I I)
  [(wf-support/e? support intro_visible intro_body)
   (wf-state? σ intro_body)
   ---------------------------------------------------- "wf answer/e"
   (wf-answer/e? (Answer support σ) intro_visible)])

(define-judgment-form
  core-e-lang
  #:contract (wf-settled/e? S intro)
  #:mode (wf-settled/e? I I)
  [(wf-support/e? support intro_visible intro_body)
   (wf-state? σ intro_body)
   ---------------------------------------------------- "wf returned/e"
   (wf-settled/e? (Returned support σ) intro_visible)])

(define-judgment-form
  core-e-lang
  #:contract (wf-work/e? W intro)
  #:mode (wf-work/e? I I)

  [(wf-support/e? support intro_visible intro_body)
   (wf-goal/e? g () intro_body)
   (wf-state? σ intro_body)
   ---------------------------------------------------- "wf work/e"
   (wf-work/e? (Work support g σ) intro_visible)]

  [(wf-support/e? support intro_visible intro_body)
   (wf-state? σ intro_body)
   ---------------------------------------------------- "wf returned work/e"
   (wf-work/e? (Returned support σ) intro_visible)]

  [(wf-support/e? support intro_visible intro_body)
   ---------------------------------------------------- "wf dead/e"
   (wf-work/e? (Dead support) intro_visible)]

  [(wf-support/e? support intro_visible intro_body)
   (wf-work/e? W intro_body)
   (wf-goal/e? g () intro_body)
   ---------------------------------------------------- "wf conjunction work/e"
   (wf-work/e? (Conj support W g) intro_visible)])

(define-judgment-form
  core-e-lang
  #:contract (wf-frontier/e? F intro)
  #:mode (wf-frontier/e? I I)

  [(wf-work/e? W intro_visible)
   ---------------------------------------------------- "wf unfinished frontier/e"
   (wf-frontier/e? (More W) intro_visible)]

  [(wf-support/e? support intro_visible intro_body)
   ---------------------------------------------------- "wf done/e"
   (wf-frontier/e? (Done support) intro_visible)]

  [(wf-support/e? support intro_visible intro_body)
   (wf-answer/e? A intro_body)
   ---------------------------------------------------- "wf last/e"
   (wf-frontier/e? (Last support A) intro_visible)])

(define-judgment-form
  core-e-lang
  #:contract (wf-cfg/e? F)
  #:mode (wf-cfg/e? I)
  [(wf-frontier/e? F ())
   ---------------------------------------------------- "wf root frontier/e"
   (wf-cfg/e? F)])
