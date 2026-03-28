#lang racket

(require redex/reduction-semantics
         "./delay-lang.rkt"
         "./disj-lang.rkt")

(provide search-base-fused-lang)

(check-redundancy #t)

(define-union-language search-base-fused/join
  delay-lang
  disj-lang)

(define-extended-language search-base-fused-lang
  search-base-fused/join
  [delayed ....
           (search <-+ search)]
  [QFront ::= hole
             (Freshened c QFront tag)
             (promoted + QFront)])
