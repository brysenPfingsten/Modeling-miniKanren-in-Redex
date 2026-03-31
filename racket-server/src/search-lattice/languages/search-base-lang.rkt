#lang racket

(require redex/reduction-semantics
         "./delay-lang.rkt"
         "./disj-lang.rkt")

(provide search-base-lang)

(check-redundancy #t)

(define-union-language search-base-lang
  delay-lang
  disj-lang)
