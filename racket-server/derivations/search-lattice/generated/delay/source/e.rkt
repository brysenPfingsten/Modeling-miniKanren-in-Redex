#lang racket

(require redex/reduction-semantics
         "../../../framework/delay-schema.rkt"
         "../../core/source/e.rkt")

(provide delay-e-representation-view
         generated-delay-e-source
         generated-delay-e-lang
         generated-delay-e-red
         raw-successors/generated/delay/e
         wf-delay/generated/e?
         live-supply/generated/delay/e
         failure-summary/generated/delay/e
         q-export/generated/delay/e
         q-rebuild/generated/delay/e
         q-focus-export/generated/delay/e
         q-focus-rebuild/generated/delay/e
         q-root-focus-export/generated/delay/e
         q-root-focus-rebuild/generated/delay/e
         q-failure-focus-export/generated/delay/e
         q-failure-focus-rebuild/generated/delay/e
         q-terminal-export/generated/delay/e
         q-terminal-rebuild/generated/delay/e
         J-core->delay/R/E)

(define-delay-representation-view delay-e-representation-view
  #:pending (PendingDelay W)
  #:pending-prefix empty
  #:forced (Forced F)
  #:forced-prefix empty)

(define-generated-delay-source generated-delay-e-source
  #:base generated-core-e-source
  #:representation delay-e-representation-view
  #:language generated-delay-e-lang
  #:relation generated-delay-e-red
  #:raw-successors raw-successors/generated/delay/e
  #:wf-root wf-delay/generated/e?
  #:live-supply live-supply/generated/delay/e
  #:failure-summary failure-summary/generated/delay/e
  #:Q
  [#:export q-export/generated/delay/e
   #:rebuild q-rebuild/generated/delay/e
   #:focus-export q-focus-export/generated/delay/e
   #:focus-rebuild q-focus-rebuild/generated/delay/e
   #:root-focus-export q-root-focus-export/generated/delay/e
   #:root-focus-rebuild q-root-focus-rebuild/generated/delay/e
   #:failure-focus-export q-failure-focus-export/generated/delay/e
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/delay/e
   #:terminal-export q-terminal-export/generated/delay/e
   #:terminal-rebuild q-terminal-rebuild/generated/delay/e])

(define (J-core->delay/R/E source)
  (unless (redex-match? generated-core-e-lang F source)
    (raise-argument-error 'J-core->delay/R/E "core E F" source))
  source)
