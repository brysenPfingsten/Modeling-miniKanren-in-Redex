#lang racket

(require redex/reduction-semantics
         "./delay-lang.rkt"
         "./disj-seq-lang.rkt")

(provide search-base-seq-lang)

(check-redundancy #t)

(define-union-language search-base-seq/join
  delay-lang
  disj-seq-lang)

(define-extended-language search-base-seq-lang
  search-base-seq/join
  [pref ....
        (Freshened c end-f)]
  [end-f ....
         (pref + end-f)]
  [K ::= hole
        (K × g c)]
  [KCorePath ::= hole
                 (Freshened c KCorePath)
                 (KCorePath <-+ f)]
  [KScopePath ::= hole
                  (Freshened c KScopePath)
                  (KScopePath <-+ f)])
