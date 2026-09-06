#lang racket

(require racket/match
         rackunit
         redex/reduction-semantics
         (prefix-in direct: "../functional-search/direct-interpreter.rkt")
         (prefix-in online:
                    "../../src/search-lattice/reduction-relations/rail-red.rkt"))

(provide finite-fusion-goals
         direct-goal
         online-goal
         direct-observation
         online-observation
         online-trace)

;; This is finite evidence for a prospective fusion theorem.  The compared
;; observation preserves every answer State, answer order, Delay count, and
;; terminal constructor.  Owner provenance is outside this interpreter's State
;; carrier; allocation and relcalls are deliberately outside this bridge probe.

(define initial-tag '(label "initial"))
(define initial-state `(state () () () ,initial-tag))

(define (equation name)
  `((nat 0) =? (nat 0) (label ,(symbol->string name))))

(define (direct-goal goal)
  (match goal
    [`(ok ,name)
     (direct:Atom
      (lambda (state)
        (direct:success-outcome
         (struct-copy direct:State state
                      [trail (append (direct:State-trail state)
                                     (list (equation name)))])))
      name)]
    ['fail (direct:FailGoal 'failure)]
    [`(delay ,body) (direct:Suspend (direct-goal body) 'delay)]
    [`(and ,left ,right)
     (direct:Conj (direct-goal left) (direct-goal right) 'conjunction)]
    [`(or ,left ,right)
     (direct:Disj (direct-goal left) (direct-goal right) 'choice)]))

(define (online-goal goal)
  (match goal
    [`(ok ,name) (equation name)]
    ['fail '(fail (label "failure"))]
    [`(delay ,body) `(suspend ,(online-goal body) (label "delay"))]
    [`(and ,left ,right)
     `(,(online-goal left) ∧ ,(online-goal right) (label "conjunction"))]
    [`(or ,left ,right)
     `(,(online-goal left) ∨ ,(online-goal right) (label "choice"))]))

(define (state-observation state)
  (match-define (direct:State 0 sub dis trail tag) state)
  `(state ,sub ,dis ,trail ,tag))

(define (direct-observation frontier)
  (match frontier
    [(direct:Done 0) '(Done)]
    [(direct:Last (direct:Answer state))
     `(Last ,(state-observation state))]
    [(direct:Emit (direct:Answer state) tail)
     `(Emit ,(state-observation state) ,(direct-observation tail))]
    [(direct:Forced tail) `(Forced ,(direct-observation tail))]))

(define (online-observation frontier)
  (match frontier
    [`(Done ,_) '(Done)]
    [`(Last ,_ (Answer ,_ ,state)) `(Last ,state)]
    [`(Emit ,_ (Answer ,_ ,state) ,tail)
     `(Emit ,state ,(online-observation tail))]
    [`(Forced ,_ ,tail) `(Forced ,(online-observation tail))]
    [_ (error 'online-observation "unfinished online frontier: ~e" frontier)]))

(define (online-trace goal [fuel 2000] [steps '()])
  (define successors
    (apply-reduction-relation/tag-with-names online:rail-red goal))
  (match successors
    ['() (values (reverse steps) goal)]
    [(list (list name next))
     (when (zero? fuel)
       (error 'online-trace "fuel exhausted at ~e" goal))
     (online-trace next (sub1 fuel) (cons (~a name) steps))]
    [_ (error 'online-trace "non-deterministic successors: ~e" successors)]))

(define (goals-of-size size)
  (match size
    [1 '((ok A) (ok B) fail)]
    [_
     (append
      (for/list ([body (in-list (goals-of-size (sub1 size)))])
        `(delay ,body))
      (for*/list ([left-size (in-range 1 (sub1 size))]
                  [left (in-list (goals-of-size left-size))]
                  [right (in-list (goals-of-size (- size left-size 1)))]
                  [operator (in-list '(and or))])
        `(,operator ,left ,right)))]))

(define nested-rail
  '(or (delay (delay (ok A)))
       (or (delay (ok B)) (delay (ok C)))))

(define bind-residual
  '(and (or (ok A) (or (ok B) (ok C)))
        (and (ok continuation) (delay (ok resumed)))))

(define eager-sibling
  '(or (ok A) (and (ok p) (and (ok q) (delay (ok h))))))

(define finite-fusion-goals
  (append (append-map goals-of-size '(1 2 3 4))
          (list nested-rail bind-residual eager-sibling)))

(module+ test
  (for ([goal (in-list finite-fusion-goals)])
    (test-case (format "finite online fusion witness: ~s" goal)
      (define-values (_names final)
        (online-trace `(More (Work (Owners) ,(online-goal goal) ,initial-state))))
      (check-equal?
       (online-observation final)
       (direct-observation
        (direct:run (direct-goal goal)
                    #:state (direct:empty-state initial-tag))))))

  ;; A matching completed readback does not identify the full work traces.
  (define-values (names _final)
    (online-trace
     `(More (Work (Owners) ,(online-goal eager-sibling) ,initial-state))))
  (check-true (< (index-of names "commit-choice-answer")
                 (index-of names "expand-conjunction"))))
