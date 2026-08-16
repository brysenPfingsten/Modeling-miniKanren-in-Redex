#lang racket

(require redex/reduction-semantics
         "../compression-spec-schema.rkt"
         "./compressed.rkt"
         "./machine.rkt"
         "./wf.rkt")

(provide pk-toy-compression-spec-lang
         decode-BM/toy
         replay-labels/exact/toy
         replay-span/exact/toy
         replay-spans/exact/toy
         root-fresh-machine/toy
         not-root-fresh-machine/toy
         corridor-continue-first/toy
         corridor-stop-first/toy
         corridor-continue-second/toy
         corridor-stop-second/toy
         compressed-step/spec/toy
         compression-step-square/toy
         compression-steps-square/toy
         reachable-compression-correspondence/toy)

(check-redundancy #t)

(define-pk-compression-spec
  pk-toy-compression-spec-lang
  pk-toy-compressed-lang
  machine-refocus-query/direct/toy
  machine-step/direct/toy
  wf-frontier/toy
  compressed-step/direct/toy
  initial-compressed/direct/toy
  decode-BM/toy
  replay-labels/exact/toy
  replay-span/exact/toy
  replay-spans/exact/toy
  root-fresh-machine/toy
  not-root-fresh-machine/toy
  corridor-continue-first/toy
  corridor-stop-first/toy
  corridor-continue-second/toy
  corridor-stop-second/toy
  compressed-step/spec/toy
  compression-step-square/toy
  compression-steps-square/toy
  reachable-compression-correspondence/toy)
