#lang racket

(require (prefix-in direct: "../../functional-search/direct-interpreter.rkt")
         (prefix-in n: "../shared/core/n/language.rkt")
         "../shared/kernel.rkt")

(provide goal->direct state->direct observation->direct direct-observation)

;; This module is an independent test boundary, never an implementation route
;; for a matrix coordinate. It interprets the old first-order numeric kernel
;; under the authoritative direct interpreter's strict control equations.
(define (state->direct state)
  (match state
    [`(state ,next ,sub ,dis ,trail ,tag) (direct:State next sub dis trail tag)]))

;; This static instance uses the independent functional interpreter's State
;; and functional producers. The matrix instances use Failure/Success data.
;; No matrix result is evaluated or converted by this native functional kernel.
(define-atomic atomic/direct direct:failure-outcome direct:success-outcome
  n:walk/n n:unify/n n:invalid?/n
  (sub dis trail tag)
  (direct:State next sub dis trail tag)
  (direct:State next sub dis trail tag))

(define (goal->direct goal)
  (match goal
    [`(succeed ,tag) (direct:Succeed tag)]
    [`(fail ,tag) (direct:FailGoal tag)]
    [`(,left ∧ ,right ,tag)
     (direct:Conj (goal->direct left) (goal->direct right) tag)]
    [`(,left ∨ ,right ,tag)
     (direct:Disj (goal->direct left) (goal->direct right) tag)]
    [`(suspend ,body ,tag) (direct:Suspend (goal->direct body) tag)]
    [`(∃ ,binders ,body ,tag)
     (direct:Fresh
      (length binders)
      (lambda variables
        (goal->direct
         (substitute-goal body (map list binders (map direct:LVar-level variables)))))
      tag)]
    [`(,_ ,(or '=? '!=) ,_ ,tag)
     (direct:Atom
      (lambda (state) (atomic/direct goal state))
      tag)]
    [_ (raise-argument-error 'goal->direct "first-order numeric goal" goal)]))

(define (observation->direct observation)
  (match observation
    [`(Done ,next) (direct:Done next)]
    [`(Last ,state) (direct:Last (direct:Answer (state->direct state)))]
    [`(Emit ,state ,tail)
     (direct:Emit (direct:Answer (state->direct state)) (observation->direct tail))]
    [`(Forced ,tail) (direct:Forced (observation->direct tail))]
    [_ (raise-argument-error 'observation->direct "numeric strict observation" observation)]))

(define (direct-observation goal
                            #:state [state '(state 0 () () () (label "initial"))])
  (direct:run (goal->direct goal) #:state (state->direct state)))
