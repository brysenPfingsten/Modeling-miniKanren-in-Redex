#lang racket

(require redex/reduction-semantics
         "../generated/core/source/n.rkt"
         "./disjunction-schema.rkt")

(provide disjunction-n-smoke-source
         disjunction-n-smoke-lang
         disjunction-n-smoke-red
         disjunction-n-smoke-red/work-raw
         disjunction-n-smoke-red/frontier-raw
         disjunction-n-smoke-successors
         wf-disjunction-n-smoke?
         wf-disjunction-n-smoke?/node-case
         live-supply/disjunction-n-smoke
         live-supply/disjunction-n-smoke/one
         failure-summary/disjunction-n-smoke
         q-export/disjunction-n-smoke
         q-rebuild/disjunction-n-smoke
         q-focus-export/disjunction-n-smoke
         q-focus-rebuild/disjunction-n-smoke
         q-root-focus-export/disjunction-n-smoke
         q-root-focus-rebuild/disjunction-n-smoke
         q-failure-focus-export/disjunction-n-smoke
         q-failure-focus-rebuild/disjunction-n-smoke
         q-terminal-export/disjunction-n-smoke
         q-terminal-rebuild/disjunction-n-smoke)

(define (transfer-choice/disjunction-n-smoke _prefix choice)
  choice)

(define-disjunction-representation-view disjunction-n-smoke-view
  #:choice (DisjL W_1 W_2)
  #:choice-prefix empty
  #:emit (Emit A F)
  #:emit-prefix empty
  #:transfer-choice transfer-choice/disjunction-n-smoke)

(define-generated-disjunction-source disjunction-n-smoke-source
  #:base generated-core-n-source
  #:representation disjunction-n-smoke-view
  #:language disjunction-n-smoke-lang
  #:relation disjunction-n-smoke-red
  #:raw-successors disjunction-n-smoke-successors
  #:wf-root wf-disjunction-n-smoke?
  #:live-supply live-supply/disjunction-n-smoke
  #:failure-summary failure-summary/disjunction-n-smoke
  #:Q
  [#:export q-export/disjunction-n-smoke
   #:rebuild q-rebuild/disjunction-n-smoke
   #:focus-export q-focus-export/disjunction-n-smoke
   #:focus-rebuild q-focus-rebuild/disjunction-n-smoke
   #:root-focus-export q-root-focus-export/disjunction-n-smoke
   #:root-focus-rebuild q-root-focus-rebuild/disjunction-n-smoke
   #:failure-focus-export q-failure-focus-export/disjunction-n-smoke
   #:failure-focus-rebuild q-failure-focus-rebuild/disjunction-n-smoke
   #:terminal-export q-terminal-export/disjunction-n-smoke
   #:terminal-rebuild q-terminal-rebuild/disjunction-n-smoke])
