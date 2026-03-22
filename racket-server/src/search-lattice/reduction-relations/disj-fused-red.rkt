#lang racket

(require redex/reduction-semantics
         "../languages/core-lang.rkt"
         "../languages/disj-fused-lang.rkt"
         "./private/common.rkt"
         "./private/context-pipeline.rkt"
         "./private/core-common.rkt"
         "./private/step-utils.rkt")

(provide disj-fused-red
         step-once)

(check-redundancy #t)

(define core-redex/disj (extend-core-redex disj-fused-lang))
(define core-collector/disj (make-core-collector disj-fused-lang))
 (define-search-frontier/one-stage core-frontier/disj core-redex/disj disj-fused-lang K)

(define disj-extra
  (reduction-relation
   disj-fused-lang
   #:domain f
   [--> (in-hole K ((g_1 ∨ g_2 tag) σ))
        (in-hole K ((g_1 σ) <-+ (g_2 σ)))
        "disj-fused/goal-to-tree"]
   [--> (in-hole K (((⊤ σ_new) <-+ f_rest) × g c))
        (in-hole K ((g σ_new) <-+ (f_rest × g c)))
        "disj-fused/continue-left-answer"]
   [--> (in-hole K (((empty-tree) <-+ f_rest) × g c))
        (in-hole K (f_rest × g c))
        "disj-fused/continue-left-fail"]
   [--> (in-hole K (((⊤ σ_new) <-+ f_mid) <-+ f_right))
        (in-hole K ((⊤ σ_new) <-+ (f_mid <-+ f_right)))
        "disj-fused/bubble-left-answer"]
   [--> ((⊤ σ_new) <-+ f_right)
        ((⊤ σ_new) + f_right)
        "disj-fused/promote-left-answer"]
   [--> (in-hole K (((empty-tree) <-+ f_mid) <-+ f_right))
        (in-hole K ((empty-tree) <-+ (f_mid <-+ f_right)))
        "disj-fused/bubble-left-fail"]
   [--> ((empty-tree) <-+ f_right)
        f_right
        "disj-fused/skip-left-fail"]))

(define disj-frontier
  (context-closure disj-extra disj-fused-lang P))

(define disj-fused-red
  (union-reduction-relations
   disj-frontier
   core-frontier/disj
   core-collector/disj))

(define (step-once prog)
  (step-once/deterministic disj-fused-red prog))
