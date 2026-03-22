#lang racket

(require redex/reduction-semantics
         "../languages/delay-lang.rkt"
         "./private/context-pipeline.rkt"
         "./private/core-common.rkt"
         "./private/step-utils.rkt")

(provide delay-red
         step-once)

(check-redundancy #t)

(define core-redex/delay (extend-core-redex delay-lang))
(define core-collector/delay (make-core-collector delay-lang))
 (define-search-frontier/one-stage core-frontier/delay core-redex/delay delay-lang K)

(define delay-extra
  (reduction-relation
   delay-lang
   #:domain f
   [--> (in-hole K ((suspend g tag) σ))
        (in-hole K (delay (g σ)))
        "delay/suspend-goal"]
   [--> (delay f_1)
        (Bounced + f_1)
        "delay/invoke-delay"]
   [--> (in-hole K ((delay f_1) × g c))
        (in-hole K (delay (f_1 × g c)))
        "delay/delay-through-conj"]))

(define delay-frontier
  (context-closure delay-extra delay-lang P))

(define delay-red
  (union-reduction-relations
   delay-frontier
   core-frontier/delay
   core-collector/delay))

(define (step-once prog)
  (step-once/deterministic delay-red prog))
