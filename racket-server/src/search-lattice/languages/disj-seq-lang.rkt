#lang racket

(require redex/reduction-semantics
         "./disj-lang.rkt")

(provide disj-seq-lang)

(check-redundancy #t)

(define-extended-language disj-seq-lang disj-lang
  [pref ....
        (Freshened c end-f)]
  [end-f ....
         (pref + end-f)]
  [K ::= hole
        (K × g c)]
  [KCorePath ::= hole
                 (Freshened c KCorePath)
                 (KCorePath <-+ f)]
  [KScopePath ::= hole
                  (Freshened c KScopePath)
                  (KScopePath <-+ f)])
