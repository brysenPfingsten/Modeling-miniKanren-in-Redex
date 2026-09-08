#lang racket

(require rackunit
         (prefix-in direct: "../derivation/interpreter.rkt")
         (prefix-in cps: "../derivation/cps.rkt")
         (prefix-in defunc: "../derivation/defunc.rkt")
         (prefix-in machine: "../derivation/machine.rkt")
         (prefix-in derive: "../derivation/derive.rkt")
         "../derivation/data.rkt"
         "../../../shared/kernel-equations.rkt"
         "../../../shared/runtime.rkt"
         "../../../test-support/witnesses.rkt")

;; The only closure description table lives in this test. It records actual
;; direct/CPS allocations without calling the closures during readback.
;; Machine results already have these exact data shapes and use no observer.
(define (reify value descriptions)
  (match value
    [(? procedure? procedure)
     (match-define (list family captures) (hash-ref descriptions procedure))
     (define fields (map (lambda (field) (reify field descriptions)) captures))
     (match family
       ['eval (apply REval fields)]
       ['scope (apply RScope fields)]
       ['merge (apply RMerge fields)]
       ['bind (apply RBind fields)]
       ['continue (apply RContinue fields)]
       ['goal (apply GRight fields)])]
    [(cons head tail) (cons (reify head descriptions) (reify tail descriptions))]
    [_ value]))

(define (contains-procedure? value)
  (match value
    [(? procedure?) #t]
    [(cons head tail) (or (contains-procedure? head) (contains-procedure? tail))]
    [(? struct?) (contains-procedure? (vector->list (struct->vector value)))]
    [(? vector?) (ormap contains-procedure? (vector->list value))]
    [_ #f]))

(struct observation (value reified work descriptions) #:transparent)
(define (observe operation [descriptions (make-hasheq)])
  (define work '())
  (define value
    (parameterize ([direct:current-closure-observer
                    (lambda (family procedure captures)
                      (hash-set! descriptions procedure (list family captures)))]
                   [current-atomic-observer
                    (lambda (goal state) (set! work (cons (list goal state) work)))])
      (operation)))
  (observation value (reify value descriptions) (reverse work) descriptions))

(define visited-pcs '())
(define visited-records '())
(define (record-shapes value)
  (match value
    [(cons head tail) (record-shapes head) (record-shapes tail)]
    [(? struct?)
     (define fields (vector->list (struct->vector value)))
     (unless (member (car fields) visited-records)
       (set! visited-records (cons (car fields) visited-records)))
     (for-each record-shapes (cdr fields))]
    [_ (void)]))

;; Visit every actual generated edge. There are no semantic observers inside
;; these configurations. The independent source map tests supply the labelled
;; transition diagram; this gate checks the functional transformation itself.
(define (checked-drive current [fuel 200000])
  (check-false (contains-procedure? current))
  (record-shapes current)
  (match current
    [(machine:Halted value) value]
    [(machine:Call pc _)
     (when (zero? fuel) (error 'checked-drive "finite witness exhausted: ~e" current))
     (unless (member pc visited-pcs) (set! visited-pcs (cons pc visited-pcs)))
     (checked-drive (machine:step current) (sub1 fuel))]))

(define (machine-run goal #:policy [policy 'flip] #:owners [owners '(Owners)]
                     #:state [state '(state () () () (label "initial"))]
                     #:relations [relations #f])
  (checked-drive (machine:initial goal #:policy policy #:owners owners
                                  #:state state #:relations relations)))

(struct engine (name run resume collect) #:transparent)
(define engines
  (list (engine 'direct direct:run direct:resume-once direct:collect-all)
        (engine 'cps cps:run cps:resume-once cps:collect-all)
        (engine 'defunc defunc:run defunc:resume-once defunc:collect-all)
        (engine 'machine machine-run
                (lambda (frontier) (checked-drive (machine:initial-advance frontier)))
                (lambda (frontier) (checked-drive (machine:initial-collect frontier))))))

(define (same-observations observations)
  (define reference (car observations))
  (for ([actual (in-list (cdr observations))])
    (check-equal? (observation-reified actual) (observation-reified reference))
    (check-equal? (observation-work actual) (observation-work reference))))
(define (complete-frontier? frontier)
  (match frontier
    [`(program ,_ ,body) (complete? body)]
    [_ (complete? frontier)]))

(define (advance-rounds observations remaining)
  (same-observations observations)
  (cond
    [(andmap (lambda (observed) (complete-frontier? (observation-value observed))) observations)
     observations]
    [(zero? remaining) observations]
    [else
     (advance-rounds
      (for/list ([implementation (in-list engines)] [previous (in-list observations)])
        (observe (lambda () ((engine-resume implementation) (observation-value previous)))
                 (observation-descriptions previous)))
      (sub1 remaining))]))

(define (check-goal goal policy #:owners [owners '(Owners)]
                    #:state [state '(state () () () (label "initial"))]
                    #:relations [relations #f] #:rounds [rounds 40] #:finite? [finite? #t])
  (define initial
    (for/list ([implementation (in-list engines)])
      (observe (lambda () ((engine-run implementation) goal #:policy policy #:owners owners
                            #:state state #:relations relations)))))
  (define final (advance-rounds initial rounds))
  (when finite?
    (for ([observed (in-list final)])
      (check-true (complete-frontier? (observation-value observed))))
    (define collected
      (for/list ([implementation (in-list engines)] [previous (in-list initial)])
        (observe (lambda () ((engine-collect implementation) (observation-value previous)))
                 (observation-descriptions previous))))
    (same-observations collected)
    (check-equal? (observation-reified (car collected))
                  (observation-reified (car final))))
  (void))

(define relation-environment
  '((r:value (x:q) (x:q =? (sym "A") (label "value")))
    (r:delayed (x:q)
               (∃ (x:unused)
                  (suspend (r:value x:q (label "resumed-call")) (label "pause"))
                  (label "unused-before-delay")))
    (r:even (x:xs)
            ((x:xs =? empty (label "even-empty")) ∨
             (∃ (x:h x:t)
                ((x:xs =? (x:h : x:t) (label "even-pair")) ∧
                 (r:odd x:t (label "to-odd")) (label "even-body"))
                (label "even-fresh")) (label "even-choice")))
    (r:odd (x:xs)
           (∃ (x:h x:t)
              ((x:xs =? (x:h : x:t) (label "odd-pair")) ∧
               (r:even x:t (label "to-even")) (label "odd-body"))
              (label "odd-fresh")))
    (r:stream ()
              ((succeed (label "stream-answer")) ∨
               (suspend (r:stream (label "stream-next")) (label "stream-delay"))
               (label "stream-choice")))
    (r:omega () (r:omega (label "unguarded-call")))))

(define (path current [fuel 1000] [seen '()])
  (match current
    [(machine:Halted _) (reverse (cons current seen))]
    [_ (when (zero? fuel) (error 'path "finite diagnostic exhausted"))
       (path (machine:step current) (sub1 fuel) (cons current seen))]))

(module+ test
  (test-case "machine generation reifies the actual thirteen tail-call controls"
    (check-true (derive:check-generated!))
    (check-equal? machine:signatures (derive:control-signatures))
    (check-equal? (length machine:signatures) 13)
    (check-false (machine:step (machine:Halted '(Done (Owners))))))

  (for* ([policy (in-list '(dfs flip rail))] [example (in-list validation-witnesses)])
    (test-case (format "~a / ~a: exact functional frontiers, scope, and work" policy (witness-name example))
      (check-goal (witness-goal example) policy #:owners (witness-owners example)
                  #:state (witness-state example))))

  (for* ([policy (in-list '(dfs flip rail))]
         [goal (in-list
                '((∃ (x:q) (r:delayed x:q (label "delay-call")) (label "query"))
                  (∃ (x:q)
                     ((r:value x:q (label "before")) ∧
                      (suspend (r:delayed x:q (label "after")) (label "outer-delay"))
                      (label "pending-bind")) (label "query"))
                  (r:even ((sym "a") : ((sym "b") : empty)) (label "mutual-even"))
                  (r:odd ((sym "a") : empty) (label "mutual-odd"))))])
    (test-case (format "~a: full relation program ~s" policy goal)
      (check-goal goal policy #:relations relation-environment)))

  (for ([policy (in-list '(dfs flip rail))])
    (test-case (format "~a: bounded productive relation frontiers" policy)
      (check-goal '(r:stream (label "start")) policy #:relations relation-environment
                  #:rounds 4 #:finite? #f)))

  (test-case "explicit empty program boundary is preserved"
    (check-goal '(succeed (label "empty-program")) 'flip #:relations '()))

  (test-case "a computational Yield tail is demanded beneath commitment without forcing a Delay"
    (define goal '((succeed (label "left")) ∨ (succeed (label "right")) (label "choice")))
    (define state '(state () () () (label "initial")))
    (define computations
      (list (lambda () (direct:eval/s 'flip goal state '(Owners) '()))
            (lambda () (cps:eval/k 'flip goal state '(Owners) '() values))
            (lambda () (defunc:eval/d 'flip goal state '(Owners) '() (KDone)))
            (lambda () (checked-drive (machine:Call 'eval/d
                                                   (list 'flip goal state '(Owners) '() (KDone)))))))
    (define matured (map observe computations))
    (same-observations matured)
    (check-equal? (map first (observation-work (car matured))) '((succeed (label "left"))))
    (check-equal? (observation-reified (car matured))
                  `(Yield (Owners) (Answer (Owners) ,state)
                          ,(REval 'flip '(succeed (label "right")) state)))
    (define configurations (path (machine:initial goal)))
    (check-not-false
     (for/or ([current (in-list configurations)])
       (match current
         [(machine:Call 'resume/d (list _ _ _ (KCommit _ (KEmit _ _ _)))) #t]
         [_ #f])))
    (check-false
     (for/or ([current (in-list configurations)])
       (match current [(machine:Call 'advance/d _) #t] [_ #f]))))

  (test-case "actual Delay stops a run and only public advancement enters its computation"
    (define goal '(suspend (succeed (label "after")) (label "delay")))
    (define initial (observe (lambda () (machine:run goal))))
    (check-equal? (observation-work initial) '())
    (check-match (observation-value initial) `(More (Delay (Owners) ,(? REval?))))
    (define next (observe (lambda () (machine:resume-once (observation-value initial)))))
    (check-equal? (map first (observation-work next)) '((succeed (label "after"))))
    (check-match (observation-value next) `(Forced (Owners) (Last (Owners) ,_))))

  (test-case "unguarded call stays explicit data and the host dispatcher has finite fuel"
    (define initial (machine:initial '(r:omega (label "start"))
                                      #:relations relation-environment))
    (define final
      (for/fold ([current initial]) ([index (in-range 50)])
        (check-false (contains-procedure? current))
        (check-match current (machine:Call 'eval/d _))
        (machine:step current)))
    (check-exn exn:fail:budget? (lambda () (machine:drive final #:fuel 50))))

  (test-case "data stages do not consult the direct interpreter's closure observer"
    (parameterize ([direct:current-closure-observer
                    (lambda _ (error 'observer "data execution consulted a test observer"))])
      (define goal '((suspend (succeed (label "A")) (label "d")) ∨
                    (succeed (label "B")) (label "choice")))
      (check-equal? (defunc:collect-all (defunc:run goal #:policy 'rail))
                    (machine:collect-all (machine:run goal #:policy 'rail)))))

  (test-case "finite corpus exercises every generated control and every closure/frame family"
    (check-equal? (sort visited-pcs symbol<?) (sort (map car machine:signatures) symbol<?))
    (for ([name (in-list '(REval RScope RMerge RBind RContinue GRight
                          KDone KProgram KConj KMerge KBind KCommit KEmit
                          KAdvanceEmit KAdvanceHistory KAdvanceForced KCollect
                          FEmpty SOne Failure Success))])
      (check-not-false (member (string->symbol (format "struct:~a" name)) visited-records)
                      (format "uncovered data constructor ~a" name)))))
