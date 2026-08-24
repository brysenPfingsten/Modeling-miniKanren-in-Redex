#lang racket

(require redex/reduction-semantics
         "../generated/core/source/e.rkt"
         "./disjunction-schema.rkt")

(provide disjunction-e-smoke-source
         disjunction-e-smoke-lang
         disjunction-e-smoke-red
         disjunction-e-smoke-successors
         wf-disjunction-e-smoke?
         q-export/disjunction-e-smoke
         q-rebuild/disjunction-e-smoke)

(define (transfer-choice/disjunction-e-smoke _prefix choice)
  choice)

(define-disjunction-representation-view disjunction-e-smoke-view
  #:choice (DisjL W_1 W_2)
  #:choice-prefix empty
  #:emit (Emit A F)
  #:emit-prefix empty
  #:transfer-choice transfer-choice/disjunction-e-smoke)

(define-generated-disjunction-source disjunction-e-smoke-source
  #:base generated-core-e-source
  #:representation disjunction-e-smoke-view
  #:language disjunction-e-smoke-lang
  #:relation disjunction-e-smoke-red
  #:raw-successors disjunction-e-smoke-successors
  #:wf-root wf-disjunction-e-smoke?
  #:live-supply live-supply/disjunction-e-smoke
  #:failure-summary failure-summary/disjunction-e-smoke
  #:Q
  [#:export q-export/disjunction-e-smoke
   #:rebuild q-rebuild/disjunction-e-smoke
   #:focus-export q-focus-export/disjunction-e-smoke
   #:focus-rebuild q-focus-rebuild/disjunction-e-smoke
   #:root-focus-export q-root-focus-export/disjunction-e-smoke
   #:root-focus-rebuild q-root-focus-rebuild/disjunction-e-smoke
   #:failure-focus-export q-failure-focus-export/disjunction-e-smoke
   #:failure-focus-rebuild q-failure-focus-rebuild/disjunction-e-smoke
   #:terminal-export q-terminal-export/disjunction-e-smoke
   #:terminal-rebuild q-terminal-rebuild/disjunction-e-smoke])
