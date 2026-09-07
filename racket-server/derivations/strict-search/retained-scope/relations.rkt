#lang racket

(require (only-in "../shared/kernel.rkt" instantiate-relation relation-name?))
(provide (struct-out ProgramGoal) goal-body goal-relations retain-goal
         relation-call? expand-call)

;; The environment is ordinary immutable data at every pending goal site.
;; Functional closures capture this pair; defunctionalized GRight/REval and
;; generated control operands contain it directly. KProgram retains the same
;; environment when no pending goal remains, including at a paused Frontier.
(struct ProgramGoal (relations goal) #:transparent)

(define (goal-body goal)
  (match goal [(ProgramGoal _ body) body] [_ goal]))

(define (goal-relations goal)
  (match goal [(ProgramGoal relations _) relations] [_ #f]))

(define (retain-goal relations goal)
  (if relations (ProgramGoal relations goal) goal))

(define (relation-call? goal)
  (match goal
    [(list (? relation-name?) _ ...) #t]
    [_ #f]))

(define (expand-call relations call)
  (unless relations
    (error 'expand-call "relation call requires an explicit program environment: ~e" call))
  (or (instantiate-relation relations call)
      (error 'expand-call "undefined relation or arity mismatch: ~e" call)))
