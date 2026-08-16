#lang racket

(require redex/reduction-semantics
         "../source-schema.rkt"
         "./kernel.rkt"
         "./language.rkt")

(provide initial-tree/mk
         source-red/mk)

;; Kmk contributes one direct, statically named Redex clause for each atomic
;; outcome.  The kernel judgment computes or validates opaque kernel data
;; under a fixed expected label; it does not choose a source context or turn a
;; generic wrapper into a source rule.
(define kernel-leaf-red/mk
  (reduction-relation
   pk-mk-lang
   [--> (Work (succeed tag) kst)
        (Returned kst)
        (judgment-holds
         (kernel-step/mk
          (succeed tag)
          kst
          (KernelSuccess kst)
          (kernel succeed core)))
        "kernel:succeed/core"]
   [--> (Work (fail tag) kst)
        Dead
        (judgment-holds
         (kernel-step/mk
          (fail tag)
          kst
          KernelFailure
          (kernel fail core)))
        "kernel:fail/core"]
   [--> (Work (t_1 =? t_2 tag) kst)
        (Returned kst_new)
        (judgment-holds
         (kernel-step/mk
          (t_1 =? t_2 tag)
          kst
          (KernelSuccess kst_new)
          (kernel unify-success core)))
        "kernel:unify-success/core"]
   [--> (Work (t_1 =? t_2 tag) kst)
        Dead
        (judgment-holds
         (kernel-step/mk
          (t_1 =? t_2 tag)
          kst
          KernelFailure
          (kernel unify-violates-disequality core)))
        "kernel:unify-violates-disequality/core"]
   [--> (Work (t_1 =? t_2 tag) kst)
        Dead
        (judgment-holds
         (kernel-step/mk
          (t_1 =? t_2 tag)
          kst
          KernelFailure
          (kernel unify-fail core)))
        "kernel:unify-fail/core"]
   [--> (Work (t_1 != t_2 tag) kst)
        (Returned kst_new)
        (judgment-holds
         (kernel-step/mk
          (t_1 != t_2 tag)
          kst
          (KernelSuccess kst_new)
          (kernel disequality-success core)))
        "kernel:disequality-success/core"]
   [--> (Work (t_1 != t_2 tag) kst)
        Dead
        (judgment-holds
         (kernel-step/mk
          (t_1 != t_2 tag)
          kst
          KernelFailure
          (kernel disequality-fail core)))
        "kernel:disequality-fail/core"]))

(define-pk-source
  pk-mk-lang
  kernel-leaf-red/mk
  kernel-initial-state/mk
  kernel-open-fresh/mk
  whole-marker-support/mk
  control-resume/mk
  control-freeze/mk
  initial-tree/mk
  settled-choice-success/mk
  settled-choice-alternate/mk
  source-red/mk)
