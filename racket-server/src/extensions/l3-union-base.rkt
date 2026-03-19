#lang racket

(require redex/reduction-semantics
         "./l1-calls-delay.rkt"
         "./l2-left-disjunction.rkt")

(check-redundancy #t)

(provide L3
         L3/K-base
         L3/K)

;; L3 is the syntax union of L1 and L2.
(define-union-language L3 L1 L2)

(define-extended-language L3/K-base
  L3
  ;; General strategic context used by call/disjunction extension rules.
  [K ::= hole
         (K × g c)
         (K <-+ s)]
  ;; Core reduction context: conjunction only (no disjunction or delay descent).
  [Kcore ::= hole
             (Kcore × g c)]
  ;; Left-disjunction scheduler context.
  [Kleft ::= hole
             (Kleft <-+ s)]
  ;; Scheduler context: disjunction traversal plus answer-stream tails.
  [Ksched ::= hole
              (Ksched <-+ s)])

(define-extended-language L3/K
  L3/K-base
  ;; Delay invocation context: top-level or under answer-stream tails only.
  [Kdelay ::= hole])
