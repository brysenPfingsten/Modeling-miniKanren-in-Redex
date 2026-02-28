#lang racket

(require redex/reduction-semantics
         "../../extensions/l4-railroad-syntax.rkt")

(check-redundancy #t)

(provide L4/K)

(define-extended-language L4/K
  L4
  [K ::= hole
         (K × g c)
         (delay K)
         (K <-+ s)
         (K +-> s)
         (s +-> K)]
  [K3 ::= K]
  [K4 ::= hole
          (K4 × g c)
          (delay K4)
          (K4 <-+ s)
          (K4 +-> s)
          (s +-> K4)])
