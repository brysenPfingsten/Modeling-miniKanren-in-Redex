#lang racket
(require (only-in "../shared/kernel.rkt"
                  owners-support owners-append fresh-names substitute-goal)
         (only-in "00-direct.rkt" atomic prefix))
(provide eval/a merge/a bind/a force/a commit/a advance/a collect/a run
         (rename-out [advance/a resume-once] [collect/a collect-all]))

;; Naming the results of 00-direct exposes strict sequencing. No new frontier
;; constructor, allocation policy, or delayed computation is introduced.
(define (eval/a goal state owners inherited)
  (match goal
    [`(∃ ,binders ,body ,tag)
     (define here (owners-support owners inherited))
     (define intro (fresh-names here (length binders)))
     (define body* (substitute-goal body (map list binders intro)))
     (define owners* (owners-append owners `(Owners (Owner ,intro ,tag))))
     (eval/a body* state owners* inherited)]
    [`(,left ∧ ,right ,_)
     (define here (owners-support owners inherited))
     (define search (eval/a left state '(Owners) here))
     (define continue
       (lambda (state* owners* inherited*) (eval/a right state* owners* inherited*)))
     (bind/a search continue owners inherited)]
    [`(,left ∨ ,right ,_)
     (define here (owners-support owners inherited))
     (define left* (eval/a left state '(Owners) here))
     (define right* (eval/a right state '(Owners) here))
     (merge/a left* right* owners inherited)]
    [`(suspend ,body ,_)
     (define here (owners-support owners inherited))
     `(Delay ,owners ,(lambda () (eval/a body state '(Owners) here)))]
    [atom
     (define outcome (atomic atom state))
     (outcome (lambda () `(Empty ,owners))
              (lambda (next) `(One ,owners ,next)))]))

(define (merge/a left right owners inherited)
  (match left
    [`(Empty ,_) (prefix owners right)]
    [`(One ,local ,state) `(Yield ,owners (Answer ,local ,state) ,right)]
    [`(Yield ,local (Answer ,answer ,state) ,rest)
     (define answer* (owners-append local answer))
     (define rest* (prefix local rest))
     (define here (owners-support owners inherited))
     (define tail (merge/a rest* right '(Owners) here))
     `(Yield ,owners (Answer ,answer* ,state) ,tail)]
    [`(Delay ,_ ,_)
     (define here (owners-support owners inherited))
     `(Delay ,owners
             ,(lambda ()
                (define forced (force/a left))
                (merge/a right forced '(Owners) here)))]))

(define (bind/a search continue owners inherited)
  (match search
    [`(Empty ,local) `(Empty ,(owners-append owners local))]
    [`(One ,local ,state)
     (define common (owners-append owners local))
     (continue state common inherited)]
    [`(Yield ,local (Answer ,answer ,state) ,rest)
     (define common (owners-append owners local))
     (define here (owners-support common inherited))
     (define head (continue state answer here))
     (define tail (bind/a rest continue '(Owners) here))
     (merge/a head tail common inherited)]
    [`(Delay ,local ,resume)
     (define common (owners-append owners local))
     (define here (owners-support common inherited))
     `(Delay ,common
             ,(lambda ()
                (define forced (resume))
                (bind/a forced continue '(Owners) here)))]))

(define (force/a search)
  (match search
    [`(Delay ,owners ,resume)
     (define forced (resume))
     (prefix owners forced)]))

(define (commit/a search)
  (match search
    [`(Empty ,owners) `(Done ,owners)]
    [`(One ,owners ,state) `(Last (Owners) (Answer ,owners ,state))]
    [`(Yield ,owners ,answer ,rest)
     (define tail (commit/a rest))
     `(Emit ,owners ,answer ,tail)]
    [`(Delay ,_ ,_) `(More ,search)]))

(define (advance/a frontier)
  (match frontier
    [`(Done ,_) frontier]
    [`(Last (Owners) ,_) frontier]
    [`(Emit ,owners ,answer ,rest)
     (define tail (advance/a rest))
     `(Emit ,owners ,answer ,tail)]
    [`(Forced ,owners ,rest)
     (define tail (advance/a rest))
     `(Forced ,owners ,tail)]
    [`(More (Delay ,owners ,resume))
     (define forced (resume))
     (define committed (commit/a forced))
     `(Forced ,owners ,committed)]))

(define (collect/a frontier)
  (match frontier
    [`(Done ,_) frontier]
    [`(Last (Owners) ,_) frontier]
    [`(Emit ,owners ,answer ,rest)
     (define tail (collect/a rest))
     `(Emit ,owners ,answer ,tail)]
    [`(Forced ,owners ,rest)
     (define tail (collect/a rest))
     `(Forced ,owners ,tail)]
    [`(More (Delay ,owners ,resume))
     (define forced (resume))
     (define committed (commit/a forced))
     (define tail (collect/a committed))
     `(Forced ,owners ,tail)]))

(define (run goal #:owners [owners '(Owners)]
             #:state [state '(state () () () (label "initial"))])
  (define search (eval/a goal state owners '()))
  (commit/a search))
