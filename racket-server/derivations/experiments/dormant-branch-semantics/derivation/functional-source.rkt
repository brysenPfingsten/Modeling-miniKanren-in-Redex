#lang racket

(require "data.rkt"
         (prefix-in machine: "machine.rkt")
         (prefix-in source: "source.rkt")
         "../../../retained-scope/relations.rkt"
         (only-in "../../../shared/kernel.rkt"
                  owners-support owners-append valid-support?))

(provide reify-resumption reify-search reify-frontier
         continuation-prefix reify-continuation
         machine->source machine-step-span administrative-rank)

;; The relation is indexed by the selected scheduler policy: a completed
;; functional Frontier need not retain a policy because there is no pending
;; computation to schedule. Every policy that IS stored in a machine record
;; must equal that index. Gamma comes from the explicit KProgram/value boundary;
;; pending ProgramGoal records must agree with it.
;;
;; Readback is structural. It does not run a resumption, kernel, machine step,
;; source step, test observer, or closure-description lookup. Search values
;; become source values and continuation frames become source contexts.
;; RScope is root attachment BEFORE execution, expressed by the source lift
;; equation lift(O,lift(local,c)) = lift(O++local,c).
;;
;; One machine transition represents either the single named source contraction
;; selected by machine-step-span, or its explicitly empty administrative span.
;; The rank below strictly decreases along every empty span. It counts pending
;; return reconstruction, atomic outcome dispatch, or the finite path through
;; demanded resumption records; it does not assign a bound to semantic work.
;;
;; Scope: initial evaluation and explicit single public advancement. The
;; collect/d / KCollect library driver is intentionally excluded: its repeated
;; public-advancement obligation has no constructor in source.rkt's grammar.

(define (extend owners inherited)
  (define here (owners-support owners inherited))
  (unless (valid-support? here)
    (error 'functional-source "invalid allocation ancestry: ~e" here))
  here)

(define (check-prefix captured structural)
  (unless (equal? captured structural)
    (error 'functional-source "captured support ~e disagrees with ancestry ~e"
           captured structural)))

(define (continuation-goal continue)
  (match continue
    [(GRight _ goal) (goal-body goal)]
    [_ (raise-argument-error 'continuation-goal "GRight" continue)]))

(define (reify-resumption resume [owners '(Owners)] [inherited '()])
  (define here (extend owners inherited))
  (match resume
    [(REval _ goal state) `(eval ,owners ,(goal-body goal) ,state)]
    [(RScope local rest)
     (reify-resumption rest (owners-append owners local) inherited)]
    [(RMerge _ side left right)
     `(,(match side ['left 'mplus] ['right 'mplusR]) ,owners
       ,(reify-resumption left '(Owners) here)
       ,(reify-resumption right '(Owners) here))]
    [(RBind _ rest continue)
     `(bind ,owners ,(reify-resumption rest '(Owners) here)
            ,(continuation-goal continue))]
    [(RContinue continue state local)
     (extend local here)
     `(eval ,(owners-append owners local) ,(continuation-goal continue) ,state)]
    [_ (raise-argument-error 'reify-resumption "defunctionalized scheduler computation" resume)]))

(define (reify-search search [inherited '()])
  (match search
    [(or `(Empty ,owners) `(One ,owners ,_))
     (extend owners inherited)
     search]
    [(or `(Yield ,owners (Answer ,private ,state) ,rest)
         `(YieldR ,owners ,rest (Answer ,private ,state)))
     (define here (extend owners inherited))
     (extend private here)
     (define residual (reify-resumption rest '(Owners) here))
     (match search
       [`(Yield ,_ ,_ ,_) `(Yield ,owners (Answer ,private ,state) ,residual)]
       [`(YieldR ,_ ,_ ,_) `(YieldR ,owners ,residual (Answer ,private ,state))])]
    [`(Delay ,owners ,resume)
     `(Delay ,owners ,(reify-resumption resume '(Owners) (extend owners inherited)))]
    [_ (raise-argument-error 'reify-search "defunctionalized scheduler Search" search)]))

(define (reify-frontier frontier [inherited '()])
  (match frontier
    [`(program ,definitions ,body) `(program ,definitions ,(reify-frontier body inherited))]
    [`(Done ,owners) (extend owners inherited) frontier]
    [`(Last ,owners (Answer ,private ,_))
     (extend private (extend owners inherited))
     frontier]
    [`(Emit ,owners (Answer ,private ,state) ,rest)
     (define here (extend owners inherited))
     (extend private here)
     `(Emit ,owners (Answer ,private ,state) ,(reify-frontier rest here))]
    [`(Forced ,owners ,rest)
     `(Forced ,owners ,(reify-frontier rest (extend owners inherited)))]
    [`(More ,(and delay `(Delay ,_ ,_))) `(More ,(reify-search delay inherited))]
    [_ (raise-argument-error 'reify-frontier "defunctionalized scheduler Frontier" frontier)]))

(define (reify-value value inherited)
  (match value
    [`(,(or 'Empty 'One 'Yield 'YieldR 'Delay) ,_ ...) (reify-search value inherited)]
    [_ (reify-frontier value inherited)]))

(define (continuation-prefix k)
  (match k
    [(KDone) '()]
    [(KProgram _ rest) (continuation-prefix rest)]
    [(or (KConj _ _ owners inherited rest)
         (KMerge _ _ _ owners inherited rest)
         (KBind _ _ owners inherited rest))
     (define outside (continuation-prefix rest))
     (check-prefix inherited outside)
     (extend owners outside)]
    [(KCommit inherited rest)
     (define outside (continuation-prefix rest))
     (check-prefix inherited outside)
     outside]
    [(or (KEmit owners _ rest) (KAdvanceEmit owners _ rest)
         (KAdvanceHistory owners rest) (KAdvanceForced owners rest))
     (extend owners (continuation-prefix rest))]
    [(KCollect _) (error 'functional-source "collect driver is outside the source grammar")]
    [_ (raise-argument-error 'continuation-prefix "scheduler continuation" k)]))

(define (reify-continuation computation k)
  (continuation-prefix k)
  (match k
    [(KDone) computation]
    [(KProgram definitions rest)
     (reify-continuation `(program ,definitions ,computation) rest)]
    [(KConj _ goal owners _ rest)
     (reify-continuation `(bind ,owners ,computation ,(goal-body goal)) rest)]
    [(KMerge _ side passive owners inherited rest)
     (define residual (reify-resumption passive '(Owners) (extend owners inherited)))
     (reify-continuation
      (match side
        ['left `(mplus ,owners ,computation ,residual)]
        ['right `(mplusR ,owners ,residual ,computation)]) rest)]
    [(KBind _ continue owners _ rest)
     (reify-continuation `(bind ,owners ,computation ,(continuation-goal continue)) rest)]
    [(KCommit _ rest) (reify-continuation `(commit ,computation) rest)]
    [(or (KEmit owners answer rest) (KAdvanceEmit owners answer rest))
     (reify-continuation `(Emit ,owners ,answer ,computation) rest)]
    [(or (KAdvanceHistory owners rest) (KAdvanceForced owners rest))
     (reify-continuation `(Forced ,owners ,computation) rest)]))

(define (read-call pc operands)
  (match (cons pc operands)
    [(list 'eval/d _ goal state owners inherited k)
     (check-prefix inherited (continuation-prefix k))
     (reify-continuation `(eval ,owners ,(goal-body goal) ,state) k)]
    [(list 'merge/d policy side left right owners inherited k)
     (check-prefix inherited (continuation-prefix k))
     (reify-continuation (reify-resumption (RMerge policy side left right) owners inherited) k)]
    [(list 'merge-active/d _ side active passive owners inherited k)
     (check-prefix inherited (continuation-prefix k))
     (define here (extend owners inherited))
     (define value (reify-search active here))
     (define residual (reify-resumption passive '(Owners) here))
     (reify-continuation
      (match side
        ['left `(mplus ,owners ,value ,residual)]
        ['right `(mplusR ,owners ,residual ,value)]) k)]
    [(list 'bind/d _ search continue owners inherited k)
     (check-prefix inherited (continuation-prefix k))
     (reify-continuation
      `(bind ,owners ,(reify-search search (extend owners inherited)) ,(continuation-goal continue)) k)]
    [(list 'continue/d continue state owners inherited k)
     (check-prefix inherited (continuation-prefix k))
     (reify-continuation `(eval ,owners ,(continuation-goal continue) ,state) k)]
    [(list 'resume/d resume owners inherited k)
     (check-prefix inherited (continuation-prefix k))
     (reify-continuation (reify-resumption resume owners inherited) k)]
    [(list 'commit/d search inherited k)
     (check-prefix inherited (continuation-prefix k))
     (reify-continuation `(commit ,(reify-search search inherited)) k)]
    [(list 'advance/d frontier inherited k)
     (check-prefix inherited (continuation-prefix k))
     (reify-continuation `(advance ,(reify-frontier frontier inherited)) k)]
    [(list 'outcome/d outcome (FEmpty owners k) (SOne owners* k*))
     (unless (and (equal? owners owners*) (equal? k k*))
       (error 'functional-source "atomic outcome handlers disagree"))
     (reify-continuation
      (match outcome [(Failure) `(Empty ,owners)] [(Success state) `(One ,owners ,state)]) k)]
    [(list 'failure/d (FEmpty owners k)) (reify-continuation `(Empty ,owners) k)]
    [(list 'success/d (SOne owners k) state) (reify-continuation `(One ,owners ,state) k)]
    [(list 'return/d value k)
     (reify-continuation (reify-value value (continuation-prefix k)) k)]
    [(list 'collect/d _ _) (error 'functional-source "collect driver is outside the source grammar")]
    [_ (raise-argument-error 'functional-source "known machine Call" (cons pc operands))]))

(define (validate-index! policy definitions datum)
  (define (check-goal goal)
    (unless (if definitions
                (and (ProgramGoal? goal) (equal? (ProgramGoal-relations goal) definitions))
                (not (ProgramGoal? goal)))
      (error 'functional-source "goal environment disagrees with program boundary: ~e" goal)))
  (match datum
    [(? procedure?) (error 'functional-source "procedure in a data configuration")]
    [(or (REval stored _ _) (RMerge stored _ _ _) (RBind stored _ _)
         (GRight stored _) (KConj stored _ _ _ _)
         (KMerge stored _ _ _ _ _) (KBind stored _ _ _ _))
     (unless (eq? stored policy)
       (error 'functional-source "stored policy ~e disagrees with index ~e" stored policy))]
    [_ (void)])
  (match datum
    [(or (REval _ goal _) (GRight _ goal) (KConj _ goal _ _ _)) (check-goal goal)]
    [(KProgram stored _)
     (unless (equal? stored definitions)
       (error 'functional-source "continuation environments disagree"))]
    [(ProgramGoal stored _)
     (unless (equal? stored definitions)
       (error 'functional-source "pending environment disagrees with program boundary"))]
    [(machine:Call 'eval/d (list stored goal _ ...))
     (unless (eq? stored policy) (error 'functional-source "active policy disagrees with index"))
     (check-goal goal)]
    [(machine:Call (or 'merge/d 'merge-active/d 'bind/d) (list stored _ ...))
     (unless (eq? stored policy) (error 'functional-source "active policy disagrees with index"))]
    [_ (void)])
  (match datum
    [(cons first rest)
     (validate-index! policy definitions first)
     (validate-index! policy definitions rest)]
    [(? struct?)
     (for ([field (in-vector (struct->vector datum) 1)])
       (validate-index! policy definitions field))]
    [_ (void)]))

(define (machine->source policy configuration)
  (check-policy policy)
  (define raw
    (match configuration
      [(machine:Call pc operands) (read-call pc operands)]
      [(machine:Halted value) (reify-frontier value)]
      [_ (raise-argument-error 'machine->source "scheduler machine configuration" configuration)]))
  (define result
    (match raw
      [`(program ,definitions ,body)
       (validate-index! policy definitions configuration)
       `(program ,policy ,definitions ,body)]
      [_ (validate-index! policy #f configuration) `(program ,policy () ,raw)]))
  (unless (source:source-in-domain? result)
    (error 'functional-source "readback is outside the indexed source grammar: ~e" result))
  result)

(define (machine-step-span configuration)
  (match configuration
    [(machine:Call 'eval/d (list _ goal _ ...))
     (list (match (goal-body goal)
             [`(∃ ,_ ,_ ,_) "eval-fresh"]
             [`(,_ ∧ ,_ ,_) "eval-conj"]
             [`(,_ ∨ ,_ ,_) "eval-disj"]
             [`(suspend ,_ ,_) "eval-suspend"]
             [(? relation-call?) "eval-call"]
             [_ "eval-atom"]))]
    [(machine:Call 'merge-active/d (list _ _ active _ ...))
     (list (match active
             [`(Empty ,_) "mplus-empty"] [`(One ,_ ,_) "mplus-one"]
             [`(Delay ,_ ,_) "mplus-delay"]
             [(or `(Yield ,_ ,_ ,_) `(YieldR ,_ ,_ ,_)) "mplus-yield"]))]
    [(machine:Call 'bind/d (list _ search _ ...))
     (list (match search
             [`(Empty ,_) "bind-empty"] [`(One ,_ ,_) "bind-one"]
             [`(Yield ,_ ,_ ,_) "bind-yield"] [`(YieldR ,_ ,_ ,_) "bind-yield-right"]
             [`(Delay ,_ ,_) "bind-delay"]))]
    [(machine:Call 'commit/d (list search _ _))
     (list (match search
             [`(Empty ,_) "commit-empty"] [`(One ,_ ,_) "commit-one"]
             [`(Yield ,_ ,_ ,_) "commit-yield"] [`(YieldR ,_ ,_ ,_) "commit-yield-right"]
             [`(Delay ,_ ,_) "commit-delay"]))]
    [(machine:Call 'advance/d (list frontier _ _))
     (list (match frontier
             [(or `(Done ,_) `(Last ,_ ,_)) "advance-terminal"]
             [`(Emit ,_ ,_ ,_) "advance-emit"] [`(Forced ,_ ,_) "advance-forced"]
             [`(More ,_) "advance-delay"]))]
    [(machine:Call (or 'merge/d 'resume/d 'continue/d 'return/d 'outcome/d 'failure/d 'success/d) _) '()]
    [_ (raise-argument-error 'machine-step-span "evaluation or single-advance Call" configuration)]))

(define (return-rank k)
  (match k
    [(KDone) 1]
    [(or (KProgram _ rest) (KEmit _ _ rest) (KAdvanceEmit _ _ rest)
         (KAdvanceHistory _ rest) (KAdvanceForced _ rest)) (add1 (return-rank rest))]
    [(or (KConj _ _ _ _ _) (KMerge _ _ _ _ _ _) (KBind _ _ _ _ _) (KCommit _ _)) 1]
    [_ (raise-argument-error 'return-rank "source continuation" k)]))

(define (resumption-rank resume)
  (match resume
    [(REval _ _ _) 1]
    [(RContinue _ _ _) 2]
    [(RScope _ rest) (add1 (resumption-rank rest))]
    [(RBind _ rest _) (add1 (resumption-rank rest))]
    [(RMerge _ side left right)
     (+ 2 (resumption-rank (match side ['left left] ['right right])))]))

(define (administrative-rank configuration)
  (match configuration
    [(machine:Halted _) 0]
    [(machine:Call 'return/d (list _ k)) (return-rank k)]
    [(machine:Call 'outcome/d (list _ (FEmpty _ k) _)) (+ 2 (return-rank k))]
    [(machine:Call 'failure/d (list (FEmpty _ k))) (add1 (return-rank k))]
    [(machine:Call 'success/d (list (SOne _ k) _)) (add1 (return-rank k))]
    [(machine:Call 'continue/d _) 1]
    [(machine:Call 'resume/d (list resume _ _ _)) (resumption-rank resume)]
    [(machine:Call 'merge/d (list _ side left right _ _ _))
     (add1 (resumption-rank (match side ['left left] ['right right])))]
    [(machine:Call (or 'eval/d 'merge-active/d 'bind/d 'commit/d 'advance/d) _) 0]
    [_ (raise-argument-error 'administrative-rank "source-corresponding machine configuration" configuration)]))
