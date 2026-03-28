#lang racket

(require redex/reduction-semantics
         "./delay-lang.rkt"
         "./disj-lang.rkt")

(provide search-base-seq-lang)

(check-redundancy #t)

(define-union-language search-base-seq/join
  delay-lang
  disj-lang)

(define-extended-language search-base-seq-lang
  search-base-seq/join
  [delayed ....
           (search <-+ search)]
  [QFront ::= hole
             (Freshened c QFront tag)
             (promoted + QFront)])
