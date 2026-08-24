#lang racket

(require redex/reduction-semantics
         "../../../framework/delay-schema.rkt"
         "../../../framework/search-join-schema.rkt"
         (only-in "../../core/source/e.rkt"
                  generated-core-e-lang)
         (only-in "../../delay/source/e.rkt"
                  delay-e-representation-view
                  generated-delay-e-lang)
         (only-in "../../disjunction/source/e.rkt"
                  generated-disjunction-e-lang
                  generated-disjunction-e-source))

(provide generated-search-e-child-source
         generated-search-e-source
         generated-search-e-lang
         generated-search-e-red
         raw-successors/generated/search/e
         wf-search/generated/e?
         live-supply/generated/search/e
         failure-summary/generated/search/e
         q-export/generated/search/e
         q-rebuild/generated/search/e
         q-focus-export/generated/search/e
         q-focus-rebuild/generated/search/e
         q-root-focus-export/generated/search/e
         q-root-focus-rebuild/generated/search/e
         q-failure-focus-export/generated/search/e
         q-failure-focus-rebuild/generated/search/e
         q-terminal-export/generated/search/e
         q-terminal-rebuild/generated/search/e
         J-core->search/R/E
         J-delay->search/R/E
         J-disjunction->search/R/E)

(define-generated-delay-source generated-search-e-child-source
  #:base generated-disjunction-e-source
  #:representation delay-e-representation-view
  #:language generated-search-e-lang
  #:relation generated-search-e-red
  #:raw-successors raw-successors/generated/search/e
  #:wf-root wf-search/generated/e?
  #:live-supply live-supply/generated/search/e
  #:failure-summary failure-summary/generated/search/e
  #:Q
  [#:export q-export/generated/search/e
   #:rebuild q-rebuild/generated/search/e
   #:focus-export q-focus-export/generated/search/e
   #:focus-rebuild q-focus-rebuild/generated/search/e
   #:root-focus-export q-root-focus-export/generated/search/e
   #:root-focus-rebuild q-root-focus-rebuild/generated/search/e
   #:failure-focus-export q-failure-focus-export/generated/search/e
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/search/e
   #:terminal-export q-terminal-export/generated/search/e
   #:terminal-rebuild q-terminal-rebuild/generated/search/e])

(define-generated-search-join-source generated-search-e-source
  #:base generated-search-e-child-source
  #:owned-rule-labels ())

(define (J-core->search/R/E source)
  (unless (redex-match? generated-core-e-lang F source)
    (raise-argument-error 'J-core->search/R/E "core E F" source))
  source)

(define (J-delay->search/R/E source)
  (unless (redex-match? generated-delay-e-lang F source)
    (raise-argument-error 'J-delay->search/R/E "Delay E F" source))
  source)

(define (J-disjunction->search/R/E source)
  (unless (redex-match? generated-disjunction-e-lang F source)
    (raise-argument-error 'J-disjunction->search/R/E "Disjunction E F" source))
  source)
