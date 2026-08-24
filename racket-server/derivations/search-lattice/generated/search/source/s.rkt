#lang racket

(require redex/reduction-semantics
         "../../../framework/delay-schema.rkt"
         "../../../framework/search-join-schema.rkt"
         (only-in "../../core/source/s.rkt"
                  generated-core-s-lang)
         (only-in "../../delay/source/s.rkt"
                  delay-s-representation-view
                  generated-delay-s-lang)
         (only-in "../../disjunction/source/s.rkt"
                  generated-disjunction-s-lang
                  generated-disjunction-s-source))

(provide generated-search-s-child-source
         generated-search-s-source
         generated-search-s-lang
         generated-search-s-red
         raw-successors/generated/search/s
         wf-search/generated/s?
         live-supply/generated/search/s
         failure-summary/generated/search/s
         q-export/generated/search/s
         q-rebuild/generated/search/s
         q-focus-export/generated/search/s
         q-focus-rebuild/generated/search/s
         q-root-focus-export/generated/search/s
         q-root-focus-rebuild/generated/search/s
         q-failure-focus-export/generated/search/s
         q-failure-focus-rebuild/generated/search/s
         q-terminal-export/generated/search/s
         q-terminal-rebuild/generated/search/s
         J-core->search/R/S
         J-delay->search/R/S
         J-disjunction->search/R/S)

;; Canonical feature order: Core, then Disjunction, then Delay.  Search itself
;; is an explicit zero-rule boundary over that complete child source.
(define-generated-delay-source generated-search-s-child-source
  #:base generated-disjunction-s-source
  #:representation delay-s-representation-view
  #:language generated-search-s-lang
  #:relation generated-search-s-red
  #:raw-successors raw-successors/generated/search/s
  #:wf-root wf-search/generated/s?
  #:live-supply live-supply/generated/search/s
  #:failure-summary failure-summary/generated/search/s
  #:Q
  [#:export q-export/generated/search/s
   #:rebuild q-rebuild/generated/search/s
   #:focus-export q-focus-export/generated/search/s
   #:focus-rebuild q-focus-rebuild/generated/search/s
   #:root-focus-export q-root-focus-export/generated/search/s
   #:root-focus-rebuild q-root-focus-rebuild/generated/search/s
   #:failure-focus-export q-failure-focus-export/generated/search/s
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/search/s
   #:terminal-export q-terminal-export/generated/search/s
   #:terminal-rebuild q-terminal-rebuild/generated/search/s])

(define-generated-search-join-source generated-search-s-source
  #:base generated-search-s-child-source
  #:owned-rule-labels ())

(define (J-core->search/R/S source)
  (unless (redex-match? generated-core-s-lang F source)
    (raise-argument-error 'J-core->search/R/S "core S F" source))
  source)

(define (J-delay->search/R/S source)
  (unless (redex-match? generated-delay-s-lang F source)
    (raise-argument-error 'J-delay->search/R/S "Delay S F" source))
  source)

(define (J-disjunction->search/R/S source)
  (unless (redex-match? generated-disjunction-s-lang F source)
    (raise-argument-error 'J-disjunction->search/R/S "Disjunction S F" source))
  source)
