#lang racket

(require "data.rkt"
         (prefix-in f: "machine.rkt")
         (only-in "machine-correspondence.rkt" functional-step-label))
(provide functional-admin-rank)

;; A structural bound on consecutive functional administrative transitions.
;; These are precisely the return clauses that rebuild a value and return
;; again. Every other continuation enters a named semantic operation or halts.
(define (return-rank k)
  (match k
    [(or (KMergeYield _ _ rest) (KCommitEmit _ _ rest)
         (KAdvanceEmit _ _ rest) (KAdvanceHistory _ rest)
         (KAdvanceForced _ rest) (KCollectEmit _ _ rest)
         (KCollectHistory _ rest) (KCollectForced _ rest))
     (add1 (return-rank rest))]
    [_ 1]))

;; RBind can enter another RBind, adding a pending bind frame each time. Its
;; saved resumption is a strict subterm. REval and RMerge enter a semantic
;; eval/force control immediately, so the growing continuation is irrelevant
;; to termination of this particular administrative span.
(define (resumption-rank resume)
  (match resume
    [(RBind inner _) (add1 (resumption-rank inner))]
    [(or (REval _ _) (RMerge _ _)) 1]))

(define (functional-admin-rank configuration)
  (match configuration
    [(f:Halted _) 0]
    [(? (lambda (current) (functional-step-label current))) 0]
    [(f:Call 'return/d (list _ k)) (return-rank k)]
    [(f:Call 'continue/d _) 1]
    [(f:Call 'resume/d (list resume _ _ _)) (resumption-rank resume)]
    [(f:Call 'failure/d (list (FEmpty _ k))) (add1 (return-rank k))]
    [(f:Call 'success/d (list (SOne _ k) _)) (add1 (return-rank k))]
    [(f:Call 'outcome/d (list outcome failure success))
     (+ 2 (match* (outcome failure success)
            [((Failure) (FEmpty _ k) _) (return-rank k)]
            [((Success _) _ (SOne _ k)) (return-rank k)]))]
    [_ (raise-argument-error 'functional-admin-rank "retained functional configuration" configuration)]))
