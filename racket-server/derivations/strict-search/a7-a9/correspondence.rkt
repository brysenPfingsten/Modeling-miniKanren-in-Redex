#lang racket

(require (prefix-in d: "../../functional-search/direct-interpreter.rkt")
         (prefix-in old: "../functional-machine.rkt")
         (prefix-in source-map: "../correspondence.rkt")
         (prefix-in m: "04-machine.rkt")
         "03-data.rkt")
(provide decode-search decode-resume decode-k decode-machine decode-source extra-admin?)

;; Structural maps only. No evaluator, stepper, forcing, or normalization.
(define (decode-search search)
  (match search
    [(d:Empty next) (old:Empty next)]
    [(d:One state) (old:One state)]
    [(d:Yield state rest) (old:Yield state (decode-search rest))]
    [(d:Delay rest) (old:Delay (decode-resume rest))]))

(define (decode-continue continue)
  (match continue [(GRight goal) (old:Continue goal)]))

(define (decode-resume resume)
  (match resume
    [(REval goal state) (old:ResumeEval goal state)]
    [(RMerge right rest) (old:ResumeMerge (decode-search right) (decode-resume rest))]
    [(RBind rest continue) (old:ResumeBind (decode-resume rest) (decode-continue continue))]))

(define (decode-value value)
  (match value
    [(or (d:Empty _) (d:One _) (d:Yield _ _) (d:Delay _)) (decode-search value)]
    [_ value]))

(define (decode-k k)
  (match k
    [(KDone) (old:Halt)]
    [(KConj goal next) (old:AfterConjLeft goal (decode-k next))]
    [(KDisjLeft goal state next) (old:AfterDisjLeft goal state (decode-k next))]
    [(KDisjRight left next) (old:AfterDisjRight (decode-search left) (decode-k next))]
    [(KYield state next) (old:RebuildYield state (decode-k next))]
    [(KBindHead rest continue next)
     (old:AfterBindHead (decode-search rest) (decode-continue continue) (decode-k next))]
    [(KBindTail head next) (old:AfterBindTail (decode-search head) (decode-k next))]
    [(KMergeForced right next) (old:AfterForceMerge (decode-search right) (decode-k next))]
    [(KBindForced continue next) (old:AfterForceBind (decode-continue continue) (decode-k next))]
    [(KRun next) (old:AfterEvalRender (decode-k next))]
    [(KEmit state next) (old:AfterEmit state (decode-k next))]
    [(KRenderForced next) (old:AfterRenderForce (decode-k next))]
    [(KForced next) (old:AfterForced (decode-k next))]))

(define (decode-machine configuration)
  (match configuration
    [(m:Call 'eval/d (list goal state _ k)) (old:Eval goal state (decode-k k))]
    [(m:Call 'merge/d (list left right _ k))
     (old:Mplus (decode-search left) (decode-search right) (decode-k k))]
    [(m:Call 'bind/d (list search continue _ k))
     (old:Bind (decode-search search) (decode-continue continue) (decode-k k))]
    [(m:Call 'continue/d (list (GRight goal) state _ k))
     (old:Eval goal state (decode-k k))]
    [(m:Call 'force/d (list resume _ k)) (old:Force (decode-resume resume) (decode-k k))]
    [(m:Call 'render/d (list search _ k)) (old:Render (decode-search search) (decode-k k))]
    [(m:Call 'return/d (list value _ k)) (old:Return (decode-value value) (decode-k k))]
    [(m:Halted value) (old:Return (decode-value value) (old:Halt))]))

(define (decode-source configuration)
  (source-map:decode-configuration (decode-machine configuration)))

;; These two concrete control cases are additional administration relative to
;; the older functional machine. Equality of decoded terms is not a classifier:
;; a Fresh self-loop is a genuine transition with an unchanged decoded term.
(define (extra-admin? configuration)
  (match configuration
    [(m:Call 'continue/d _) #t]
    [(m:Call 'return/d (list _ _ (KDone))) #t]
    [_ #f]))
