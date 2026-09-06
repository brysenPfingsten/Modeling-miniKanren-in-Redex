#lang racket
(require (only-in "../shared/kernel.rkt"
                  owners-support owners-append fresh-names substitute-goal)
         "03-data.rkt")
(provide (all-defined-out))

;; Suffix /d identifies the first-order tail functions reified by derive.rkt.
;; No semantic procedure is stored in an outcome, frontier, continuation, or
;; resumption. Primitive kernel production is native data, not an adapter.
(define (eval/d goal state owners inherited k)
  (match goal
    [`(∃ ,binders ,body ,tag)
     (define here (owners-support owners inherited))
     (define intro (fresh-names here (length binders)))
     (define body* (substitute-goal body (map list binders intro)))
     (define owners* (owners-append owners `(Owners (Owner ,intro ,tag))))
     (eval/d body* state owners* inherited k)]
    [`(,left ∧ ,right ,_)
     (define here (owners-support owners inherited))
     (eval/d left state '(Owners) here (KConj right owners inherited k))]
    [`(,left ∨ ,right ,_)
     (define here (owners-support owners inherited))
     (eval/d left state '(Owners) here (KDisjLeft right state owners inherited k))]
    [`(suspend ,body ,_)
     (define here (owners-support owners inherited))
     (return/d `(Delay ,owners ,(REval body state here)) k)]
    [atom
     (define outcome (atomic/data atom state))
     (outcome/d outcome (FEmpty owners k) (SOne owners k))]))

(define (merge/d left right owners inherited k)
  (match left
    [`(Empty ,_) (return/d (prefix owners right) k)]
    [`(One ,local ,state)
     (return/d `(Yield ,owners (Answer ,local ,state) ,right) k)]
    [`(Yield ,local (Answer ,answer ,state) ,rest)
     (define answer* `(Answer ,(owners-append local answer) ,state))
     (define rest* (prefix local rest))
     (define here (owners-support owners inherited))
     (merge/d rest* right '(Owners) here (KMergeYield owners answer* k))]
    [`(Delay ,_ ,_)
     (define here (owners-support owners inherited))
     (return/d `(Delay ,owners ,(RMerge right left here)) k)]))

(define (bind/d search continue owners inherited k)
  (match search
    [`(Empty ,local) (return/d `(Empty ,(owners-append owners local)) k)]
    [`(One ,local ,state)
     (define common (owners-append owners local))
     (continue/d continue state common inherited k)]
    [`(Yield ,local (Answer ,answer ,state) ,rest)
     (define common (owners-append owners local))
     (define here (owners-support common inherited))
     (continue/d continue state answer here (KBindHead rest continue common inherited k))]
    [`(Delay ,local ,resume)
     (define common (owners-append owners local))
     (define here (owners-support common inherited))
     (return/d `(Delay ,common ,(RBind resume continue here)) k)]))

(define (continue/d continue state owners inherited k)
  (match continue [(GRight goal) (eval/d goal state owners inherited k)]))
(define (resume/d resume k)
  (match resume
    [(REval goal state here) (eval/d goal state '(Owners) here k)]
    [(RMerge right left here) (force/d left (KMergeForced right here k))]
    [(RBind rest continue here) (resume/d rest (KBindForced continue here k))]))
(define (force/d search k)
  (match search [`(Delay ,owners ,resume) (resume/d resume (KPrefix owners k))]))

;; All pending goal obligations are already reflected in this mature Search.
;; commit/d never runs a goal, merge, bind, or resumption. A Delay remains
;; active search under More, and only the eager candidate chunk is settled.
(define (commit/d search k)
  (match search
    [`(Empty ,owners) (return/d `(Done ,owners) k)]
    [`(One ,owners ,state) (return/d `(Last (Owners) (Answer ,owners ,state)) k)]
    [`(Yield ,owners ,answer ,rest) (commit/d rest (KCommitEmit owners answer k))]
    [`(Delay ,_ ,_) (return/d `(More ,search) k)]))

(define (advance/d frontier k)
  (match frontier
    [`(Done ,_) (return/d frontier k)]
    [`(Last (Owners) ,_) (return/d frontier k)]
    [`(Emit ,owners ,answer ,rest) (advance/d rest (KAdvanceEmit owners answer k))]
    [`(Forced ,owners ,rest) (advance/d rest (KAdvanceHistory owners k))]
    [`(More (Delay ,owners ,resume))
     (resume/d resume (KCommit (KAdvanceForced owners k)))]))
(define (collect/d frontier k)
  (match frontier
    [`(Done ,_) (return/d frontier k)]
    [`(Last (Owners) ,_) (return/d frontier k)]
    [`(Emit ,owners ,answer ,rest) (collect/d rest (KCollectEmit owners answer k))]
    [`(Forced ,owners ,rest) (collect/d rest (KCollectHistory owners k))]
    [`(More (Delay ,owners ,resume))
     (resume/d resume (KCommit (KCollectResume owners k)))]))

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
    [(KConj right owners inherited rest)
     (bind/d value (GRight right) owners inherited rest)]
    [(KDisjLeft right state owners inherited rest)
     (define here (owners-support owners inherited))
     (eval/d right state '(Owners) here (KDisjRight value owners inherited rest))]
    [(KDisjRight left owners inherited rest) (merge/d left value owners inherited rest)]
    [(KMergeYield owners answer rest) (return/d `(Yield ,owners ,answer ,value) rest)]
    [(KBindHead tail continue common inherited rest)
     (define here (owners-support common inherited))
     (bind/d tail continue '(Owners) here (KBindTail value common inherited rest))]
    [(KBindTail head common inherited rest) (merge/d head value common inherited rest)]
    [(KMergeForced right here rest) (merge/d right value '(Owners) here rest)]
    [(KBindForced continue here rest) (bind/d value continue '(Owners) here rest)]
    [(KPrefix owners rest) (return/d (prefix owners value) rest)]
    [(KCommit rest) (commit/d value rest)]
    [(KCommitEmit owners answer rest) (return/d `(Emit ,owners ,answer ,value) rest)]
    [(KAdvanceEmit owners answer rest) (return/d `(Emit ,owners ,answer ,value) rest)]
    [(KAdvanceHistory owners rest) (return/d `(Forced ,owners ,value) rest)]
    [(KAdvanceForced owners rest) (return/d `(Forced ,owners ,value) rest)]
    [(KCollectEmit owners answer rest) (return/d `(Emit ,owners ,answer ,value) rest)]
    [(KCollectHistory owners rest) (return/d `(Forced ,owners ,value) rest)]
    [(KCollectResume owners rest) (collect/d value (KCollectForced owners rest))]
    [(KCollectForced owners rest) (return/d `(Forced ,owners ,value) rest)]))

(define (run goal #:owners [owners '(Owners)]
             #:state [state '(state () () () (label "initial"))])
  (eval/d goal state owners '() (KCommit (KDone))))
(define (resume-once frontier) (advance/d frontier (KDone)))
(define (collect-all frontier) (collect/d frontier (KDone)))
