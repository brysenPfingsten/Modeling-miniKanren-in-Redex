#lang racket

(require redex/reduction-semantics
         "./disj-lang.rkt")

(provide disj-fused-lang)

(check-redundancy #t)

(define-extended-language disj-fused-lang disj-lang
  [pref ....
        (Freshened c end-f)]
  [end-f ....
         (pref + end-f)]
  [K .... (K <-+ f)])
