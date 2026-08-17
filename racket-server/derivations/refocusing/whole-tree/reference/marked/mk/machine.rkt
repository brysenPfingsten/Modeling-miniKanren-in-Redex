#lang racket

(require redex/reduction-semantics
         "../machine-schema.rkt"
         "./decomposition.rkt"
         "./labels.rkt"
         "./refocused.rkt")

(provide pk-mk-machine-lang
         encode-ZM/mk
         decode-MZ/mk
         D->M/mk
         M->D/mk
         readback-M/mk
         machine-refocus-query/direct/mk
         machine-refocus/direct/mk
         machine-step/direct/mk
         machine-steps/direct/mk
         machine-red/direct/mk)

(check-redundancy #t)

(define-pk-machine-stage
  #:refocused-language pk-mk-refocused-lang
  #:machine-language pk-mk-machine-lang
  #:contract contract/mk
  #:contract-label contract-label/mk
  #:label->redex-name label->redex-name/mk
  #:encode encode-ZM/mk
  #:decode decode-MZ/mk
  #:d->m D->M/mk
  #:m->d M->D/mk
  #:readback readback-M/mk
  #:refocus-query machine-refocus-query/direct/mk
  #:refocus machine-refocus/direct/mk
  #:step machine-step/direct/mk
  #:steps machine-steps/direct/mk
  #:relation machine-red/direct/mk)
