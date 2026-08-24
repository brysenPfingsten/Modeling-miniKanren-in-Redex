#lang racket

(require redex/reduction-semantics
         "../../../framework/disjunction-schema.rkt"
         "../../core/source/n.rkt")

(provide disjunction-n-representation-view
         generated-disjunction-n-source
         generated-disjunction-n-lang
         generated-disjunction-n-red
         raw-successors/generated/disjunction/n
         wf-disjunction/generated/n?
         live-supply/generated/disjunction/n
         failure-summary/generated/disjunction/n
         q-export/generated/disjunction/n
         q-rebuild/generated/disjunction/n
         q-focus-export/generated/disjunction/n
         q-focus-rebuild/generated/disjunction/n
         q-root-focus-export/generated/disjunction/n
         q-root-focus-rebuild/generated/disjunction/n
         q-failure-focus-export/generated/disjunction/n
         q-failure-focus-rebuild/generated/disjunction/n
         q-terminal-export/generated/disjunction/n
         q-terminal-rebuild/generated/disjunction/n
         J-core->disjunction/R/N)

(define (transfer-choice/generated/disjunction/n _prefix choice)
  choice)

(define-disjunction-representation-view disjunction-n-representation-view
  #:choice (DisjL W_1 W_2)
  #:choice-prefix empty
  #:emit (Emit A F)
  #:emit-prefix empty
  #:transfer-choice transfer-choice/generated/disjunction/n)

(define-generated-disjunction-source generated-disjunction-n-source
  #:base generated-core-n-source
  #:representation disjunction-n-representation-view
  #:language generated-disjunction-n-lang
  #:relation generated-disjunction-n-red
  #:raw-successors raw-successors/generated/disjunction/n
  #:wf-root wf-disjunction/generated/n?
  #:live-supply live-supply/generated/disjunction/n
  #:failure-summary failure-summary/generated/disjunction/n
  #:Q
  [#:export q-export/generated/disjunction/n
   #:rebuild q-rebuild/generated/disjunction/n
   #:focus-export q-focus-export/generated/disjunction/n
   #:focus-rebuild q-focus-rebuild/generated/disjunction/n
   #:root-focus-export q-root-focus-export/generated/disjunction/n
   #:root-focus-rebuild q-root-focus-rebuild/generated/disjunction/n
   #:failure-focus-export q-failure-focus-export/generated/disjunction/n
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/disjunction/n
   #:terminal-export q-terminal-export/generated/disjunction/n
   #:terminal-rebuild q-terminal-rebuild/generated/disjunction/n])

(define (J-core->disjunction/R/N source)
  (unless (redex-match? generated-core-n-lang F source)
    (raise-argument-error 'J-core->disjunction/R/N "core N F" source))
  source)
