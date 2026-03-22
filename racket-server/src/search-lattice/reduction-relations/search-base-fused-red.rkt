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
(define core-collector/search-base-fused (make-core-collector search-base-fused-lang))
 (define-search-frontier/one-stage
  core-frontier/search-base-fused
  core-redex/search-base-fused
  search-base-fused-lang
  K)

(define delay-extra
  (reduction-relation
   search-base-fused-lang
   #:domain f
   [--> (in-hole K ((suspend g tag) σ))
        (in-hole K (delay (g σ)))
        "delay/suspend-goal"]
   [--> (delay f_1)
        (Bounced + f_1)
        "delay/invoke-delay"]
   [--> (in-hole K ((delay f_1) × g c))
        (in-hole K (delay (f_1 × g c)))
        "delay/delay-through-conj"]))

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
        "search-base-fused/continue-left-fail"]
   [--> ((evt + f_left) <-+ f_right)
        (evt + (f_left <-+ f_right))
        "search-base-fused/continue-left-prefix"]
   [--> (in-hole K (((⊤ σ_new) <-+ f_mid) <-+ f_right))
        (in-hole K ((⊤ σ_new) <-+ (f_mid <-+ f_right)))
        "search-base-fused/bubble-left-answer"]
   [--> ((⊤ σ_new) <-+ f_right)
        ((⊤ σ_new) + f_right)
        "search-base-fused/promote-left-answer"]
   [--> (in-hole K (((empty-tree) <-+ f_mid) <-+ f_right))
        (in-hole K ((empty-tree) <-+ (f_mid <-+ f_right)))
        "search-base-fused/bubble-left-fail"]
   [--> ((empty-tree) <-+ f_right)
        f_right
        "search-base-fused/skip-left-fail"]))

(define delay-frontier
  (context-closure delay-extra search-base-fused-lang P))

(define search-frontier
  (context-closure search-extra search-base-fused-lang P))

(define search-base-fused-red
  (union-reduction-relations
   search-frontier
   delay-frontier
   core-frontier/search-base-fused
   core-collector/search-base-fused))

(define (step-once prog)
  (step-once/deterministic search-base-fused-red prog))
