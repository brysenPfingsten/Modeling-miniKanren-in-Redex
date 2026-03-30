#lang racket

(require redex/reduction-semantics
         "./core-lang.rkt")

(provide delay-lang)

(check-redundancy #t)

;; Explicit delayed-goal/runtime delay layer, independent of relation calls.
(define-extended-language delay-lang core-lang
  [g ....
     (suspend g tag)]
  [cfg (Freshened c cfg tag)
       cfg-root]
  [cfg-root search
            (Bounced cfg)]
  [search ....
          (delay runnable-search)]
  [QSpine ::= ....
              (Bounced QSpine)])
