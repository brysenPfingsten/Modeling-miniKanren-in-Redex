#lang racket

(require redex/reduction-semantics
         "../generated/core/source/s.rkt"
         "./delay-schema.rkt")

(provide delay-s-smoke-source
         delay-s-smoke-lang
         delay-s-smoke-red
         delay-s-smoke-successors
         wf-delay-s-smoke?
         q-export/delay-s-smoke
         q-rebuild/delay-s-smoke
         delay-s-asymmetric-source
         delay-s-asymmetric-lang
         delay-s-asymmetric-red
         delay-s-asymmetric-successors)

(define (transfer-pending/delay-s-smoke prefix delayed-work)
  (match* (prefix delayed-work)
    [(`(Owners ,prefix-owner ...)
      `(PendingDelay (Owners ,local-owner ...) ,work))
     `(PendingDelay
       (Owners ,@prefix-owner ,@local-owner)
       ,work)]
    [(_ _)
     (error 'transfer-pending/delay-s-smoke
            "expected an Owner prefix and PendingDelay, received ~e and ~e"
            prefix
            delayed-work)]))

(define (transfer-pending/delay-s-asymmetric prefix delayed-work)
  (match* (prefix delayed-work)
    [(`(Owners ,prefix-owner ...)
      `(PendingAsymmetric (Owners ,local-owner ...) ,work))
     `(PendingAsymmetric
       (Owners ,@prefix-owner ,@local-owner)
       ,work)]
    [(_ _)
     (error 'transfer-pending/delay-s-asymmetric
            "expected an Owner prefix and PendingAsymmetric, received ~e and ~e"
            prefix
            delayed-work)]))

(define-delay-representation-view delay-s-smoke-view
  #:pending (PendingDelay supply W)
  #:pending-prefix supply
  #:forced (Forced supply F)
  #:forced-prefix supply
  #:transfer-pending transfer-pending/delay-s-smoke)

(define-generated-delay-source delay-s-smoke-source
  #:base generated-core-s-source
  #:representation delay-s-smoke-view
  #:language delay-s-smoke-lang
  #:relation delay-s-smoke-red
  #:raw-successors delay-s-smoke-successors
  #:wf-root wf-delay-s-smoke?
  #:live-supply live-supply/delay-s-smoke
  #:failure-summary failure-summary/delay-s-smoke
  #:Q
  [#:export q-export/delay-s-smoke
   #:rebuild q-rebuild/delay-s-smoke
   #:focus-export q-focus-export/delay-s-smoke
   #:focus-rebuild q-focus-rebuild/delay-s-smoke
   #:root-focus-export q-root-focus-export/delay-s-smoke
   #:root-focus-rebuild q-root-focus-rebuild/delay-s-smoke
   #:failure-focus-export q-failure-focus-export/delay-s-smoke
   #:failure-focus-rebuild q-failure-focus-rebuild/delay-s-smoke
   #:terminal-export q-terminal-export/delay-s-smoke
   #:terminal-rebuild q-terminal-rebuild/delay-s-smoke])

;; Pending and Forced intentionally use different prefix encodings here.  This
;; small representation descriptor ensures Delay rendering consults each view
;; independently instead of relying on the equality used by S/E/N.
(define-delay-representation-view delay-s-asymmetric-view
  #:pending (PendingAsymmetric supply W)
  #:pending-prefix supply
  #:forced (ForcedAsymmetric supply F)
  #:forced-prefix empty
  #:transfer-pending transfer-pending/delay-s-asymmetric)

(define-generated-delay-source delay-s-asymmetric-source
  #:base generated-core-s-source
  #:representation delay-s-asymmetric-view
  #:language delay-s-asymmetric-lang
  #:relation delay-s-asymmetric-red
  #:raw-successors delay-s-asymmetric-successors
  #:wf-root wf-delay-s-asymmetric?
  #:live-supply live-supply/delay-s-asymmetric
  #:failure-summary failure-summary/delay-s-asymmetric
  #:Q
  [#:export q-export/delay-s-asymmetric
   #:rebuild q-rebuild/delay-s-asymmetric
   #:focus-export q-focus-export/delay-s-asymmetric
   #:focus-rebuild q-focus-rebuild/delay-s-asymmetric
   #:root-focus-export q-root-focus-export/delay-s-asymmetric
   #:root-focus-rebuild q-root-focus-rebuild/delay-s-asymmetric
   #:failure-focus-export q-failure-focus-export/delay-s-asymmetric
   #:failure-focus-rebuild q-failure-focus-rebuild/delay-s-asymmetric
   #:terminal-export q-terminal-export/delay-s-asymmetric
   #:terminal-rebuild q-terminal-rebuild/delay-s-asymmetric])
