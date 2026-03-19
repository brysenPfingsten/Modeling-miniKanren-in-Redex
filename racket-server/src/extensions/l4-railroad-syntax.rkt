#lang racket

(require redex/reduction-semantics
         "./l3-union-base.rkt")

(check-redundancy #t)

(provide L4
         L4/K)

;; L4 adds right-pointing disjunction for railroad variants.
(define-extended-language L4 L3
  [s .... (s +-> s)])

(define-extended-language L4/K
  L3/K
  ;; Extend scheduler/strategy contexts through right-rail positions.
  [s .... (s +-> s)]
  [K .... (s +-> K)]
  [Kleft .... (s +-> Kleft)]
  [Ksched .... (s +-> Ksched)])
