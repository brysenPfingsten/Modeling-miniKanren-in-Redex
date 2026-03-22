#lang racket

(require redex/reduction-semantics
         "./core-lang.rkt")

(provide disj-lang)

(check-redundancy #t)

;; Neutral disjunction syntax with no hoist policy baked into contexts.
(define-extended-language disj-lang core-lang
  [pref ....
        (Freshened c end-f)]
  [end-f ....
         (pref + end-f)]
  [g ....
     (g ∨ g tag)]
  [w ....
     (f <-+ f)])
