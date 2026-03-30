#lang racket

(require redex/reduction-semantics
         "./calls-lang.rkt"
         "./disj-lang.rkt")

(provide search-base-calls-lang)

(check-redundancy #t)

(define-union-language search-base-calls/join
  calls-lang
  disj-lang)

(define-extended-language search-base-calls-lang
  search-base-calls/join
  [QFront ::= hole
              (Freshened c QFront tag)
              (promoted + QFront)])
