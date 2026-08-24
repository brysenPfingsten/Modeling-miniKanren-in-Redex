#lang racket

(require "../../../../framework/disjunction-schema.rkt"
         "../../../../framework/search-join-schema.rkt"
         (only-in "../../../delay/source/n.rkt"
                  generated-delay-n-source)
         (only-in "../../../disjunction/source/n.rkt"
                  disjunction-n-representation-view))

(provide generated-search-reverse-n-child-source
         generated-search-reverse-n-source
         generated-search-reverse-n-lang
         generated-search-reverse-n-red
         raw-successors/generated/search/reverse/n
         wf-search/generated/reverse/n?
         live-supply/generated/search/reverse/n
         failure-summary/generated/search/reverse/n
         q-export/generated/search/reverse/n
         q-rebuild/generated/search/reverse/n
         q-focus-export/generated/search/reverse/n
         q-focus-rebuild/generated/search/reverse/n
         q-root-focus-export/generated/search/reverse/n
         q-root-focus-rebuild/generated/search/reverse/n
         q-failure-focus-export/generated/search/reverse/n
         q-failure-focus-rebuild/generated/search/reverse/n
         q-terminal-export/generated/search/reverse/n
         q-terminal-rebuild/generated/search/reverse/n)

(define-generated-disjunction-source generated-search-reverse-n-child-source
  #:base generated-delay-n-source
  #:representation disjunction-n-representation-view
  #:language generated-search-reverse-n-lang
  #:relation generated-search-reverse-n-red
  #:raw-successors raw-successors/generated/search/reverse/n
  #:wf-root wf-search/generated/reverse/n?
  #:live-supply live-supply/generated/search/reverse/n
  #:failure-summary failure-summary/generated/search/reverse/n
  #:Q
  [#:export q-export/generated/search/reverse/n
   #:rebuild q-rebuild/generated/search/reverse/n
   #:focus-export q-focus-export/generated/search/reverse/n
   #:focus-rebuild q-focus-rebuild/generated/search/reverse/n
   #:root-focus-export q-root-focus-export/generated/search/reverse/n
   #:root-focus-rebuild q-root-focus-rebuild/generated/search/reverse/n
   #:failure-focus-export q-failure-focus-export/generated/search/reverse/n
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/search/reverse/n
   #:terminal-export q-terminal-export/generated/search/reverse/n
   #:terminal-rebuild q-terminal-rebuild/generated/search/reverse/n])

(define-generated-search-join-source generated-search-reverse-n-source
  #:base generated-search-reverse-n-child-source
  #:owned-rule-labels ())
