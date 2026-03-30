#lang racket

(require redex/reduction-semantics
         "./calls-lang.rkt"
         "./disj-lang.rkt")

(provide search-base-fused-calls-lang)

(check-redundancy #t)

(define-union-language search-base-fused-calls/join
  calls-lang
  disj-lang)

(define-extended-language search-base-fused-calls-lang
  search-base-fused-calls/join
  [QFront ::= hole
             (Freshened c QFront tag)
             (promoted + QFront)])
