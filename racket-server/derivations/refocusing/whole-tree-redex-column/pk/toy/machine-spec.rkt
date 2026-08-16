#lang racket

(require redex/reduction-semantics
         "../machine-spec-schema.rkt"
         "./decomposition.rkt"
         "./machine.rkt"
         "./refocused.rkt"
         "./wf.rkt")

(provide initial-M/toy
         machine-corresponds/toy
         machine-step/spec/toy
         ZM-step-square/toy
         reachable-machine/via/toy)

(define-pk-machine-spec
  #:machine-language pk-toy-machine-lang
  #:decompose decompose/toy
  #:well-formed-frontier wf-frontier/toy
  #:d->m D->M/toy
  #:encode encode-ZM/toy
  #:decode decode-MZ/toy
  #:refocused-step refocused-step/direct/toy
  #:machine-step machine-step/direct/toy
  #:machine-steps machine-steps/direct/toy
  #:initial initial-M/toy
  #:corresponds machine-corresponds/toy
  #:step-spec machine-step/spec/toy
  #:step-square ZM-step-square/toy
  #:reachable reachable-machine/via/toy)
