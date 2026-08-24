#lang racket

(require "../../../../framework/disjunction-schema.rkt"
         "../../../../framework/search-join-schema.rkt"
         (only-in "../../../delay/source/e.rkt"
                  generated-delay-e-source)
         (only-in "../../../disjunction/source/e.rkt"
                  disjunction-e-representation-view))

(provide generated-search-reverse-e-child-source
         generated-search-reverse-e-source
         generated-search-reverse-e-lang
         generated-search-reverse-e-red
         raw-successors/generated/search/reverse/e
         wf-search/generated/reverse/e?
         live-supply/generated/search/reverse/e
         failure-summary/generated/search/reverse/e
         q-export/generated/search/reverse/e
         q-rebuild/generated/search/reverse/e
         q-focus-export/generated/search/reverse/e
         q-focus-rebuild/generated/search/reverse/e
         q-root-focus-export/generated/search/reverse/e
         q-root-focus-rebuild/generated/search/reverse/e
         q-failure-focus-export/generated/search/reverse/e
         q-failure-focus-rebuild/generated/search/reverse/e
         q-terminal-export/generated/search/reverse/e
         q-terminal-rebuild/generated/search/reverse/e)

(define-generated-disjunction-source generated-search-reverse-e-child-source
  #:base generated-delay-e-source
  #:representation disjunction-e-representation-view
  #:language generated-search-reverse-e-lang
  #:relation generated-search-reverse-e-red
  #:raw-successors raw-successors/generated/search/reverse/e
  #:wf-root wf-search/generated/reverse/e?
  #:live-supply live-supply/generated/search/reverse/e
  #:failure-summary failure-summary/generated/search/reverse/e
  #:Q
  [#:export q-export/generated/search/reverse/e
   #:rebuild q-rebuild/generated/search/reverse/e
   #:focus-export q-focus-export/generated/search/reverse/e
   #:focus-rebuild q-focus-rebuild/generated/search/reverse/e
   #:root-focus-export q-root-focus-export/generated/search/reverse/e
   #:root-focus-rebuild q-root-focus-rebuild/generated/search/reverse/e
   #:failure-focus-export q-failure-focus-export/generated/search/reverse/e
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/search/reverse/e
   #:terminal-export q-terminal-export/generated/search/reverse/e
   #:terminal-rebuild q-terminal-rebuild/generated/search/reverse/e])

(define-generated-search-join-source generated-search-reverse-e-source
  #:base generated-search-reverse-e-child-source
  #:owned-rule-labels ())
