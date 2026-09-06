#lang racket

(require racket/match "outcomes.rkt")

(provide (all-defined-out) (all-from-out "outcomes.rkt"))

#|
The ordinary direct-style interpreter at the left edge of the A7--A9
transformation sequence.

Unlike natural-interpreter.rkt in this directory, this file does not take the
extra "what does valof defunctionalize?" step of representing goal syntax by
procedures.  Goals are ordinary syntax structures and value-of dispatches on
them.  What has been refunctionalized is control:

  * conjunction passes an actual State -> Search procedure to bind;
  * rail scheduling is ordinary recursion in mplus;
  * only an explicit Delay contains a nullary Racket procedure;
  * output construction is ordinary recursion in render.

The kernel and Atom callbacks return native functional outcomes. Kernel work
is eager; selecting the completed outcome does not rerun it or create Delay.

There are no machine continuations, scheduler trees or paths, output
continuations, configurations, registers, program counters, or trampoline.
|#

;; ---------------------------------------------------------------------------
;; State and goal syntax

(struct State (next substitution disequalities trail tag)
  #:transparent)

(struct LVar (level)
  #:transparent)

(struct Succeed (tag)
  #:transparent)

(struct FailGoal (tag)
  #:transparent)

(struct Atom (procedure tag)
  #:transparent)

(struct Fresh (arity body tag)
  #:transparent)

(struct Conj (left right tag)
  #:transparent)

(struct Disj (left right tag)
  #:transparent)

(struct Suspend (goal tag)
  #:transparent)

(struct Call (name arguments tag)
  #:transparent)

(define (empty-state [tag 'initial])
  (State 0 '() '() '() tag))

(define (basic-kernel goal state)
  (match goal
    [(Succeed _) (success-outcome state)]
    [(FailGoal _) (failure-outcome)]
    [(Atom procedure _) (procedure state)]
    [_ (error 'basic-kernel "not an atomic goal: ~e" goal)]))

(define (put value [tag 'put])
  (Atom
   (lambda (state)
     (success-outcome (struct-copy State state [tag value])))
   tag))

;; ---------------------------------------------------------------------------
;; Lazy search results

;; Yield is a mature cell: rest is an already-produced Search, not a thunk.
;; Delay is the only Search constructor whose payload is a suspended
;; computation.

(struct Empty (next)
  #:transparent)

(struct One (state)
  #:transparent)

(struct Yield (state rest)
  #:transparent)

(struct Delay (rest)
  #:transparent)

;; ---------------------------------------------------------------------------
;; Rail merge
;;
;; Both operands are already-produced Search values.  Delay changes the active
;; side by swapping the operands.  Nested calls retain the source grouping of
;; choices; this is not a flattened queue.

(define (mplus left right)
  (match left
    [(Empty _)
     right]
    [(One state)
     (Yield state right)]
    [(Yield state left-rest)
     (Yield state
           (mplus left-rest right))]
    [(Delay left-rest)
     (Delay
      (lambda ()
        (mplus right (left-rest))))]))

;; ---------------------------------------------------------------------------
;; Late/shared conjunction
;;
;; continue is the ordinary higher-order object that eventually becomes the
;; machine's persistent Then suffix.  Every residual recursive call shares the
;; same Racket procedure.

(define (bind search continue)
  (match search
    [(Empty next)
     (Empty next)]
    [(One state)
     (continue state)]
    [(Yield state rest)
     (mplus
      (continue state)
      (bind rest continue))]
    [(Delay rest)
     (Delay
      (lambda ()
        (bind (rest) continue)))]))

;; ---------------------------------------------------------------------------
;; The direct interpreter

(define (value-of goal state K relations)
  (match goal
    [(Fresh arity body _)
     (unless (exact-nonnegative-integer? arity)
       (raise-argument-error 'value-of
                             "exact-nonnegative-integer?"
                             arity))
     (define next (State-next state))
     (define variables
       (for/list ([offset (in-range arity)])
         (LVar (+ next offset))))
     (define state*
       (struct-copy State state [next (+ next arity)]))
     (value-of (apply body variables) state* K relations)]

    [(Conj left right _)
     (bind
      (value-of left state K relations)
      (lambda (state*)
        (value-of right state* K relations)))]

    [(Disj left right _)
     (mplus
      (value-of left state K relations)
      (value-of right state K relations))]

    [(Suspend delayed-goal _)
     (Delay
      (lambda ()
        (value-of delayed-goal state K relations)))]

    [(Call name arguments _)
     (define relation
       (hash-ref
        relations name
        (lambda ()
          (error 'value-of "unknown relation ~e" name))))
     ;; Expansion itself is not a Delay.  A fair relation-entry policy remains
     ;; explicit in the source as Suspend around Call.
     (value-of (apply relation arguments) state K relations)]

    [atomic
     ((K atomic state)
      (lambda () (Empty (State-next state)))
      One)]))

;; ---------------------------------------------------------------------------
;; Exact finite readback

(struct Answer (state)
  #:transparent)

(struct Done (next)
  #:transparent)

(struct Last (answer)
  #:transparent)

(struct Emit (answer tail)
  #:transparent)

(struct Forced (tail)
  #:transparent)

(define (render search)
  (match search
    [(Empty next)
     (Done next)]
    [(One state)
     (Last (Answer state))]
    [(Yield state rest)
     (Emit (Answer state)
           (render rest))]
    [(Delay rest)
     (Forced
      (render (rest)))]))

(define (run-search goal
                    #:kernel [K basic-kernel]
                    #:relations [relations (hash)]
                    #:state [state (empty-state)])
  (value-of goal state K relations))

(define (run goal
             #:kernel [K basic-kernel]
             #:relations [relations (hash)]
             #:state [state (empty-state)])
  (render
   (run-search goal
               #:kernel K
               #:relations relations
               #:state state)))

(define (frontier-shape frontier)
  (match frontier
    [(Done next)
     `(Done ,next)]
    [(Last (Answer state))
     `(Last ,(State-tag state))]
    [(Emit (Answer state) tail)
     `(Emit ,(State-tag state) ,(frontier-shape tail))]
    [(Forced tail)
     `(Forced ,(frontier-shape tail))]))

;; ---------------------------------------------------------------------------
;; Characteristic nested rail witness

(define nested-rail-witness
  (Disj
   (Suspend
    (Suspend (put 'A) 'A-second-delay)
    'A-first-delay)
   (Disj
    (Suspend (put 'B) 'B-delay)
    (Suspend (put 'C) 'C-delay)
    'inner-choice)
   'outer-choice))

(module+ test
  (require rackunit)

  (match (run-search (Disj (put 'A) (put 'B) 'choice))
    [(Yield _ rest)
     (check-true (One? rest))
     (check-false (procedure? rest))])

  (match (run-search
          (Disj (put 'A)
                (Suspend (put 'B) 'delay)
                'choice))
    [(Yield _ rest)
     (check-true (Delay? rest))
     (check-true (procedure? (Delay-rest rest)))])

  (define right-ran? #f)
  (define eager-right
    (Atom
     (lambda (state)
       (set! right-ran? #t)
       (success-outcome state))
     'eager-right))
  (void (run-search (Disj (put 'A) eager-right 'choice)))
  (check-true right-ran?)

  (check-equal?
   (frontier-shape (run (put 'A)))
   '(Last A))

  (check-equal?
   (frontier-shape
    (run (Disj (put 'A) (put 'B) 'choice)))
   '(Emit A (Last B)))

  (check-equal?
   (frontier-shape
    (run (Disj (put 'A) (FailGoal 'failure) 'choice)))
   '(Emit A (Done 0)))

  (check-equal?
   (frontier-shape
    (run (Disj (FailGoal 'failure) (put 'B) 'choice)))
   '(Last B))

  (check-equal?
   (frontier-shape
    (run (Disj
          (put 'A)
          (Suspend (put 'B) 'delay)
          'choice)))
   '(Emit A (Forced (Last B))))

  (check-equal?
   (frontier-shape
    (run (Disj
          (Suspend (put 'A) 'delay)
          (put 'B)
          'choice)))
   '(Forced (Emit B (Last A))))

  (check-equal?
   (frontier-shape (run nested-rail-witness))
   '(Forced
     (Forced
      (Forced
       (Forced
        (Emit A (Emit B (Last C))))))))

  (define append-then
    (Atom
     (lambda (state)
       (success-outcome
        (struct-copy State state
                     [tag (list (State-tag state) 'then)])))
     'append-then))

  (check-equal?
   (frontier-shape
    (run (Conj
          (Disj (put 'A) (put 'B) 'choice)
          append-then
          'conjunction)))
   '(Emit (A then) (Last (B then))))

  (check-equal?
   (frontier-shape
    (run (Conj
          (Disj (put 'A) (put 'B) 'choice)
          (Suspend append-then 'delay)
          'conjunction)))
   '(Forced
     (Forced
      (Emit (A then) (Last (B then))))))

  (define relations
    (hash
     'put
     (lambda (value)
       (put value))
     'countdown
     (lambda (n)
       (if (zero? n)
           (put 'countdown-done)
           (Suspend
            (Call 'countdown (list (sub1 n)) 'recursive-call)
            'relation-entry-delay)))))

  (check-equal?
   (frontier-shape
    (run (Call 'put (list 'relation-answer) 'call)
         #:relations relations))
   '(Last relation-answer))

  (check-equal?
   (frontier-shape
    (run (Suspend
          (Call 'put (list 'delayed-relation-answer) 'call)
          'delay)
         #:relations relations))
   '(Forced (Last delayed-relation-answer)))

  (check-equal?
   (frontier-shape
    (run (Call 'countdown (list 2) 'call)
         #:relations relations))
   '(Forced (Forced (Last countdown-done))))

  (match (run (Fresh 2
                     (lambda (_x _y)
                       (Succeed 'success))
                     'fresh))
    [(Last (Answer (State next _ _ _ _)))
     (check-equal? next 2)]))
