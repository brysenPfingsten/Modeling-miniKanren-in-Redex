#lang racket

(require redex/reduction-semantics
         "../../../framework/delay-schema.rkt"
         "../../core/source/s.rkt")

(provide delay-s-representation-view
         transfer-pending/generated/delay/s
         generated-delay-s-source
         generated-delay-s-lang
         generated-delay-s-red
         raw-successors/generated/delay/s
         wf-delay/generated/s?
         live-supply/generated/delay/s
         failure-summary/generated/delay/s
         q-export/generated/delay/s
         q-rebuild/generated/delay/s
         q-focus-export/generated/delay/s
         q-focus-rebuild/generated/delay/s
         q-root-focus-export/generated/delay/s
         q-root-focus-rebuild/generated/delay/s
         q-failure-focus-export/generated/delay/s
         q-failure-focus-rebuild/generated/delay/s
         q-terminal-export/generated/delay/s
         q-terminal-rebuild/generated/delay/s
         J-core->delay/R/S)

(define (transfer-pending/generated/delay/s prefix delayed-work)
  (match* (prefix delayed-work)
    [(`(Owners ,prefix-owner ...)
      `(PendingDelay (Owners ,local-owner ...) ,work))
     `(PendingDelay
       (Owners ,@prefix-owner ,@local-owner)
       ,work)]
    [(_ _)
     (error 'transfer-pending/generated/delay/s
            "expected an Owner prefix and PendingDelay, received ~e and ~e"
            prefix
            delayed-work)]))

(define-delay-representation-view delay-s-representation-view
  #:pending (PendingDelay supply W)
  #:pending-prefix supply
  #:forced (Forced supply F)
  #:forced-prefix supply
  #:transfer-pending transfer-pending/generated/delay/s)

(define-generated-delay-source generated-delay-s-source
  #:base generated-core-s-source
  #:representation delay-s-representation-view
  #:language generated-delay-s-lang
  #:relation generated-delay-s-red
  #:raw-successors raw-successors/generated/delay/s
  #:wf-root wf-delay/generated/s?
  #:live-supply live-supply/generated/delay/s
  #:failure-summary failure-summary/generated/delay/s
  #:Q
  [#:export q-export/generated/delay/s
   #:rebuild q-rebuild/generated/delay/s
   #:focus-export q-focus-export/generated/delay/s
   #:focus-rebuild q-focus-rebuild/generated/delay/s
   #:root-focus-export q-root-focus-export/generated/delay/s
   #:root-focus-rebuild q-root-focus-rebuild/generated/delay/s
   #:failure-focus-export q-failure-focus-export/generated/delay/s
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/delay/s
   #:terminal-export q-terminal-export/generated/delay/s
   #:terminal-rebuild q-terminal-rebuild/generated/delay/s])

(define (J-core->delay/R/S source)
  (unless (redex-match? generated-core-s-lang F source)
    (raise-argument-error 'J-core->delay/R/S "core S F" source))
  source)
