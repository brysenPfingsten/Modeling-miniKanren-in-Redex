#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in core-lang:
                    "../../source/languages/core-lang.rkt")
         (prefix-in disj-lang:
                    "../../source/languages/disj-lang.rkt")
         (prefix-in core:
                    "../../source/reduction-relations/core-red.rkt")
         (prefix-in disj:
                    "../../source/reduction-relations/disj-red.rkt")
         (prefix-in core-wf:
                    "../../source/wf/core-wf.rkt")
         (prefix-in disj-wf:
                    "../../source/wf/disj-wf.rkt")
         "../support.rkt"
         "./core-edge-corpus.rkt"
         "./embedding-audit.rkt")

(provide CORE-DISJUNCTION-EDGE)

(define (core-frontier? t)
  (redex-match? core-lang:core-lang F t))

(define (disjunction-frontier? t)
  (redex-match? disj-lang:disj-lang F t))

(define (core-wf? t)
  (judgment-holds (core-wf:wf-cfg/core? ,t)))

(define (disjunction-wf? t)
  (judgment-holds (disj-wf:wf-cfg/disj? ,t)))

(define/provide-test-suite CORE-DISJUNCTION-EDGE
  (test-case "core -> disjunction is a conservative additive-feature edge"
    (audit-identity-edge
     #:label "core -> disjunction"
     #:source-relation core:core-red
     #:target-relation disj:disj-red
     #:source? core-frontier?
     #:target? disjunction-frontier?
     #:source-wf? core-wf?
     #:target-wf? disjunction-wf?
     #:representatives CORE-RULE-REPRESENTATIVES
     #:generated CORE-GENERATED)))

(module+ test
  (run-tests CORE-DISJUNCTION-EDGE))
