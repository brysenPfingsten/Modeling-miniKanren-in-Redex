#lang racket

(require "private/shared.rkt"
         (prefix-in s: "s/source.rkt")
         (prefix-in e: "e/source.rkt")
         (prefix-in n: "n/source.rkt"))

(provide S-world-support/disjunction
         E-live-support/disjunction
         Q-SE/F/disjunction
         Q-EN/F/disjunction
         Q-SN/F/disjunction
         disjunction-row-observation
         Q-SE-step-square-sides/disjunction
         Q-SE-step-square/raw?/disjunction
         Q-EN-step-square-sides/disjunction
         Q-EN-step-square/raw?/disjunction
         Q-SN-step-square-sides/disjunction
         Q-SN-step-square/raw?/disjunction
         Q-SN-composition?/disjunction)

;; Direct structural maps for three independently stated source carriers.
;; Every branch is traversed with its own possible-world supply; neither map
;; collapses siblings into one global allocation registry.

(define (u-symbol? datum)
  (and (symbol? datum)
       (regexp-match? #rx"^u:" (symbol->string datum))))

(define (extend-with-owners owners [support '()])
  (match owners
    [`(Owners) support]
    [`(Owners (Owner ,intro ,_tag) ,rest ...)
     (extend-with-owners `(Owners ,@rest) (append support intro))]
    [_
     (error 'extend-with-owners
            "expected an Owners sequence, received ~e"
            owners)]))

;; This view deliberately follows only DisjL's active left child and Emit's
;; residual.  It is used as an observation, never as a whole-tree registry.
(define (S-work-support/disjunction work [support '()])
  (match work
    [`(Conj ,owners ,inner ,_goal)
     (S-work-support/disjunction
      inner
      (extend-with-owners owners support))]
    [`(DisjL ,owners ,left ,_right)
     (S-work-support/disjunction
      left
      (extend-with-owners owners support))]
    [`(Work ,owners ,_goal ,_state)
     (extend-with-owners owners support)]
    [`(Returned ,owners ,_state)
     (extend-with-owners owners support)]
    [`(Dead ,owners)
     (extend-with-owners owners support)]
    [_
     (error 'S-work-support/disjunction
            "expected Disjunction S work, received ~e"
            work)]))

(define (S-world-support/disjunction frontier [support '()])
  (match frontier
    [`(Emit ,owners ,_answer ,residual)
     (S-world-support/disjunction
      residual
      (extend-with-owners owners support))]
    [`(More ,work)
     (S-work-support/disjunction work support)]
    [`(Done ,owners)
     (extend-with-owners owners support)]
    [`(Last ,owners (Answer ,answer-owners ,_state))
     (extend-with-owners
      answer-owners
      (extend-with-owners owners support))]
    [_
     (error 'S-world-support/disjunction
            "expected a Disjunction S frontier, received ~e"
            frontier)]))

(define (validate-E-support who support)
  (unless (and (andmap u-symbol? support)
               (= (length support) (length (remove-duplicates support))))
    (error who "ill-formed E support: ~e" support))
  support)

(define (support-from-E-state state)
  (match state
    [`(state (Support ,support ...) ,_sub ,_dis ,_trail ,_tag)
     (validate-E-support 'support-from-E-state support)]
    [_
     (error 'support-from-E-state
            "expected an E state, received ~e"
            state)]))

(define (support-from-E-summary summary)
  (match summary
    [`(Support ,support ...)
     (validate-E-support 'support-from-E-summary support)]
    [_
     (error 'support-from-E-summary
            "expected an E Support summary, received ~e"
            summary)]))

(define (E-work-live-support/disjunction work)
  (match work
    [`(DisjL ,left ,_right)
     (E-work-live-support/disjunction left)]
    [`(Conj ,inner ,_goal)
     (E-work-live-support/disjunction inner)]
    [`(Work ,_goal ,state)
     (support-from-E-state state)]
    [`(Returned ,state)
     (support-from-E-state state)]
    [`(Dead ,support)
     (support-from-E-summary support)]
    [_
     (error 'E-work-live-support/disjunction
            "expected Disjunction E work, received ~e"
            work)]))

(define (E-live-support/disjunction frontier)
  (match frontier
    [`(Emit ,_answer ,residual)
     (E-live-support/disjunction residual)]
    [`(More ,work)
     (E-work-live-support/disjunction work)]
    [`(Last (Answer ,state))
     (support-from-E-state state)]
    [`(Done ,support)
     (support-from-E-summary support)]
    [_
     (error 'E-live-support/disjunction
            "expected a Disjunction E frontier, received ~e"
            frontier)]))

(define (address-atom atom support)
  (match (index-of support atom)
    [#f
     (error 'address-atom
            "runtime atom ~e is absent from world support ~e"
            atom
            support)]
    [index index]))

(define (address-term term support)
  (match term
    [(? u-symbol? u) (address-atom u support)]
    [`(,left : ,right)
     `(,(address-term left support) : ,(address-term right support))]
    [_ term]))

;; Both direct maps to N state the recursion through ∨ explicitly.
(define (address-goal/disjunction goal support)
  (match goal
    [`(succeed ,tag) `(succeed ,tag)]
    [`(fail ,tag) `(fail ,tag)]
    [`(,left =? ,right ,tag)
     `(,(address-term left support)
       =?
       ,(address-term right support)
       ,tag)]
    [`(,left != ,right ,tag)
     `(,(address-term left support)
       !=
       ,(address-term right support)
       ,tag)]
    [`(,left ∧ ,right ,tag)
     `(,(address-goal/disjunction left support)
       ∧
       ,(address-goal/disjunction right support)
       ,tag)]
    [`(,left ∨ ,right ,tag)
     `(,(address-goal/disjunction left support)
       ∨
       ,(address-goal/disjunction right support)
       ,tag)]
    [`(∃ ,binders ,body ,tag)
     `(∃ ,binders ,(address-goal/disjunction body support) ,tag)]
    [_
     (error 'address-goal/disjunction
            "expected a Disjunction goal, received ~e"
            goal)]))

(define (address-equation equation support)
  (match equation
    [`(,left =? ,right ,tag)
     `(,(address-term left support)
       =?
       ,(address-term right support)
       ,tag)]))

(define (address-substitution substitution support)
  (for/list ([binding (in-list substitution)])
    (match binding
      [(list u term)
       (list (address-atom u support)
             (address-term term support))])))

(define (address-disequalities disequalities support)
  (for/list ([disequality (in-list disequalities)])
    (match disequality
      [(list left right)
       (list (address-term left support)
             (address-term right support))])))

(define (S-state->E state support)
  (match state
    [`(state ,sub ,dis ,trail ,tag)
     `(state (Support ,@support) ,sub ,dis ,trail ,tag)]
    [_
     (error 'S-state->E "expected an S state, received ~e" state)]))

(define (S-answer->E answer support)
  (match answer
    [`(Answer ,owners ,state)
     (define support-here (extend-with-owners owners support))
     `(Answer ,(S-state->E state support-here))]))

(define (S-work->E/disjunction work [support '()])
  (match work
    [`(Work ,owners ,goal ,state)
     (define support-here (extend-with-owners owners support))
     `(Work ,goal ,(S-state->E state support-here))]
    [`(Returned ,owners ,state)
     (define support-here (extend-with-owners owners support))
     `(Returned ,(S-state->E state support-here))]
    [`(Dead ,owners)
     `(Dead (Support ,@(extend-with-owners owners support)))]
    [`(Conj ,owners ,inner ,goal)
     (define support-here (extend-with-owners owners support))
     `(Conj ,(S-work->E/disjunction inner support-here) ,goal)]
    [`(DisjL ,owners ,left ,right)
     (define support-here (extend-with-owners owners support))
     `(DisjL ,(S-work->E/disjunction left support-here)
             ,(S-work->E/disjunction right support-here))]
    [_
     (error 'S-work->E/disjunction
            "expected Disjunction S work, received ~e"
            work)]))

(define (S-frontier->E/disjunction frontier [support '()])
  (match frontier
    [`(More ,work)
     `(More ,(S-work->E/disjunction work support))]
    [`(Done ,owners)
     `(Done (Support ,@(extend-with-owners owners support)))]
    [`(Last ,owners ,answer)
     (define support-here (extend-with-owners owners support))
     `(Last ,(S-answer->E answer support-here))]
    [`(Emit ,owners ,answer ,residual)
     (define support-here (extend-with-owners owners support))
     `(Emit ,(S-answer->E answer support-here)
            ,(S-frontier->E/disjunction residual support-here))]
    [_
     (error 'S-frontier->E/disjunction
            "expected Disjunction S frontier, received ~e"
            frontier)]))

(define (Q-SE/F/disjunction frontier)
  (S-frontier->E/disjunction frontier))

(define (E-state->N state support)
  (match state
    [`(state (Support ,state-support ...) ,sub ,dis ,trail ,tag)
     (unless (equal? state-support support)
       (error 'E-state->N
              "state support ~e disagrees with world support ~e"
              state-support
              support))
     `(state
       ,(length support)
       ,(address-substitution sub support)
       ,(address-disequalities dis support)
       ,(map (lambda (equation) (address-equation equation support)) trail)
       ,tag)]))

(define (E-answer->N answer)
  (match answer
    [`(Answer ,state)
     (define support (support-from-E-state state))
     `(Answer ,(E-state->N state support))]))

;; Each E branch supplies its own support.  This is what preserves sibling
;; allocation reuse instead of falsely numbering across the whole frontier.
(define (E-work->N/disjunction work)
  (match work
    [`(Work ,goal ,state)
     (define support (support-from-E-state state))
     `(Work ,(address-goal/disjunction goal support)
            ,(E-state->N state support))]
    [`(Returned ,state)
     (define support (support-from-E-state state))
     `(Returned ,(E-state->N state support))]
    [`(Dead ,summary)
     `(Dead ,(length (support-from-E-summary summary)))]
    [`(Conj ,inner ,goal)
     (define support (E-work-live-support/disjunction inner))
     `(Conj ,(E-work->N/disjunction inner)
            ,(address-goal/disjunction goal support))]
    [`(DisjL ,left ,right)
     `(DisjL ,(E-work->N/disjunction left)
             ,(E-work->N/disjunction right))]
    [_
     (error 'E-work->N/disjunction
            "expected Disjunction E work, received ~e"
            work)]))

(define (E-frontier->N/disjunction frontier)
  (match frontier
    [`(More ,work)
     `(More ,(E-work->N/disjunction work))]
    [`(Done ,summary)
     `(Done ,(length (support-from-E-summary summary)))]
    [`(Last ,answer)
     `(Last ,(E-answer->N answer))]
    [`(Emit ,answer ,residual)
     `(Emit ,(E-answer->N answer)
            ,(E-frontier->N/disjunction residual))]
    [_
     (error 'E-frontier->N/disjunction
            "expected Disjunction E frontier, received ~e"
            frontier)]))

(define (Q-EN/F/disjunction frontier)
  (E-frontier->N/disjunction frontier))

(define (S-state->N state support)
  (match state
    [`(state ,sub ,dis ,trail ,tag)
     `(state
       ,(length support)
       ,(address-substitution sub support)
       ,(address-disequalities dis support)
       ,(map (lambda (equation) (address-equation equation support)) trail)
       ,tag)]))

(define (S-answer->N answer support)
  (match answer
    [`(Answer ,owners ,state)
     (define support-here (extend-with-owners owners support))
     `(Answer ,(S-state->N state support-here))]))

(define (S-work->N/disjunction work [support '()])
  (match work
    [`(Work ,owners ,goal ,state)
     (define support-here (extend-with-owners owners support))
     `(Work ,(address-goal/disjunction goal support-here)
            ,(S-state->N state support-here))]
    [`(Returned ,owners ,state)
     (define support-here (extend-with-owners owners support))
     `(Returned ,(S-state->N state support-here))]
    [`(Dead ,owners)
     `(Dead ,(length (extend-with-owners owners support)))]
    [`(Conj ,owners ,inner ,goal)
     (define support-here (extend-with-owners owners support))
     `(Conj ,(S-work->N/disjunction inner support-here)
            ,(address-goal/disjunction goal support-here))]
    [`(DisjL ,owners ,left ,right)
     (define support-here (extend-with-owners owners support))
     `(DisjL ,(S-work->N/disjunction left support-here)
             ,(S-work->N/disjunction right support-here))]
    [_
     (error 'S-work->N/disjunction
            "expected Disjunction S work, received ~e"
            work)]))

(define (S-frontier->N/disjunction frontier [support '()])
  (match frontier
    [`(More ,work)
     `(More ,(S-work->N/disjunction work support))]
    [`(Done ,owners)
     `(Done ,(length (extend-with-owners owners support)))]
    [`(Last ,owners ,answer)
     (define support-here (extend-with-owners owners support))
     `(Last ,(S-answer->N answer support-here))]
    [`(Emit ,owners ,answer ,residual)
     (define support-here (extend-with-owners owners support))
     `(Emit ,(S-answer->N answer support-here)
            ,(S-frontier->N/disjunction residual support-here))]
    [_
     (error 'S-frontier->N/disjunction
            "expected Disjunction S frontier, received ~e"
            frontier)]))

;; Direct S-to-N traversal: neither other vertical map is called.
(define (Q-SN/F/disjunction frontier)
  (S-frontier->N/disjunction frontier))

(define (disjunction-row-observation source)
  (list (list 'S source)
        (list 'E (Q-SE/F/disjunction source))
        (list 'N (Q-SN/F/disjunction source))))

(define (Q-SE-step-square-sides/disjunction source)
  (list
   (for/list ([successor
               (in-list (s:raw-successors/disjunction/s source))])
     (match successor
       [(list name target)
        (list name (Q-SE/F/disjunction target))]))
   (e:raw-successors/disjunction/e (Q-SE/F/disjunction source))))

(define (Q-SE-step-square/raw?/disjunction source)
  (match-define (list transported direct)
    (Q-SE-step-square-sides/disjunction source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-EN-step-square-sides/disjunction source)
  (list
   (for/list ([successor
               (in-list (e:raw-successors/disjunction/e source))])
     (match successor
       [(list name target)
        (list name (Q-EN/F/disjunction target))]))
   (n:raw-successors/disjunction/n (Q-EN/F/disjunction source))))

(define (Q-EN-step-square/raw?/disjunction source)
  (match-define (list transported direct)
    (Q-EN-step-square-sides/disjunction source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-SN-step-square-sides/disjunction source)
  (list
   (for/list ([successor
               (in-list (s:raw-successors/disjunction/s source))])
     (match successor
       [(list name target)
        (list name (Q-SN/F/disjunction target))]))
   (n:raw-successors/disjunction/n (Q-SN/F/disjunction source))))

(define (Q-SN-step-square/raw?/disjunction source)
  (match-define (list transported direct)
    (Q-SN-step-square-sides/disjunction source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-SN-composition?/disjunction source)
  (equal? (Q-SN/F/disjunction source)
          (Q-EN/F/disjunction (Q-SE/F/disjunction source))))
