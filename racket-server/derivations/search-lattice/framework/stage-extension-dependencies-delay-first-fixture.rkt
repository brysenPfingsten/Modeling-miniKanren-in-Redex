#lang racket

(require redex/reduction-semantics
         "./core-stage-schema.rkt"
         "./delay-schema.rkt"
         "./disjunction-schema.rkt"
         "../generated/delay/source/s.rkt"
         (prefix-in core-stage: "../generated/core/stages/s.rkt"))

(provide delay-first/search-source
         delay-first/search-lang
         q-export/delay-first/search
         q-rebuild/delay-first/search
         q-focus-export/delay-first/search
         q-focus-rebuild/delay-first/search
         q-failure-focus-export/delay-first/search
         q-failure-focus-rebuild/delay-first/search
         delay-first/delay-row
         delay-first/search-row)

(define (transfer-choice/delay-first prefix choice)
  (match* (prefix choice)
    [(`(Owners ,prefix-owner ...)
      `(DisjL (Owners ,local-owner ...) ,left ,right))
     `(DisjL
       (Owners ,@prefix-owner ,@local-owner)
       ,left
       ,right)]
    [(_ _)
     (error 'transfer-choice/delay-first
            "expected an Owner prefix and DisjL, received ~e and ~e"
            prefix
            choice)]))

(define-disjunction-representation-view delay-first/disjunction-view
  #:choice (DisjL supply W_1 W_2)
  #:choice-prefix supply
  #:emit (Emit supply A F)
  #:emit-prefix supply
  #:transfer-choice transfer-choice/delay-first)

(define-generated-disjunction-source delay-first/search-source
  #:base generated-delay-s-source
  #:representation delay-first/disjunction-view
  #:language delay-first/search-lang
  #:relation delay-first/search-red
  #:raw-successors raw-successors/delay-first/search
  #:wf-root wf-delay-first/search?
  #:live-supply live-supply/delay-first/search
  #:failure-summary failure-summary/delay-first/search
  #:Q
  [#:export q-export/delay-first/search
   #:rebuild q-rebuild/delay-first/search
   #:focus-export q-focus-export/delay-first/search
   #:focus-rebuild q-focus-rebuild/delay-first/search
   #:root-focus-export q-root-focus-export/delay-first/search
   #:root-focus-rebuild q-root-focus-rebuild/delay-first/search
   #:failure-focus-export q-failure-focus-export/delay-first/search
   #:failure-focus-rebuild q-failure-focus-rebuild/delay-first/search
   #:terminal-export q-terminal-export/delay-first/search
   #:terminal-rebuild q-terminal-rebuild/delay-first/search])

(define-generated-delay-stage-extension delay-first/delay-extension
  #:source generated-delay-s-source
  #:dependencies-from delay-first/search-source)

(define-generated-disjunction-stage-extension delay-first/disjunction-extension
  #:source delay-first/search-source)

(apply-selected-stage-extension delay-first/delay-row
  #:extension delay-first/delay-extension
  #:base core-stage:core/staged-row/S)

(apply-selected-stage-extension delay-first/search-row
  #:extension delay-first/disjunction-extension
  #:base delay-first/delay-row)
