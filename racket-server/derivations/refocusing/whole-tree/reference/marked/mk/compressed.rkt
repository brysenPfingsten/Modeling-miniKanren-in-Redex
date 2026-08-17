#lang racket

(require redex/reduction-semantics
         "../compressed-schema.rkt"
         "./kernel.rkt"
         "./machine.rkt"
         "./wf.rkt")

(provide pk-mk-compressed-lang
         residual-state/mk
         symbolic-path/direct/mk
         compressed-step/direct/mk
         compressed-steps/direct/mk
         initial-compressed-query/direct/mk
         initial-compressed/direct/mk
         compressed-readback/mk
         reachable-compressed/via/mk
         compressed-red/direct/mk)

(check-redundancy #t)

(define-pk-compressed
  pk-mk-compressed-lang
  pk-mk-machine-lang
  kernel-step/mk
  kernel-open-fresh/mk
  whole-marker-support/mk
  control-resume/mk
  control-freeze/mk
  wf-frontier/mk
  residual-state/mk
  symbolic-path/direct/mk
  compressed-step/direct/mk
  compressed-steps/direct/mk
  initial-compressed-query/direct/mk
  initial-compressed/direct/mk
  compressed-readback/mk
  reachable-compressed/via/mk
  compressed-red/direct/mk)
