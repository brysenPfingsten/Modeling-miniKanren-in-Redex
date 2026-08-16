#lang racket

(require racket/list
         redex/reduction-semantics
         "./languages.rkt")

(provide (struct-out policy)
         (struct-out presentation)
         (struct-out semantics)
         (struct-out transition)
         (struct-out decomposition)
         (struct-out contraction)
         (struct-out refocused-machine)
         (struct-out tree-observation)
         core-presentation
         delay-presentation
         disj-presentation
         search-presentation
         presentation-for
         make-semantics
         initial-tree
         well-formed-tree?
         frontier-events
         answer-payloads
         extensional-answers
         residual-tail
         observe-tree
         decompose
         plug
         contract
         source-step
         source-trace
         tree->machine
         machine->tree
         machine-step
         machine-trace
         core-red
         delay-red
         disj-early-red
         disj-late-red
         search-early-dfs-red
         search-late-dfs-red
         search-early-rail-red
         search-late-rail-red)

(struct policy (hoist scheduler) #:transparent)

;; These fields are the executable counterparts of <G,T,V,C,WF,->,O>.
(struct presentation
  (index goal-language tree-language value-language context-language
         well-formed reduction observations rule-owners)
  #:transparent)

(struct semantics (presentation policy) #:transparent)
(struct transition (name owner next) #:transparent)
(struct decomposition (sort focus context) #:transparent)
(struct contraction (name owner sort replacement context) #:transparent)
(struct refocused-machine (semantics sort focus context) #:transparent)
(struct tree-observation (events answers residual) #:transparent)
(struct choice-view (orientation fresh-frames left right) #:transparent)

(define all-rule-owners
  '(("work-succeed" . core)
    ("work-fail" . core)
    ("work-put" . core)
    ("allocate-fresh" . core)
    ("expose-frontier-fresh" . core)
    ("expand-conjunction" . core)
    ("conj-return" . core)
    ("conj-fail" . core)
    ("erase-dead-fresh" . core)
    ("finish-success" . core)
    ("finish-failure" . core)
    ("suspend-goal" . delay)
    ("bubble-delay-through-fresh" . delay)
    ("bubble-delay-through-conj" . delay)
    ("force-delay" . delay)
    ("expand-disjunction" . disj)
    ("early-distribute-choice" . disj)
    ("distribute-fresh-over-choice" . disj)
    ("reassociate-left-result" . disj)
    ("reassociate-right-result" . search-join)
    ("late-distribute-settled" . disj)
    ("commit-choice-answer" . disj)
    ("skip-left-failure" . disj)
    ("early-distribute-right-choice" . search-join)
    ("distribute-fresh-over-right-choice" . search-join)
    ("late-distribute-right-settled" . search-join)
    ("commit-right-choice-answer" . search-join)
    ("skip-right-failure" . search-join)
    ("dfs-carry-delay-left" . search-join)
    ("dfs-carry-delay-right" . search-join)
    ("rail-enter-right" . search-join)
    ("rail-return-left" . search-join)))

(define (owners-through index)
  (define included
    (match index
      ['core '(core)]
      ['delay '(core delay)]
      ['disj '(core disj)]
      ['search '(core delay disj search-join)]
      [_ '()]))
  (filter (lambda (entry) (member (cdr entry) included))
          all-rule-owners))

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
    [`(PendingDelay ,inner)
     (well-formed-work-structure? inner)]
    [`(Conj ,left ,right)
     (and (well-formed-work-structure? left)
          (well-formed-goal-structure? right))]
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
    [`(Emit ,answer ,rest)
     (if (well-formed-answer-structure? answer)
         (frontier-terminal-count rest)
         0)]
    [`(FrontierFresh ,intro ,rest ,_tag)
     (if (distinct-names? intro)
         (frontier-terminal-count rest)
         0)]
    [`(Forced ,rest)
     (frontier-terminal-count rest)]
    [_ 0]))

(define (well-formed-tree? index tree)
  (and (tree-in-language? index tree)
       (= 1 (frontier-terminal-count tree))))

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

(define (answer-state answer)
  (match answer
    [`(Answer ,state) state]
    [`(AnswerFresh ,_intro ,inner ,_tag)
     (answer-state inner)]))

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

(define (extensional-answers tree)
  (match (answer-payloads tree)
    [#f #f]
    [answers
     (map answer-state answers)]))

(define (residual-tail tree)
  (match tree
    [`(Emit ,_answer ,rest) (residual-tail rest)]
    [`(FrontierFresh ,_intro ,rest ,_tag) (residual-tail rest)]
    [`(Forced ,rest) (residual-tail rest)]
    [`(More ,work) work]
    ['Done 'Done]
    [`(Last ,answer) `(Last ,answer)]
    [_ #f]))

(define (observe-tree tree)
  (tree-observation (frontier-events tree)
                    (answer-payloads tree)
                    (residual-tail tree)))

(define (initial-tree goal [state '(state unit)])
  `(More (Work ,goal ,state)))

(define (default-hoist index)
  (if (member index '(disj search))
      'late
      'none))

(define (valid-policy? index candidate)
  (match-define (policy hoist scheduler) candidate)
  (and (if (member index '(disj search))
           (member hoist '(early late))
           (equal? hoist 'none))
       (if (equal? index 'search)
           (member scheduler '(dfs rail))
           (equal? scheduler 'dfs))))

(define (make-semantics index
                        #:hoist [hoist (default-hoist index)]
                        #:scheduler [scheduler 'dfs])
  (define selected-policy
    (policy hoist scheduler))
  (unless (valid-policy? index selected-policy)
    (raise-arguments-error 'make-semantics
                           "policy is not available at this feature node"
                           "index" index
                           "hoist" hoist
                           "scheduler" scheduler))
  (semantics (presentation-for index)
             selected-policy))

(define (system-index system)
  (presentation-index (semantics-presentation system)))

(define (fresh-choice-view work [fresh-frames '()])
  (match work
    [`(WorkFresh ,intro ,inner ,tag)
     (fresh-choice-view inner
                        (cons `(fresh-frame ,intro ,tag) fresh-frames))]
    [`(DisjL ,left ,right)
     (choice-view 'left fresh-frames left right)]
    [`(DisjR ,left ,right)
     (choice-view 'right fresh-frames left right)]
    [_ #f]))

(define (wrap-work work fresh-frames)
  (for/fold ([work* work])
            ([frame (in-list fresh-frames)])
    (match frame
      [`(fresh-frame ,intro ,tag)
       `(WorkFresh ,intro ,work* ,tag)])))

(define (decompose-frontier system tree [context '()])
  (match tree
    [`(Emit ,answer ,rest)
     (decompose-frontier system
                         rest
                         (cons `(emit-frame ,answer) context))]
    [`(FrontierFresh ,intro ,rest ,tag)
     (decompose-frontier system
                         rest
                         (cons `(frontier-fresh-frame ,intro ,tag) context))]
    [`(Forced ,rest)
     (decompose-frontier system rest (cons 'forced-frame context))]
    [`(More ,work)
     (decompose-work system work (cons 'more-frame context))]
    ['Done
     (decomposition 'F 'Done context)]
    [`(Last ,answer)
     (decomposition 'F `(Last ,answer) context)]))

(define (decompose-work system work context)
  (define selected-policy
    (semantics-policy system))
  (match work
    [`(WorkFresh ,_intro ,_inner ,_tag)
     #:when (equal? (first context) 'more-frame)
     (decomposition 'W work context)]
    [`(WorkFresh ,intro ,inner ,tag)
     (decompose-work system
                     inner
                     (cons `(fresh-frame ,intro ,tag) context))]
    [`(Conj ,left ,_right)
     #:when (and (equal? (policy-hoist selected-policy) 'early)
                 (fresh-choice-view left))
     (decomposition 'W work context)]
    [`(Conj ,left ,right)
     (decompose-work system left (cons `(conj-frame ,right) context))]
    [`(DisjL ,left ,right)
     (decompose-work system
                     left
                     (cons `(disj-left-frame ,right) context))]
    [`(DisjR ,left ,right)
     (decompose-work system
                     right
                     (cons `(disj-right-frame ,left) context))]
    [_
     (decomposition 'W work context)]))

(define (decompose system tree)
  (define index
    (system-index system))
  (unless (well-formed-tree? index tree)
    (raise-arguments-error 'decompose
                           "term is not a well-formed whole tree at this node"
                           "index" index
                           "term" tree))
  (decompose-frontier system tree))

(define (plug-frame term frame)
  (match frame
    [`(fresh-frame ,intro ,tag)
     `(WorkFresh ,intro ,term ,tag)]
    [`(conj-frame ,goal)
     `(Conj ,term ,goal)]
    [`(disj-left-frame ,right)
     `(DisjL ,term ,right)]
    [`(disj-right-frame ,left)
     `(DisjR ,left ,term)]
    ['more-frame
     `(More ,term)]
    [`(emit-frame ,answer)
     `(Emit ,answer ,term)]
    [`(frontier-fresh-frame ,intro ,tag)
     `(FrontierFresh ,intro ,term ,tag)]
    ['forced-frame
     `(Forced ,term)]))

(define (plug term context)
  (match context
    ['() term]
    [(cons frame rest)
     (plug (plug-frame term frame) rest)]))

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

(define (settle-choice-success orientation success alternate context)
  (match context
    [(cons `(fresh-frame ,intro ,tag) rest)
     (contraction
      (if (equal? orientation 'left)
          "distribute-fresh-over-choice"
          "distribute-fresh-over-right-choice")
      (if (equal? orientation 'left) 'disj 'search-join)
      'W
      (if (equal? orientation 'left)
          `(DisjL (WorkFresh ,intro ,success ,tag)
                  (WorkFresh ,intro ,alternate ,tag))
          `(DisjR (WorkFresh ,intro ,alternate ,tag)
                  (WorkFresh ,intro ,success ,tag)))
      rest)]
    [(cons `(conj-frame ,goal) rest)
     (contraction
      (if (equal? orientation 'left)
          "late-distribute-settled"
          "late-distribute-right-settled")
      (if (equal? orientation 'left) 'disj 'search-join)
      'W
      (if (equal? orientation 'left)
          `(DisjL ,(resume-success success goal)
                  (Conj ,alternate ,goal))
          `(DisjR (Conj ,alternate ,goal)
                  ,(resume-success success goal)))
      rest)]
    [(cons `(disj-left-frame ,outer-right) rest)
     (contraction
      "reassociate-left-result"
      'disj
      'W
      `(DisjL ,success (DisjL ,alternate ,outer-right))
      rest)]
    [(cons `(disj-right-frame ,outer-left) rest)
     (contraction
      "reassociate-right-result"
      'search-join
      'W
      `(DisjR (DisjR ,outer-left ,alternate) ,success)
      rest)]
    [(cons 'more-frame rest)
     (contraction (if (equal? orientation 'left)
                      "commit-choice-answer"
                      "commit-right-choice-answer")
                  (if (equal? orientation 'left) 'disj 'search-join)
                  'F
                  `(Emit ,(freeze-success success)
                         (More ,alternate))
                  rest)]
    [_ #f]))

(define (settle-success state context [success `(Returned ,state)])
  (match context
    [(cons `(fresh-frame ,intro ,tag) rest)
     (settle-success state
                     rest
                     `(WorkFresh ,intro ,success ,tag))]
    [(cons `(conj-frame ,goal) rest)
     (contraction "conj-return"
                  'core
                  'W
                  (resume-success success goal)
                  rest)]
    [(cons `(disj-left-frame ,right) rest)
     (settle-choice-success 'left success right rest)]
    [(cons `(disj-right-frame ,left) rest)
     (settle-choice-success 'right success left rest)]
    [(cons 'more-frame rest)
     (contraction "finish-success"
                  'core
                  'F
                  `(Last ,(freeze-success success))
                  rest)]
    [_ #f]))

(define (settle-dead context)
  (match context
    [(cons `(fresh-frame ,_intro ,_tag) rest)
     (contraction "erase-dead-fresh" 'core 'W 'Dead rest)]
    [(cons `(conj-frame ,_goal) rest)
     (contraction "conj-fail" 'core 'W 'Dead rest)]
    [(cons `(disj-left-frame ,right) rest)
     (contraction "skip-left-failure" 'disj 'W right rest)]
    [(cons `(disj-right-frame ,left) rest)
     (contraction "skip-right-failure" 'search-join 'W left rest)]
    [(cons 'more-frame rest)
     (contraction "finish-failure" 'core 'F 'Done rest)]
    [_ #f]))

(define (move-pending-delay system inner context)
  (define scheduler
    (policy-scheduler (semantics-policy system)))
  (match context
    [(cons `(fresh-frame ,intro ,tag) rest)
     (contraction "bubble-delay-through-fresh"
                  'delay
                  'W
                  `(PendingDelay (WorkFresh ,intro ,inner ,tag))
                  rest)]
    [(cons `(conj-frame ,goal) rest)
     (contraction "bubble-delay-through-conj"
                  'delay
                  'W
                  `(PendingDelay (Conj ,inner ,goal))
                  rest)]
    [(cons `(disj-left-frame ,right) rest)
     (contraction (if (equal? scheduler 'rail)
                      "rail-enter-right"
                      "dfs-carry-delay-left")
                  'search-join
                  'W
                  `(PendingDelay
                    ,(if (equal? scheduler 'rail)
                         `(DisjR ,inner ,right)
                         `(DisjL ,inner ,right)))
                  rest)]
    [(cons `(disj-right-frame ,left) rest)
     (contraction (if (equal? scheduler 'rail)
                      "rail-return-left"
                      "dfs-carry-delay-right")
                  'search-join
                  'W
                  `(PendingDelay
                    ,(if (equal? scheduler 'rail)
                         `(DisjL ,left ,inner)
                         `(DisjR ,left ,inner)))
                  rest)]
    [(cons 'more-frame rest)
     (contraction "force-delay"
                  'delay
                  'F
                  `(Forced (More ,inner))
                  rest)]
    [_ #f]))

(define (contract-work goal state context)
  (match goal
    [`(succeed ,_tag)
     (contraction "work-succeed" 'core 'W `(Returned ,state) context)]
    [`(fail ,_tag)
     (contraction "work-fail" 'core 'W 'Dead context)]
    [`(put ,payload ,_tag)
     (contraction "work-put" 'core 'W `(Returned (state ,payload)) context)]
    [`(fresh ,lexical ,body ,tag)
     (define intro
       (fresh-u-list (logical-vars-in (list goal state context)) lexical))
     (define bindings
       (map list lexical intro))
     (contraction "allocate-fresh"
                  'core
                  'W
                  `(WorkFresh ,intro
                              (Work ,(substitute-goal body bindings) ,state)
                              ,tag)
                  context)]
    [`(conj ,left ,right ,_tag)
     (contraction "expand-conjunction"
                  'core
                  'W
                  `(Conj (Work ,left ,state) ,right)
                  context)]
    [`(disj ,left ,right ,_tag)
     (contraction "expand-disjunction"
                  'disj
                  'W
                  `(DisjL (Work ,left ,state) (Work ,right ,state))
                  context)]
    [`(suspend ,body ,_tag)
     (contraction "suspend-goal"
                  'delay
                  'W
                  `(PendingDelay (Work ,body ,state))
                  context)]
    [_ #f]))

(define (contract-early-conjunction focus context)
  (match focus
    [`(Conj ,left ,goal)
     (match (fresh-choice-view left)
       [(choice-view orientation fresh-frames branch-left branch-right)
        (define next-left
          `(Conj ,(wrap-work branch-left fresh-frames) ,goal))
        (define next-right
          `(Conj ,(wrap-work branch-right fresh-frames) ,goal))
        (contraction (if (equal? orientation 'right)
                         "early-distribute-right-choice"
                         "early-distribute-choice")
                     (if (equal? orientation 'right)
                         'search-join
                         'disj)
                     'W
                     (if (equal? orientation 'right)
                         `(DisjR ,next-left ,next-right)
                         `(DisjL ,next-left ,next-right))
                     context)]
       [_ #f])]
    [_ #f]))

(define (contract system decomposition-result)
  (match-define (decomposition _sort focus context)
    decomposition-result)
  (match focus
    [`(Work ,goal ,state)
     (contract-work goal state context)]
    [`(WorkFresh ,intro ,inner ,tag)
     #:when (and (pair? context)
                 (equal? (first context) 'more-frame))
     (contraction "expose-frontier-fresh"
                  'core
                  'F
                  `(FrontierFresh ,intro (More ,inner) ,tag)
                  (rest context))]
    [`(Conj ,_left ,_goal)
     (contract-early-conjunction focus context)]
    [`(Returned ,state)
     (settle-success state context)]
    ['Dead
     (settle-dead context)]
    [`(PendingDelay ,inner)
     (move-pending-delay system inner context)]
    [_ #f]))

(define (refocus system sort replacement context)
  (match sort
    ['F (decompose-frontier system replacement context)]
    ['W (decompose-work system replacement context)]))

(define (source-step/index index selected-policy tree)
  (unless (well-formed-tree? index tree)
    (raise-arguments-error 'source-step
                           "term is not a well-formed whole tree at this node"
                           "index" index
                           "term" tree))
  (define system
    (semantics (presentation-for index) selected-policy))
  (match (contract system (decompose system tree))
    [#f #f]
    [(contraction name owner _sort replacement context)
     (define next
       (plug replacement context))
     (unless (well-formed-tree? index next)
       (error 'source-step
              "rule ~a produced a malformed ~a tree: ~e"
              name
              index
              next))
     (transition name owner next)]))

(define (source-step system tree)
  ((presentation-reduction (semantics-presentation system))
   (semantics-policy system)
   tree))

(define (source-trace system tree [limit 128] [steps '()] [trees (list tree)])
  (match (source-step system tree)
    [#f
     (values (reverse steps)
             tree
             (if ((presentation-value-language
                   (semantics-presentation system))
                  tree)
                 'value
                 'stuck)
             (reverse trees))]
    [_ #:when (zero? limit)
     (values (reverse steps) tree 'cap (reverse trees))]
    [(transition name owner next)
     (source-trace system
                   next
                   (sub1 limit)
                   (cons (list name owner) steps)
                   (cons next trees))]))

(define (tree->machine system tree)
  (match-define (decomposition sort focus context)
    (decompose system tree))
  (refocused-machine system sort focus context))

(define (machine->tree machine)
  (match machine
    [(refocused-machine _system _sort focus context)
     (plug focus context)]))

(define (machine-step machine)
  (match machine
    [(refocused-machine system _sort _focus _context)
     (match (contract system
                      (decomposition (refocused-machine-sort machine)
                                     (refocused-machine-focus machine)
                                     (refocused-machine-context machine)))
       [#f #f]
       [(contraction name owner sort replacement context)
        (match-define (decomposition next-sort next-focus next-context)
          (refocus system sort replacement context))
        (transition name
                    owner
                    (refocused-machine system
                                       next-sort
                                       next-focus
                                       next-context))])]))

(define (machine-trace machine [limit 128] [steps '()] [machines (list machine)])
  (match (machine-step machine)
    [#f
     (define tree
       (machine->tree machine))
     (values (reverse steps)
             machine
             (if ((presentation-value-language
                   (semantics-presentation
                    (refocused-machine-semantics machine)))
                  tree)
                 'value
                 'stuck)
             (reverse machines))]
    [_ #:when (zero? limit)
     (values (reverse steps) machine 'cap (reverse machines))]
    [(transition name owner next)
     (machine-trace next
                    (sub1 limit)
                    (cons (list name owner) steps)
                    (cons next machines))]))

(define (make-presentation index)
  (presentation
   index
   (lambda (goal) (goal-in-language? index goal))
   (lambda (tree) (tree-in-language? index tree))
   (lambda (value) (value-in-language? index value))
   (lambda (context) (context-in-language? index context))
   (lambda (tree) (well-formed-tree? index tree))
   (lambda (selected-policy tree)
     (source-step/index index selected-policy tree))
   observe-tree
   (owners-through index)))

(define core-presentation
  (make-presentation 'core))

(define delay-presentation
  (make-presentation 'delay))

(define disj-presentation
  (make-presentation 'disj))

(define search-presentation
  (make-presentation 'search))

(define (presentation-for index)
  (match index
    ['core core-presentation]
    ['delay delay-presentation]
    ['disj disj-presentation]
    ['search search-presentation]
    [_ (raise-argument-error 'presentation-for
                             "(or/c 'core 'delay 'disj 'search)"
                             index)]))

(define core-system
  (make-semantics 'core))
(define delay-system
  (make-semantics 'delay))
(define disj-early-system
  (make-semantics 'disj #:hoist 'early))
(define disj-late-system
  (make-semantics 'disj #:hoist 'late))
(define search-early-dfs-system
  (make-semantics 'search #:hoist 'early #:scheduler 'dfs))
(define search-late-dfs-system
  (make-semantics 'search #:hoist 'late #:scheduler 'dfs))
(define search-early-rail-system
  (make-semantics 'search #:hoist 'early #:scheduler 'rail))
(define search-late-rail-system
  (make-semantics 'search #:hoist 'late #:scheduler 'rail))

(define (next-tree-or-no-match system tree)
  (match (source-step system tree)
    [#f 'no-directed-step]
    [(transition _name _owner next) next]))

(define-syntax-rule (define-whole-relation name language system)
  (define name
    (reduction-relation
     language
     #:domain F
     [--> F_1 F_2
          (where F_2 ,(next-tree-or-no-match system (term F_1)))
          "directed-step"])))

(define-whole-relation core-red whole-core-lang core-system)
(define-whole-relation delay-red whole-delay-lang delay-system)
(define-whole-relation disj-early-red whole-disj-lang disj-early-system)
(define-whole-relation disj-late-red whole-disj-lang disj-late-system)
(define-whole-relation search-early-dfs-red
  whole-search-lang
  search-early-dfs-system)
(define-whole-relation search-late-dfs-red
  whole-search-lang
  search-late-dfs-system)
(define-whole-relation search-early-rail-red
  whole-search-lang
  search-early-rail-system)
(define-whole-relation search-late-rail-red
  whole-search-lang
  search-late-rail-system)
