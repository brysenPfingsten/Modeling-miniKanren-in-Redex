#lang racket

(require redex/reduction-semantics
         "../generated/core/source/n.rkt"
         "./delay-schema.rkt")

(provide delay-n-smoke-source
         delay-n-smoke-lang
         delay-n-smoke-red
         delay-n-smoke-red/work-raw
         delay-n-smoke-red/frontier-raw
         delay-n-smoke-red/allocation-raw
         delay-n-smoke-red/transfer-work-prefix
         delay-n-smoke-successors
         wf-delay-n-smoke?
         wf-delay-n-smoke?/goal
         wf-delay-n-smoke?/work
         wf-delay-n-smoke?/frontier
         wf-delay-n-smoke?/goal-case
         wf-delay-n-smoke?/node-case
         live-supply/delay-n-smoke
         failure-summary/delay-n-smoke
         q-export/delay-n-smoke
         q-rebuild/delay-n-smoke
         q-focus-export/delay-n-smoke
         q-focus-rebuild/delay-n-smoke
         q-root-focus-export/delay-n-smoke
         q-root-focus-rebuild/delay-n-smoke
         q-failure-focus-export/delay-n-smoke
         q-failure-focus-rebuild/delay-n-smoke
         q-terminal-export/delay-n-smoke
         q-terminal-rebuild/delay-n-smoke)

(define-delay-representation-view delay-n-smoke-view
  #:pending (PendingDelay W)
  #:pending-prefix empty
  #:forced (Forced F)
  #:forced-prefix empty)

(define-generated-delay-source delay-n-smoke-source
  #:base generated-core-n-source
  #:representation delay-n-smoke-view
  #:language delay-n-smoke-lang
  #:relation delay-n-smoke-red
  #:raw-successors delay-n-smoke-successors
  #:wf-root wf-delay-n-smoke?
  #:live-supply live-supply/delay-n-smoke
  #:failure-summary failure-summary/delay-n-smoke
  #:Q
  [#:export q-export/delay-n-smoke
   #:rebuild q-rebuild/delay-n-smoke
   #:focus-export q-focus-export/delay-n-smoke
   #:focus-rebuild q-focus-rebuild/delay-n-smoke
   #:root-focus-export q-root-focus-export/delay-n-smoke
   #:root-focus-rebuild q-root-focus-rebuild/delay-n-smoke
   #:failure-focus-export q-failure-focus-export/delay-n-smoke
   #:failure-focus-rebuild q-failure-focus-rebuild/delay-n-smoke
   #:terminal-export q-terminal-export/delay-n-smoke
   #:terminal-rebuild q-terminal-rebuild/delay-n-smoke])
