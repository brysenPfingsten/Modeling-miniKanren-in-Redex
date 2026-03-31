#lang racket

(require redex/reduction-semantics
         "../languages/delay-lang.rkt"
         (only-in "./core-red.rkt"
                  extend-core-redex)
         "./private/step-utils.rkt")

(provide delay-local/base
         delay-local/under-QShell
         delay-frontier/base
         delay-red
         step-once)

(check-redundancy #t)

(define core-base/delay
  (extend-core-redex delay-lang))

(define core-local/delay
  (context-closure core-base/delay delay-lang KLocal))

(define core-red/delay
  (context-closure core-local/delay delay-lang QShell))

(define delay-local/base
  (reduction-relation
   delay-lang
   #:domain cfg
   [--> (in-hole KLocal ((suspend g tag) σ))
        (in-hole KLocal (delay (g σ)))
        "delay/suspend-goal"]
   [--> (in-hole KLocal ((delay runnable-search_1) × g c))
        (in-hole KLocal (delay (runnable-search_1 × g c)))
        "delay/delay-through-conj"]))

(define delay-frontier/base
  (reduction-relation
   delay-lang
   #:domain cfg
   [--> (in-hole QShell (delay runnable-search_1))
        (in-hole QShell (Bounced runnable-search_1))
        "delay/invoke-delay"]))

(define delay-local/under-QShell
  (context-closure delay-local/base delay-lang QShell))

(define delay-red
  (union-reduction-relations
   core-red/delay
   delay-local/under-QShell
   delay-frontier/base))

(define (step-once prog)
  (step-once/deterministic delay-red prog))
