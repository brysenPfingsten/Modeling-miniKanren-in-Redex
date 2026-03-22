#lang racket

(require redex/reduction-semantics
         "./delay-lang.rkt"
         "./disj-fused-lang.rkt")

(provide search-base-fused-lang)

(check-redundancy #t)

(define-union-language search-base-fused/join
  delay-lang
  disj-fused-lang)

(define-extended-language search-base-fused-lang
  search-base-fused/join
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
