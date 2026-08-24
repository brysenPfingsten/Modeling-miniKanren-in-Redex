#lang racket

(require redex/reduction-semantics
         "./language.rkt"
         (prefix-in core: "../../core/n/wf.rkt"))

(provide wf-g-oracle/delay/n?
         live-next-oracle/delay/n?
         wf-W-oracle/delay/n?
         wf-F-oracle/delay/n?
         wf-delay-oracle/n?)

(check-redundancy #t)

(define-extended-judgment-form
  delay-n-oracle-lang
  core:wf-g-oracle/n?
  #:mode (wf-g-oracle/delay/n? I I I)
  #:contract (wf-g-oracle/delay/n? g (x ...) next)

  [(wf-g-oracle/delay/n? g (x_bound ...) next)
   ---------------------------------------------------- "suspended goal/delay/n"
   (wf-g-oracle/delay/n?
    (suspend g tag)
    (x_bound ...)
    next)])

(define-extended-judgment-form
  delay-n-oracle-lang
  core:live-next-oracle/n?
  #:mode (live-next-oracle/delay/n? I O)
  #:contract (live-next-oracle/delay/n? W next)

  [(live-next-oracle/delay/n? W next)
   ---------------------------------------------------- "next through pending delay/n"
   (live-next-oracle/delay/n? (PendingDelay W) next)])

(define-overriding-judgment-form
  delay-n-oracle-lang
  core:wf-W-oracle/n?
  #:mode (wf-W-oracle/delay/n? I)
  #:contract (wf-W-oracle/delay/n? W)

  [(core:wf-state-oracle/n? σ)
   (where next (core:state-next/n σ))
   (wf-g-oracle/delay/n? g () next)
   ---------------------------------------------------- "work/n"
   (wf-W-oracle/delay/n? (Work g σ))]

  [(wf-W-oracle/delay/n? W)
   (live-next-oracle/delay/n? W next)
   (wf-g-oracle/delay/n? g () next)
   ---------------------------------------------------- "conjunction under exposed next/n"
   (wf-W-oracle/delay/n? (Conj W g))]

  [(wf-W-oracle/delay/n? W)
   ---------------------------------------------------- "pending delay/delay/n"
   (wf-W-oracle/delay/n? (PendingDelay W))])

(define-overriding-judgment-form
  delay-n-oracle-lang
  core:wf-F-oracle/n?
  #:mode (wf-F-oracle/delay/n? I)
  #:contract (wf-F-oracle/delay/n? F)

  [(wf-W-oracle/delay/n? W)
   ---------------------------------------------------- "unfinished frontier/n"
   (wf-F-oracle/delay/n? (More W))]

  [(wf-F-oracle/delay/n? F)
   ---------------------------------------------------- "forced frontier/delay/n"
   (wf-F-oracle/delay/n? (Forced F))])

(define-judgment-form
  delay-n-oracle-lang
  #:mode (wf-delay-oracle/n? I)
  #:contract (wf-delay-oracle/n? F)
  [(wf-F-oracle/delay/n? F)
   ---------------------------------------------------- "Delay N root"
   (wf-delay-oracle/n? F)])
