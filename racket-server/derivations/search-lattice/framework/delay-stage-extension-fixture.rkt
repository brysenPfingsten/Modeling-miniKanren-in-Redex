#lang racket

(require redex/reduction-semantics
         "./core-stage-schema.rkt"
         "./delay-schema.rkt"
         "./delay-schema-prefix-fixture.rkt"
         "./delay-schema-source-fixture.rkt"
         "../generated/core/source/e.rkt"
         (prefix-in stage-s: "../generated/core/stages/s.rkt")
         (prefix-in stage-e: "../generated/core/stages/e.rkt")
         (prefix-in stage-n: "../generated/core/stages/n.rkt"))

(provide delay-stage-e-source
         delay-stage-e-lang
         delay-stage-e-red
         delay-stage-e-successors
         delay/stage-extension/S
         delay/stage-extension/E
         delay/stage-extension/N
         delay/staged-row/S
         delay/staged-row/E
         delay/staged-row/N)

(define-delay-representation-view delay-stage-e-view
  #:pending (PendingDelay W)
  #:pending-prefix empty
  #:forced (Forced F)
  #:forced-prefix empty)

(define-generated-delay-source delay-stage-e-source
  #:base generated-core-e-source
  #:representation delay-stage-e-view
  #:language delay-stage-e-lang
  #:relation delay-stage-e-red
  #:raw-successors delay-stage-e-successors
  #:wf-root wf-delay-stage-e?
  #:live-supply live-supply/delay-stage-e
  #:failure-summary failure-summary/delay-stage-e
  #:Q
  [#:export q-export/delay-stage-e
   #:rebuild q-rebuild/delay-stage-e
   #:focus-export q-focus-export/delay-stage-e
   #:focus-rebuild q-focus-rebuild/delay-stage-e
   #:root-focus-export q-root-focus-export/delay-stage-e
   #:root-focus-rebuild q-root-focus-rebuild/delay-stage-e
   #:failure-focus-export q-failure-focus-export/delay-stage-e
   #:failure-focus-rebuild q-failure-focus-rebuild/delay-stage-e
   #:terminal-export q-terminal-export/delay-stage-e
   #:terminal-rebuild q-terminal-rebuild/delay-stage-e])

(define-generated-delay-stage-extension delay/stage-extension/S
  #:source delay-s-smoke-source)

(define-generated-delay-stage-extension delay/stage-extension/E
  #:source delay-stage-e-source)

(define-generated-delay-stage-extension delay/stage-extension/N
  #:source delay-n-smoke-source)

(apply-selected-stage-extension delay/staged-row/S
  #:extension delay/stage-extension/S
  #:base stage-s:core/staged-row/S)

(apply-selected-stage-extension delay/staged-row/E
  #:extension delay/stage-extension/E
  #:base stage-e:core/staged-row/E)

(apply-selected-stage-extension delay/staged-row/N
  #:extension delay/stage-extension/N
  #:base stage-n:core/staged-row/N)
