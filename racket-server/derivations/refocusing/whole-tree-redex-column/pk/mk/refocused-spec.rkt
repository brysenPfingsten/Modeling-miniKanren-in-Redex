#lang racket

(require redex/reduction-semantics
         "../refocused-spec-schema.rkt"
         "./decomposition.rkt"
         "./refocused.rkt"
         "./wf.rkt")

(provide initial-Z/mk
         refocus-spec/mk
         refocused-step/spec/mk
         reachable-refocused/via/mk)

(define-pk-refocused-spec
  #:refocused-language pk-mk-refocused-lang
  #:decompose decompose/mk
  #:contract contract/mk
  #:contract-label contract-label/mk
  #:plug-contract plug-C/mk
  #:well-formed-frontier wf-frontier/mk
  #:d->z D->Z/mk
  #:z->d Z->D/mk
  #:direct-steps refocused-steps/direct/mk
  #:initial initial-Z/mk
  #:refocus-spec refocus-spec/mk
  #:step-spec refocused-step/spec/mk
  #:reachable reachable-refocused/via/mk)
