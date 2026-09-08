#lang racket

(require (only-in "../../../shared/kernel.rkt"
                  owners-support owners-append fresh-names substitute-goal)
         "../../../shared/kernel-equations.rkt"
         "../../../retained-scope/relations.rkt")
(provide (all-defined-out))

;; A demand variation of the retained-scope direct interpreter. Both arguments
;; of merge are computations, and Yield's residual is a computation. These
;; procedures are NOT object-language Delays. Only the Delay constructor marks
;; a scheduler/public suspension. The strict interpreter is unchanged.
;;
;; DFS and Flip share the smaller Search/resumption language. Rail adds
;; YieldR and a right-active merge resumption; stable slots replace swapping.
(define policies '(dfs flip rail))
(define (check-policy policy)
  (unless (member policy policies) (raise-argument-error 'policy "dfs, flip, or rail" policy)))

(define (failure-outcome) (lambda (failure _success) (failure)))
(define (success-outcome state) (lambda (_failure success) (success state)))
(define-kernel atomic failure-outcome success-outcome)

;; Optional test observation of actual closures, following the existing direct
;; derivation. Execution never reads a description table. Derived data machines
;; do not use this observer.
(define current-closure-observer
  (make-parameter (lambda (_family _procedure _captures) (void))))
(define (observe-closure family procedure captures)
  ((current-closure-observer) family procedure captures)
  procedure)

(define (prefix owners search)
  (match search
    [`(Empty ,local) `(Empty ,(owners-append owners local))]
    [`(One ,local ,state) `(One ,(owners-append owners local) ,state)]
    [`(Yield ,local ,answer ,rest)
     `(Yield ,(owners-append owners local) ,answer ,rest)]
    [`(YieldR ,local ,rest ,answer)
     `(YieldR ,(owners-append owners local) ,rest ,answer)]
    [`(Delay ,local ,resume) `(Delay ,(owners-append owners local) ,resume)]))

(define (eval-computation policy goal state)
  (observe-closure
   'eval (lambda (owners inherited) (eval/s policy goal state owners inherited))
   (list policy goal state)))
(define (scope-computation local resume)
  (observe-closure
   'scope
   (lambda (owners inherited) (resume (owners-append owners local) inherited))
   (list local resume)))
(define (merge-computation policy side left right)
  (observe-closure
   'merge
   (lambda (owners inherited) (merge/s policy side left right owners inherited))
   (list policy side left right)))
(define (bind-computation policy resume continue)
  (observe-closure
   'bind
   (lambda (owners inherited)
     (bind/s policy (resume '(Owners) (owners-support owners inherited))
             continue owners inherited))
   (list policy resume continue)))
(define (continue-computation continue state local)
  (observe-closure
   'continue
   (lambda (owners inherited)
     (continue state (owners-append owners local) inherited))
   (list continue state local)))

(define (eval/s policy goal state owners inherited)
  (define relations (goal-relations goal))
  (match (goal-body goal)
    [`(∃ ,binders ,body ,tag)
     (define intro (fresh-names (owners-support owners inherited) (length binders)))
     (eval/s policy (retain-goal relations (substitute-goal body (map list binders intro)))
             state (owners-append owners `(Owners (Owner ,intro ,tag))) inherited)]
    [`(,left ∧ ,right ,_)
     (bind/s policy
             (eval/s policy (retain-goal relations left) state '(Owners)
                     (owners-support owners inherited))
             (observe-closure
              'goal
              (lambda (state* owners* inherited*)
                (eval/s policy (retain-goal relations right) state* owners* inherited*))
              (list policy (retain-goal relations right)))
             owners inherited)]
    [`(,left ∨ ,right ,_)
     (merge/s policy 'left
              (eval-computation policy (retain-goal relations left) state)
              (eval-computation policy (retain-goal relations right) state)
              owners inherited)]
    [`(suspend ,body ,_)
     `(Delay ,owners ,(eval-computation policy (retain-goal relations body) state))]
    [(? relation-call? call)
     (eval/s policy (retain-goal relations (expand-call relations call)) state owners inherited)]
    [atom ((atomic atom state)
           (lambda () `(Empty ,owners))
           (lambda (next) `(One ,owners ,next)))]))

;; The order of these calls, not the order of host procedure arguments, selects
;; the demanded operand. A right-active operation exists only in the extension.
(define (merge/s policy side left right owners inherited)
  (match side
    ['left
     (merge-active/s policy side
                     (left '(Owners) (owners-support owners inherited))
                     right owners inherited)]
    ['right
     (unless (eq? policy 'rail) (error 'merge/s "right-active merge requires rail"))
     (merge-active/s policy side
                     (right '(Owners) (owners-support owners inherited))
                     left owners inherited)]))

(define (merge-active/s policy side active passive owners inherited)
  (match active
    [`(Empty ,_) (passive owners inherited)]
    [`(One ,local ,state)
     (match side
       ['left `(Yield ,owners (Answer ,local ,state) ,passive)]
       ['right `(YieldR ,owners ,passive (Answer ,local ,state))])]
    [(or `(Yield ,local (Answer ,private ,state) ,tail)
         `(YieldR ,local ,tail (Answer ,private ,state)))
     (define residual (scope-computation local tail))
     (define answer `(Answer ,(owners-append local private) ,state))
     (match side
       ['left `(Yield ,owners ,answer
                      ,(merge-computation policy 'left residual passive))]
       ['right `(YieldR ,owners ,(merge-computation policy 'right passive residual)
                        ,answer)])]
    [`(Delay ,local ,resume)
     (define residual (scope-computation local resume))
     `(Delay ,owners
             ,(match policy
                ['dfs (merge-computation policy 'left residual passive)]
                ['flip (merge-computation policy 'left passive residual)]
                ['rail
                 (match side
                   ['left (merge-computation policy 'right residual passive)]
                   ['right (merge-computation policy 'left passive residual)])]))]))

(define (bind/s policy search continue owners inherited)
  (match search
    [`(Empty ,local) `(Empty ,(owners-append owners local))]
    [`(One ,local ,state) (continue state (owners-append owners local) inherited)]
    [(or `(Yield ,local (Answer ,private ,state) ,tail)
         `(YieldR ,local ,tail (Answer ,private ,state)))
     (define common (owners-append owners local))
     (define head (continue-computation continue state private))
     (define rest (bind-computation policy tail continue))
     (match search
       [`(Yield ,_ ,_ ,_) (merge/s policy 'left head rest common inherited)]
       [`(YieldR ,_ ,_ ,_) (merge/s policy 'right rest head common inherited)])]
    [`(Delay ,local ,resume)
     `(Delay ,(owners-append owners local) ,(bind-computation policy resume continue))]))

;; As in the strict account, commitment consumes only settled Search heads.
;; Its newly computational tail is demanded UNDER the emitted prefix. It is
;; not forced as a Delay, and introduces no Forced node or scheduler turn.
(define (commit/s search inherited)
  (match search
    [`(Empty ,owners) `(Done ,owners)]
    [`(One ,owners ,state) `(Last (Owners) (Answer ,owners ,state))]
    [(or `(Yield ,owners ,answer ,rest) `(YieldR ,owners ,rest ,answer))
     (define here (owners-support owners inherited))
     `(Emit ,owners ,answer ,(commit/s (rest '(Owners) here) here))]
    [`(Delay ,_ ,_) `(More ,search)]))

(define (advance/s frontier inherited)
  (match frontier
    [(or `(Done ,_) `(Last ,_ ,_)) frontier]
    [`(Emit ,owners ,answer ,rest)
     `(Emit ,owners ,answer ,(advance/s rest (owners-support owners inherited)))]
    [`(Forced ,owners ,rest)
     `(Forced ,owners ,(advance/s rest (owners-support owners inherited)))]
    [`(More (Delay ,owners ,resume))
     (define here (owners-support owners inherited))
     `(Forced ,owners ,(commit/s (resume '(Owners) here) here))]))

(define (complete? frontier)
  (match frontier
    [(or `(Done ,_) `(Last ,_ ,_)) #t]
    [(or `(Emit ,_ ,_ ,rest) `(Forced ,_ ,rest)) (complete? rest)]
    [`(More ,_) #f]))
(define (collect/s frontier)
  (if (complete? frontier) frontier (collect/s (advance/s frontier '()))))

(define (run goal #:policy [policy 'flip] #:owners [owners '(Owners)]
             #:state [state '(state () () () (label "initial"))] #:relations [relations #f])
  (check-policy policy)
  (define result (commit/s (eval/s policy (retain-goal relations goal) state owners '()) '()))
  (if relations `(program ,relations ,result) result))
(define (resume-once frontier)
  (match frontier
    [`(program ,relations ,body) `(program ,relations ,(advance/s body '()))]
    [_ (advance/s frontier '())]))
(define (collect-all frontier)
  (match frontier
    [`(program ,relations ,body) `(program ,relations ,(collect/s body))]
    [_ (collect/s frontier)]))
