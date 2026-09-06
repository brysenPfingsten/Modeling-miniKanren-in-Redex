#lang racket

(require racket/match)

(provide (all-defined-out))

#|
Scott-encoded Search, retained only as a representation comparison.

This is not the direct source interpreter for the A7--A9/ParentheC
derivation: representing the Search sum by its eliminator has already chosen a
Scott encoding.  See direct-interpreter.rkt for the ordinary algebraic lazy
Search datatype with higher-order control.

Only object-program syntax and domain values are represented as data.  Search
computations, suspended branches, conjunction continuations, and the recursive
control of the rail are Racket procedures.  Lambda lifting and
defunctionalization expose the first-order records and apply dispatchers from
which a ParentheC-style machine can be registerized and trampolined.

A Search is Scott encoded as a procedure accepting four handlers:

  on-empty : Nat -> Result
  on-one   : State -> Result
  on-more  : State x Thunk<Search> -> Result
  on-delay : Thunk<Search> -> Result

The four closure constructors below are the higher-order representations that
defunctionalize to Empty, One, More, and Delay.
|#

;; ---------------------------------------------------------------------------
;; State and object-program syntax

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
    [(Succeed _) state]
    [(FailGoal _) #f]
    [(Atom procedure _) (procedure state)]
    [_ (error 'basic-kernel "not an atomic goal: ~e" goal)]))

(define (put value [tag 'put])
  (Atom
   (lambda (state)
     (struct-copy State state [tag value]))
   tag))

;; ---------------------------------------------------------------------------
;; Functional representation of Search

(define (empty-search next)
  (lambda (on-empty _on-one _on-more _on-delay)
    (on-empty next)))

(define (one-search state)
  (lambda (_on-empty on-one _on-more _on-delay)
    (on-one state)))

(define (more-search state rest)
  (lambda (_on-empty _on-one on-more _on-delay)
    (on-more state rest)))

(define (delay-search rest)
  (lambda (_on-empty _on-one _on-more on-delay)
    (on-delay rest)))

(define (apply-search search on-empty on-one on-more on-delay)
  (search on-empty on-one on-more on-delay))

;; ---------------------------------------------------------------------------
;; Functional oriented rail
;;
;; right is a dormant Thunk<Search> in mplus-left; left is dormant in
;; mplus-right.  No scheduler tree or zipper exists at this level.

(define (mplus-left left right)
  (apply-search
   left
   (lambda (_next)
     (right))
   (lambda (state)
     (more-search state right))
   (lambda (state left-rest)
     (more-search
      state
      (lambda ()
        (mplus-left (left-rest) right))))
   (lambda (left-rest)
     (delay-search
      (lambda ()
        (mplus-right left-rest (right)))))))

(define (mplus-right left right)
  (apply-search
   right
   (lambda (_next)
     (left))
   (lambda (state)
     (more-search state left))
   (lambda (state right-rest)
     (more-search
      state
      (lambda ()
        (mplus-right left (right-rest)))))
   (lambda (right-rest)
     (delay-search
      (lambda ()
        (mplus-left (left) right-rest))))))

;; ---------------------------------------------------------------------------
;; Functional late/shared conjunction
;;
;; continue is a State -> Search procedure.  Every residual computation closes
;; over the same procedure object.

(define (bind search continue)
  (apply-search
   search
   (lambda (next)
     (empty-search next))
   (lambda (state)
     (continue state))
   (lambda (state rest)
     (mplus-left
      (continue state)
      (lambda ()
        (bind (rest) continue))))
   (lambda (rest)
     (delay-search
      (lambda ()
        (bind (rest) continue))))))

;; ---------------------------------------------------------------------------
;; Direct interpretation of goal syntax

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
     (mplus-left
      (value-of left state K relations)
      (lambda ()
        (value-of right state K relations)))]

    [(Suspend delayed-goal _)
     (delay-search
      (lambda ()
        (value-of delayed-goal state K relations)))]

    [(Call name arguments _)
     (define relation
       (hash-ref
        relations name
        (lambda ()
          (error 'value-of "unknown relation ~e" name))))
     ;; Relation expansion does not itself introduce a scheduling delay.
     (value-of (apply relation arguments) state K relations)]

    [atomic
     (match (K atomic state)
       [#f
        (empty-search (State-next state))]
       [(? State? state*)
        (one-search state*)]
       [result
        (error 'value-of
               "kernel returned neither a State nor #f: ~e"
               result)])]))

;; ---------------------------------------------------------------------------
;; Observable finite frontier

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
  (apply-search
   search
   (lambda (next)
     (Done next))
   (lambda (state)
     (Last (Answer state)))
   (lambda (state rest)
     (Emit (Answer state)
           (render (rest))))
   (lambda (rest)
     (Forced
      (render (rest))))))

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
       (struct-copy State state
                    [tag (list (State-tag state) 'then)]))
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
