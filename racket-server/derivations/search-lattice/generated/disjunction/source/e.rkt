#lang racket

(require redex/reduction-semantics
         "../../../framework/disjunction-schema.rkt"
         "../../core/source/e.rkt")

(provide disjunction-e-representation-view
         generated-disjunction-e-source
         generated-disjunction-e-lang
         generated-disjunction-e-red
         raw-successors/generated/disjunction/e
         wf-disjunction/generated/e?
         live-supply/generated/disjunction/e
         failure-summary/generated/disjunction/e
         q-export/generated/disjunction/e
         q-rebuild/generated/disjunction/e
         q-focus-export/generated/disjunction/e
         q-focus-rebuild/generated/disjunction/e
         q-root-focus-export/generated/disjunction/e
         q-root-focus-rebuild/generated/disjunction/e
         q-failure-focus-export/generated/disjunction/e
         q-failure-focus-rebuild/generated/disjunction/e
         q-terminal-export/generated/disjunction/e
         q-terminal-rebuild/generated/disjunction/e
         J-core->disjunction/R/E)

(define (transfer-choice/generated/disjunction/e _prefix choice)
  choice)

(define-disjunction-representation-view disjunction-e-representation-view
  #:choice (DisjL W_1 W_2)
  #:choice-prefix empty
  #:emit (Emit A F)
  #:emit-prefix empty
  #:transfer-choice transfer-choice/generated/disjunction/e)

(define-generated-disjunction-source generated-disjunction-e-source
  #:base generated-core-e-source
  #:representation disjunction-e-representation-view
  #:language generated-disjunction-e-lang
  #:relation generated-disjunction-e-red
  #:raw-successors raw-successors/generated/disjunction/e
  #:wf-root wf-disjunction/generated/e?
  #:live-supply live-supply/generated/disjunction/e
  #:failure-summary failure-summary/generated/disjunction/e
  #:Q
  [#:export q-export/generated/disjunction/e
   #:rebuild q-rebuild/generated/disjunction/e
   #:focus-export q-focus-export/generated/disjunction/e
   #:focus-rebuild q-focus-rebuild/generated/disjunction/e
   #:root-focus-export q-root-focus-export/generated/disjunction/e
   #:root-focus-rebuild q-root-focus-rebuild/generated/disjunction/e
   #:failure-focus-export q-failure-focus-export/generated/disjunction/e
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/disjunction/e
   #:terminal-export q-terminal-export/generated/disjunction/e
   #:terminal-rebuild q-terminal-rebuild/generated/disjunction/e])

(define (J-core->disjunction/R/E source)
  (unless (redex-match? generated-core-e-lang F source)
    (raise-argument-error 'J-core->disjunction/R/E "core E F" source))
  source)
