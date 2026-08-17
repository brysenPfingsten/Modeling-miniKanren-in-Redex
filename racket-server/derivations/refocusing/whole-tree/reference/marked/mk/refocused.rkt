#lang racket

(require redex/reduction-semantics
         "../refocused-schema.rkt"
         "./decomposition.rkt"
         "./labels.rkt")

(provide pk-mk-refocused-lang
         D->Z/mk
         Z->D/mk
         readback-Z/mk
         refocus-query/direct/mk
         refocus-direct/mk
         refocused-step/direct/mk
         refocused-steps/direct/mk
         refocused-image/mk
         refocused-red/direct/mk)

(check-redundancy #t)

(define-pk-refocused-stage
  #:decomposition-language pk-mk-decomposition-lang
  #:refocused-language pk-mk-refocused-lang
  #:contract contract/mk
  #:contract-label contract-label/mk
  #:label->redex-name label->redex-name/mk
  #:d->z D->Z/mk
  #:z->d Z->D/mk
  #:readback readback-Z/mk
  #:refocus-query refocus-query/direct/mk
  #:refocus refocus-direct/mk
  #:step refocused-step/direct/mk
  #:steps refocused-steps/direct/mk
  #:image refocused-image/mk
  #:relation refocused-red/direct/mk)
