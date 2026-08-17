#lang racket

(require redex/reduction-semantics
         "../machine-spec-schema.rkt"
         "./decomposition.rkt"
         "./machine.rkt"
         "./refocused.rkt"
         "./wf.rkt")

(provide initial-M/mk
         machine-corresponds/mk
         machine-step/spec/mk
         ZM-step-square/mk
         reachable-machine/via/mk)

(define-pk-machine-spec
  #:machine-language pk-mk-machine-lang
  #:decompose decompose/mk
  #:well-formed-frontier wf-frontier/mk
  #:d->m D->M/mk
  #:encode encode-ZM/mk
  #:decode decode-MZ/mk
  #:refocused-step refocused-step/direct/mk
  #:machine-step machine-step/direct/mk
  #:machine-steps machine-steps/direct/mk
  #:initial initial-M/mk
  #:corresponds machine-corresponds/mk
  #:step-spec machine-step/spec/mk
  #:step-square ZM-step-square/mk
  #:reachable reachable-machine/via/mk)
