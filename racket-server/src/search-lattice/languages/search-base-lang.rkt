#lang racket

(require redex/reduction-semantics
         "./delay-lang.rkt"
         "./disj-lang.rkt")

(provide search-base-lang)

(check-redundancy #t)

(define-union-language search-base/join
  delay-lang
  disj-lang)

(define-extended-language search-base-lang
  search-base/join
  [QFront ::= hole
              (Freshened c QFront tag)
              (promoted + QFront)])
