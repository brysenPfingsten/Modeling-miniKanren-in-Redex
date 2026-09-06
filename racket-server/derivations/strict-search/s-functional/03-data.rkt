#lang racket
(require "../shared/kernel-equations.rkt" (only-in "../shared/kernel.rkt" owners-append))
(provide (all-defined-out))

(struct KDone () #:transparent) ; C0
(struct KConj (right owners inherited k) #:transparent) ; C1
(struct KDisjLeft (right state owners inherited k) #:transparent) ; C2
(struct KDisjRight (left owners inherited k) #:transparent) ; C3
(struct KMergeYield (owners answer k) #:transparent) ; C4, active eager tail
(struct KBindHead (rest continue common inherited k) #:transparent) ; C5
(struct KBindTail (head common inherited k) #:transparent) ; C6
(struct KMergeForced (right here k) #:transparent) ; C7
(struct KBindForced (continue here k) #:transparent) ; C8
(struct KPrefix (owners k) #:transparent) ; C9
(struct KCommit (k) #:transparent) ; P0, Search -> Frontier boundary
(struct KCommitEmit (owners answer k) #:transparent) ; P1, settled tail
(struct KAdvanceEmit (owners answer k) #:transparent) ; A0
(struct KAdvanceHistory (owners k) #:transparent) ; A1
(struct KAdvanceForced (owners k) #:transparent) ; A2, receives committed F
(struct KCollectEmit (owners answer k) #:transparent) ; L0
(struct KCollectHistory (owners k) #:transparent) ; L1
(struct KCollectResume (owners k) #:transparent) ; L2, receives committed F
(struct KCollectForced (owners k) #:transparent) ; L3
(struct GRight (goal) #:transparent) ; G0
(struct REval (goal state here) #:transparent) ; R0
(struct RMerge (right left here) #:transparent) ; R1
(struct RBind (resume continue here) #:transparent) ; R2
(struct FEmpty (owners k) #:transparent) ; F0, active failure
(struct SOne (owners k) #:transparent) ; S0, active success

;; Both native producers and all consumers change at this pass.
(struct Failure () #:transparent)
(struct Success (state) #:transparent)
(define-kernel atomic/data Failure Success)

(define (prefix owners search)
  (match search
    [`(Empty ,local) `(Empty ,(owners-append owners local))]
    [`(One ,local ,state) `(One ,(owners-append owners local) ,state)]
    [`(Yield ,local ,answer ,rest)
     `(Yield ,(owners-append owners local) ,answer ,rest)]
    [`(Delay ,local ,resume) `(Delay ,(owners-append owners local) ,resume)]))
