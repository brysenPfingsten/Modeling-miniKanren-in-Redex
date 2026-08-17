#lang racket

(require redex/reduction-semantics
         "../compression-spec-schema.rkt"
         "./compressed.rkt"
         "./machine.rkt"
         "./wf.rkt")

(provide pk-mk-compression-spec-lang
         decode-BM/mk
         replay-labels/exact/mk
         replay-span/exact/mk
         replay-spans/exact/mk
         root-fresh-machine/mk
         not-root-fresh-machine/mk
         corridor-continue-first/mk
         corridor-stop-first/mk
         corridor-continue-second/mk
         corridor-stop-second/mk
         compressed-step/spec/mk
         compression-step-square/mk
         compression-steps-square/mk
         reachable-compression-correspondence/mk)

(check-redundancy #t)

(define-pk-compression-spec
  pk-mk-compression-spec-lang
  pk-mk-compressed-lang
  machine-refocus-query/direct/mk
  machine-step/direct/mk
  wf-frontier/mk
  compressed-step/direct/mk
  initial-compressed/direct/mk
  decode-BM/mk
  replay-labels/exact/mk
  replay-span/exact/mk
  replay-spans/exact/mk
  root-fresh-machine/mk
  not-root-fresh-machine/mk
  corridor-continue-first/mk
  corridor-stop-first/mk
  corridor-continue-second/mk
  corridor-stop-second/mk
  compressed-step/spec/mk
  compression-step-square/mk
  compression-steps-square/mk
  reachable-compression-correspondence/mk)
