#lang racket

(require redex/reduction-semantics
         "../machine-schema.rkt"
         "./decomposition.rkt"
         "./labels.rkt"
         "./refocused.rkt")

(provide pk-toy-machine-lang
         encode-ZM/toy
         decode-MZ/toy
         D->M/toy
         M->D/toy
         readback-M/toy
         machine-refocus-query/direct/toy
         machine-refocus/direct/toy
         machine-step/direct/toy
         machine-steps/direct/toy
         machine-red/direct/toy)

(check-redundancy #t)

(define-pk-machine-stage
  #:refocused-language pk-toy-refocused-lang
  #:machine-language pk-toy-machine-lang
  #:contract contract/toy
  #:contract-label contract-label/toy
  #:label->redex-name label->redex-name/toy
  #:encode encode-ZM/toy
  #:decode decode-MZ/toy
  #:d->m D->M/toy
  #:m->d M->D/toy
  #:readback readback-M/toy
  #:refocus-query machine-refocus-query/direct/toy
  #:refocus machine-refocus/direct/toy
  #:step machine-step/direct/toy
  #:steps machine-steps/direct/toy
  #:relation machine-red/direct/toy)
