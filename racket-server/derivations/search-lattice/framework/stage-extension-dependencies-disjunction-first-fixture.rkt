#lang racket

(require redex/reduction-semantics
         "./core-stage-schema.rkt"
         "./delay-schema.rkt"
         "./disjunction-schema.rkt"
         "../generated/disjunction/source/s.rkt"
         (prefix-in core-stage: "../generated/core/stages/s.rkt"))

(provide disjunction-first/search-source
         disjunction-first/search-lang
         q-export/disjunction-first/search
         q-rebuild/disjunction-first/search
         q-focus-export/disjunction-first/search
         q-focus-rebuild/disjunction-first/search
         q-failure-focus-export/disjunction-first/search
         q-failure-focus-rebuild/disjunction-first/search
         disjunction-first/disjunction-row
         disjunction-first/search-row)

(define (transfer-pending/disjunction-first prefix delayed-work)
  (match* (prefix delayed-work)
    [(`(Owners ,prefix-owner ...)
      `(PendingDelay (Owners ,local-owner ...) ,work))
     `(PendingDelay
       (Owners ,@prefix-owner ,@local-owner)
       ,work)]
    [(_ _)
     (error 'transfer-pending/disjunction-first
            "expected an Owner prefix and PendingDelay, received ~e and ~e"
            prefix
            delayed-work)]))

(define-delay-representation-view disjunction-first/delay-view
  #:pending (PendingDelay supply W)
  #:pending-prefix supply
  #:forced (Forced supply F)
  #:forced-prefix supply
  #:transfer-pending transfer-pending/disjunction-first)

(define-generated-delay-source disjunction-first/search-source
  #:base generated-disjunction-s-source
  #:representation disjunction-first/delay-view
  #:language disjunction-first/search-lang
  #:relation disjunction-first/search-red
  #:raw-successors raw-successors/disjunction-first/search
  #:wf-root wf-disjunction-first/search?
  #:live-supply live-supply/disjunction-first/search
  #:failure-summary failure-summary/disjunction-first/search
  #:Q
  [#:export q-export/disjunction-first/search
   #:rebuild q-rebuild/disjunction-first/search
   #:focus-export q-focus-export/disjunction-first/search
   #:focus-rebuild q-focus-rebuild/disjunction-first/search
   #:root-focus-export q-root-focus-export/disjunction-first/search
   #:root-focus-rebuild q-root-focus-rebuild/disjunction-first/search
   #:failure-focus-export q-failure-focus-export/disjunction-first/search
   #:failure-focus-rebuild q-failure-focus-rebuild/disjunction-first/search
   #:terminal-export q-terminal-export/disjunction-first/search
   #:terminal-rebuild q-terminal-rebuild/disjunction-first/search])

(define-generated-disjunction-stage-extension disjunction-first/disjunction-extension
  #:source generated-disjunction-s-source
  #:dependencies-from disjunction-first/search-source)

(define-generated-delay-stage-extension disjunction-first/delay-extension
  #:source disjunction-first/search-source)

(apply-selected-stage-extension disjunction-first/disjunction-row
  #:extension disjunction-first/disjunction-extension
  #:base core-stage:core/staged-row/S)

(apply-selected-stage-extension disjunction-first/search-row
  #:extension disjunction-first/delay-extension
  #:base disjunction-first/disjunction-row)
