#lang racket

(require redex/reduction-semantics
         "../source-schema.rkt"
         "./kernel.rkt"
         "./language.rkt")

(provide whole-runtime-support/lean-toy
         control-resume/lean-toy
         control-freeze/lean-toy
         initial-tree/lean-toy
         source-red/lean-toy)

(define kernel-leaf-red/lean-toy
  (reduction-relation
   lean-toy-lang
   [--> (Work (succeed tag) kst)
        (Returned kst)
        "work-succeed/core"]
   [--> (Work (fail tag) kst)
        Dead
        "work-fail/core"]
   [--> (Work (put p_new tag) (state p_old))
        (Returned (state p_new))
        "work-put/core"]))

(define-lean-source
  lean-toy-lang
  kernel-leaf-red/lean-toy
  kernel-initial-state/lean-toy
  kernel-open-fresh/lean-toy
  whole-runtime-support/lean-toy
  control-resume/lean-toy
  control-freeze/lean-toy
  initial-tree/lean-toy
  settled-choice-success/lean-toy
  settled-choice-alternate/lean-toy
  source-red/lean-toy)
