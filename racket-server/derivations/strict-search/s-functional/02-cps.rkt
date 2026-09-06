#lang racket
(require (only-in "../shared/kernel.rkt"
                  owners-support owners-append fresh-names substitute-goal)
         (only-in "00-direct.rkt" atomic prefix))
(provide eval/k merge/k bind/k force/k commit/k advance/k collect/k run resume-once collect-all)

;; Every control call, including invoking a Delay resumption and selecting an
;; Outcome, returns through k. Labels identify all semantic closure families.
(define (eval/k goal state owners inherited k)
  (match goal
    [`(∃ ,binders ,body ,tag)
     (define here (owners-support owners inherited))
     (define intro (fresh-names here (length binders)))
     (define body* (substitute-goal body (map list binders intro)))
     (define owners* (owners-append owners `(Owners (Owner ,intro ,tag))))
     (eval/k body* state owners* inherited k)]
    [`(,left ∧ ,right ,_)
     (define here (owners-support owners inherited))
     (eval/k left state '(Owners) here
             (lambda (search) ; C1
               (bind/k search
                       (lambda (state* owners* inherited* k*) ; G0
                         (eval/k right state* owners* inherited* k*))
                       owners inherited k)))]
    [`(,left ∨ ,right ,_)
     (define here (owners-support owners inherited))
     (eval/k left state '(Owners) here
             (lambda (left*) ; C2
               (eval/k right state '(Owners) here
                       (lambda (right*) ; C3
                         (merge/k left* right* owners inherited k)))))]
    [`(suspend ,body ,_)
     (define here (owners-support owners inherited))
     (k `(Delay ,owners ,(lambda (k*) (eval/k body state '(Owners) here k*))))] ; R0
    [atom
     (define outcome (atomic atom state))
     (outcome (lambda () (k `(Empty ,owners))) ; F0
              (lambda (next) (k `(One ,owners ,next))))])) ; S0

(define (merge/k left right owners inherited k)
  (match left
    [`(Empty ,_) (k (prefix owners right))]
    [`(One ,local ,state) (k `(Yield ,owners (Answer ,local ,state) ,right))]
    [`(Yield ,local (Answer ,answer ,state) ,rest)
     (define answer* `(Answer ,(owners-append local answer) ,state))
     (define rest* (prefix local rest))
     (define here (owners-support owners inherited))
     (merge/k rest* right '(Owners) here
              (lambda (tail) (k `(Yield ,owners ,answer* ,tail))))] ; C4
    [`(Delay ,_ ,_)
     (define here (owners-support owners inherited))
     (k `(Delay ,owners
                ,(lambda (k*) ; R1
                   (force/k left
                            (lambda (forced) ; C7
                              (merge/k right forced '(Owners) here k*))))))]))

(define (bind/k search continue owners inherited k)
  (match search
    [`(Empty ,local) (k `(Empty ,(owners-append owners local)))]
    [`(One ,local ,state)
     (define common (owners-append owners local))
     (continue state common inherited k)]
    [`(Yield ,local (Answer ,answer ,state) ,rest)
     (define common (owners-append owners local))
     (define here (owners-support common inherited))
     (continue state answer here
               (lambda (head) ; C5
                 (bind/k rest continue '(Owners) here
                         (lambda (tail) ; C6
                           (merge/k head tail common inherited k)))))]
    [`(Delay ,local ,resume)
     (define common (owners-append owners local))
     (define here (owners-support common inherited))
     (k `(Delay ,common
                ,(lambda (k*) ; R2
                   (resume (lambda (forced) ; C8
                             (bind/k forced continue '(Owners) here k*))))))]))

(define (force/k search k)
  (match search
    [`(Delay ,owners ,resume)
     (resume (lambda (forced) (k (prefix owners forced))))])) ; C9

(define (commit/k search k)
  (match search
    [`(Empty ,owners) (k `(Done ,owners))]
    [`(One ,owners ,state) (k `(Last (Owners) (Answer ,owners ,state)))]
    [`(Yield ,owners ,answer ,rest)
     (commit/k rest (lambda (tail) (k `(Emit ,owners ,answer ,tail))))] ; P1
    [`(Delay ,_ ,_) (k `(More ,search))]))

(define (advance/k frontier k)
  (match frontier
    [`(Done ,_) (k frontier)]
    [`(Last (Owners) ,_) (k frontier)]
    [`(Emit ,owners ,answer ,rest)
     (advance/k rest (lambda (tail) (k `(Emit ,owners ,answer ,tail))))] ; A0
    [`(Forced ,owners ,rest)
     (advance/k rest (lambda (tail) (k `(Forced ,owners ,tail))))] ; A1
    [`(More (Delay ,owners ,resume))
     (define committed (lambda (next) (k `(Forced ,owners ,next)))) ; A2
     (resume (lambda (search) (commit/k search committed)))])) ; P0

(define (collect/k frontier k)
  (match frontier
    [`(Done ,_) (k frontier)]
    [`(Last (Owners) ,_) (k frontier)]
    [`(Emit ,owners ,answer ,rest)
     (collect/k rest (lambda (tail) (k `(Emit ,owners ,answer ,tail))))] ; L0
    [`(Forced ,owners ,rest)
     (collect/k rest (lambda (tail) (k `(Forced ,owners ,tail))))] ; L1
    [`(More (Delay ,owners ,resume))
     (define committed
       (lambda (next) ; L2
         (collect/k next (lambda (tail) (k `(Forced ,owners ,tail)))))) ; L3
     (resume (lambda (search) (commit/k search committed)))])) ; P0

(define (run goal #:owners [owners '(Owners)]
             #:state [state '(state () () () (label "initial"))])
  (define committed (lambda (value) value)) ; C0
  (eval/k goal state owners '() (lambda (search) (commit/k search committed)))) ; P0
(define (resume-once frontier)
  (advance/k frontier (lambda (value) value))) ; C0
(define (collect-all frontier)
  (collect/k frontier (lambda (value) value))) ; C0
