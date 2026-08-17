#lang racket

(require redex/reduction-semantics
         "../compressed-schema.rkt"
         "./kernel.rkt"
         "./machine.rkt"
         "./wf.rkt")

(provide pk-toy-compressed-lang
         residual-state/toy
         symbolic-path/direct/toy
         compressed-step/direct/toy
         compressed-steps/direct/toy
         initial-compressed-query/direct/toy
         initial-compressed/direct/toy
         compressed-readback/toy
         reachable-compressed/via/toy
         compressed-red/direct/toy)

(check-redundancy #t)

(define-pk-compressed
  pk-toy-compressed-lang
  pk-toy-machine-lang
  kernel-step/toy
  kernel-open-fresh/toy
  whole-marker-support/toy
  control-resume/toy
  control-freeze/toy
  wf-frontier/toy
  residual-state/toy
  symbolic-path/direct/toy
  compressed-step/direct/toy
  compressed-steps/direct/toy
  initial-compressed-query/direct/toy
  initial-compressed/direct/toy
  compressed-readback/toy
  reachable-compressed/via/toy
  compressed-red/direct/toy)
