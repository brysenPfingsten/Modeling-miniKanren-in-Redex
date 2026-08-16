#lang racket

(require redex/reduction-semantics
         "../source-schema.rkt"
         "./kernel.rkt"
         "./language.rkt")

(provide initial-tree/toy
         source-red/toy)

;; Ktoy contributes one genuine named Redex rule for each atomic outcome.
;; The shared source schema lifts this W relation through the grammatical WF
;; contexts; no judgment-backed generic source rule is involved.
(define kernel-leaf-red/toy
  (reduction-relation
   pk-toy-lang
   [--> (Work (succeed tag) kst)
        (Returned kst)
        "work-succeed/core"]
   [--> (Work (fail tag) kst)
        Dead
        "work-fail/core"]
   [--> (Work (put p_new tag) (state p_old))
        (Returned (state p_new))
        "work-put/core"]))

(define-pk-source
  pk-toy-lang
  kernel-leaf-red/toy
  kernel-initial-state/toy
  kernel-open-fresh/toy
  whole-marker-support/toy
  control-resume/toy
  control-freeze/toy
  initial-tree/toy
  settled-choice-success/toy
  settled-choice-alternate/toy
  source-red/toy)
