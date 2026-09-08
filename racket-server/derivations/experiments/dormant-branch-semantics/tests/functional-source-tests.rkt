#lang racket

(require rackunit
         "../derivation/functional-source.rkt" "../derivation/data.rkt"
         (prefix-in machine: "../derivation/machine.rkt")
         (prefix-in source: "../derivation/source.rkt")
         (prefix-in derive: "../derivation/derive.rkt")
         "../../../retained-scope/relations.rkt"
         "../../../test-support/witnesses.rkt")

(define empty-state '(state () () () (label "initial")))
(define policies '(dfs flip rail))
(define visited-pcs '())
(define visited-labels '())
(define administrative-edges 0)
(define semantic-edges 0)

(define (data-only? datum)
  (match datum
    [(? procedure?) #f]
    [(cons first rest) (and (data-only? first) (data-only? rest))]
    [(? struct?) (for/and ([field (in-vector (struct->vector datum) 1)]) (data-only? field))]
    [_ #t]))

(define (body program)
  (match program [`(program ,_ ,_ ,term) term]))

;; Exactly the prescribed empty/singleton source span is checked. The map
;; compares the original and immediately following machine configurations;
;; there is no search for a later matching result on either side.
(define (check-edge policy current)
  (check-true (data-only? current))
  (define before (machine->source policy current))
  (match-define (machine:Call pc _) current)
  (unless (member pc visited-pcs) (set! visited-pcs (cons pc visited-pcs)))
  (define next (machine:step current))
  (check-true (data-only? next))
  (define after (machine->source policy next))
  (match (machine-step-span current)
    ['()
     (set! administrative-edges (add1 administrative-edges))
     (check-equal? before after)
     (check-true (< (administrative-rank next) (administrative-rank current)))]
    [(list label)
     (set! semantic-edges (add1 semantic-edges))
     (unless (member label visited-labels) (set! visited-labels (cons label visited-labels)))
     (check-equal? (source:step before) (list label after))])
  next)

(define (check-round policy current [fuel 5000] #:halt? [halt? #t])
  (match current
    [(machine:Halted _)
     (define source (machine->source policy current))
     (check-true (source:frontier? (body source)))
     (check-false (source:step source))
     current]
    [_
     (cond
       [(zero? fuel)
        (when halt? (fail-check "finite functional/source round exceeded its explicit step budget"))
        current]
       [else (check-round policy (check-edge policy current) (sub1 fuel) #:halt? halt?)])]))

(define (check-advances policy halted remaining #:finite? [finite? #t])
  (define source (machine->source policy halted))
  (cond
    [(source:complete? (body source)) halted]
    [(zero? remaining)
     (when finite? (fail-check "finite witness exceeded its public-advancement budget"))
     halted]
    [else
     (match-define (machine:Halted frontier) halted)
     (define next (machine:initial-advance frontier))
     ;; Public invocation is separate from both host dispatch and the source
     ;; advance-delay contraction that subsequently crosses object Delay.
     (check-equal? (machine->source policy next) (source:advance source))
     (check-advances policy (check-round policy next) (sub1 remaining) #:finite? finite?)]))

(define (check-goal policy goal #:owners [owners '(Owners)] #:state [state empty-state]
                    #:relations [definitions '()] #:rounds [rounds 40] #:finite? [finite? #t])
  (define initial
    (machine:initial goal #:policy policy #:owners owners #:state state #:relations definitions))
  (check-equal? (machine->source policy initial)
                (source:initial goal #:policy policy #:owners owners #:state state
                                #:relations (or definitions '())))
  (check-advances policy (check-round policy initial) rounds #:finite? finite?))

(define definitions
  '((r:id (x:q) (x:q =? (sym "A") (label "id-body")))
    (r:later (x:q)
             (∃ (x:unused)
                  (suspend (r:id x:q (label "resumed-call")) (label "pause"))
                  (label "unused-introduction")))
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
                (label "odd-fresh")))))

(module+ test
  (test-case "generated machine remains the literal defunctionalized program"
    (check-true (derive:check-generated!)))

  (for* ([policy (in-list policies)] [example (in-list validation-witnesses)])
    (test-case (format "~a / ~a: every machine configuration and explicit public boundary"
                       policy (witness-name example))
      (check-goal policy (witness-goal example)
                  #:owners (witness-owners example) #:state (witness-state example))))

  (for ([policy (in-list policies)])
    (test-case (format "~a / a right-active candidate still has a pending bind" policy)
      (check-goal
       policy
       '(∃ (x:common)
            (((suspend (∃ (x:left) (succeed (label "left")) (label "left-owner"))
                       (label "left-delay")) ∨
              (∃ (x:right) (succeed (label "right")) (label "right-owner"))
              (label "choice")) ∧
             (∃ (x:bound) (succeed (label "bound")) (label "bind-owner"))
             (label "bind")) (label "common-owner")))))

  (for* ([policy (in-list policies)]
         [goal (in-list
                (list '(∃ (x:q) (r:later x:q (label "call")) (label "query"))
                      '(r:even ((sym "a") : ((sym "b") : empty)) (label "even"))
                      '(r:odd ((sym "a") : empty) (label "odd"))
                      '(∃ (x:q)
                           ((suspend (r:id x:q (label "left")) (label "delay-left")) ∨
                            ((r:later x:q (label "right")) ∧
                             (x:q != (sym "B") (label "pending")) (label "bind"))
                            (label "choice")) (label "query"))))])
    (test-case (format "~a / full relation work: ~s" policy (last goal))
      (check-goal policy goal #:relations definitions)))

  (for ([policy (in-list policies)])
    (test-case (format "~a / guarded infinite finite observations retain their pending work" policy)
      (define guarded
        '((r:again (x:q)
                   ((x:q =? (sym "A") (label "answer")) ∨
                    (suspend (r:again x:q (label "again")) (label "pause"))
                    (label "choice")))))
      (define halted
        (check-goal policy '(∃ (x:q) (r:again x:q (label "start")) (label "query"))
                    #:relations guarded #:rounds 8 #:finite? #f))
      (check-false (source:complete? (body (machine->source policy halted))))))

  (test-case "unguarded work remains an explicit computation after the settled prefix"
    (define recursive '((r:loop () (r:loop (label "loop")))))
    (for ([policy (in-list policies)])
      (define initial
        (machine:initial '((succeed (label "answer")) ∨ (r:loop (label "start-loop"))
                           (label "choice")) #:policy policy #:relations recursive))
      (define prefix (check-round policy initial 75 #:halt? #f))
      (check-false (machine:Halted? prefix))
      (check-match (body (machine->source policy prefix)) `(Emit ,_ ,_ (commit (eval ,_ ,_ ,_))))))

  (test-case "terminal advancement and a call-free machine without Gamma retain their interfaces"
    (for ([policy (in-list policies)])
      (check-goal policy '(succeed (label "plain")) #:relations #f)
      (for ([frontier (in-list (list '(Done (Owners)) `(Last (Owners) (Answer (Owners) ,empty-state))))])
        (define initial (machine:initial-advance frontier))
        (check-equal? (machine->source policy initial) `(program ,policy () (advance ,frontier)))
        (check-equal? (check-round policy initial) (machine:Halted frontier)))))

  (test-case "readback rejects foreign policies, lost scope, lost Gamma, closures, and collect-driver states"
    (define initial (machine:initial '(succeed (label "yes")) #:policy 'flip #:relations '()))
    (check-exn exn:fail? (lambda () (machine->source 'dfs initial)))
    (define misplaced-support
      (machine:Call 'eval/d
                    (list 'flip (ProgramGoal '() '(succeed (label "yes")))
                          empty-state '(Owners) '(u:9)
                          (KCommit '() (KProgram '() (KDone))))))
    (define missing-environment
      (machine:Call 'eval/d
                    (list 'flip '(succeed (label "lost-environment"))
                          empty-state '(Owners) '()
                          (KCommit '() (KProgram '() (KDone))))))
    (define collecting-return
      (machine:Call 'return/d (list '(Done (Owners)) (KCollect (KDone)))))
    (for ([invalid (in-list (list misplaced-support missing-environment collecting-return
                                 (machine:initial-collect '(Done (Owners)))))])
      (check-exn exn:fail? (lambda () (machine->source 'flip invalid))))
    (check-exn exn:fail?
               (lambda () (reify-resumption (lambda _ (error 'test "must not execute"))))))

  (test-case "the finite corpus exercises every source contraction and every in-scope PC"
    (check-equal? (sort visited-pcs symbol<?)
                  (sort (remove 'collect/d (map first machine:signatures)) symbol<?))
    (check-equal?
     (sort visited-labels string<?)
     (sort '("eval-fresh" "eval-conj" "eval-disj" "eval-suspend" "eval-call" "eval-atom"
             "mplus-empty" "mplus-one" "mplus-yield" "mplus-delay"
             "bind-empty" "bind-one" "bind-yield" "bind-yield-right" "bind-delay"
             "commit-empty" "commit-one" "commit-yield" "commit-yield-right" "commit-delay"
             "advance-terminal" "advance-emit" "advance-forced" "advance-delay") string<?))
    (check-true (> administrative-edges 0))
    (check-true (> semantic-edges 0)))

  (printf "Functional/source: ~a semantic edges and ~a decreasing administrative edges checked.\n"
          semantic-edges administrative-edges))
