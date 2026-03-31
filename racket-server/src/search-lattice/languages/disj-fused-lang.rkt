#lang racket

(require redex/reduction-semantics
         "./disj-lang.rkt")

(provide disj-fused-lang)

(check-redundancy #t)

(define-extended-language disj-fused-lang disj-lang
  [QShell ::= ....
              (promoted + QShell)]
  [KBranch ::= hole
               (Freshened c KBranch tag)
               (KBranch <-+ search)]
  [KTail ::= ....
             (KTail <-+ search)])
