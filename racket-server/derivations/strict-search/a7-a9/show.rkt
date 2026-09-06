#lang racket

(require (prefix-in d: "../../functional-search/direct-interpreter.rkt")
         (prefix-in m: "04-machine.rkt") "03-data.rkt")
(provide witness trace-rows)

(define witness
  (d:Disj (d:Disj (d:put 'A 'A) (d:put 'B 'B) 'left-chunk)
          (d:Conj (d:put 'p 'p) (d:put 'q 'q) 'right-work)
          'outer-choice))

(define (chunk search)
  (match search
    [(d:Empty next) `(Empty ,next)]
    [(d:One state) (list (d:State-tag state))]
    [(d:Yield state rest) (cons (d:State-tag state) (chunk rest))]
    [(d:Delay _) '(Delay)]))

(define (value-summary value)
  (match value
    [(or (d:Empty _) (d:One _) (d:Yield _ _) (d:Delay _)) (chunk value)]
    [_ (d:frontier-shape value)]))

(define (goal-tag goal)
  (match goal
    [(d:Atom _ tag) tag] [(d:Succeed tag) tag] [(d:FailGoal tag) tag]
    [(d:Fresh _ _ tag) tag] [(d:Conj _ _ tag) tag]
    [(d:Disj _ _ tag) tag] [(d:Suspend _ tag) tag]))

(define (parked k)
  (match k
    [(KDone) '()]
    [(KDisjRight left next) (cons `(left ,(chunk left)) (parked next))]
    [(KBindTail head next) (cons `(bind-head ,(chunk head)) (parked next))]
    [_
     ;; Each of the remaining known continuation records has next as its
     ;; final field. This display traversal never follows a Search/Delay.
     (define fields (struct->vector k))
     (parked (vector-ref fields (sub1 (vector-length fields))))]))

(define (summary current)
  (match current
    [(m:Halted value) (list 'halt (value-summary value) '())]
    [(m:Call pc operands)
     (define active
       (match current
         [(m:Call 'eval/d (list goal _ _ _)) (goal-tag goal)]
         [(m:Call 'continue/d (list (GRight goal) _ _ _)) `(apply ,(goal-tag goal))]
         [(m:Call 'merge/d (list left right _ _)) `(,(chunk left) + ,(chunk right))]
         [(m:Call 'bind/d (list search (GRight goal) _ _)) `(,(chunk search) then ,(goal-tag goal))]
         [(m:Call 'force/d (list resume _ _)) (object-name resume)]
         [(m:Call 'render/d (list search _ _)) (chunk search)]
         [(m:Call 'return/d (list value _ _)) (value-summary value)]))
     (list pc active (parked (last operands)))]))

(define (trace-rows current [step 0] [reversed '()])
  (define rows (cons (cons step (summary current)) reversed))
  (match current
    [(m:Halted _) (reverse rows)]
    [_ (trace-rows (m:step current) (add1 step) rows)]))

(module+ main
  (displayln "step | control point | active work/result | retained eager chunks")
  (for ([row (in-list (trace-rows (m:initial witness)))])
    (match-define (list step pc active saved) row)
    (printf "~a | ~a | ~s | ~s\n" step pc active saved))
  (printf "\nNested rail: ~s\n" (d:frontier-shape (m:run d:nested-rail-witness))))
