#lang racket
;; Generated from 03-defunc.rkt by derive.rkt. Regenerate; do not edit.
(require (only-in
          "../shared/kernel.rkt"
          owners-support
          owners-append
          fresh-names
          substitute-goal)
         "03-data.rkt"
         "../shared/runtime.rkt")

(provide (all-defined-out))

(define signatures
  '((eval/d goal state owners inherited k)
    (merge/d left right owners inherited k)
    (bind/d search continue owners inherited k)
    (continue/d continue state owners inherited k)
    (resume/d resume k)
    (force/d search k)
    (commit/d search k)
    (advance/d frontier k)
    (collect/d frontier k)
    (outcome/d outcome failure success)
    (failure/d failure)
    (success/d success state)
    (return/d value k)))

(struct Call (pc operands) #:transparent)

(struct Halted (value) #:transparent)

(define (initial
         goal
         #:owners
         (owners '(Owners))
         #:state
         (state '(state () () () (label "initial"))))
  (Call 'eval/d (list goal state owners '() (KCommit (KDone)))))

(define (drive/steps current fuel)
  (match
   current
   ((Halted value) value)
   (_
    (when (zero? fuel) (exhausted 'machine current))
    (drive/steps (step current) (sub1 fuel)))))

(define (drive current #:fuel (fuel 100000)) (check-fuel fuel) (drive/steps current fuel))

(define (run
         goal
         #:owners
         (owners '(Owners))
         #:state
         (state '(state () () () (label "initial")))
         #:fuel
         (fuel 100000))
  (drive (initial goal #:owners owners #:state state) #:fuel fuel))

(define (resume-once frontier #:fuel (fuel 100000))
  (drive (Call 'advance/d (list frontier (KDone))) #:fuel fuel))

(define (collect-all frontier #:fuel (fuel 100000))
  (drive (Call 'collect/d (list frontier (KDone))) #:fuel fuel))

(define (step current)
  (match
   current
   ((Call 'eval/d (list goal state owners inherited k))
    (match
     goal
     (`(∃ ,binders ,body ,tag)
      (define here (owners-support owners inherited))
      (define intro (fresh-names here (length binders)))
      (define body* (substitute-goal body (map list binders intro)))
      (define owners* (owners-append owners `(Owners (Owner ,intro ,tag))))
      (Call 'eval/d (list body* state owners* inherited k)))
     (`(,left ∧ ,right ,_)
      (define here (owners-support owners inherited))
      (Call 'eval/d (list left state '(Owners) here (KConj right owners inherited k))))
     (`(,left ∨ ,right ,_)
      (define here (owners-support owners inherited))
      (Call
       'eval/d
       (list left state '(Owners) here (KDisjLeft right state owners inherited k))))
     (`(suspend ,body ,_)
      (define here (owners-support owners inherited))
      (Call 'return/d (list `(Delay ,owners ,(REval body state here)) k)))
     (atom
      (define outcome (atomic/data atom state))
      (Call 'outcome/d (list outcome (FEmpty owners k) (SOne owners k))))))
   ((Call 'merge/d (list left right owners inherited k))
    (match
     left
     (`(Empty ,_) (Call 'return/d (list (prefix owners right) k)))
     (`(One ,local ,state)
      (Call 'return/d (list `(Yield ,owners (Answer ,local ,state) ,right) k)))
     (`(Yield ,local (Answer ,answer ,state) ,rest)
      (define answer* `(Answer ,(owners-append local answer) ,state))
      (define rest* (prefix local rest))
      (define here (owners-support owners inherited))
      (Call 'merge/d (list rest* right '(Owners) here (KMergeYield owners answer* k))))
     (`(Delay ,_ ,_)
      (define here (owners-support owners inherited))
      (Call 'return/d (list `(Delay ,owners ,(RMerge right left here)) k)))))
   ((Call 'bind/d (list search continue owners inherited k))
    (match
     search
     (`(Empty ,local) (Call 'return/d (list `(Empty ,(owners-append owners local)) k)))
     (`(One ,local ,state)
      (define common (owners-append owners local))
      (Call 'continue/d (list continue state common inherited k)))
     (`(Yield ,local (Answer ,answer ,state) ,rest)
      (define common (owners-append owners local))
      (define here (owners-support common inherited))
      (Call
       'continue/d
       (list continue state answer here (KBindHead rest continue common inherited k))))
     (`(Delay ,local ,resume)
      (define common (owners-append owners local))
      (define here (owners-support common inherited))
      (Call 'return/d (list `(Delay ,common ,(RBind resume continue here)) k)))))
   ((Call 'continue/d (list continue state owners inherited k))
    (match continue ((GRight goal) (Call 'eval/d (list goal state owners inherited k)))))
   ((Call 'resume/d (list resume k))
    (match
     resume
     ((REval goal state here) (Call 'eval/d (list goal state '(Owners) here k)))
     ((RMerge right left here) (Call 'force/d (list left (KMergeForced right here k))))
     ((RBind rest continue here) (Call 'resume/d (list rest (KBindForced continue here k))))))
   ((Call 'force/d (list search k))
    (match search (`(Delay ,owners ,resume) (Call 'resume/d (list resume (KPrefix owners k))))))
   ((Call 'commit/d (list search k))
    (match
     search
     (`(Empty ,owners) (Call 'return/d (list `(Done ,owners) k)))
     (`(One ,owners ,state) (Call 'return/d (list `(Last (Owners) (Answer ,owners ,state)) k)))
     (`(Yield ,owners ,answer ,rest) (Call 'commit/d (list rest (KCommitEmit owners answer k))))
     (`(Delay ,_ ,_) (Call 'return/d (list `(More ,search) k)))))
   ((Call 'advance/d (list frontier k))
    (match
     frontier
     (`(Done ,_) (Call 'return/d (list frontier k)))
     (`(Last (Owners) ,_) (Call 'return/d (list frontier k)))
     (`(Emit ,owners ,answer ,rest)
      (Call 'advance/d (list rest (KAdvanceEmit owners answer k))))
     (`(Forced ,owners ,rest) (Call 'advance/d (list rest (KAdvanceHistory owners k))))
     (`(More (Delay ,owners ,resume))
      (Call 'resume/d (list resume (KCommit (KAdvanceForced owners k)))))))
   ((Call 'collect/d (list frontier k))
    (match
     frontier
     (`(Done ,_) (Call 'return/d (list frontier k)))
     (`(Last (Owners) ,_) (Call 'return/d (list frontier k)))
     (`(Emit ,owners ,answer ,rest)
      (Call 'collect/d (list rest (KCollectEmit owners answer k))))
     (`(Forced ,owners ,rest) (Call 'collect/d (list rest (KCollectHistory owners k))))
     (`(More (Delay ,owners ,resume))
      (Call 'resume/d (list resume (KCommit (KCollectResume owners k)))))))
   ((Call 'outcome/d (list outcome failure success))
    (match
     outcome
     ((Failure) (Call 'failure/d (list failure)))
     ((Success state) (Call 'success/d (list success state)))))
   ((Call 'failure/d (list failure))
    (match failure ((FEmpty owners k) (Call 'return/d (list `(Empty ,owners) k)))))
   ((Call 'success/d (list success state))
    (match success ((SOne owners k) (Call 'return/d (list `(One ,owners ,state) k)))))
   ((Call 'return/d (list value k))
    (match
     k
     ((KDone) (Halted value))
     ((KConj right owners inherited rest)
      (Call 'bind/d (list value (GRight right) owners inherited rest)))
     ((KDisjLeft right state owners inherited rest)
      (define here (owners-support owners inherited))
      (Call 'eval/d (list right state '(Owners) here (KDisjRight value owners inherited rest))))
     ((KDisjRight left owners inherited rest)
      (Call 'merge/d (list left value owners inherited rest)))
     ((KMergeYield owners answer rest)
      (Call 'return/d (list `(Yield ,owners ,answer ,value) rest)))
     ((KBindHead tail continue common inherited rest)
      (define here (owners-support common inherited))
      (Call
       'bind/d
       (list tail continue '(Owners) here (KBindTail value common inherited rest))))
     ((KBindTail head common inherited rest)
      (Call 'merge/d (list head value common inherited rest)))
     ((KMergeForced right here rest) (Call 'merge/d (list right value '(Owners) here rest)))
     ((KBindForced continue here rest) (Call 'bind/d (list value continue '(Owners) here rest)))
     ((KPrefix owners rest) (Call 'return/d (list (prefix owners value) rest)))
     ((KCommit rest) (Call 'commit/d (list value rest)))
     ((KCommitEmit owners answer rest)
      (Call 'return/d (list `(Emit ,owners ,answer ,value) rest)))
     ((KAdvanceEmit owners answer rest)
      (Call 'return/d (list `(Emit ,owners ,answer ,value) rest)))
     ((KAdvanceHistory owners rest) (Call 'return/d (list `(Forced ,owners ,value) rest)))
     ((KAdvanceForced owners rest) (Call 'return/d (list `(Forced ,owners ,value) rest)))
     ((KCollectEmit owners answer rest)
      (Call 'return/d (list `(Emit ,owners ,answer ,value) rest)))
     ((KCollectHistory owners rest) (Call 'return/d (list `(Forced ,owners ,value) rest)))
     ((KCollectResume owners rest) (Call 'collect/d (list value (KCollectForced owners rest))))
     ((KCollectForced owners rest) (Call 'return/d (list `(Forced ,owners ,value) rest)))))
   ((Halted _) #f)
   (_ (raise-argument-error 'step "derived machine configuration" current))))

