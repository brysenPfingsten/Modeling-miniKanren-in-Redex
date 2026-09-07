#lang racket

(require "../shared/kernel-equations.rkt"
         (only-in "../shared/kernel.rkt" owners-append))
(provide (all-defined-out))

;; Every semantic lambda family in cps.rkt has a data constructor. Scope is
;; supplied when a resumption is entered, never cached inside the resumption.
(struct KDone () #:transparent)
(struct KProgram (relations k) #:transparent)
(struct KConj (right owners inherited k) #:transparent)
(struct KDisjLeft (right state owners inherited k) #:transparent)
(struct KDisjRight (left owners inherited k) #:transparent)
(struct KMergeYield (owners answer k) #:transparent)
(struct KBindHead (rest continue common inherited k) #:transparent)
(struct KBindTail (head common inherited k) #:transparent)
(struct KMergeForced (right owners inherited k) #:transparent)
(struct KBindForced (continue owners inherited k) #:transparent)
(struct KCommit (k) #:transparent)
(struct KCommitEmit (owners answer k) #:transparent)
(struct KAdvanceEmit (owners answer k) #:transparent)
(struct KAdvanceHistory (owners k) #:transparent)
(struct KAdvanceForced (owners k) #:transparent)
(struct KCollectEmit (owners answer k) #:transparent)
(struct KCollectHistory (owners k) #:transparent)
(struct KCollectResume (owners here k) #:transparent)
(struct KCollectForced (owners k) #:transparent)
(struct GRight (goal) #:transparent)
(struct REval (goal state) #:transparent)
(struct RMerge (right left) #:transparent)
(struct RBind (resume continue) #:transparent)
(struct FEmpty (owners k) #:transparent)
(struct SOne (owners k) #:transparent)

;; Producer and consumer change together: the primitive kernel constructs
;; these outcomes directly, with no functional-result-to-data adapter.
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
