#lang racket

(require redex/reduction-semantics
         "../languages/search-base-fused-lang.rkt"
         "./private/common.rkt"
         "./private/context-pipeline.rkt"
         "./private/core-common.rkt"
         "./private/step-utils.rkt")

(provide search-base-fused-red
         step-once)

(check-redundancy #t)

(define core-redex/search-base-fused (extend-core-redex search-base-fused-lang))
(define-search-frontier/one-stage
  core-frontier/search-base-fused
  core-redex/search-base-fused
  search-base-fused-lang
  K)

(define delay-local
  (reduction-relation
   search-base-fused-lang
   #:domain f
   [--> (in-hole K ((suspend g tag) σ))
        (in-hole K (delay (g σ)))
        "delay/suspend-goal"]
   [--> (in-hole K ((delay f_1) × g c))
        (in-hole K (delay (f_1 × g c)))
        "delay/delay-through-conj"]))

(define delay-frontier-extra
  (reduction-relation
   search-base-fused-lang
   #:domain f
   [--> (in-hole P (delay f_1))
        (in-hole P (Bounced + f_1))
        "delay/invoke-delay"]))

(define search-extra
  (reduction-relation
   search-base-fused-lang
   #:domain f
   [--> (in-hole K ((g_1 ∨ g_2 tag) σ))
        (in-hole K ((g_1 σ) <-+ (g_2 σ)))
        "search-base-fused/goal-to-tree"]
   [--> (in-hole K (((⊤ σ_new) + f_rest) × g c))
        (in-hole K ((g σ_new) <-+ (f_rest × g c)))
        "search-base-fused/continue-left-prefix-answer"]
   [--> (in-hole K ((Bounced + f_rest) × g c))
        (in-hole K (Bounced + (f_rest × g c)))
        "search-base-fused/continue-left-prefix-bounce"]
   [--> (in-hole K (((⊤ σ_new) <-+ f_rest) × g c))
        (in-hole K ((g σ_new) <-+ (f_rest × g c)))
        "search-base-fused/continue-left-answer"]
   [--> (in-hole K (((empty-tree) <-+ f_rest) × g c))
        (in-hole K (f_rest × g c))
        "search-base-fused/continue-left-fail"]))

(define search-frontier-extra
  (reduction-relation
   search-base-fused-lang
   #:domain f
   [--> ((pref_1 + f_left) <-+ f_right)
        (pref_1 + (f_left <-+ f_right))
        "search-base-fused/continue-left-prefix"]
   [--> ((pref_1 <-+ f_mid) <-+ f_right)
        (pref_1 <-+ (f_mid <-+ f_right))
        "search-base-fused/bubble-left-observable"]
   [--> (pref_1 <-+ f_right)
        (pref_1 + f_right)
        "search-base-fused/promote-left-observable"]
   [--> (((empty-tree) <-+ f_mid) <-+ f_right)
        ((empty-tree) <-+ (f_mid <-+ f_right))
        "search-base-fused/bubble-left-fail"]
   [--> ((empty-tree) <-+ f_right)
        f_right
        "search-base-fused/skip-left-fail"]))

(define delay-extra
  (context-closure delay-local search-base-fused-lang Q))

(define delay-frontier delay-frontier-extra)

(define search-frontier
  (context-closure search-frontier-extra search-base-fused-lang P))

(define search-local
  (context-closure search-extra search-base-fused-lang Q))

(define search-base-fused-red
  (union-reduction-relations
   search-local
   search-frontier
   delay-frontier
   delay-extra
   core-frontier/search-base-fused))

(define (step-once prog)
  (step-once/deterministic search-base-fused-red prog))
