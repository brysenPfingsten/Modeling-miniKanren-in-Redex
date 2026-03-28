#lang racket

(require redex/reduction-semantics
         "../languages/delay-lang.rkt"
         (only-in "./core-red.rkt"
                  extend-core-redex)
         "./private/step-utils.rkt")

(provide delay-local/base
         delay-local/under-QSpine
         delay-frontier/base
         delay-red
         step-once)

(check-redundancy #t)

(define core-base/delay
  (extend-core-redex delay-lang))

(define core-local/delay
  (context-closure core-base/delay delay-lang KWork))

(define core-red/delay
  (context-closure core-local/delay delay-lang QSpine))

(define delay-local/base
  (reduction-relation
   delay-lang
   #:domain cfg
   [--> (in-hole KWork ((suspend g tag) σ))
        (in-hole KWork (delay (g σ)))
        "delay/suspend-goal"]
   [--> (in-hole KWork ((delay delayed_1) × g c))
        (in-hole KWork (delay (delayed_1 × g c)))
        "delay/delay-through-conj"]))

(define delay-frontier/base
  (reduction-relation
   delay-lang
   #:domain cfg
   [--> (in-hole QSpine (delay delayed_1))
        (in-hole QSpine (Bounced delayed_1))
        "delay/invoke-delay"]))

(define delay-local/under-QSpine
  (context-closure delay-local/base delay-lang QSpine))

(define delay-red
  (union-reduction-relations
   core-red/delay
   delay-local/under-QSpine
   delay-frontier/base))

(define (step-once prog)
  (step-once/deterministic delay-red prog))
