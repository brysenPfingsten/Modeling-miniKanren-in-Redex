#lang racket

(require redex/reduction-semantics
         "./calls-lang.rkt"
         "./disj-seq-lang.rkt")

(provide search-base-seq-calls-lang)

(check-redundancy #t)

(define-union-language search-base-seq-calls/join
  calls-lang
  disj-seq-lang)

(define-extended-language search-base-seq-calls-lang
  search-base-seq-calls/join
  [K ::= hole
        (K × g c)]
  [KCorePath ::= hole
                 (Scoped c KCorePath)
                 (KCorePath <-+ f)]
  [KScopePath ::= hole
                  (Scoped c KScopePath)
                  (KScopePath <-+ f)])
