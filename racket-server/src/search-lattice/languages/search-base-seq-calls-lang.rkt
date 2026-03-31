#lang racket

(require redex/reduction-semantics
         "./calls-lang.rkt"
         "./search-base-seq-lang.rkt")

(provide search-base-seq-calls-lang)

(check-redundancy #t)

(define-union-language search-base-seq-calls-lang
  calls-lang
  search-base-seq-lang)
