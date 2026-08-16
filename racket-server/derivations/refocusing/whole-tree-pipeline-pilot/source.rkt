#lang racket

(require racket/list
         redex/reduction-semantics
         "./language.rkt")

(provide (struct-out transition)
         (struct-out scope-owner)
         (struct-out scoped-answer)
         (struct-out source-observation)
         initial-tree
         well-formed-tree?
         source-step
         source-trace
         source-red
         frontier-events
         answer-payloads
         extensional-answers
         scoped-answers
         residual-tail
         observe-source)

(struct transition (name owner next) #:transparent)
(struct scope-owner (intro tag) #:transparent)
(struct scoped-answer (state owners) #:transparent)
(struct source-observation (events answers residual) #:transparent)

;; An internal rewrite result.  This is host implementation data, not a source
;; term or a machine state.
(struct rewrite (name owner replacement) #:transparent)

(define (x-symbol? value)
  (and (symbol? value)
       (regexp-match? #rx"^x:" (symbol->string value))))

(define (u-symbol? value)
  (and (symbol? value)
       (regexp-match? #rx"^u:" (symbol->string value))))

(define (logical-vars-in datum [vars '()])
  (match datum
    [(? u-symbol? u)
     (if (member u vars) vars (cons u vars))]
    [(cons first rest)
     (logical-vars-in first (logical-vars-in rest vars))]
    [_ vars]))

(define (fresh-u-symbol used [n 0])
  (define candidate
    (string->symbol (format "u:~a" n)))
  (if (member candidate used)
      (fresh-u-symbol used (add1 n))
      candidate))

(define (fresh-u-list used lexical)
  (define-values (reversed _used)
    (for/fold ([reversed '()]
               [used* used])
              ([_x (in-list lexical)])
      (define u
        (fresh-u-symbol used*))
      (values (cons u reversed)
              (cons u used*))))
  (reverse reversed))

(define (drop-shadowed-bindings lexical bindings)
  (filter (lambda (binding)
            (not (member (first binding) lexical)))
          bindings))

(define (substitute-payload payload bindings)
  (match payload
    [(? x-symbol? x)
     (match (assoc x bindings)
       [(list _ u) u]
       [_ x])]
    [`(,first : ,rest)
     `(,(substitute-payload first bindings)
       :
       ,(substitute-payload rest bindings))]
    [_ payload]))

(define (substitute-goal goal bindings)
  (match goal
    [`(succeed ,tag)
     `(succeed ,tag)]
    [`(fail ,tag)
     `(fail ,tag)]
    [`(put ,payload ,tag)
     `(put ,(substitute-payload payload bindings) ,tag)]
    [`(fresh ,lexical ,body ,tag)
     `(fresh ,lexical
             ,(substitute-goal
               body
               (drop-shadowed-bindings lexical bindings))
             ,tag)]
    [`(conj ,left ,right ,tag)
     `(conj ,(substitute-goal left bindings)
            ,(substitute-goal right bindings)
            ,tag)]
    [`(disj ,left ,right ,tag)
     `(disj ,(substitute-goal left bindings)
            ,(substitute-goal right bindings)
            ,tag)]
    [`(suspend ,body ,tag)
     `(suspend ,(substitute-goal body bindings) ,tag)]))

(define (distinct-names? names)
  (= (length names)
     (length (remove-duplicates names))))

(define (well-formed-goal-structure? goal)
  (match goal
    [`(succeed ,_tag) #t]
    [`(fail ,_tag) #t]
    [`(put ,_payload ,_tag) #t]
    [`(fresh ,lexical ,body ,_tag)
     (and (distinct-names? lexical)
          (well-formed-goal-structure? body))]
    [`(conj ,left ,right ,_tag)
     (and (well-formed-goal-structure? left)
          (well-formed-goal-structure? right))]
    [`(disj ,left ,right ,_tag)
     (and (well-formed-goal-structure? left)
          (well-formed-goal-structure? right))]
    [`(suspend ,body ,_tag)
     (well-formed-goal-structure? body)]
    [_ #f]))

(define (well-formed-answer-structure? answer)
  (match answer
    [`(Answer ,_state) #t]
    [`(AnswerFresh ,intro ,inner ,_tag)
     (and (distinct-names? intro)
          (well-formed-answer-structure? inner))]
    [_ #f]))

(define (well-formed-work-structure? work)
  (match work
    [`(Work ,goal ,_state)
     (well-formed-goal-structure? goal)]
    [`(Returned ,_state) #t]
    ['Dead #t]
    [`(WorkFresh ,intro ,inner ,_tag)
     (and (distinct-names? intro)
          (well-formed-work-structure? inner))]
    [`(Conj ,left ,right)
     (and (well-formed-work-structure? left)
          (well-formed-goal-structure? right))]
    [`(PendingDelay ,inner)
     (well-formed-work-structure? inner)]
    [`(DisjL ,left ,right)
     (and (well-formed-work-structure? left)
          (well-formed-work-structure? right))]
    [`(DisjR ,left ,right)
     (and (well-formed-work-structure? left)
          (well-formed-work-structure? right))]
    [_ #f]))

(define (frontier-terminal-count tree)
  (match tree
    [`(More ,work)
     (if (well-formed-work-structure? work) 1 0)]
    ['Done 1]
    [`(Last ,answer)
     (if (well-formed-answer-structure? answer) 1 0)]
    [`(FrontierFresh ,intro ,rest ,_tag)
     (if (distinct-names? intro)
         (frontier-terminal-count rest)
         0)]
    [`(Emit ,answer ,rest)
     (if (well-formed-answer-structure? answer)
         (frontier-terminal-count rest)
         0)]
    [`(Forced ,rest)
     (frontier-terminal-count rest)]
    [_ 0]))

(define (well-formed-tree? tree)
  (and (frontier-in-language? tree)
       (= 1 (frontier-terminal-count tree))))

(define (initial-tree goal [state '(state unit)])
  (unless (goal-in-language? goal)
    (raise-argument-error 'initial-tree "goal-in-language?" goal))
  `(More (Work ,goal ,state)))

(define (settled-success? work)
  (match work
    [`(Returned ,_state) #t]
    [`(WorkFresh ,_intro ,inner ,_tag)
     (settled-success? inner)]
    [_ #f]))

(define (resume-success success goal)
  (match success
    [`(Returned ,state)
     `(Work ,goal ,state)]
    [`(WorkFresh ,intro ,inner ,tag)
     `(WorkFresh ,intro ,(resume-success inner goal) ,tag)]))

(define (freeze-success success)
  (match success
    [`(Returned ,state)
     `(Answer ,state)]
    [`(WorkFresh ,intro ,inner ,tag)
     `(AnswerFresh ,intro ,(freeze-success inner) ,tag)]))

;; Returns orientation, settled active branch, and its alternate.
(define (settled-choice-view work)
  (match work
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (list 'left active alternate)]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (list 'right active alternate)]
    [_ #f]))

(define (lift-rewrite result rebuild)
  (match result
    [#f #f]
    [(rewrite name owner replacement)
     (rewrite name owner (rebuild replacement))]))

;; These functions implement the F -> F source relation directly.  They do not
;; construct a decomposition, plug a context, or invoke the whole-tree spike.
(define (step-frontier tree used)
  (match tree
    [`(Emit ,answer ,rest)
     (lift-rewrite (step-frontier rest used)
                   (lambda (rest*) `(Emit ,answer ,rest*)))]
    [`(FrontierFresh ,intro ,rest ,tag)
     (lift-rewrite (step-frontier rest used)
                   (lambda (rest*) `(FrontierFresh ,intro ,rest* ,tag)))]
    [`(Forced ,rest)
     (lift-rewrite (step-frontier rest used)
                   (lambda (rest*) `(Forced ,rest*)))]
    [`(More ,work)
     (step-more work used)]
    ['Done #f]
    [`(Last ,_answer) #f]))

(define (step-more work used)
  (match work
    [`(WorkFresh ,intro ,inner ,tag)
     (rewrite "expose-frontier-fresh"
              'core
              `(FrontierFresh ,intro (More ,inner) ,tag))]
    [`(Returned ,state)
     (rewrite "finish-success" 'core `(Last (Answer ,state)))]
    ['Dead
     (rewrite "finish-failure" 'core 'Done)]
    [`(PendingDelay ,inner)
     (rewrite "force-delay" 'delay `(Forced (More ,inner)))]
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (rewrite "commit-choice-answer"
              'disj
              `(Emit ,(freeze-success active) (More ,alternate)))]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (rewrite "commit-right-choice-answer"
              'search-join
              `(Emit ,(freeze-success active) (More ,alternate)))]
    [_
     (lift-rewrite (step-work work used)
                   (lambda (work*) `(More ,work*)))]))

(define (step-atomic-work goal state used)
  (match goal
    [`(succeed ,_tag)
     (rewrite "work-succeed" 'core `(Returned ,state))]
    [`(fail ,_tag)
     (rewrite "work-fail" 'core 'Dead)]
    [`(put ,payload ,_tag)
     (rewrite "work-put" 'core `(Returned (state ,payload)))]
    [`(fresh ,lexical ,body ,tag)
     (define intro
       (fresh-u-list used lexical))
     (define bindings
       (map list lexical intro))
     (rewrite "allocate-fresh"
              'core
              `(WorkFresh ,intro
                          (Work ,(substitute-goal body bindings) ,state)
                          ,tag))]
    [`(conj ,left ,right ,_tag)
     (rewrite "expand-conjunction"
              'core
              `(Conj (Work ,left ,state) ,right))]
    [`(disj ,left ,right ,_tag)
     (rewrite "expand-disjunction"
              'disj
              `(DisjL (Work ,left ,state) (Work ,right ,state)))]
    [`(suspend ,body ,_tag)
     (rewrite "suspend-goal"
              'delay
              `(PendingDelay (Work ,body ,state)))]))

(define (step-work-fresh intro inner tag used)
  (match inner
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (rewrite
      "expose-choice-through-work-fresh"
      'disj
      `(DisjL (WorkFresh ,intro ,active ,tag)
              (WorkFresh ,intro ,alternate ,tag)))]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (rewrite
      "expose-choice-through-work-fresh"
      'search-join
      `(DisjR (WorkFresh ,intro ,alternate ,tag)
              (WorkFresh ,intro ,active ,tag)))]
    ['Dead
     (rewrite "erase-dead-fresh" 'core 'Dead)]
    [`(PendingDelay ,work)
     (rewrite "bubble-delay-through-fresh"
              'delay
              `(PendingDelay (WorkFresh ,intro ,work ,tag)))]
    [_
     (lift-rewrite (step-work inner used)
                   (lambda (inner*) `(WorkFresh ,intro ,inner* ,tag)))]))

(define (step-conjunction left goal used)
  (match left
    [(? settled-success? success)
     (rewrite "conj-return" 'core (resume-success success goal))]
    ['Dead
     (rewrite "conj-fail" 'core 'Dead)]
    [`(PendingDelay ,work)
     (rewrite "bubble-delay-through-conj"
              'delay
              `(PendingDelay (Conj ,work ,goal)))]
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (rewrite "late-distribute-settled"
              'disj
              `(DisjL ,(resume-success active goal)
                      (Conj ,alternate ,goal)))]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (rewrite "late-distribute-right-settled"
              'search-join
              `(DisjR (Conj ,alternate ,goal)
                      ,(resume-success active goal)))]
    [_
     (lift-rewrite (step-work left used)
                   (lambda (left*) `(Conj ,left* ,goal)))]))

(define (step-left-choice left right used)
  (match left
    ['Dead
     (rewrite "skip-left-failure" 'disj right)]
    [`(PendingDelay ,work)
     (rewrite "rail-enter-right"
              'search-join
              `(PendingDelay (DisjR ,work ,right)))]
    [_
     (match (settled-choice-view left)
       [(list _orientation success alternate)
        (rewrite "reassociate-left-result"
                 'disj
                 `(DisjL ,success (DisjL ,alternate ,right)))]
       [_
        (lift-rewrite (step-work left used)
                      (lambda (left*) `(DisjL ,left* ,right)))])]))

(define (step-right-choice left right used)
  (match right
    ['Dead
     (rewrite "skip-right-failure" 'search-join left)]
    [`(PendingDelay ,work)
     (rewrite "rail-return-left"
              'search-join
              `(PendingDelay (DisjL ,left ,work)))]
    [_
     (match (settled-choice-view right)
       [(list _orientation success alternate)
        (rewrite "reassociate-right-result"
                 'search-join
                 `(DisjR (DisjR ,left ,alternate) ,success))]
       [_
        (lift-rewrite (step-work right used)
                      (lambda (right*) `(DisjR ,left ,right*)))])]))

(define (step-work work used)
  (match work
    [`(Work ,goal ,state)
     (step-atomic-work goal state used)]
    [`(WorkFresh ,intro ,inner ,tag)
     (step-work-fresh intro inner tag used)]
    [`(Conj ,left ,goal)
     (step-conjunction left goal used)]
    [`(DisjL ,left ,right)
     (step-left-choice left right used)]
    [`(DisjR ,left ,right)
     (step-right-choice left right used)]
    [`(Returned ,_state) #f]
    ['Dead #f]
    [`(PendingDelay ,_inner) #f]))

(define (source-step tree)
  (unless (well-formed-tree? tree)
    (raise-arguments-error 'source-step
                           "term is not a well-formed pilot source tree"
                           "term" tree))
  (match (step-frontier tree (logical-vars-in tree))
    [#f #f]
    [(rewrite name owner next)
     (unless (well-formed-tree? next)
       (error 'source-step
              "rule ~a produced a malformed source tree: ~e"
              name
              next))
     (transition name owner next)]))

(define (source-trace tree [limit 256] [steps '()] [trees (list tree)])
  (match (source-step tree)
    [#f
     (values (reverse steps)
             tree
             (if (value-in-language? tree) 'value 'stuck)
             (reverse trees))]
    [_ #:when (zero? limit)
     (values (reverse steps) tree 'cap (reverse trees))]
    [(transition name owner next)
     (source-trace next
                   (sub1 limit)
                   (cons (list name owner) steps)
                   (cons next trees))]))

(define (frontier-events tree [events '()])
  (match tree
    [`(Emit ,answer ,rest)
     (frontier-events rest (cons `(emit ,answer) events))]
    [`(FrontierFresh ,intro ,rest ,tag)
     (frontier-events rest (cons `(frontier-fresh ,intro ,tag) events))]
    [`(Forced ,rest)
     (frontier-events rest (cons 'forced events))]
    [`(More ,_work)
     (reverse (cons 'more events))]
    ['Done
     (reverse (cons 'done events))]
    [`(Last ,answer)
     (reverse (cons `(last ,answer) events))]
    [_ #f]))

(define (answer-payloads tree [answers '()])
  (match tree
    [`(Emit ,answer ,rest)
     (answer-payloads rest (cons answer answers))]
    [`(FrontierFresh ,_intro ,rest ,_tag)
     (answer-payloads rest answers)]
    [`(Forced ,rest)
     (answer-payloads rest answers)]
    [`(More ,_work)
     (reverse answers)]
    ['Done
     (reverse answers)]
    [`(Last ,answer)
     (reverse (cons answer answers))]
    [_ #f]))

(define (answer->scoped answer owners)
  (match answer
    [`(Answer ,state)
     (scoped-answer state owners)]
    [`(AnswerFresh ,intro ,inner ,tag)
     (answer->scoped inner
                     (append owners (list (scope-owner intro tag))))]))

(define (scoped-answers tree [owners '()] [answers '()])
  (match tree
    [`(Emit ,answer ,rest)
     (scoped-answers rest
                     owners
                     (cons (answer->scoped answer owners) answers))]
    [`(FrontierFresh ,intro ,rest ,tag)
     (scoped-answers rest
                     (append owners (list (scope-owner intro tag)))
                     answers)]
    [`(Forced ,rest)
     (scoped-answers rest owners answers)]
    [`(More ,_work)
     (reverse answers)]
    ['Done
     (reverse answers)]
    [`(Last ,answer)
     (reverse (cons (answer->scoped answer owners) answers))]
    [_ #f]))

(define (extensional-answers tree)
  (match (scoped-answers tree)
    [#f #f]
    [answers
     (map scoped-answer-state answers)]))

(define (residual-tail tree)
  (match tree
    [`(Emit ,_answer ,rest) (residual-tail rest)]
    [`(FrontierFresh ,_intro ,rest ,_tag) (residual-tail rest)]
    [`(Forced ,rest) (residual-tail rest)]
    [`(More ,work) work]
    ['Done 'Done]
    [`(Last ,answer) `(Last ,answer)]
    [_ #f]))

(define (observe-source tree)
  (source-observation (frontier-events tree)
                      (scoped-answers tree)
                      (residual-tail tree)))

(define (next-tree-or-no-match tree)
  (match (source-step tree)
    [#f 'no-directed-step]
    [(transition _name _owner next) next]))

(define source-red
  (reduction-relation
   pilot-source-lang
   #:domain F
   [--> F_1 F_2
        (where F_2 ,(next-tree-or-no-match (term F_1)))
        "directed-source-step"]))
