#lang racket

(require (prefix-in d: "../../functional-search/direct-interpreter.rkt")
         (prefix-in s: "semantics.rkt"))
(provide denote reify-search reflect-search reify-frontier run run-search)

;; Compositional syntax-to-meaning map. In particular a Fresh body is translated
;; only when called with its allocated variables, never at translation time.
;; This module contains no call to the direct interpreter's evaluator.
(define (denote goal)
  (match goal
    [(or (d:Succeed _) (d:FailGoal _) (d:Atom _ _)) (s:atomic goal)]
    [(d:Fresh arity body _)
     (s:fresh arity (lambda variables (denote (apply body variables))))]
    [(d:Conj left right _) (s:conj (denote left) (denote right))]
    [(d:Disj left right _) (s:disj (denote left) (denote right))]
    [(d:Suspend body _) (s:suspend (denote body))]
    [(d:Call _ _ _)
     (error 'denote "relation-call syntax is outside this derivation")]
    [_ (raise-argument-error 'denote "strict goal syntax" goal)]))

;; Reification selects the constructor lambda and rebuilds its captured data.
;; Only the Delay case places recursive reification beneath a new lambda.
;; Neither direction forces a suspended computation during translation.
(define (reify-search search)
  (s:case-search
   search d:Empty d:One
   (lambda (state rest) (d:Yield state (reify-search rest)))
   (lambda (resume) (d:Delay (lambda () (reify-search (resume)))))))

(define (reflect-search search)
  (match search
    [(d:Empty next) (s:empty-search next)]
    [(d:One state) (s:one-search state)]
    [(d:Yield state rest) (s:yield-search state (reflect-search rest))]
    [(d:Delay resume) (s:delay-search (lambda () (reflect-search (resume))))]))

(define (reify-frontier frontier)
  (s:case-frontier
   frontier d:Done
   (lambda (state) (d:Last (d:Answer state)))
   (lambda (state rest) (d:Emit (d:Answer state) (reify-frontier rest)))
   (lambda (rest) (d:Forced (reify-frontier rest)))))

;; Both presentations use the same native functional kernel outcomes.
(define (run-search goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)])
  (reify-search (s:run-search (denote goal) #:kernel K #:state state)))
(define (run goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)])
  (reify-frontier (s:run (denote goal) #:kernel K #:state state)))
