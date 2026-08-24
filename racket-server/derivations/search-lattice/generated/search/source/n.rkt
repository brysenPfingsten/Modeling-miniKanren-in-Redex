#lang racket

(require redex/reduction-semantics
         "../../../framework/delay-schema.rkt"
         "../../../framework/search-join-schema.rkt"
         (only-in "../../core/source/n.rkt"
                  generated-core-n-lang)
         (only-in "../../delay/source/n.rkt"
                  delay-n-representation-view
                  generated-delay-n-lang)
         (only-in "../../disjunction/source/n.rkt"
                  generated-disjunction-n-lang
                  generated-disjunction-n-source))

(provide generated-search-n-child-source
         generated-search-n-source
         generated-search-n-lang
         generated-search-n-red
         raw-successors/generated/search/n
         wf-search/generated/n?
         live-supply/generated/search/n
         failure-summary/generated/search/n
         q-export/generated/search/n
         q-rebuild/generated/search/n
         q-focus-export/generated/search/n
         q-focus-rebuild/generated/search/n
         q-root-focus-export/generated/search/n
         q-root-focus-rebuild/generated/search/n
         q-failure-focus-export/generated/search/n
         q-failure-focus-rebuild/generated/search/n
         q-terminal-export/generated/search/n
         q-terminal-rebuild/generated/search/n
         J-core->search/R/N
         J-delay->search/R/N
         J-disjunction->search/R/N)

(define-generated-delay-source generated-search-n-child-source
  #:base generated-disjunction-n-source
  #:representation delay-n-representation-view
  #:language generated-search-n-lang
  #:relation generated-search-n-red
  #:raw-successors raw-successors/generated/search/n
  #:wf-root wf-search/generated/n?
  #:live-supply live-supply/generated/search/n
  #:failure-summary failure-summary/generated/search/n
  #:Q
  [#:export q-export/generated/search/n
   #:rebuild q-rebuild/generated/search/n
   #:focus-export q-focus-export/generated/search/n
   #:focus-rebuild q-focus-rebuild/generated/search/n
   #:root-focus-export q-root-focus-export/generated/search/n
   #:root-focus-rebuild q-root-focus-rebuild/generated/search/n
   #:failure-focus-export q-failure-focus-export/generated/search/n
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/search/n
   #:terminal-export q-terminal-export/generated/search/n
   #:terminal-rebuild q-terminal-rebuild/generated/search/n])

(define-generated-search-join-source generated-search-n-source
  #:base generated-search-n-child-source
  #:owned-rule-labels ())

(define (J-core->search/R/N source)
  (unless (redex-match? generated-core-n-lang F source)
    (raise-argument-error 'J-core->search/R/N "core N F" source))
  source)

(define (J-delay->search/R/N source)
  (unless (redex-match? generated-delay-n-lang F source)
    (raise-argument-error 'J-delay->search/R/N "Delay N F" source))
  source)

(define (J-disjunction->search/R/N source)
  (unless (redex-match? generated-disjunction-n-lang F source)
    (raise-argument-error 'J-disjunction->search/R/N "Disjunction N F" source))
  source)
