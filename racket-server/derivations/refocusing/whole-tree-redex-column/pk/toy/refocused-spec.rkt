#lang racket

(require redex/reduction-semantics
         "../refocused-spec-schema.rkt"
         "./decomposition.rkt"
         "./refocused.rkt"
         "./wf.rkt")

(provide initial-Z/toy
         refocus-spec/toy
         refocused-step/spec/toy
         reachable-refocused/via/toy)

(define-pk-refocused-spec
  #:refocused-language pk-toy-refocused-lang
  #:decompose decompose/toy
  #:contract contract/toy
  #:contract-label contract-label/toy
  #:plug-contract plug-C/toy
  #:well-formed-frontier wf-frontier/toy
  #:d->z D->Z/toy
  #:z->d Z->D/toy
  #:direct-steps refocused-steps/direct/toy
  #:initial initial-Z/toy
  #:refocus-spec refocus-spec/toy
  #:step-spec refocused-step/spec/toy
  #:reachable reachable-refocused/via/toy)
