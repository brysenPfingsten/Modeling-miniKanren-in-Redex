#lang racket

(require redex/reduction-semantics
         "../generated/core/source/s.rkt"
         "./disjunction-schema.rkt")

(provide disjunction-s-smoke-source
         disjunction-s-smoke-lang
         disjunction-s-smoke-red
         disjunction-s-smoke-successors
         wf-disjunction-s-smoke?
         q-export/disjunction-s-smoke
         q-rebuild/disjunction-s-smoke
         q-focus-export/disjunction-s-smoke
         q-focus-rebuild/disjunction-s-smoke)

(define (transfer-choice/disjunction-s-smoke prefix choice)
  (match* (prefix choice)
    [(`(Owners ,prefix-owner ...)
      `(DisjL (Owners ,local-owner ...) ,left ,right))
     `(DisjL
       (Owners ,@prefix-owner ,@local-owner)
       ,left
       ,right)]
    [(_ _)
     (error 'transfer-choice/disjunction-s-smoke
            "expected an Owner prefix and DisjL, received ~e and ~e"
            prefix
            choice)]))

(define-disjunction-representation-view disjunction-s-smoke-view
  #:choice (DisjL supply W_1 W_2)
  #:choice-prefix supply
  #:emit (Emit supply A F)
  #:emit-prefix supply
  #:transfer-choice transfer-choice/disjunction-s-smoke)

(define-generated-disjunction-source disjunction-s-smoke-source
  #:base generated-core-s-source
  #:representation disjunction-s-smoke-view
  #:language disjunction-s-smoke-lang
  #:relation disjunction-s-smoke-red
  #:raw-successors disjunction-s-smoke-successors
  #:wf-root wf-disjunction-s-smoke?
  #:live-supply live-supply/disjunction-s-smoke
  #:failure-summary failure-summary/disjunction-s-smoke
  #:Q
  [#:export q-export/disjunction-s-smoke
   #:rebuild q-rebuild/disjunction-s-smoke
   #:focus-export q-focus-export/disjunction-s-smoke
   #:focus-rebuild q-focus-rebuild/disjunction-s-smoke
   #:root-focus-export q-root-focus-export/disjunction-s-smoke
   #:root-focus-rebuild q-root-focus-rebuild/disjunction-s-smoke
   #:failure-focus-export q-failure-focus-export/disjunction-s-smoke
   #:failure-focus-rebuild q-failure-focus-rebuild/disjunction-s-smoke
   #:terminal-export q-terminal-export/disjunction-s-smoke
   #:terminal-rebuild q-terminal-rebuild/disjunction-s-smoke])
