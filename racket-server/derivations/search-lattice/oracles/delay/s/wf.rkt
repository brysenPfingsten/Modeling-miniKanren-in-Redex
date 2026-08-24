#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         (prefix-in core: "../../core/s/wf.rkt"))

(provide wf-g-oracle/delay/s?
         wf-W-oracle/delay/s?
         wf-F-oracle/delay/s?
         wf-delay-oracle/s?)

(check-redundancy #t)

(define-extended-judgment-form
  delay-s-oracle-lang
  core:wf-g-oracle/s?
  #:mode (wf-g-oracle/delay/s? I I I)
  #:contract (wf-g-oracle/delay/s? g (x ...) intro)

  [(wf-g-oracle/delay/s? g (x_bound ...) intro_visible)
   ---------------------------------------------------- "suspended goal/delay/s"
   (wf-g-oracle/delay/s?
    (suspend g tag)
    (x_bound ...)
    intro_visible)])

;; Override only the inherited carrier clauses whose dependencies must see the
;; extended goal/work judgments.  Returned and Dead remain inherited verbatim.
(define-overriding-judgment-form
  delay-s-oracle-lang
  core:wf-W-oracle/s?
  #:mode (wf-W-oracle/delay/s? I I)
  #:contract (wf-W-oracle/delay/s? W intro)

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-g-oracle/delay/s? g () intro_body)
   (core:wf-state-oracle/s? σ intro_body)
   ---------------------------------------------------- "active work/s"
   (wf-W-oracle/delay/s? (Work owners g σ) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-W-oracle/delay/s? W intro_body)
   (wf-g-oracle/delay/s? g () intro_body)
   ---------------------------------------------------- "conjunction frame/s"
   (wf-W-oracle/delay/s?
    (Conj owners W g)
    intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-W-oracle/delay/s? W intro_body)
   ---------------------------------------------------- "pending delay/delay/s"
   (wf-W-oracle/delay/s?
    (PendingDelay owners W)
    intro_visible)])

(define-overriding-judgment-form
  delay-s-oracle-lang
  core:wf-F-oracle/s?
  #:mode (wf-F-oracle/delay/s? I I)
  #:contract (wf-F-oracle/delay/s? F intro)

  [(wf-W-oracle/delay/s? W intro_visible)
   ---------------------------------------------------- "unfinished frontier/s"
   (wf-F-oracle/delay/s? (More W) intro_visible)]

  [(core:wf-owner-stack-oracle/s? owners intro_visible intro_body)
   (wf-F-oracle/delay/s? F intro_body)
   ---------------------------------------------------- "forced frontier/delay/s"
   (wf-F-oracle/delay/s?
    (Forced owners F)
    intro_visible)])

(define-judgment-form
  delay-s-oracle-lang
  #:mode (wf-delay-oracle/s? I)
  #:contract (wf-delay-oracle/s? F)
  [(wf-F-oracle/delay/s? F ())
   ---------------------------------------------------- "Delay S root"
   (wf-delay-oracle/s? F)])
