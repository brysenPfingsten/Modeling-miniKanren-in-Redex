#lang racket

(require redex/reduction-semantics
         "./core-lang.rkt")

(provide delay-lang)

(check-redundancy #t)

;; Explicit delayed-goal/runtime delay layer, independent of relation calls.
(define-extended-language delay-lang core-lang
  [g ....
     (suspend g tag)]
  [cfg search
       (Bounced cfg)
       (Freshened c cfg tag)]
  [delayed (delay delayed)
		   (g σ)
		   (delayed × g c)]
  [search ....
          (delay delayed)]
  [QSpine ::= ....
              (Bounced QSpine)])
