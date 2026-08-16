#lang racket

(require redex/reduction-semantics
         "../refocused-schema.rkt"
         "./decomposition.rkt"
         "./labels.rkt")

(provide pk-toy-refocused-lang
         D->Z/toy
         Z->D/toy
         readback-Z/toy
         refocus-query/direct/toy
         refocus-direct/toy
         refocused-step/direct/toy
         refocused-steps/direct/toy
         refocused-image/toy
         refocused-red/direct/toy)

(check-redundancy #t)

(define-pk-refocused-stage
  #:decomposition-language pk-toy-decomposition-lang
  #:refocused-language pk-toy-refocused-lang
  #:contract contract/toy
  #:contract-label contract-label/toy
  #:label->redex-name label->redex-name/toy
  #:d->z D->Z/toy
  #:z->d Z->D/toy
  #:readback readback-Z/toy
  #:refocus-query refocus-query/direct/toy
  #:refocus refocus-direct/toy
  #:step refocused-step/direct/toy
  #:steps refocused-steps/direct/toy
  #:image refocused-image/toy
  #:relation refocused-red/direct/toy)
