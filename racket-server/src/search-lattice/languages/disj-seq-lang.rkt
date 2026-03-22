#lang racket

(require redex/reduction-semantics
         "./disj-lang.rkt")

(provide disj-seq-lang)

(check-redundancy #t)

(define-extended-language disj-seq-lang disj-lang
  [pref ....
        (Freshened c end-f)]
  [end-f ....
         (pref + end-f)]
  [KBase ::= hole
             (KBase × g c)]
  [KBranch ::= hole
               (Freshened c KBranch)
               (KBranch <-+ f)])
