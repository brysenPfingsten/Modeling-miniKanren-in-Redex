#lang racket

(require redex/reduction-semantics
         "../../../framework/delay-schema.rkt"
         "../../core/source/n.rkt")

(provide delay-n-representation-view
         generated-delay-n-source
         generated-delay-n-lang
         generated-delay-n-red
         raw-successors/generated/delay/n
         wf-delay/generated/n?
         live-supply/generated/delay/n
         failure-summary/generated/delay/n
         q-export/generated/delay/n
         q-rebuild/generated/delay/n
         q-focus-export/generated/delay/n
         q-focus-rebuild/generated/delay/n
         q-root-focus-export/generated/delay/n
         q-root-focus-rebuild/generated/delay/n
         q-failure-focus-export/generated/delay/n
         q-failure-focus-rebuild/generated/delay/n
         q-terminal-export/generated/delay/n
         q-terminal-rebuild/generated/delay/n
         J-core->delay/R/N)

(define-delay-representation-view delay-n-representation-view
  #:pending (PendingDelay W)
  #:pending-prefix empty
  #:forced (Forced F)
  #:forced-prefix empty)

(define-generated-delay-source generated-delay-n-source
  #:base generated-core-n-source
  #:representation delay-n-representation-view
  #:language generated-delay-n-lang
  #:relation generated-delay-n-red
  #:raw-successors raw-successors/generated/delay/n
  #:wf-root wf-delay/generated/n?
  #:live-supply live-supply/generated/delay/n
  #:failure-summary failure-summary/generated/delay/n
  #:Q
  [#:export q-export/generated/delay/n
   #:rebuild q-rebuild/generated/delay/n
   #:focus-export q-focus-export/generated/delay/n
   #:focus-rebuild q-focus-rebuild/generated/delay/n
   #:root-focus-export q-root-focus-export/generated/delay/n
   #:root-focus-rebuild q-root-focus-rebuild/generated/delay/n
   #:failure-focus-export q-failure-focus-export/generated/delay/n
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/delay/n
   #:terminal-export q-terminal-export/generated/delay/n
   #:terminal-rebuild q-terminal-rebuild/generated/delay/n])

(define (J-core->delay/R/N source)
  (unless (redex-match? generated-core-n-lang F source)
    (raise-argument-error 'J-core->delay/R/N "core N F" source))
  source)
