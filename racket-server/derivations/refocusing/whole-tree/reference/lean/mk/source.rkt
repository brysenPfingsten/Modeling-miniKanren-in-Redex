#lang racket

(require redex/reduction-semantics
         "../source-schema.rkt"
         "./kernel.rkt"
         "./language.rkt")

(provide whole-runtime-support/lean-mk
         control-resume/lean-mk
         control-freeze/lean-mk
         initial-tree/lean-mk
         source-red/lean-mk)

(define kernel-leaf-red/lean-mk
  (reduction-relation
   lean-mk-lang
   [--> (Work (succeed tag) kst)
        (Returned kst)
        (judgment-holds
         (kernel-step/lean-mk
          (succeed tag)
          kst
          (KernelSuccess kst)
          (kernel succeed core)))
        "kernel:succeed/core"]
   [--> (Work (fail tag) kst)
        Dead
        (judgment-holds
         (kernel-step/lean-mk
          (fail tag)
          kst
          KernelFailure
          (kernel fail core)))
        "kernel:fail/core"]
   [--> (Work (t_1 =? t_2 tag) kst)
        (Returned kst_new)
        (judgment-holds
         (kernel-step/lean-mk
          (t_1 =? t_2 tag)
          kst
          (KernelSuccess kst_new)
          (kernel unify-success core)))
        "kernel:unify-success/core"]
   [--> (Work (t_1 =? t_2 tag) kst)
        Dead
        (judgment-holds
         (kernel-step/lean-mk
          (t_1 =? t_2 tag)
          kst
          KernelFailure
          (kernel unify-violates-disequality core)))
        "kernel:unify-violates-disequality/core"]
   [--> (Work (t_1 =? t_2 tag) kst)
        Dead
        (judgment-holds
         (kernel-step/lean-mk
          (t_1 =? t_2 tag)
          kst
          KernelFailure
          (kernel unify-fail core)))
        "kernel:unify-fail/core"]
   [--> (Work (t_1 != t_2 tag) kst)
        (Returned kst_new)
        (judgment-holds
         (kernel-step/lean-mk
          (t_1 != t_2 tag)
          kst
          (KernelSuccess kst_new)
          (kernel disequality-success core)))
        "kernel:disequality-success/core"]
   [--> (Work (t_1 != t_2 tag) kst)
        Dead
        (judgment-holds
         (kernel-step/lean-mk
          (t_1 != t_2 tag)
          kst
          KernelFailure
          (kernel disequality-fail core)))
        "kernel:disequality-fail/core"]))

(define-lean-source
  lean-mk-lang
  kernel-leaf-red/lean-mk
  kernel-initial-state/lean-mk
  kernel-open-fresh/lean-mk
  whole-runtime-support/lean-mk
  control-resume/lean-mk
  control-freeze/lean-mk
  initial-tree/lean-mk
  settled-choice-success/lean-mk
  settled-choice-alternate/lean-mk
  source-red/lean-mk)
