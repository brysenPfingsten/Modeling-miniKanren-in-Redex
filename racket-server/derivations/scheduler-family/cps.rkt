#lang racket

(require (only-in "../strict-search/shared/kernel.rkt"
                  owners-support owners-append fresh-names substitute-goal)
         (only-in "interpreter.rkt" atomic check-policy complete? observe-closure)
         "../strict-search/retained-scope/relations.rkt")
(provide (all-defined-out))

;; CPS changes the calling convention of EVERY computation, including Yield
;; tails and actual Delay resumptions. Creating a computation still does no
;; goal work. The continuation argument is supplied only when it is demanded.
(define (eval-computation/k policy goal state)
  (observe-closure
   'eval (lambda (owners inherited k) (eval/k policy goal state owners inherited k))
   (list policy goal state)))
(define (scope-computation/k local resume)
  (observe-closure
   'scope
   (lambda (owners inherited k) (resume (owners-append owners local) inherited k))
   (list local resume)))
(define (merge-computation/k policy side left right)
  (observe-closure
   'merge
   (lambda (owners inherited k) (merge/k policy side left right owners inherited k))
   (list policy side left right)))
(define (bind-computation/k policy resume continue)
  (observe-closure
   'bind
   (lambda (owners inherited k)
     (resume '(Owners) (owners-support owners inherited)
             (lambda (search) ; KBind
               (bind/k policy search continue owners inherited k))))
   (list policy resume continue)))
(define (continue-computation/k continue state local)
  (observe-closure
   'continue
   (lambda (owners inherited k)
     (continue state (owners-append owners local) inherited k))
   (list continue state local)))

(define (eval/k policy goal state owners inherited k)
  (define relations (goal-relations goal))
  (match (goal-body goal)
    [`(∃ ,binders ,body ,tag)
     (define intro (fresh-names (owners-support owners inherited) (length binders)))
     (eval/k policy (retain-goal relations (substitute-goal body (map list binders intro)))
             state (owners-append owners `(Owners (Owner ,intro ,tag))) inherited k)]
    [`(,left ∧ ,right ,_)
     (eval/k policy (retain-goal relations left) state '(Owners)
             (owners-support owners inherited)
             (lambda (search) ; KConj
               (bind/k policy search
                       (observe-closure
                        'goal
                        (lambda (state* owners* inherited* k*)
                          (eval/k policy (retain-goal relations right)
                                  state* owners* inherited* k*))
                        (list policy (retain-goal relations right)))
                       owners inherited k)))]
    [`(,left ∨ ,right ,_)
     (merge/k policy 'left
              (eval-computation/k policy (retain-goal relations left) state)
              (eval-computation/k policy (retain-goal relations right) state)
              owners inherited k)]
    [`(suspend ,body ,_)
     (k `(Delay ,owners ,(eval-computation/k policy (retain-goal relations body) state)))]
    [(? relation-call? call)
     (eval/k policy (retain-goal relations (expand-call relations call)) state owners inherited k)]
    [atom
     (define outcome (atomic atom state))
     (outcome (lambda () (k `(Empty ,owners))) ; FEmpty
              (lambda (next) (k `(One ,owners ,next))))])) ; SOne

(define (merge/k policy side left right owners inherited k)
  (match side
    ['left
     (left '(Owners) (owners-support owners inherited)
           (lambda (active) ; KMerge
             (merge-active/k policy side active right owners inherited k)))]
    ['right
     (unless (eq? policy 'rail) (error 'merge/k "right-active merge requires rail"))
     (right '(Owners) (owners-support owners inherited)
            (lambda (active) ; KMerge
              (merge-active/k policy side active left owners inherited k)))]))

(define (merge-active/k policy side active passive owners inherited k)
  (match active
    [`(Empty ,_) (passive owners inherited k)]
    [`(One ,local ,state)
     (match side
       ['left (k `(Yield ,owners (Answer ,local ,state) ,passive))]
       ['right (k `(YieldR ,owners ,passive (Answer ,local ,state)))])]
    [(or `(Yield ,local (Answer ,private ,state) ,tail)
         `(YieldR ,local ,tail (Answer ,private ,state)))
     (define residual (scope-computation/k local tail))
     (define answer `(Answer ,(owners-append local private) ,state))
     (match side
       ['left (k `(Yield ,owners ,answer
                        ,(merge-computation/k policy 'left residual passive)))]
       ['right (k `(YieldR ,owners ,(merge-computation/k policy 'right passive residual)
                          ,answer))])]
    [`(Delay ,local ,resume)
     (define residual (scope-computation/k local resume))
     (k `(Delay ,owners
                ,(match policy
                   ['dfs (merge-computation/k policy 'left residual passive)]
                   ['flip (merge-computation/k policy 'left passive residual)]
                   ['rail
                    (match side
                      ['left (merge-computation/k policy 'right residual passive)]
                      ['right (merge-computation/k policy 'left passive residual)])])))]))

(define (bind/k policy search continue owners inherited k)
  (match search
    [`(Empty ,local) (k `(Empty ,(owners-append owners local)))]
    [`(One ,local ,state) (continue state (owners-append owners local) inherited k)]
    [(or `(Yield ,local (Answer ,private ,state) ,tail)
         `(YieldR ,local ,tail (Answer ,private ,state)))
     (define common (owners-append owners local))
     (define head (continue-computation/k continue state private))
     (define rest (bind-computation/k policy tail continue))
     (match search
       [`(Yield ,_ ,_ ,_) (merge/k policy 'left head rest common inherited k)]
       [`(YieldR ,_ ,_ ,_) (merge/k policy 'right rest head common inherited k)])]
    [`(Delay ,local ,resume)
     (k `(Delay ,(owners-append owners local) ,(bind-computation/k policy resume continue)))]))

(define (commit/k search inherited k)
  (match search
    [`(Empty ,owners) (k `(Done ,owners))]
    [`(One ,owners ,state) (k `(Last (Owners) (Answer ,owners ,state)))]
    [(or `(Yield ,owners ,answer ,rest) `(YieldR ,owners ,rest ,answer))
     (define here (owners-support owners inherited))
     (rest '(Owners) here
           (lambda (search*) ; KCommit
             (commit/k search* here
                       (lambda (tail) ; KEmit
                         (k `(Emit ,owners ,answer ,tail))))))]
    [`(Delay ,_ ,_) (k `(More ,search))]))

(define (advance/k frontier inherited k)
  (match frontier
    [(or `(Done ,_) `(Last ,_ ,_)) (k frontier)]
    [`(Emit ,owners ,answer ,rest)
     (advance/k rest (owners-support owners inherited)
                (lambda (tail) ; KAdvanceEmit
                  (k `(Emit ,owners ,answer ,tail))))]
    [`(Forced ,owners ,rest)
     (advance/k rest (owners-support owners inherited)
                (lambda (tail) ; KAdvanceHistory
                  (k `(Forced ,owners ,tail))))]
    [`(More (Delay ,owners ,resume))
     (define here (owners-support owners inherited))
     (resume '(Owners) here
             (lambda (search) ; KCommit
               (commit/k search here
                         (lambda (tail) ; KAdvanceForced
                           (k `(Forced ,owners ,tail))))))]))

(define (collect/k frontier k)
  (if (complete? frontier)
      (k frontier)
      (advance/k frontier '()
                 (lambda (next) ; KCollect
                   (collect/k next k)))))

(define (run goal #:policy [policy 'flip] #:owners [owners '(Owners)]
             #:state [state '(state () () () (label "initial"))] #:relations [relations #f])
  (check-policy policy)
  (define done
    (if relations
        (lambda (frontier) `(program ,relations ,frontier)) ; KProgram
        (lambda (frontier) frontier))) ; KDone
  (eval/k policy (retain-goal relations goal) state owners '()
          (lambda (search) (commit/k search '() done)))) ; KCommit
(define (resume-once frontier)
  (match frontier
    [`(program ,relations ,body)
     (advance/k body '() (lambda (next) `(program ,relations ,next)))]
    [_ (advance/k frontier '() (lambda (next) next))]))
(define (collect-all frontier)
  (match frontier
    [`(program ,relations ,body)
     (collect/k body (lambda (next) `(program ,relations ,next)))]
    [_ (collect/k frontier (lambda (next) next))]))
