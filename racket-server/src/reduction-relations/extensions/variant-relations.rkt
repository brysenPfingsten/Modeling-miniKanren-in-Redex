#lang racket

(require redex/reduction-semantics
         "../step-utils.rkt"
         "./rcall-eager.rkt"
         "./rcall-lazy.rkt"
         "./rdisj-left.rkt"
         "./rdfs-nodelay.rkt"
         "./rbase-e.rkt"
         "./rbase-l.rkt"
         "./rbase-l4.rkt"
         "./rflip-e.rkt"
         "./rflip-l.rkt"
         "./rrail-e.rkt"
         "./rrail-l.rkt"
         "./core-l3.rkt")

;; Canonical relation names follow the language/relation lattice:
;; - Rl1-call-{eager,lazy}
;; - Rl2-disj-left
;; - Rl3-pre-{eager,lazy}
;; - Rl3-dfs-{eager,lazy}
;; - Rl3-flip-{eager,lazy}
;; - Rl4-rail-{eager,lazy}
;;
;; Legacy names are preserved as aliases for compatibility with existing tests/tools.
(define Rl1-call-eager Rcall-eager)
(define Rl1-call-lazy  Rcall-lazy)
(define Rl2-disj-left  Rdisj-left)
(define Rl3-pre-eager  Rbase-e)
(define Rl3-pre-lazy   Rbase-l)
(define Rl3-flip-eager Rflip-e)
(define Rl3-flip-lazy  Rflip-l)
(define Rl4-rail-eager Rrail-e)
(define Rl4-rail-lazy  Rrail-l)

(define (step-priority name)
  (if (member name
              '("disj/promote-left-stream"
                "dfsn/promote-left-stream"
                "rail/promote-right-stream"))
      5
      0))

(define (determinize-tagged-successors succ*)
  (match succ*
    ['() '()]
    [(list _) succ*]
    [_ (define max-pr
         (for/fold ([best -inf.0])
                   ([succ (in-list succ*)])
           (match succ
             [(list name _cfg) (max best (step-priority name))]
             [_ best])))
       (for/first ([succ (in-list succ*)]
                   #:when (match succ
                            [(list name _cfg) (= (step-priority name) max-pr)]
                            [_ #f]))
         (list succ))]))

(define (step-once/by rel prog)
  (determinize-tagged-successors
   (dedupe-tagged-successors
    (apply-reduction-relation/tag-with-names rel (term ,prog)))))

(define (extend-with-dfs-rules base-rel)
  (extend-reduction-relation
   base-rel
   L3/K
   [--> (Γ (in-hole K ((delay s_1) <-+ s_2)))
        (Γ (in-hole K (delay (s_1 <-+ s_2))))
        "dfs/delay-through-left"]
   [--> (Γ (in-hole Kdelay (delay s_1)))
        (Γ (in-hole Kdelay s_1))
        (side-condition (not (redex-match? L3/K (proceed pr) (term s_1))))
        "dfs/invoke-delay"]))

(define Rl3-dfs-eager
  (extend-with-dfs-rules Rl3-pre-eager))

(define Rl3-dfs-lazy
  (extend-with-dfs-rules Rl3-pre-lazy))

(provide
 ;; Canonical exports
 Rl1-call-eager
 Rl1-call-lazy
 Rl2-disj-left
 Rl3-pre-eager
 Rl3-pre-lazy
 Rl3-dfs-eager
 Rl3-dfs-lazy
 Rl3-flip-eager
 Rl3-flip-lazy
 Rl4-rail-eager
 Rl4-rail-lazy
 ;; Legacy exports
 Rcall-eager
 Rcall-lazy
 Rdisj-left
 Rdfs-nodelay
 Rbase-e
 Rbase-l
 Rbase-l4
 Rflip-e
 Rflip-l
 Rrail-e
 Rrail-l
 ;; Canonical step wrappers
 step-once/Rl1-call-eager
 step-once/Rl1-call-lazy
 step-once/Rl2-disj-left
 step-once/Rl3-pre-eager
 step-once/Rl3-pre-lazy
 step-once/Rl3-dfs-eager
 step-once/Rl3-dfs-lazy
 step-once/Rl3-flip-eager
 step-once/Rl3-flip-lazy
 step-once/Rl4-rail-eager
 step-once/Rl4-rail-lazy
 ;; Legacy step wrappers
 step-once/Rcall-eager
 step-once/Rcall-lazy
 step-once/Rdisj-left
 step-once/Rdfs-nodelay
 step-once/Rbase-e
 step-once/Rbase-l
 step-once/Rbase-l4
 step-once/Rflip-e
 step-once/Rflip-l
 step-once/Rrail-e
 step-once/Rrail-l)

;; Canonical step wrappers.
(define (step-once/Rl1-call-eager prog)
  (step-once/by Rl1-call-eager prog))

(define (step-once/Rl1-call-lazy prog)
  (step-once/by Rl1-call-lazy prog))

(define (step-once/Rl2-disj-left prog)
  (step-once/by Rl2-disj-left prog))

(define (step-once/Rl3-pre-eager prog)
  (step-once/by Rl3-pre-eager prog))

(define (step-once/Rl3-pre-lazy prog)
  (step-once/by Rl3-pre-lazy prog))

(define (step-once/Rl3-dfs-eager prog)
  (step-once/by Rl3-dfs-eager prog))

(define (step-once/Rl3-dfs-lazy prog)
  (step-once/by Rl3-dfs-lazy prog))

(define (step-once/Rl3-flip-eager prog)
  (step-once/by Rl3-flip-eager prog))

(define (step-once/Rl3-flip-lazy prog)
  (step-once/by Rl3-flip-lazy prog))

(define (step-once/Rl4-rail-eager prog)
  (step-once/by Rl4-rail-eager prog))

(define (step-once/Rl4-rail-lazy prog)
  (step-once/by Rl4-rail-lazy prog))

;; Legacy wrappers.
(define step-once/Rcall-eager step-once/Rl1-call-eager)
(define step-once/Rcall-lazy  step-once/Rl1-call-lazy)
(define step-once/Rdisj-left  step-once/Rl2-disj-left)
(define step-once/Rdfs-nodelay
  (lambda (prog)
    (step-once/by Rdfs-nodelay prog)))
(define step-once/Rbase-e step-once/Rl3-pre-eager)
(define step-once/Rbase-l step-once/Rl3-pre-lazy)
(define (step-once/Rbase-l4 prog)
  (step-once/by Rbase-l4 prog))
(define step-once/Rflip-e step-once/Rl3-flip-eager)
(define step-once/Rflip-l step-once/Rl3-flip-lazy)
(define step-once/Rrail-e step-once/Rl4-rail-eager)
(define step-once/Rrail-l step-once/Rl4-rail-lazy)
