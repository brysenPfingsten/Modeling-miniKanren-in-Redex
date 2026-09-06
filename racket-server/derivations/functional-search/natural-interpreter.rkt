#lang racket

(require racket/match)

(provide (all-defined-out))

#|
The direct, functional source of the N/late/rail/relcall machine.

This is deliberately on the other side of the A7--A9 transformations:

  * a goal is a Racket procedure, not a goal-syntax structure;
  * conjunction's success continuation is a Racket procedure;
  * rail scheduling is the recursion of mplus-left/mplus-right;
  * output construction is the recursion of render;
  * there are no continuation, zipper, configuration, or program-counter
    structures.

All dormant search computations are promises.  That qualification is
essential in strict Racket: without it, disjunction and suspension would
evaluate work before the rail selects it.
|#

;; ---------------------------------------------------------------------------
;; Kernel state and atomic requests

(struct State (next substitution disequalities trail tag)
  #:transparent)

(struct LVar (level)
  #:transparent)

;; These are requests understood by K, not compound goal syntax.
(struct Succeed (tag)
  #:transparent)

(struct FailGoal (tag)
  #:transparent)

(struct Atom (procedure tag)
  #:transparent)

(define (empty-state [tag 'initial])
  (State 0 '() '() '() tag))

(define (basic-kernel request state)
  (match request
    [(Succeed _) state]
    [(FailGoal _) #f]
    [(Atom procedure _) (procedure state)]
    [_ (error 'basic-kernel "not an atomic request: ~e" request)]))

;; ---------------------------------------------------------------------------
;; The lazy semantic domain
;;
;; A Search is one of:
;;
;;   Empty(next)       no answer
;;   One(state)        one terminal answer
;;   More(state,rest)  one answer with residual search
;;   Delay(rest)       one observable rail delay
;;
;; The rest fields are promises of Search values.  They are semantic
;; observations, not defunctionalized control continuations.

(struct Empty (next)
  #:transparent)

(struct One (state)
  #:transparent)

(struct More (state rest)
  #:transparent)

(struct Delay (rest)
  #:transparent)

;; ---------------------------------------------------------------------------
;; Oriented rail merge
;;
;; The second argument of mplus-left and the first argument of mplus-right
;; are dormant promises.  A Delay changes which side is active.  These two
;; mutually recursive program points are the functional source of ChoiceL and
;; ChoiceR; after CPS, defunctionalization, and fusion, their host-language
;; calls become the scheduler zipper.

(define (mplus-left left right)
  (match left
    [(Empty _)
     (force right)]
    [(One state)
     (More state right)]
    [(More state left-rest)
     (More state
           (delay
             (mplus-left (force left-rest) right)))]
    [(Delay left-rest)
     (Delay
      (delay
        (mplus-right left-rest (force right))))]))

(define (mplus-right left right)
  (match right
    [(Empty _)
     (force left)]
    [(One state)
     (More state left)]
    [(More state right-rest)
     (More state
           (delay
             (mplus-right left (force right-rest))))]
    [(Delay right-rest)
     (Delay
      (delay
        (mplus-left (force left) right-rest)))]))

;; ---------------------------------------------------------------------------
;; Late/shared conjunction
;;
;; continue is an actual higher-order continuation, State -> Search.  The
;; same procedure is retained in every residual recursive call.  This is the
;; functional object that CPS, defunctionalization, and fusion turn into the
;; shared Then suffix.

(define (bind search continue)
  (match search
    [(Empty next)
     (Empty next)]
    [(One state)
     (continue state)]
    [(More state rest)
     (mplus-left
      (continue state)
      (delay
        (bind (force rest) continue)))]
    [(Delay rest)
     (Delay
      (delay
        (bind (force rest) continue)))]))

;; ---------------------------------------------------------------------------
;; Functional goal constructors
;;
;; A Goal is a procedure:
;;
;;   Kernel x RelationEnvironment x State -> Search
;;
;; After the two global semantic parameters are fixed, this is simply
;; State -> Search.
;;
;; In the sense of "From what program is valof defunctionalized?", these
;; procedures are the denotations of goals.  valof is consequently just
;; procedure application.

(define (valof goal K relations state)
  (goal K relations state))

(define (make-atomic request)
  (lambda (K _relations state)
    (match (K request state)
      [#f
       (Empty (State-next state))]
      [(? State? state*)
       (One state*)]
      [result
       (error 'make-atomic
              "kernel returned neither a State nor #f: ~e"
              result)])))

(define (make-succeed [tag 'succeed])
  (make-atomic (Succeed tag)))

(define (make-fail [tag 'fail])
  (make-atomic (FailGoal tag)))

(define (put value [tag 'put])
  (make-atomic
   (Atom
    (lambda (state)
      (struct-copy State state [tag value]))
    tag)))

(define (make-fresh arity body)
  (unless (exact-nonnegative-integer? arity)
    (raise-argument-error 'make-fresh
                          "exact-nonnegative-integer?"
                          arity))
  (lambda (K relations state)
    (define next (State-next state))
    (define variables
      (for/list ([offset (in-range arity)])
        (LVar (+ next offset))))
    (define state*
      (struct-copy State state [next (+ next arity)]))
    (valof (apply body variables) K relations state*)))

(define (make-conj left right)
  (lambda (K relations state)
    (bind
     (valof left K relations state)
     (lambda (state*)
       (valof right K relations state*)))))

(define (make-disj left right)
  (lambda (K relations state)
    (mplus-left
     (valof left K relations state)
     (delay
       (valof right K relations state)))))

(define (make-suspend goal)
  (lambda (K relations state)
    (Delay
     (delay
       (valof goal K relations state)))))

(define (make-relcall name . arguments)
  (lambda (K relations state)
    (define relation
      (hash-ref
       relations name
       (lambda ()
         (error 'make-relcall "unknown relation ~e" name))))
    ;; Expansion is intentionally not a Delay.  A relation-entry scheduling
    ;; policy is written explicitly as (make-suspend (make-relcall ...)).
    (valof (apply relation arguments) K relations state)))

;; ---------------------------------------------------------------------------
;; Settled frontiers and their direct renderer
;;
;; render's ordinary Racket call stack is the functional object that later
;; CPSes and defunctionalizes to the monotone output continuation.

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
    [(More state rest)
     (Emit (Answer state)
           (render (force rest)))]
    [(Delay rest)
     (Forced
      (render (force rest)))]))

(define (run-search goal
                    #:kernel [K basic-kernel]
                    #:relations [relations (hash)]
                    #:state [state (empty-state)])
  (valof goal K relations state))

(define (run goal
             #:kernel [K basic-kernel]
             #:relations [relations (hash)]
             #:state [state (empty-state)])
  (render
   (run-search goal
               #:kernel K
               #:relations relations
               #:state state)))

;; A compact, exact projection useful at the REPL.  Unlike answer-tags, this
;; retains delay and terminal-shape information.
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
;; Nested rail witness

(define nested-rail-witness
  (make-disj
   (make-suspend
    (make-suspend (put 'A)))
   (make-disj
    (make-suspend (put 'B))
    (make-suspend (put 'C)))))

(module+ test
  (require rackunit)

  (check-equal?
   (frontier-shape (run (put 'A)))
   '(Last A))

  (check-equal?
   (frontier-shape
    (run (make-disj (put 'A) (put 'B))))
   '(Emit A (Last B)))

  (check-equal?
   (frontier-shape
    (run (make-disj (put 'A) (make-fail))))
   '(Emit A (Done 0)))

  (check-equal?
   (frontier-shape
    (run (make-disj (make-fail) (put 'B))))
   '(Last B))

  (check-equal?
   (frontier-shape
    (run (make-disj
          (put 'A)
          (make-suspend (put 'B)))))
   '(Emit A (Forced (Last B))))

  (check-equal?
   (frontier-shape
    (run (make-disj
          (make-suspend (put 'A))
          (put 'B))))
   '(Forced (Emit B (Last A))))

  (check-equal?
   (frontier-shape (run nested-rail-witness))
   '(Forced
     (Forced
      (Forced
       (Forced
        (Emit A (Emit B (Last C))))))))

  (check-equal?
   (frontier-shape
    (run (make-conj (put 'left) (put 'right))))
   '(Last right))

  (define append-then
    (make-atomic
     (Atom
      (lambda (state)
        (struct-copy State state
                     [tag (list (State-tag state) 'then)]))
      'append-then)))

  (check-equal?
   (frontier-shape
    (run (make-conj
          (make-disj (put 'A) (put 'B))
          append-then)))
   '(Emit (A then) (Last (B then))))

  (check-equal?
   (frontier-shape
    (run (make-conj
          (make-disj (put 'A) (put 'B))
          (make-suspend append-then))))
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
           (make-suspend
            (make-relcall 'countdown (sub1 n)))))))

  (check-equal?
   (frontier-shape
    (run (make-relcall 'put 'relation-answer)
         #:relations relations))
   '(Last relation-answer))

  (check-equal?
   (frontier-shape
    (run (make-suspend
          (make-relcall 'put 'delayed-relation-answer))
         #:relations relations))
   '(Forced (Last delayed-relation-answer)))

  (check-equal?
   (frontier-shape
    (run (make-relcall 'countdown 2)
         #:relations relations))
   '(Forced (Forced (Last countdown-done))))

  (match (run (make-fresh 2
                          (lambda (_x _y)
                            (make-succeed))))
    [(Last (Answer (State next _ _ _ _)))
     (check-equal? next 2)]))
