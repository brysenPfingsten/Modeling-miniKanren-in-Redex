#lang racket

(require redex/reduction-semantics
         "../../../framework/disjunction-schema.rkt"
         "../../core/source/s.rkt")

(provide disjunction-s-representation-view
         transfer-choice/generated/disjunction/s
         generated-disjunction-s-source
         generated-disjunction-s-lang
         generated-disjunction-s-red
         raw-successors/generated/disjunction/s
         wf-disjunction/generated/s?
         live-supply/generated/disjunction/s
         failure-summary/generated/disjunction/s
         q-export/generated/disjunction/s
         q-rebuild/generated/disjunction/s
         q-focus-export/generated/disjunction/s
         q-focus-rebuild/generated/disjunction/s
         q-root-focus-export/generated/disjunction/s
         q-root-focus-rebuild/generated/disjunction/s
         q-failure-focus-export/generated/disjunction/s
         q-failure-focus-rebuild/generated/disjunction/s
         q-terminal-export/generated/disjunction/s
         q-terminal-rebuild/generated/disjunction/s
         J-core->disjunction/R/S)

(define (transfer-choice/generated/disjunction/s prefix choice)
  (match* (prefix choice)
    [(`(Owners ,prefix-owner ...)
      `(DisjL (Owners ,local-owner ...) ,left ,right))
     `(DisjL
       (Owners ,@prefix-owner ,@local-owner)
       ,left
       ,right)]
    [(_ _)
     (error 'transfer-choice/generated/disjunction/s
            "expected an Owner prefix and DisjL, received ~e and ~e"
            prefix
            choice)]))

(define-disjunction-representation-view disjunction-s-representation-view
  #:choice (DisjL supply W_1 W_2)
  #:choice-prefix supply
  #:emit (Emit supply A F)
  #:emit-prefix supply
  #:transfer-choice transfer-choice/generated/disjunction/s)

(define-generated-disjunction-source generated-disjunction-s-source
  #:base generated-core-s-source
  #:representation disjunction-s-representation-view
  #:language generated-disjunction-s-lang
  #:relation generated-disjunction-s-red
  #:raw-successors raw-successors/generated/disjunction/s
  #:wf-root wf-disjunction/generated/s?
  #:live-supply live-supply/generated/disjunction/s
  #:failure-summary failure-summary/generated/disjunction/s
  #:Q
  [#:export q-export/generated/disjunction/s
   #:rebuild q-rebuild/generated/disjunction/s
   #:focus-export q-focus-export/generated/disjunction/s
   #:focus-rebuild q-focus-rebuild/generated/disjunction/s
   #:root-focus-export q-root-focus-export/generated/disjunction/s
   #:root-focus-rebuild q-root-focus-rebuild/generated/disjunction/s
   #:failure-focus-export q-failure-focus-export/generated/disjunction/s
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/disjunction/s
   #:terminal-export q-terminal-export/generated/disjunction/s
   #:terminal-rebuild q-terminal-rebuild/generated/disjunction/s])

(define (J-core->disjunction/R/S source)
  (unless (redex-match? generated-core-s-lang F source)
    (raise-argument-error 'J-core->disjunction/R/S "core S F" source))
  source)
