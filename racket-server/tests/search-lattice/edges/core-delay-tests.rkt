#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in core-lang:
                    "../../../src/search-lattice/languages/core-lang.rkt")
         (prefix-in delay-lang:
                    "../../../src/search-lattice/languages/delay-lang.rkt")
         (prefix-in core:
                    "../../../src/search-lattice/reduction-relations/core-red.rkt")
         (prefix-in delay:
                    "../../../src/search-lattice/reduction-relations/delay-red.rkt")
         (prefix-in core-wf:
                    "../../../src/search-lattice/wf/core-wf.rkt")
         (prefix-in delay-wf:
                    "../../../src/search-lattice/wf/delay-wf.rkt")
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
