#lang racket
;; Generated from defunc.rkt by derive.rkt. Regenerate; do not edit.
(require (only-in
          "../strict-search/shared/kernel.rkt"
          owners-support
          owners-append
          fresh-names
          substitute-goal)
         "../strict-search/retained-scope/relations.rkt"
         "../strict-search/shared/runtime.rkt"
         "data.rkt")

(provide (all-defined-out))

(define signatures
  '((eval/d policy goal state owners inherited k)
    (merge/d policy side left right owners inherited k)
    (merge-active/d policy side active passive owners inherited k)
    (bind/d policy search continue owners inherited k)
    (continue/d continue state owners inherited k)
    (resume/d resume owners inherited k)
    (commit/d search inherited k)
    (advance/d frontier inherited k)
    (collect/d frontier k)
    (outcome/d outcome failure success)
    (failure/d failure)
    (success/d success state)
    (return/d value k)))

(struct Call (pc operands) #:transparent)

(struct Halted (value) #:transparent)

(define (initial
         goal
         #:policy
         (policy 'flip)
         #:owners
         (owners '(Owners))
         #:state
         (state '(state () () () (label "initial")))
         #:relations
         (relations #f))
  (check-policy policy)
  (Call
   'eval/d
   (list
    policy
    (retain-goal relations goal)
    state
    owners
    '()
    (KCommit '() (if relations (KProgram relations (KDone)) (KDone))))))

(define (initial-advance frontier)
  (match
   frontier
   (`(program ,relations ,body) (Call 'advance/d (list body '() (KProgram relations (KDone)))))
   (_ (Call 'advance/d (list frontier '() (KDone))))))

(define (initial-collect frontier)
  (match
   frontier
   (`(program ,relations ,body) (Call 'collect/d (list body (KProgram relations (KDone)))))
   (_ (Call 'collect/d (list frontier (KDone))))))

(define (drive/steps current fuel)
  (match
   current
   ((Halted value) value)
   (_
    (when (zero? fuel) (exhausted 'scheduler-family-machine current))
    (drive/steps (step current) (sub1 fuel)))))

(define (drive current #:fuel (fuel 100000)) (check-fuel fuel) (drive/steps current fuel))

(define (run
         goal
         #:policy
         (policy 'flip)
         #:owners
         (owners '(Owners))
         #:state
         (state '(state () () () (label "initial")))
         #:relations
         (relations #f)
         #:fuel
         (fuel 100000))
  (drive
   (initial goal #:policy policy #:owners owners #:state state #:relations relations)
   #:fuel
   fuel))

(define (resume-once frontier #:fuel (fuel 100000))
  (drive (initial-advance frontier) #:fuel fuel))

(define (collect-all frontier #:fuel (fuel 100000))
  (drive (initial-collect frontier) #:fuel fuel))

(define (step current)
  (match
   current
   ((Call 'eval/d (list policy goal state owners inherited k))
    (begin
      (define relations (goal-relations goal))
      (match
       (goal-body goal)
       (`(∃ ,binders ,body ,tag)
        (define intro (fresh-names (owners-support owners inherited) (length binders)))
        (Call
         'eval/d
         (list
          policy
          (retain-goal relations (substitute-goal body (map list binders intro)))
          state
          (owners-append owners `(Owners (Owner ,intro ,tag)))
          inherited
          k)))
       (`(,left ∧ ,right ,_)
        (Call
         'eval/d
         (list
          policy
          (retain-goal relations left)
          state
          '(Owners)
          (owners-support owners inherited)
          (KConj policy (retain-goal relations right) owners inherited k))))
       (`(,left ∨ ,right ,_)
        (Call
         'merge/d
         (list
          policy
          'left
          (REval policy (retain-goal relations left) state)
          (REval policy (retain-goal relations right) state)
          owners
          inherited
          k)))
       (`(suspend ,body ,_)
        (Call
         'return/d
         (list `(Delay ,owners ,(REval policy (retain-goal relations body) state)) k)))
       ((? relation-call? call)
        (Call
         'eval/d
         (list
          policy
          (retain-goal relations (expand-call relations call))
          state
          owners
          inherited
          k)))
       (atom
        (define outcome (atomic/data atom state))
        (Call 'outcome/d (list outcome (FEmpty owners k) (SOne owners k)))))))
   ((Call 'merge/d (list policy side left right owners inherited k))
    (begin
      (match
       side
       ('left
        (Call
         'resume/d
         (list
          left
          '(Owners)
          (owners-support owners inherited)
          (KMerge policy side right owners inherited k))))
       ('right
        (unless (eq? policy 'rail) (error 'merge/d "right-active merge requires rail"))
        (Call
         'resume/d
         (list
          right
          '(Owners)
          (owners-support owners inherited)
          (KMerge policy side left owners inherited k)))))))
   ((Call 'merge-active/d (list policy side active passive owners inherited k))
    (begin
      (match
       active
       (`(Empty ,_) (Call 'resume/d (list passive owners inherited k)))
       (`(One ,local ,state)
        (match
         side
         ('left (Call 'return/d (list `(Yield ,owners (Answer ,local ,state) ,passive) k)))
         ('right (Call 'return/d (list `(YieldR ,owners ,passive (Answer ,local ,state)) k)))))
       ((or `(Yield ,local (Answer ,private ,state) ,tail)
            `(YieldR ,local ,tail (Answer ,private ,state)))
        (define residual (RScope local tail))
        (define answer `(Answer ,(owners-append local private) ,state))
        (match
         side
         ('left
          (Call
           'return/d
           (list `(Yield ,owners ,answer ,(RMerge policy 'left residual passive)) k)))
         ('right
          (Call
           'return/d
           (list `(YieldR ,owners ,(RMerge policy 'right passive residual) ,answer) k)))))
       (`(Delay ,local ,resume)
        (define residual (RScope local resume))
        (Call
         'return/d
         (list
          `(Delay
            ,owners
            ,(match
              policy
              ('dfs (RMerge policy 'left residual passive))
              ('flip (RMerge policy 'left passive residual))
              ('rail
               (match
                side
                ('left (RMerge policy 'right residual passive))
                ('right (RMerge policy 'left passive residual))))))
          k))))))
   ((Call 'bind/d (list policy search continue owners inherited k))
    (begin
      (match
       search
       (`(Empty ,local) (Call 'return/d (list `(Empty ,(owners-append owners local)) k)))
       (`(One ,local ,state)
        (Call 'continue/d (list continue state (owners-append owners local) inherited k)))
       ((or `(Yield ,local (Answer ,private ,state) ,tail)
            `(YieldR ,local ,tail (Answer ,private ,state)))
        (define common (owners-append owners local))
        (define head (RContinue continue state private))
        (define rest (RBind policy tail continue))
        (match
         search
         (`(Yield ,_ ,_ ,_) (Call 'merge/d (list policy 'left head rest common inherited k)))
         (`(YieldR ,_ ,_ ,_)
          (Call 'merge/d (list policy 'right rest head common inherited k)))))
       (`(Delay ,local ,resume)
        (Call
         'return/d
         (list `(Delay ,(owners-append owners local) ,(RBind policy resume continue)) k))))))
   ((Call 'continue/d (list continue state owners inherited k))
    (begin
      (match
       continue
       ((GRight policy goal) (Call 'eval/d (list policy goal state owners inherited k))))))
   ((Call 'resume/d (list resume owners inherited k))
    (begin
      (match
       resume
       ((REval policy goal state) (Call 'eval/d (list policy goal state owners inherited k)))
       ((RScope local rest)
        (Call 'resume/d (list rest (owners-append owners local) inherited k)))
       ((RMerge policy side left right)
        (Call 'merge/d (list policy side left right owners inherited k)))
       ((RBind policy rest continue)
        (Call
         'resume/d
         (list
          rest
          '(Owners)
          (owners-support owners inherited)
          (KBind policy continue owners inherited k))))
       ((RContinue continue state local)
        (Call 'continue/d (list continue state (owners-append owners local) inherited k))))))
   ((Call 'commit/d (list search inherited k))
    (begin
      (match
       search
       (`(Empty ,owners) (Call 'return/d (list `(Done ,owners) k)))
       (`(One ,owners ,state)
        (Call 'return/d (list `(Last (Owners) (Answer ,owners ,state)) k)))
       ((or `(Yield ,owners ,answer ,rest) `(YieldR ,owners ,rest ,answer))
        (define here (owners-support owners inherited))
        (Call 'resume/d (list rest '(Owners) here (KCommit here (KEmit owners answer k)))))
       (`(Delay ,_ ,_) (Call 'return/d (list `(More ,search) k))))))
   ((Call 'advance/d (list frontier inherited k))
    (begin
      (match
       frontier
       ((or `(Done ,_) `(Last ,_ ,_)) (Call 'return/d (list frontier k)))
       (`(Emit ,owners ,answer ,rest)
        (Call
         'advance/d
         (list rest (owners-support owners inherited) (KAdvanceEmit owners answer k))))
       (`(Forced ,owners ,rest)
        (Call
         'advance/d
         (list rest (owners-support owners inherited) (KAdvanceHistory owners k))))
       (`(More (Delay ,owners ,resume))
        (define here (owners-support owners inherited))
        (Call
         'resume/d
         (list resume '(Owners) here (KCommit here (KAdvanceForced owners k))))))))
   ((Call 'collect/d (list frontier k))
    (begin
      (if (complete? frontier)
        (Call 'return/d (list frontier k))
        (Call 'advance/d (list frontier '() (KCollect k))))))
   ((Call 'outcome/d (list outcome failure success))
    (begin
      (match
       outcome
       ((Failure) (Call 'failure/d (list failure)))
       ((Success state) (Call 'success/d (list success state))))))
   ((Call 'failure/d (list failure))
    (begin (match failure ((FEmpty owners k) (Call 'return/d (list `(Empty ,owners) k))))))
   ((Call 'success/d (list success state))
    (begin (match success ((SOne owners k) (Call 'return/d (list `(One ,owners ,state) k))))))
   ((Call 'return/d (list value k))
    (begin
      (match
       k
       ((KDone) (Halted value))
       ((KProgram relations rest) (Call 'return/d (list `(program ,relations ,value) rest)))
       ((KConj policy right owners inherited rest)
        (Call 'bind/d (list policy value (GRight policy right) owners inherited rest)))
       ((KMerge policy side passive owners inherited rest)
        (Call 'merge-active/d (list policy side value passive owners inherited rest)))
       ((KBind policy continue owners inherited rest)
        (Call 'bind/d (list policy value continue owners inherited rest)))
       ((KCommit inherited rest) (Call 'commit/d (list value inherited rest)))
       ((KEmit owners answer rest) (Call 'return/d (list `(Emit ,owners ,answer ,value) rest)))
       ((KAdvanceEmit owners answer rest)
        (Call 'return/d (list `(Emit ,owners ,answer ,value) rest)))
       ((KAdvanceHistory owners rest) (Call 'return/d (list `(Forced ,owners ,value) rest)))
       ((KAdvanceForced owners rest) (Call 'return/d (list `(Forced ,owners ,value) rest)))
       ((KCollect rest) (Call 'collect/d (list value rest))))))
   ((Halted _) #f)
   (_ (raise-argument-error 'step "derived scheduler-family configuration" current))))
