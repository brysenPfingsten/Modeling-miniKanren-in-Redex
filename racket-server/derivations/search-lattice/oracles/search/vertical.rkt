#lang racket

(require "private/shared.rkt"
         (prefix-in s: "s/source.rkt")
         (prefix-in e: "e/source.rkt")
         (prefix-in n: "n/source.rkt"))

(provide S-world-support/search
         E-live-support/search
         Q-SE/F/search
         Q-EN/F/search
         Q-SN/F/search
         search-row-observation
         Q-SE-step-square-sides/search
         Q-SE-step-square/raw?/search
         Q-EN-step-square-sides/search
         Q-EN-step-square/raw?/search
         Q-SN-step-square-sides/search
         Q-SN-step-square/raw?/search
         Q-SN-composition?/search)

;; These are three direct structural maps over the joined source carriers.  No
;; map decodes through generated declarations, and direct S-to-N never calls
;; either adjacent map.

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

(define (S-work-support/search work [support '()])
  (match work
    [`(Conj ,owners ,inner ,_goal)
     (S-work-support/search inner (extend-with-owners owners support))]
    [`(PendingDelay ,owners ,inner)
     (S-work-support/search inner (extend-with-owners owners support))]
    [`(DisjL ,owners ,left ,_right)
     (S-work-support/search left (extend-with-owners owners support))]
    [`(Work ,owners ,_goal ,_state)
     (extend-with-owners owners support)]
    [`(Returned ,owners ,_state)
     (extend-with-owners owners support)]
    [`(Dead ,owners)
     (extend-with-owners owners support)]
    [_
     (error 'S-work-support/search
            "expected Search S work, received ~e"
            work)]))

(define (S-world-support/search frontier [support '()])
  (match frontier
    [`(Forced ,owners ,inner)
     (S-world-support/search inner (extend-with-owners owners support))]
    [`(Emit ,owners ,_answer ,residual)
     (S-world-support/search residual (extend-with-owners owners support))]
    [`(More ,work)
     (S-work-support/search work support)]
    [`(Done ,owners)
     (extend-with-owners owners support)]
    [`(Last ,owners (Answer ,answer-owners ,_state))
     (extend-with-owners
      answer-owners
      (extend-with-owners owners support))]
    [_
     (error 'S-world-support/search
            "expected Search S frontier, received ~e"
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

(define (E-work-live-support/search work)
  (match work
    [`(Conj ,inner ,_goal)
     (E-work-live-support/search inner)]
    [`(PendingDelay ,inner)
     (E-work-live-support/search inner)]
    [`(DisjL ,left ,_right)
     (E-work-live-support/search left)]
    [`(Work ,_goal ,state)
     (support-from-E-state state)]
    [`(Returned ,state)
     (support-from-E-state state)]
    [`(Dead ,summary)
     (support-from-E-summary summary)]
    [_
     (error 'E-work-live-support/search
            "expected Search E work, received ~e"
            work)]))

(define (E-live-support/search frontier)
  (match frontier
    [`(Forced ,inner)
     (E-live-support/search inner)]
    [`(Emit ,_answer ,residual)
     (E-live-support/search residual)]
    [`(More ,work)
     (E-work-live-support/search work)]
    [`(Last (Answer ,state))
     (support-from-E-state state)]
    [`(Done ,summary)
     (support-from-E-summary summary)]
    [_
     (error 'E-live-support/search
            "expected Search E frontier, received ~e"
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

(define (address-goal/search goal support)
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
     `(,(address-goal/search left support)
       ∧
       ,(address-goal/search right support)
       ,tag)]
    [`(,left ∨ ,right ,tag)
     `(,(address-goal/search left support)
       ∨
       ,(address-goal/search right support)
       ,tag)]
    [`(∃ ,binders ,body ,tag)
     `(∃ ,binders ,(address-goal/search body support) ,tag)]
    [`(suspend ,body ,tag)
     `(suspend ,(address-goal/search body support) ,tag)]
    [_
     (error 'address-goal/search
            "expected a Search goal, received ~e"
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

(define (S-work->E/search work [support '()])
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
     `(Conj ,(S-work->E/search inner support-here) ,goal)]
    [`(PendingDelay ,owners ,inner)
     (define support-here (extend-with-owners owners support))
     `(PendingDelay ,(S-work->E/search inner support-here))]
    [`(DisjL ,owners ,left ,right)
     (define support-here (extend-with-owners owners support))
     `(DisjL ,(S-work->E/search left support-here)
             ,(S-work->E/search right support-here))]
    [_
     (error 'S-work->E/search
            "expected Search S work, received ~e"
            work)]))

(define (S-frontier->E/search frontier [support '()])
  (match frontier
    [`(More ,work)
     `(More ,(S-work->E/search work support))]
    [`(Done ,owners)
     `(Done (Support ,@(extend-with-owners owners support)))]
    [`(Last ,owners ,answer)
     (define support-here (extend-with-owners owners support))
     `(Last ,(S-answer->E answer support-here))]
    [`(Forced ,owners ,inner)
     (define support-here (extend-with-owners owners support))
     `(Forced ,(S-frontier->E/search inner support-here))]
    [`(Emit ,owners ,answer ,residual)
     (define support-here (extend-with-owners owners support))
     `(Emit ,(S-answer->E answer support-here)
            ,(S-frontier->E/search residual support-here))]
    [_
     (error 'S-frontier->E/search
            "expected Search S frontier, received ~e"
            frontier)]))

(define (Q-SE/F/search frontier)
  (S-frontier->E/search frontier))

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

;; Every branch supplies its own support.  This preserves literal sibling-local
;; allocation reuse instead of numbering across the whole frontier.
(define (E-work->N/search work)
  (match work
    [`(Work ,goal ,state)
     (define support (support-from-E-state state))
     `(Work ,(address-goal/search goal support)
            ,(E-state->N state support))]
    [`(Returned ,state)
     (define support (support-from-E-state state))
     `(Returned ,(E-state->N state support))]
    [`(Dead ,summary)
     `(Dead ,(length (support-from-E-summary summary)))]
    [`(Conj ,inner ,goal)
     (define support (E-work-live-support/search inner))
     `(Conj ,(E-work->N/search inner)
            ,(address-goal/search goal support))]
    [`(PendingDelay ,inner)
     `(PendingDelay ,(E-work->N/search inner))]
    [`(DisjL ,left ,right)
     `(DisjL ,(E-work->N/search left)
             ,(E-work->N/search right))]
    [_
     (error 'E-work->N/search
            "expected Search E work, received ~e"
            work)]))

(define (E-frontier->N/search frontier)
  (match frontier
    [`(More ,work)
     `(More ,(E-work->N/search work))]
    [`(Done ,summary)
     `(Done ,(length (support-from-E-summary summary)))]
    [`(Last ,answer)
     `(Last ,(E-answer->N answer))]
    [`(Forced ,inner)
     `(Forced ,(E-frontier->N/search inner))]
    [`(Emit ,answer ,residual)
     `(Emit ,(E-answer->N answer)
            ,(E-frontier->N/search residual))]
    [_
     (error 'E-frontier->N/search
            "expected Search E frontier, received ~e"
            frontier)]))

(define (Q-EN/F/search frontier)
  (E-frontier->N/search frontier))

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

(define (S-work->N/search work [support '()])
  (match work
    [`(Work ,owners ,goal ,state)
     (define support-here (extend-with-owners owners support))
     `(Work ,(address-goal/search goal support-here)
            ,(S-state->N state support-here))]
    [`(Returned ,owners ,state)
     (define support-here (extend-with-owners owners support))
     `(Returned ,(S-state->N state support-here))]
    [`(Dead ,owners)
     `(Dead ,(length (extend-with-owners owners support)))]
    [`(Conj ,owners ,inner ,goal)
     (define support-here (extend-with-owners owners support))
     `(Conj ,(S-work->N/search inner support-here)
            ,(address-goal/search goal support-here))]
    [`(PendingDelay ,owners ,inner)
     (define support-here (extend-with-owners owners support))
     `(PendingDelay ,(S-work->N/search inner support-here))]
    [`(DisjL ,owners ,left ,right)
     (define support-here (extend-with-owners owners support))
     `(DisjL ,(S-work->N/search left support-here)
             ,(S-work->N/search right support-here))]
    [_
     (error 'S-work->N/search
            "expected Search S work, received ~e"
            work)]))

(define (S-frontier->N/search frontier [support '()])
  (match frontier
    [`(More ,work)
     `(More ,(S-work->N/search work support))]
    [`(Done ,owners)
     `(Done ,(length (extend-with-owners owners support)))]
    [`(Last ,owners ,answer)
     (define support-here (extend-with-owners owners support))
     `(Last ,(S-answer->N answer support-here))]
    [`(Forced ,owners ,inner)
     (define support-here (extend-with-owners owners support))
     `(Forced ,(S-frontier->N/search inner support-here))]
    [`(Emit ,owners ,answer ,residual)
     (define support-here (extend-with-owners owners support))
     `(Emit ,(S-answer->N answer support-here)
            ,(S-frontier->N/search residual support-here))]
    [_
     (error 'S-frontier->N/search
            "expected Search S frontier, received ~e"
            frontier)]))

(define (Q-SN/F/search frontier)
  (S-frontier->N/search frontier))

(define (search-row-observation source)
  (list (list 'S source)
        (list 'E (Q-SE/F/search source))
        (list 'N (Q-SN/F/search source))))

(define (Q-SE-step-square-sides/search source)
  (list
   (for/list ([successor (in-list (s:raw-successors/search/s source))])
     (match successor
       [(list name target)
        (list name (Q-SE/F/search target))]))
   (e:raw-successors/search/e (Q-SE/F/search source))))

(define (Q-SE-step-square/raw?/search source)
  (match-define (list transported direct)
    (Q-SE-step-square-sides/search source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-EN-step-square-sides/search source)
  (list
   (for/list ([successor (in-list (e:raw-successors/search/e source))])
     (match successor
       [(list name target)
        (list name (Q-EN/F/search target))]))
   (n:raw-successors/search/n (Q-EN/F/search source))))

(define (Q-EN-step-square/raw?/search source)
  (match-define (list transported direct)
    (Q-EN-step-square-sides/search source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-SN-step-square-sides/search source)
  (list
   (for/list ([successor (in-list (s:raw-successors/search/s source))])
     (match successor
       [(list name target)
        (list name (Q-SN/F/search target))]))
   (n:raw-successors/search/n (Q-SN/F/search source))))

(define (Q-SN-step-square/raw?/search source)
  (match-define (list transported direct)
    (Q-SN-step-square-sides/search source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-SN-composition?/search source)
  (equal? (Q-SN/F/search source)
          (Q-EN/F/search (Q-SE/F/search source))))
