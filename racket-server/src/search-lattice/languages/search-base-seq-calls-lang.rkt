#lang racket

(require redex/reduction-semantics
         "./calls-lang.rkt"
         "./disj-lang.rkt")

(provide search-base-seq-calls-lang)

(check-redundancy #t)

(define-union-language search-base-seq-calls/join
  calls-lang
  disj-lang)

(define-extended-language search-base-seq-calls-lang
  search-base-seq-calls/join
  [QFront ::= hole
             (Freshened c QFront tag)
             (promoted + QFront)])
