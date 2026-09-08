#lang racket

(require "../strict-search/shared/kernel-equations.rkt")
(provide (all-defined-out))

;; Literal closure families of the demand interpreter and its CPS transform.
;; These records represent computations even when carried by a Yield tail;
;; constructing one does not introduce an object-language Delay.
(struct REval (policy goal state) #:transparent)
(struct RScope (local resume) #:transparent)
(struct RMerge (policy side left right) #:transparent)
(struct RBind (policy resume continue) #:transparent)
(struct RContinue (continue state local) #:transparent)
(struct GRight (policy goal) #:transparent)

(struct KDone () #:transparent)
(struct KProgram (relations k) #:transparent)
(struct KConj (policy right owners inherited k) #:transparent)
(struct KMerge (policy side passive owners inherited k) #:transparent)
(struct KBind (policy continue owners inherited k) #:transparent)
(struct KCommit (inherited k) #:transparent)
(struct KEmit (owners answer k) #:transparent)
(struct KAdvanceEmit (owners answer k) #:transparent)
(struct KAdvanceHistory (owners k) #:transparent)
(struct KAdvanceForced (owners k) #:transparent)
(struct KCollect (k) #:transparent)
(struct FEmpty (owners k) #:transparent)
(struct SOne (owners k) #:transparent)

;; The producer changes with its consumers at defunctionalization. There is
;; no functional outcome adapter and no closure table in the data machine.
(struct Failure () #:transparent)
(struct Success (state) #:transparent)
(define-kernel atomic/data Failure Success)

(define (check-policy policy)
  (unless (member policy '(dfs flip rail))
    (raise-argument-error 'policy "dfs, flip, or rail" policy)))
(define (complete? frontier)
  (match frontier
    [(or `(Done ,_) `(Last ,_ ,_)) #t]
    [(or `(Emit ,_ ,_ ,rest) `(Forced ,_ ,rest)) (complete? rest)]
    [`(More ,_) #f]))
