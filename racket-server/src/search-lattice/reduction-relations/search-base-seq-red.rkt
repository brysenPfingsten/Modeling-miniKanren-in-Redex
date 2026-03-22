#lang racket

(require redex/reduction-semantics
         "../languages/search-base-seq-lang.rkt"
         "./private/common.rkt"
         "./private/context-pipeline.rkt"
         "./private/core-common.rkt"
         "./private/step-utils.rkt")

(provide search-base-seq-red
         step-once)

(check-redundancy #t)

(define core-redex/search-base-seq (extend-core-redex search-base-seq-lang))
(define core-collector/search-base-seq (make-core-collector search-base-seq-lang))
 (define-search-frontier/two-stage
  core-frontier/search-base-seq
  core-redex/search-base-seq
  search-base-seq-lang
  K
  KDisj)

(define delay-extra
  (reduction-relation
   search-base-seq-lang
   #:domain f
   [--> (in-hole KDisj (in-hole K ((suspend g tag) σ)))
        (in-hole KDisj (in-hole K (delay (g σ))))
        "delay/suspend-goal"]
   [--> (delay f_1)
        (Bounced + f_1)
        "delay/invoke-delay"]
   [--> (in-hole KDisj (in-hole K ((delay f_1) × g c)))
        (in-hole KDisj (in-hole K (delay (f_1 × g c))))
        "delay/delay-through-conj"]))

(define search-extra
  (reduction-relation
   search-base-seq-lang
   #:domain f
   [--> (in-hole KDisj (in-hole K ((g_1 ∨ g_2 tag) σ)))
        (in-hole KDisj (in-hole K ((g_1 σ) <-+ (g_2 σ))))
        "search-base-seq/goal-to-tree"]
   [--> (in-hole KDisj (in-hole K (((⊤ σ_new) + f_rest) × g c)))
        (in-hole KDisj (in-hole K ((g σ_new) <-+ (f_rest × g c))))
        "search-base-seq/continue-left-prefix-answer"]
   [--> (in-hole KDisj (in-hole K ((Bounced + f_rest) × g c)))
        (in-hole KDisj (in-hole K (Bounced + (f_rest × g c))))
        "search-base-seq/continue-left-prefix-bounce"]
   [--> (in-hole KDisj (in-hole K ((f_1 <-+ f_2) × g c)))
        (in-hole KDisj (in-hole K ((f_1 × g c) <-+ (f_2 × g c))))
        "search-base-seq/distribute-over-conj"]
   [--> ((evt + f_left) <-+ f_right)
        (evt + (f_left <-+ f_right))
        "search-base-seq/continue-left-prefix"]
   [--> (in-hole KDisj (((⊤ σ_new) <-+ f_mid) <-+ f_right))
        (in-hole KDisj ((⊤ σ_new) <-+ (f_mid <-+ f_right)))
        "search-base-seq/bubble-left-answer"]
   [--> ((⊤ σ_new) <-+ f_right)
        ((⊤ σ_new) + f_right)
        "search-base-seq/promote-left-answer"]
   [--> (in-hole KDisj (((empty-tree) <-+ f_mid) <-+ f_right))
        (in-hole KDisj ((empty-tree) <-+ (f_mid <-+ f_right)))
        "search-base-seq/bubble-left-fail"]
   [--> ((empty-tree) <-+ f_right)
        f_right
        "search-base-seq/skip-left-fail"]))

(define delay-frontier
  (context-closure delay-extra search-base-seq-lang P))

(define search-frontier
  (context-closure search-extra search-base-seq-lang P))

(define search-base-seq-red
  (union-reduction-relations
   search-frontier
   delay-frontier
   core-frontier/search-base-seq
   core-collector/search-base-seq))

(define (step-once prog)
  (step-once/deterministic search-base-seq-red prog))
