#lang racket

(require "private/shared.rkt"
         (prefix-in s: "s/source.rkt")
         (prefix-in e: "e/source.rkt")
         (prefix-in n: "n/source.rkt"))

(provide S-world-support/delay
         E-live-support/delay
         Q-SE/F/delay
         Q-EN/F/delay
         Q-SN/F/delay
         delay-row-observation
         Q-SE-step-square-sides/delay
         Q-SE-step-square/raw?/delay
         Q-EN-step-square-sides/delay
         Q-EN-step-square/raw?/delay
         Q-SN-step-square-sides/delay
         Q-SN-step-square/raw?/delay
         Q-SN-composition?/delay)

;; Direct structural maps for the three independent Delay source carriers.
;; None decodes through an earlier representation, and none imports generated
;; declarations or relations.

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

(define (S-work-support/delay work [support '()])
  (match work
    [`(Conj ,owners ,inner ,_goal)
     (S-work-support/delay inner (extend-with-owners owners support))]
    [`(PendingDelay ,owners ,inner)
     (S-work-support/delay inner (extend-with-owners owners support))]
    [`(Work ,owners ,_goal ,_state)
     (extend-with-owners owners support)]
    [`(Returned ,owners ,_state)
     (extend-with-owners owners support)]
    [`(Dead ,owners)
     (extend-with-owners owners support)]
    [_
     (error 'S-work-support/delay
            "expected Delay S work, received ~e"
            work)]))

(define (S-world-support/delay frontier [support '()])
  (match frontier
    [`(Forced ,owners ,inner)
     (S-world-support/delay inner (extend-with-owners owners support))]
    [`(More ,work) (S-work-support/delay work support)]
    [`(Done ,owners) (extend-with-owners owners support)]
    [`(Last ,owners (Answer ,answer-owners ,_state))
     (extend-with-owners
      answer-owners
      (extend-with-owners owners support))]
    [_
     (error 'S-world-support/delay
            "expected a Delay S frontier, received ~e"
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

(define (E-work-live-support/delay work)
  (match work
    [`(PendingDelay ,inner) (E-work-live-support/delay inner)]
    [`(Conj ,inner ,_goal) (E-work-live-support/delay inner)]
    [`(Work ,_goal ,state) (support-from-E-state state)]
    [`(Returned ,state) (support-from-E-state state)]
    [`(Dead ,support) (support-from-E-summary support)]
    [_
     (error 'E-work-live-support/delay
            "expected Delay E work, received ~e"
            work)]))

(define (E-live-support/delay frontier)
  (match frontier
    [`(Forced ,inner) (E-live-support/delay inner)]
    [`(More ,work) (E-work-live-support/delay work)]
    [`(Last (Answer ,state)) (support-from-E-state state)]
    [`(Done ,support) (support-from-E-summary support)]
    [_
     (error 'E-live-support/delay
            "expected a Delay E frontier, received ~e"
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

;; Addressing is explicitly recursive through suspend in both direct maps to
;; N.  This is not inherited via a codec or an S-to-E intermediate.
(define (address-goal/delay goal support)
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
     `(,(address-goal/delay left support)
       ∧
       ,(address-goal/delay right support)
       ,tag)]
    [`(∃ ,binders ,body ,tag)
     `(∃ ,binders ,(address-goal/delay body support) ,tag)]
    [`(suspend ,body ,tag)
     `(suspend ,(address-goal/delay body support) ,tag)]
    [_
     (error 'address-goal/delay
            "expected a Delay goal, received ~e"
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

(define (S-work->E/delay work [support '()])
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
     `(Conj ,(S-work->E/delay inner support-here) ,goal)]
    [`(PendingDelay ,owners ,inner)
     (define support-here (extend-with-owners owners support))
     `(PendingDelay ,(S-work->E/delay inner support-here))]
    [_
     (error 'S-work->E/delay
            "expected Delay S work, received ~e"
            work)]))

(define (S-frontier->E/delay frontier [support '()])
  (match frontier
    [`(More ,work) `(More ,(S-work->E/delay work support))]
    [`(Done ,owners)
     `(Done (Support ,@(extend-with-owners owners support)))]
    [`(Last ,owners ,answer)
     (define support-here (extend-with-owners owners support))
     `(Last ,(S-answer->E answer support-here))]
    [`(Forced ,owners ,inner)
     (define support-here (extend-with-owners owners support))
     `(Forced ,(S-frontier->E/delay inner support-here))]
    [_
     (error 'S-frontier->E/delay
            "expected Delay S frontier, received ~e"
            frontier)]))

(define (Q-SE/F/delay frontier)
  (S-frontier->E/delay frontier))

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

(define (E-work->N/delay work support)
  (match work
    [`(Work ,goal ,state)
     `(Work ,(address-goal/delay goal support)
            ,(E-state->N state support))]
    [`(Returned ,state) `(Returned ,(E-state->N state support))]
    [`(Dead (Support ,dead-support ...))
     (unless (equal? dead-support support)
       (error 'E-work->N/delay
              "Dead support ~e disagrees with world support ~e"
              dead-support
              support))
     `(Dead ,(length support))]
    [`(Conj ,inner ,goal)
     `(Conj ,(E-work->N/delay inner support)
            ,(address-goal/delay goal support))]
    [`(PendingDelay ,inner)
     `(PendingDelay ,(E-work->N/delay inner support))]
    [_
     (error 'E-work->N/delay
            "expected Delay E work, received ~e"
            work)]))

(define (E-frontier->N/delay frontier support)
  (match frontier
    [`(More ,work) `(More ,(E-work->N/delay work support))]
    [`(Done (Support ,done-support ...))
     (unless (equal? done-support support)
       (error 'E-frontier->N/delay
              "Done support ~e disagrees with world support ~e"
              done-support
              support))
     `(Done ,(length support))]
    [`(Last (Answer ,state))
     `(Last (Answer ,(E-state->N state support)))]
    [`(Forced ,inner)
     `(Forced ,(E-frontier->N/delay inner support))]
    [_
     (error 'E-frontier->N/delay
            "expected Delay E frontier, received ~e"
            frontier)]))

(define (Q-EN/F/delay frontier)
  (E-frontier->N/delay frontier (E-live-support/delay frontier)))

(define (S-state->N state support)
  (match state
    [`(state ,sub ,dis ,trail ,tag)
     `(state
       ,(length support)
       ,(address-substitution sub support)
       ,(address-disequalities dis support)
       ,(map (lambda (equation) (address-equation equation support)) trail)
       ,tag)]))

(define (S-work->N/delay work support)
  (match work
    [`(Work ,_owners ,goal ,state)
     `(Work ,(address-goal/delay goal support)
            ,(S-state->N state support))]
    [`(Returned ,_owners ,state)
     `(Returned ,(S-state->N state support))]
    [`(Dead ,_owners) `(Dead ,(length support))]
    [`(Conj ,_owners ,inner ,goal)
     `(Conj ,(S-work->N/delay inner support)
            ,(address-goal/delay goal support))]
    [`(PendingDelay ,_owners ,inner)
     `(PendingDelay ,(S-work->N/delay inner support))]
    [_
     (error 'S-work->N/delay
            "expected Delay S work, received ~e"
            work)]))

(define (S-frontier->N/delay frontier support)
  (match frontier
    [`(More ,work) `(More ,(S-work->N/delay work support))]
    [`(Done ,_owners) `(Done ,(length support))]
    [`(Last ,_owners (Answer ,_answer-owners ,state))
     `(Last (Answer ,(S-state->N state support)))]
    [`(Forced ,_owners ,inner)
     `(Forced ,(S-frontier->N/delay inner support))]
    [_
     (error 'S-frontier->N/delay
            "expected Delay S frontier, received ~e"
            frontier)]))

;; Direct S-to-N traversal: Q-SE/F/delay and Q-EN/F/delay are not called.
(define (Q-SN/F/delay frontier)
  (S-frontier->N/delay frontier (S-world-support/delay frontier)))

(define (delay-row-observation source)
  (list (list 'S source)
        (list 'E (Q-SE/F/delay source))
        (list 'N (Q-SN/F/delay source))))

(define (Q-SE-step-square-sides/delay source)
  (list
   (for/list ([successor (in-list (s:raw-successors/delay/s source))])
     (match successor
       [(list name target) (list name (Q-SE/F/delay target))]))
   (e:raw-successors/delay/e (Q-SE/F/delay source))))

(define (Q-SE-step-square/raw?/delay source)
  (match-define (list transported direct)
    (Q-SE-step-square-sides/delay source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-EN-step-square-sides/delay source)
  (list
   (for/list ([successor (in-list (e:raw-successors/delay/e source))])
     (match successor
       [(list name target) (list name (Q-EN/F/delay target))]))
   (n:raw-successors/delay/n (Q-EN/F/delay source))))

(define (Q-EN-step-square/raw?/delay source)
  (match-define (list transported direct)
    (Q-EN-step-square-sides/delay source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-SN-step-square-sides/delay source)
  (list
   (for/list ([successor (in-list (s:raw-successors/delay/s source))])
     (match successor
       [(list name target) (list name (Q-SN/F/delay target))]))
   (n:raw-successors/delay/n (Q-SN/F/delay source))))

(define (Q-SN-step-square/raw?/delay source)
  (match-define (list transported direct)
    (Q-SN-step-square-sides/delay source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-SN-composition?/delay source)
  (equal? (Q-SN/F/delay source)
          (Q-EN/F/delay (Q-SE/F/delay source))))
