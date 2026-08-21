#lang racket

(require redex/reduction-semantics
         "./machine.rkt"
         "./compressed.rkt")

(provide MB-corresponds/s
         replay-transition-span/M/s
         compressed-step/spec/s
         MB-step-square/s)

(check-redundancy #t)

(define-judgment-form
  core-s-compressed-lang
  #:contract (MB-corresponds/s M B)
  #:mode (MB-corresponds/s I O)

  [(where B (encode-MB/s M))
   ---------------------------------------------------- "structural M/B correspondence/S"
   (MB-corresponds/s M B)])

;; A singleton compressed edge replays one exact M edge.  Each two-label edge
;; replays one of the seven result producers followed by exactly one
;; conjunction/finish edge.  There is deliberately no three-or-more case.
(define-judgment-form
  core-s-compressed-lang
  #:contract (replay-transition-span/M/s M TransitionSpan M)
  #:mode (replay-transition-span/M/s I O O)

  [(machine-step/direct/s
    M_0
    SingletonRuleName
    M_1)
   ---------------------------------------------------- "replay singleton compressed span/S"
   (replay-transition-span/M/s
    M_0
    (transition-span SingletonRuleName)
    M_1)]

  [(machine-step/direct/s
    M_0
    ProducerRuleName
    M_1)
   (machine-step/direct/s
    M_1
    FollowRuleName
    M_2)
   ---------------------------------------------------- "replay fused result span/S"
   (replay-transition-span/M/s
    M_0
    (transition-span ProducerRuleName FollowRuleName)
    M_2)])

(define-judgment-form
  core-s-compressed-lang
  #:contract (compressed-step/spec/s B TransitionSpan B)
  #:mode (compressed-step/spec/s I O O)

  [(where M_0 (decode-BM/s B_0))
   (replay-transition-span/M/s M_0 TransitionSpan M_1)
   (where B_1 (encode-MB/s M_1))
   ---------------------------------------------------- "exact M replay specification/S"
   (compressed-step/spec/s B_0 TransitionSpan B_1)])

(define-judgment-form
  core-s-compressed-lang
  #:contract (MB-step-square/s B TransitionSpan B M M)
  #:mode (MB-step-square/s I O O O O)

  [(where M_0 (decode-BM/s B_0))
   (replay-transition-span/M/s M_0 TransitionSpan M_1)
   (where B_1 (encode-MB/s M_1))
   (compressed-step/direct/s B_0 TransitionSpan B_1)
   ---------------------------------------------------- "exact labeled M/B compression square/S"
   (MB-step-square/s B_0 TransitionSpan B_1 M_0 M_1)])
