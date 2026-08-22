#lang racket

(require redex/reduction-semantics
         (prefix-in s: "./s/source.rkt")
         (prefix-in e: "./e/source.rkt")
         (prefix-in n: "./n/source.rkt"))

(provide S-world-support
         E-live-support
         Q-SE/F
         Q-EN/F
         Q-SN/F
         Q-SE-step-square-sides
         Q-SE-step-square/raw?
         Q-EN-step-square-sides
         Q-EN-step-square/raw?
         Q-SN-step-square-sides
         Q-SN-step-square/raw?
         Q-SN-composition?)

;; These are direct structural maps between the three independently stated
;; source languages.  Every possible-world phase exposes its allocation
;; supply: live/successful E worlds through state, failed E worlds through the
;; narrow Support summary in Dead/Done, and N worlds analogously through next.

(define (u-symbol? datum)
  (and (symbol? datum)
       (regexp-match? #rx"^u:" (symbol->string datum))))

(define (extend-with-owners owners [support '()])
  (match owners
    [`(Owners) support]
    [`(Owners (Owner ,intro ,_tag) ,rest ...)
     (extend-with-owners `(Owners ,@rest) (append support intro))]
    [_
     (error 'extend-with-owners "expected Owners, received ~e" owners)]))

(define (S-work-support work [support '()])
  (match work
    [`(Conj ,owners ,inner ,_goal)
     (S-work-support inner (extend-with-owners owners support))]
    [`(Work ,owners ,_goal ,_state)
     (extend-with-owners owners support)]
    [`(Returned ,owners ,_state)
     (extend-with-owners owners support)]
    [`(Dead ,owners)
     (extend-with-owners owners support)]
    [_
     (error 'S-work-support "expected S work, received ~e" work)]))

(define (S-world-support frontier)
  (match frontier
    [`(More ,work) (S-work-support work)]
    [`(Done ,owners) (extend-with-owners owners)]
    [`(Last ,owners (Answer ,answer-owners ,_state))
     (extend-with-owners
      answer-owners
      (extend-with-owners owners))]
    [_
     (error 'S-world-support "expected an S frontier, received ~e" frontier)]))

(define (support-from-E-state state)
  (match state
    [`(state (Support ,support ...) ,_sub ,_dis ,_trail ,_tag)
     (validate-E-support 'support-from-E-state support)]
    [_
     (error 'support-from-E-state "expected an E state, received ~e" state)]))

(define (validate-E-support who support)
  (unless (and (andmap u-symbol? support)
               (duplicate-free? support))
    (error who "ill-formed E support: ~e" support))
  support)

(define (support-from-E-summary summary)
  (match summary
    [`(Support ,support ...)
     (validate-E-support 'support-from-E-summary support)]
    [_
     (error 'support-from-E-summary
            "expected an E Support summary, received ~e"
            summary)]))

(define (E-work-live-support work)
  (match work
    [`(Work ,_goal ,state) (support-from-E-state state)]
    [`(Returned ,state) (support-from-E-state state)]
    [`(Dead ,support) (support-from-E-summary support)]
    [`(Conj ,inner ,_goal) (E-work-live-support inner)]
    [_
     (error 'E-work-live-support "expected E work, received ~e" work)]))

(define (E-live-support frontier)
  (match frontier
    [`(More ,work) (E-work-live-support work)]
    [`(Last (Answer ,state)) (support-from-E-state state)]
    [`(Done ,support) (support-from-E-summary support)]
    [_
     (error 'E-live-support "expected an E frontier, received ~e" frontier)]))

(define (duplicate-free? values)
  (= (length values) (length (remove-duplicates values))))

(define (address-atom atom support)
  (match (index-of support atom)
    [#f
     (error 'Q-EN/F
            "runtime atom ~e is absent from stored world support ~e"
            atom
            support)]
    [index index]))

(define (address-term term support)
  (match term
    [(? u-symbol? u) (address-atom u support)]
    [`(,left : ,right)
     `(,(address-term left support) : ,(address-term right support))]
    [_ term]))

(define (address-goal goal support)
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
     `(,(address-goal left support)
       ∧
       ,(address-goal right support)
       ,tag)]
    [`(∃ ,binders ,body ,tag)
     `(∃ ,binders ,(address-goal body support) ,tag)]
    [_
     (error 'address-goal "expected a core goal, received ~e" goal)]))

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
     (error 'Q-SE/F "expected an S state, received ~e" state)]))

(define (S-answer->E answer [support '()])
  (match answer
    [`(Answer ,owners ,state)
     (define support-here (extend-with-owners owners support))
     `(Answer ,(S-state->E state support-here))]))

(define (S-work->E work [support '()])
  (match work
    [`(Work ,owners ,goal ,state)
     (define support-here (extend-with-owners owners support))
     `(Work ,goal ,(S-state->E state support-here))]
    [`(Returned ,owners ,state)
     (define support-here (extend-with-owners owners support))
     `(Returned ,(S-state->E state support-here))]
    [`(Dead ,owners)
     (define support-here (extend-with-owners owners support))
     `(Dead (Support ,@support-here))]
    [`(Conj ,owners ,inner ,goal)
     (define support-here (extend-with-owners owners support))
     `(Conj ,(S-work->E inner support-here) ,goal)]
    [_
     (error 'Q-SE/F "expected S work, received ~e" work)]))

(define (Q-SE/F frontier)
  (match frontier
    [`(More ,work) `(More ,(S-work->E work))]
    [`(Done ,owners)
     `(Done (Support ,@(extend-with-owners owners)))]
    [`(Last ,owners ,answer)
     (define support-here (extend-with-owners owners))
     `(Last ,(S-answer->E answer support-here))]
    [_
     (error 'Q-SE/F "expected an S frontier, received ~e" frontier)]))

(define (E-state->N state support)
  (match state
    [`(state (Support ,state-support ...) ,sub ,dis ,trail ,tag)
     (unless (equal? state-support support)
       (error 'Q-EN/F
              "state support ~e disagrees with world support ~e"
              state-support
              support))
     `(state
       ,(length support)
       ,(address-substitution sub support)
       ,(address-disequalities dis support)
       ,(map (lambda (equation) (address-equation equation support)) trail)
       ,tag)]))

(define (E-answer->N answer support)
  (match answer
    [`(Answer ,state) `(Answer ,(E-state->N state support))]))

(define (E-work->N work support)
  (match work
    [`(Work ,goal ,state)
     `(Work ,(address-goal goal support) ,(E-state->N state support))]
    [`(Returned ,state) `(Returned ,(E-state->N state support))]
    [`(Dead (Support ,dead-support ...))
     (unless (equal? dead-support support)
       (error 'Q-EN/F
              "Dead support ~e disagrees with world support ~e"
              dead-support
              support))
     `(Dead ,(length support))]
    [`(Conj ,inner ,goal)
     `(Conj ,(E-work->N inner support) ,(address-goal goal support))]
    [_
     (error 'Q-EN/F "expected E work, received ~e" work)]))

(define (Q-EN/F frontier)
  (define support (E-live-support frontier))
  (match frontier
    [`(More ,work) `(More ,(E-work->N work support))]
    [`(Done (Support ,done-support ...))
     (unless (equal? done-support support)
       (error 'Q-EN/F
              "Done support ~e disagrees with world support ~e"
              done-support
              support))
     `(Done ,(length support))]
    [`(Last ,answer) `(Last ,(E-answer->N answer support))]
    [_
     (error 'Q-EN/F "expected an E frontier, received ~e" frontier)]))

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
    [`(Answer ,_owners ,state) `(Answer ,(S-state->N state support))]))

(define (S-work->N work support)
  (match work
    [`(Work ,_owners ,goal ,state)
     `(Work ,(address-goal goal support) ,(S-state->N state support))]
    [`(Returned ,_owners ,state) `(Returned ,(S-state->N state support))]
    [`(Dead ,_owners) `(Dead ,(length support))]
    [`(Conj ,_owners ,inner ,goal)
     `(Conj ,(S-work->N inner support) ,(address-goal goal support))]
    [_
     (error 'Q-SN/F "expected S work, received ~e" work)]))

;; This implementation traverses S directly.  It does not call Q-SE/F or
;; Q-EN/F.  The equality with their composition is an executable obligation.
(define (Q-SN/F frontier)
  (define support (S-world-support frontier))
  (match frontier
    [`(More ,work) `(More ,(S-work->N work support))]
    [`(Done ,_owners) `(Done ,(length support))]
    [`(Last ,_owners ,answer) `(Last ,(S-answer->N answer support))]
    [_
     (error 'Q-SN/F "expected an S frontier, received ~e" frontier)]))

(define (normalize-name name)
  (string->symbol (~a name)))

(define (named-successors relation source)
  (for/list ([successor
              (in-list
               (apply-reduction-relation/tag-with-names relation source))])
    (match successor
      [(list name target) (list (normalize-name name) target)])))

(define (canonical-multiset values)
  (sort values string<? #:key ~s))

(define (Q-SE-step-square-sides source)
  (list
   (for/list ([successor
               (in-list (named-successors s:core-s-oracle-red source))])
     (match successor
       [(list name target) (list name (Q-SE/F target))]))
   (named-successors e:core-e-oracle-red (Q-SE/F source))))

(define (Q-SE-step-square/raw? source)
  (match-define (list transported direct)
    (Q-SE-step-square-sides source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-EN-step-square-sides source)
  (list
   (for/list ([successor
               (in-list (named-successors e:core-e-oracle-red source))])
     (match successor
       [(list name target)
        (list name (Q-EN/F target))]))
   (named-successors
    n:core-n-oracle-red
    (Q-EN/F source))))

(define (Q-EN-step-square/raw? source)
  (match-define (list transported direct)
    (Q-EN-step-square-sides source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-SN-step-square-sides source)
  (list
   (for/list ([successor
               (in-list (named-successors s:core-s-oracle-red source))])
     (match successor
       [(list name target) (list name (Q-SN/F target))]))
   (named-successors n:core-n-oracle-red (Q-SN/F source))))

(define (Q-SN-step-square/raw? source)
  (match-define (list transported direct)
    (Q-SN-step-square-sides source))
  (equal? (canonical-multiset transported)
          (canonical-multiset direct)))

(define (Q-SN-composition? source)
  (equal? (Q-SN/F source)
          (Q-EN/F (Q-SE/F source))))
