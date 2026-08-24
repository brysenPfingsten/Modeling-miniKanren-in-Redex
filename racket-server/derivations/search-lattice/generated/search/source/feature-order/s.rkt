#lang racket

(require "../../../../framework/disjunction-schema.rkt"
         "../../../../framework/search-join-schema.rkt"
         (only-in "../../../delay/source/s.rkt"
                  generated-delay-s-source)
         (only-in "../../../disjunction/source/s.rkt"
                  disjunction-s-representation-view))

(provide generated-search-reverse-s-child-source
         generated-search-reverse-s-source
         generated-search-reverse-s-lang
         generated-search-reverse-s-red
         raw-successors/generated/search/reverse/s
         wf-search/generated/reverse/s?
         live-supply/generated/search/reverse/s
         failure-summary/generated/search/reverse/s
         q-export/generated/search/reverse/s
         q-rebuild/generated/search/reverse/s
         q-focus-export/generated/search/reverse/s
         q-focus-rebuild/generated/search/reverse/s
         q-root-focus-export/generated/search/reverse/s
         q-root-focus-rebuild/generated/search/reverse/s
         q-failure-focus-export/generated/search/reverse/s
         q-failure-focus-rebuild/generated/search/reverse/s
         q-terminal-export/generated/search/reverse/s
         q-terminal-rebuild/generated/search/reverse/s)

;; Test-only reverse feature order: Core, then Delay, then Disjunction.  It is
;; independently generated; no adapter decodes through the canonical source.
(define-generated-disjunction-source generated-search-reverse-s-child-source
  #:base generated-delay-s-source
  #:representation disjunction-s-representation-view
  #:language generated-search-reverse-s-lang
  #:relation generated-search-reverse-s-red
  #:raw-successors raw-successors/generated/search/reverse/s
  #:wf-root wf-search/generated/reverse/s?
  #:live-supply live-supply/generated/search/reverse/s
  #:failure-summary failure-summary/generated/search/reverse/s
  #:Q
  [#:export q-export/generated/search/reverse/s
   #:rebuild q-rebuild/generated/search/reverse/s
   #:focus-export q-focus-export/generated/search/reverse/s
   #:focus-rebuild q-focus-rebuild/generated/search/reverse/s
   #:root-focus-export q-root-focus-export/generated/search/reverse/s
   #:root-focus-rebuild q-root-focus-rebuild/generated/search/reverse/s
   #:failure-focus-export q-failure-focus-export/generated/search/reverse/s
   #:failure-focus-rebuild q-failure-focus-rebuild/generated/search/reverse/s
   #:terminal-export q-terminal-export/generated/search/reverse/s
   #:terminal-rebuild q-terminal-rebuild/generated/search/reverse/s])

(define-generated-search-join-source generated-search-reverse-s-source
  #:base generated-search-reverse-s-child-source
  #:owned-rule-labels ())
