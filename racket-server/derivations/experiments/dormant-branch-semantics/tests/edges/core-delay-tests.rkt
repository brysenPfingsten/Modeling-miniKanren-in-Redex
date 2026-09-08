#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in core-lang:
                    "../../source/languages/core-lang.rkt")
         (prefix-in delay-lang:
                    "../../source/languages/delay-lang.rkt")
         (prefix-in core:
                    "../../source/reduction-relations/core-red.rkt")
         (prefix-in delay:
                    "../../source/reduction-relations/delay-red.rkt")
         (prefix-in core-wf:
                    "../../source/wf/core-wf.rkt")
         (prefix-in delay-wf:
                    "../../source/wf/delay-wf.rkt")
         "../support.rkt"
         "./core-edge-corpus.rkt"
         "./embedding-audit.rkt")

(provide CORE-DELAY-EDGE)

(define (core-frontier? t)
  (redex-match? core-lang:core-lang F t))

(define (delay-frontier? t)
  (redex-match? delay-lang:delay-lang F t))

(define (core-wf? t)
  (judgment-holds (core-wf:wf-cfg/core? ,t)))

(define (delay-wf? t)
  (judgment-holds (delay-wf:wf-cfg/delay? ,t)))

(define/provide-test-suite CORE-DELAY-EDGE
  (test-case "core -> delay is a conservative additive-feature edge"
    (audit-identity-edge
     #:label "core -> delay"
     #:source-relation core:core-red
     #:target-relation delay:delay-red
     #:source? core-frontier?
     #:target? delay-frontier?
     #:source-wf? core-wf?
     #:target-wf? delay-wf?
     #:representatives CORE-RULE-REPRESENTATIVES
     #:generated CORE-GENERATED)))

(module+ test
  (run-tests CORE-DELAY-EDGE))
