#lang racket

(require redex/reduction-semantics
         "./core-lang.rkt")

(provide disj-lang)

(check-redundancy #t)

;; Neutral disjunction syntax with no hoist policy baked into contexts.
(define-extended-language disj-lang core-lang
  [promoted cell
            (Freshened c promoted tag)]
  [g ....
     (g ∨ g tag)]
  [cfg (Freshened c cfg tag)
       cfg-root]
  [cfg-root search
            (promoted + cfg)]
  [QSpine ::= hole
              (Freshened c QSpine tag)
              (promoted + QSpine)]
  [runnable-root ....
                 (search <-+ search)]
  [KBranch ::= hole
               (Freshened c KBranch tag)
               (KBranch <-+ search)])
