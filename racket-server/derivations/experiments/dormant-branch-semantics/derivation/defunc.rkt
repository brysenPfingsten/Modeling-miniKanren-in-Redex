#lang racket

(require (only-in "../../../shared/kernel.rkt"
                  owners-support owners-append fresh-names substitute-goal)
         "../../../s-reference/relations.rkt"
         "data.rkt")
(provide (all-defined-out))

;; Every /d call is a tail transfer. derive.rkt reifies these bodies directly;
;; this file neither calls the source reduction relation nor uses observers.
(define (eval/d policy goal state owners inherited k)
  (define relations (goal-relations goal))
  (match (goal-body goal)
    [`(∃ ,binders ,body ,tag)
     (define intro (fresh-names (owners-support owners inherited) (length binders)))
     (eval/d policy (retain-goal relations (substitute-goal body (map list binders intro)))
             state (owners-append owners `(Owners (Owner ,intro ,tag))) inherited k)]
    [`(,left ∧ ,right ,_)
     (eval/d policy (retain-goal relations left) state '(Owners)
             (owners-support owners inherited)
             (KConj policy (retain-goal relations right) owners inherited k))]
    [`(,left ∨ ,right ,_)
     (merge/d policy 'left
              (REval policy (retain-goal relations left) state)
              (REval policy (retain-goal relations right) state)
              owners inherited k)]
    [`(suspend ,body ,_)
     (return/d `(Delay ,owners ,(REval policy (retain-goal relations body) state)) k)]
    [(? relation-call? call)
     (eval/d policy (retain-goal relations (expand-call relations call)) state owners inherited k)]
    [atom
     (define outcome (atomic/data atom state))
     (outcome/d outcome (FEmpty owners k) (SOne owners k))]))

(define (merge/d policy side left right owners inherited k)
  (match side
    ['left
     (resume/d left '(Owners) (owners-support owners inherited)
               (KMerge policy side right owners inherited k))]
    ['right
     (unless (eq? policy 'rail) (error 'merge/d "right-active merge requires rail"))
     (resume/d right '(Owners) (owners-support owners inherited)
               (KMerge policy side left owners inherited k))]))

(define (merge-active/d policy side active passive owners inherited k)
  (match active
    [`(Empty ,_) (resume/d passive owners inherited k)]
    [`(One ,local ,state)
     (match side
       ['left (return/d `(Yield ,owners (Answer ,local ,state) ,passive) k)]
       ['right (return/d `(YieldR ,owners ,passive (Answer ,local ,state)) k)])]
    [(or `(Yield ,local (Answer ,private ,state) ,tail)
         `(YieldR ,local ,tail (Answer ,private ,state)))
     (define residual (RScope local tail))
     (define answer `(Answer ,(owners-append local private) ,state))
     (match side
       ['left (return/d `(Yield ,owners ,answer
                               ,(RMerge policy 'left residual passive)) k)]
       ['right (return/d `(YieldR ,owners ,(RMerge policy 'right passive residual)
                                 ,answer) k)])]
    [`(Delay ,local ,resume)
     (define residual (RScope local resume))
     (return/d
      `(Delay ,owners
              ,(match policy
                 ['dfs (RMerge policy 'left residual passive)]
                 ['flip (RMerge policy 'left passive residual)]
                 ['rail
                  (match side
                    ['left (RMerge policy 'right residual passive)]
                    ['right (RMerge policy 'left passive residual)])])) k)]))

(define (bind/d policy search continue owners inherited k)
  (match search
    [`(Empty ,local) (return/d `(Empty ,(owners-append owners local)) k)]
    [`(One ,local ,state)
     (continue/d continue state (owners-append owners local) inherited k)]
    [(or `(Yield ,local (Answer ,private ,state) ,tail)
         `(YieldR ,local ,tail (Answer ,private ,state)))
     (define common (owners-append owners local))
     (define head (RContinue continue state private))
     (define rest (RBind policy tail continue))
     (match search
       [`(Yield ,_ ,_ ,_) (merge/d policy 'left head rest common inherited k)]
       [`(YieldR ,_ ,_ ,_) (merge/d policy 'right rest head common inherited k)])]
    [`(Delay ,local ,resume)
     (return/d `(Delay ,(owners-append owners local) ,(RBind policy resume continue)) k)]))

(define (continue/d continue state owners inherited k)
  (match continue
    [(GRight policy goal) (eval/d policy goal state owners inherited k)]))

(define (resume/d resume owners inherited k)
  (match resume
    [(REval policy goal state) (eval/d policy goal state owners inherited k)]
    [(RScope local rest) (resume/d rest (owners-append owners local) inherited k)]
    [(RMerge policy side left right) (merge/d policy side left right owners inherited k)]
    [(RBind policy rest continue)
     (resume/d rest '(Owners) (owners-support owners inherited)
               (KBind policy continue owners inherited k))]
    [(RContinue continue state local)
     (continue/d continue state (owners-append owners local) inherited k)]))

(define (commit/d search inherited k)
  (match search
    [`(Empty ,owners) (return/d `(Done ,owners) k)]
    [`(One ,owners ,state) (return/d `(Last (Owners) (Answer ,owners ,state)) k)]
    [(or `(Yield ,owners ,answer ,rest) `(YieldR ,owners ,rest ,answer))
     (define here (owners-support owners inherited))
     (resume/d rest '(Owners) here (KCommit here (KEmit owners answer k)))]
    [`(Delay ,_ ,_) (return/d `(More ,search) k)]))

(define (advance/d frontier inherited k)
  (match frontier
    [(or `(Done ,_) `(Last ,_ ,_)) (return/d frontier k)]
    [`(Emit ,owners ,answer ,rest)
     (advance/d rest (owners-support owners inherited) (KAdvanceEmit owners answer k))]
    [`(Forced ,owners ,rest)
     (advance/d rest (owners-support owners inherited) (KAdvanceHistory owners k))]
    [`(More (Delay ,owners ,resume))
     (define here (owners-support owners inherited))
     (resume/d resume '(Owners) here (KCommit here (KAdvanceForced owners k)))]))

(define (collect/d frontier k)
  (if (complete? frontier)
      (return/d frontier k)
      (advance/d frontier '() (KCollect k))))

(define (outcome/d outcome failure success)
  (match outcome
    [(Failure) (failure/d failure)]
    [(Success state) (success/d success state)]))
(define (failure/d failure)
  (match failure [(FEmpty owners k) (return/d `(Empty ,owners) k)]))
(define (success/d success state)
  (match success [(SOne owners k) (return/d `(One ,owners ,state) k)]))

(define (return/d value k)
  (match k
    [(KDone) value]
    [(KProgram relations rest) (return/d `(program ,relations ,value) rest)]
    [(KConj policy right owners inherited rest)
     (bind/d policy value (GRight policy right) owners inherited rest)]
    [(KMerge policy side passive owners inherited rest)
     (merge-active/d policy side value passive owners inherited rest)]
    [(KBind policy continue owners inherited rest)
     (bind/d policy value continue owners inherited rest)]
    [(KCommit inherited rest) (commit/d value inherited rest)]
    [(KEmit owners answer rest) (return/d `(Emit ,owners ,answer ,value) rest)]
    [(KAdvanceEmit owners answer rest) (return/d `(Emit ,owners ,answer ,value) rest)]
    [(KAdvanceHistory owners rest) (return/d `(Forced ,owners ,value) rest)]
    [(KAdvanceForced owners rest) (return/d `(Forced ,owners ,value) rest)]
    [(KCollect rest) (collect/d value rest)]))

(define (run goal #:policy [policy 'flip] #:owners [owners '(Owners)]
             #:state [state '(state () () () (label "initial"))] #:relations [relations #f])
  (check-policy policy)
  (eval/d policy (retain-goal relations goal) state owners '()
          (KCommit '() (if relations (KProgram relations (KDone)) (KDone)))))
(define (resume-once frontier)
  (match frontier
    [`(program ,relations ,body) (advance/d body '() (KProgram relations (KDone)))]
    [_ (advance/d frontier '() (KDone))]))
(define (collect-all frontier)
  (match frontier
    [`(program ,relations ,body) (collect/d body (KProgram relations (KDone)))]
    [_ (collect/d frontier (KDone))]))
