#lang racket

(require rackunit
         (prefix-in direct: "../functional-search/direct-interpreter.rkt")
         (prefix-in functional: "functional-machine.rkt")
         (prefix-in registers: "register-machine.rkt")
         (prefix-in correspondence: "correspondence.rkt")
         (prefix-in source: "source.rkt")
         (only-in "tests.rkt" finite-goals)
         redex/reduction-semantics)

(define (check-lockstep configuration bank [fuel 4000])
  (check-equal? (registers:decode-machine bank) configuration)
  (check-equal? (registers:decode-machine
                (registers:registers-from-machine configuration))
               configuration)
  (when (member (registers:Registers-pc bank) '(force render return))
    (check-false (registers:Registers-y bank)))
  (cond
    [(functional:machine-final? configuration)
     (define steps (registers:Registers-steps bank))
     (check-true (registers:register-final? bank))
     (check-false (registers:register-step! bank))
     (check-equal? (registers:Registers-steps bank) steps)]
    [else
     (when (zero? fuel) (error 'check-lockstep "correspondence budget exhausted"))
     (define steps (registers:Registers-steps bank))
     (define next (functional:machine-step configuration))
     (check-true (registers:register-step! bank))
     (check-equal? (registers:Registers-steps bank) (add1 steps))
     ;; Register correspondence composes with the already-independent source
     ;; decoder. Semantic self-loops are not classified as administration.
     (define before-source (correspondence:decode-configuration configuration))
     (define after-source (correspondence:decode-configuration
                           (registers:decode-machine bank)))
     (unless (equal? before-source after-source)
       (check-equal? (apply-reduction-relation source:strict-red before-source)
                      (list after-source)))
     (check-lockstep next bank (sub1 fuel))]))

(module+ test
  ;; Clause witnesses complement the size-bounded source corpus: every PC and
  ;; continuation dispatch is checked, including merge-yield and bind-yield
  ;; corridors that require larger goals to arise naturally.
  (define state (direct:empty-state))
  (define goal (direct:Succeed 'success))
  (define halt (functional:Halt))
  (define one (functional:One state))
  (define rest (functional:ResumeEval goal state))
  (define continue (functional:Continue goal))
  (define clause-configurations
    (append
     (for/list ([g (in-list (list goal (direct:FailGoal 'failure) (direct:put 'A)
                                 (direct:Fresh 1 (lambda (_x) goal) 'fresh)
                                 (direct:Conj goal goal 'and)
                                 (direct:Disj goal goal 'or)
                                 (direct:Suspend goal 'delay)))])
       (functional:Eval g state halt))
     (append-map
      (lambda (search)
        (list (functional:Mplus search one halt)
              (functional:Bind search continue halt)
              (functional:Render search halt)))
      (list (functional:Empty 0) one (functional:Yield state one)
            (functional:Delay rest)))
     (for/list ([resume (in-list (list rest (functional:ResumeMerge one rest)
                                      (functional:ResumeBind rest continue)))])
       (functional:Force resume halt))
     (for/list ([k (in-list
                   (list halt
                         (functional:AfterConjLeft goal halt)
                         (functional:AfterDisjLeft goal state halt)
                         (functional:AfterDisjRight one halt)
                         (functional:RebuildYield state halt)
                         (functional:AfterBindHead one continue halt)
                         (functional:AfterBindTail one halt)
                         (functional:AfterForceMerge one halt)
                         (functional:AfterForceBind continue halt)
                         (functional:AfterEvalRender halt)
                         (functional:AfterRenderForce halt)))])
       (functional:Return one k))
     (list (functional:Return (direct:Done 0) (functional:AfterEmit state halt))
           (functional:Return (direct:Done 0) (functional:AfterForced halt)))))
  (for ([configuration (in-list clause-configurations)] [index (in-naturals)])
    (test-case (format "PC/continuation clause correspondence ~a" index)
      (define bank (registers:registers-from-machine configuration))
      (define expected (functional:machine-step configuration))
      (registers:register-step! bank)
      (check-equal? (registers:decode-machine bank) expected)))

  (for ([goal (in-list (append finite-goals (list direct:nested-rail-witness)))]
        [index (in-naturals)])
    (test-case (format "strict register result and exact machine trace ~a" index)
      (check-equal? (registers:run goal) (direct:run goal))
      (check-equal? (registers:run-search goal) (functional:run-search goal))
      (check-lockstep
       (functional:initial-machine goal #:render? #t)
       (registers:make-registers goal))))

  (test-case "mature left Search is retained by identity while right evaluates"
    (define bank (registers:make-registers
                  (direct:Disj (direct:put 'A) (direct:put 'B) 'disj)
                  #:observe? #f))
    (registers:register-step! bank)
    (registers:register-step! bank)
    (define mature-left (registers:Registers-x bank))
    (registers:register-step! bank)
    (check-equal? (registers:Registers-pc bank) 'eval)
    (match (registers:Registers-k bank)
      [(functional:AfterDisjRight stored (functional:Halt))
       (check-eq? stored mature-left)]
      [_ (fail-check "missing strict retained-left frame")]))

  (test-case "eager bind computes every head continuation before returning"
    (define events (box '()))
    (define continuation
      (direct:Conj
       (direct:Atom
        (lambda (state)
          (set-box! events (cons (direct:State-tag state) (unbox events)))
          (direct:success-outcome state))
        'continue)
       (direct:Suspend (direct:Succeed 'resumed) 'delay)
       'then-delay))
    (define result
      (registers:run-search
       (direct:Conj (direct:Disj (direct:put 'A) (direct:put 'B) 'choice)
                    continuation 'bind)))
    (check-true (functional:Delay? result))
    (check-equal? (reverse (unbox events)) '(A B)))

  (test-case "kernel order and unforced barrier survive PC dispatch"
    (define events (box '()))
    (define (note tag)
      (direct:Atom (lambda (state)
                    (set-box! events (cons tag (unbox events)))
                    (direct:success-outcome state))
                   tag))
    (define result
      (registers:run-search
       (direct:Disj
        (direct:put 'A)
        (direct:Conj (note 'p)
                     (direct:Conj (note 'q) (direct:Suspend (note 'h) 'delay) 'q-h)
                     'p-q)
        'choice)))
    (check-equal? (reverse (unbox events)) '(p q))
    (match result
      [(functional:Yield _ (functional:Delay _)) (void)]
      [_ (fail-check "right search did not mature at its actual Delay")]))

  (test-case "banks can interleave with distinct kernel environments"
    (define (kernel value)
      (lambda (_goal state)
        (direct:success-outcome (struct-copy direct:State state [tag value]))))
    (define a (registers:make-registers (direct:Succeed 'g) #:kernel (kernel 'A)))
    (define b (registers:make-registers (direct:Succeed 'g) #:kernel (kernel 'B)))
    (registers:register-step! a)
    (registers:register-step! b)
    (check-equal? (direct:frontier-shape (registers:drive! a)) '(Last A))
    (check-equal? (direct:frontier-shape (registers:drive! b)) '(Last B)))

  (test-case "nested fresh carries full state through numeric register operands"
    (define goal
      (direct:Fresh
       2 (lambda (x y)
           (direct:Fresh
            1 (lambda (z)
                (direct:Atom (lambda (state)
                               (direct:success-outcome
                                (struct-copy direct:State state
                                             [substitution (list (list x z))]
                                             [trail (list x y z)])))
                             'remember))
            'inner))
       'outer))
    (define state (struct-copy direct:State (direct:empty-state) [next 8]))
    (check-equal? (registers:run goal #:state state) (direct:run goal #:state state)))

  (test-case "unguarded source divergence stays a running eval PC"
    (define (omega) (direct:Fresh 0 omega 'omega))
    (define bank
      (registers:make-registers
       (direct:Disj (direct:put 'A) (omega) 'choice) #:observe? #f))
    (check-exn registers:exn:fail:register-fuel?
               (lambda () (registers:drive! bank #:fuel 64)))
    (check-false (registers:register-final? bank))
    (check-equal? (registers:Registers-pc bank) 'eval)
    (check-true (functional:AfterDisjRight? (registers:Registers-k bank)))
    (define before (registers:decode-machine bank))
    (registers:register-step! bank)
    (check-equal? (registers:decode-machine bank) before)
    (check-true (functional:Yield?
                 (registers:run-search
                  (direct:Disj (direct:put 'A)
                               (direct:Suspend (omega) 'guard) 'choice)
                  #:fuel 64))))

  (test-case "invalid fuel and relcalls are rejected"
    (for ([fuel (in-list (list -1 1/2 #f))])
      (check-exn exn:fail:contract?
                 (lambda () (registers:run (direct:Succeed 'g) #:fuel fuel))))
    (check-exn #rx"relcalls" (lambda () (registers:run (direct:Call 'later '() 'call))))))
