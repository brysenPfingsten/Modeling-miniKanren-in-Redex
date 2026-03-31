#lang racket

(require redex/reduction-semantics
         "./disj-lang.rkt")

(provide disj-seq-lang)

(check-redundancy #t)

(define-extended-language disj-seq-lang disj-lang
  [QShell ::= ....
              (promoted + QShell)]
  [KBranch ::= hole
               (Freshened c KBranch tag)
               (KBranch <-+ search)]
  [KTail ::= ....
             (KTail <-+ search)])
