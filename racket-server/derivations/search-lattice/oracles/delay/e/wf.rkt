#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         (prefix-in core: "../../core/e/wf.rkt"))

(provide wf-g-oracle/delay/e?
         live-support-oracle/delay/e?
         wf-W-oracle/delay/e?
         wf-F-oracle/delay/e?
         wf-delay-oracle/e?)

(check-redundancy #t)

(define-extended-judgment-form
  delay-e-oracle-lang
  core:wf-g-oracle/e?
  #:mode (wf-g-oracle/delay/e? I I I)
  #:contract (wf-g-oracle/delay/e? g (x ...) support)

  [(wf-g-oracle/delay/e? g (x_bound ...) support)
   ---------------------------------------------------- "suspended goal/delay/e"
   (wf-g-oracle/delay/e?
    (suspend g tag)
    (x_bound ...)
    support)])

(define-extended-judgment-form
  delay-e-oracle-lang
  core:live-support-oracle/e?
  #:mode (live-support-oracle/delay/e? I O)
  #:contract (live-support-oracle/delay/e? W support)

  [(live-support-oracle/delay/e? W support)
   ---------------------------------------------------- "support through pending delay/e"
   (live-support-oracle/delay/e? (PendingDelay W) support)])

(define-overriding-judgment-form
  delay-e-oracle-lang
  core:wf-W-oracle/e?
  #:mode (wf-W-oracle/delay/e? I)
  #:contract (wf-W-oracle/delay/e? W)

  [(core:wf-state-oracle/e? σ)
   (where support (core:state-support/e σ))
   (wf-g-oracle/delay/e? g () support)
   ---------------------------------------------------- "work/e"
   (wf-W-oracle/delay/e? (Work g σ))]

  [(wf-W-oracle/delay/e? W)
   (live-support-oracle/delay/e? W support)
   (wf-g-oracle/delay/e? g () support)
   ---------------------------------------------------- "conjunction closed by exposed support/e"
   (wf-W-oracle/delay/e? (Conj W g))]

  [(wf-W-oracle/delay/e? W)
   ---------------------------------------------------- "pending delay/delay/e"
   (wf-W-oracle/delay/e? (PendingDelay W))])

(define-overriding-judgment-form
  delay-e-oracle-lang
  core:wf-F-oracle/e?
  #:mode (wf-F-oracle/delay/e? I)
  #:contract (wf-F-oracle/delay/e? F)

  [(wf-W-oracle/delay/e? W)
   ---------------------------------------------------- "unfinished frontier/e"
   (wf-F-oracle/delay/e? (More W))]

  [(wf-F-oracle/delay/e? F)
   ---------------------------------------------------- "forced frontier/delay/e"
   (wf-F-oracle/delay/e? (Forced F))])

(define-judgment-form
  delay-e-oracle-lang
  #:mode (wf-delay-oracle/e? I)
  #:contract (wf-delay-oracle/e? F)
  [(wf-F-oracle/delay/e? F)
   ---------------------------------------------------- "Delay E root"
   (wf-delay-oracle/e? F)])
