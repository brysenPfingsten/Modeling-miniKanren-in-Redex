#lang racket

(require racket/list
         redex/reduction-semantics
         "./language.rkt")

(provide pilot-decomposition-lang
         ww-context-in-language?
         wf-context-in-language?
         ff-context-in-language?
         (struct-out DecWork)
         (struct-out DecFrontier)
         (struct-out ContractWork)
         (struct-out ContractFrontier)
         (struct-out derived-transition)
         plug-ww
         plug-wf
         plug-ff
         plug
         plug-contract
         decompose
         contract
         derived-source-step)

(check-redundancy #t)

;; The three context families are an indexed inductive structure.  Their
;; input/output categories are implicit in their grammar, rather than stored as
;; W/F tags in a context, decomposition, contraction, or machine state.
(define-extended-language pilot-decomposition-lang pilot-source-lang
  ;; A W hole whose completed context is another W.
  [WWCtx ww-hole
         (ww-fresh intro tag WWCtx)
         (ww-conj g WWCtx)
         (ww-disj-left W WWCtx)
         (ww-disj-right W WWCtx)]

  ;; An F hole whose completed context is another F.
  [FFCtx ff-hole
         (ff-frontier-fresh intro tag FFCtx)
         (ff-emit A FFCtx)
         (ff-forced FFCtx)]

  ;; The unique W-to-F bridge is More.  Its inner W-to-W and outer F-to-F
  ;; contexts retain the grammatical indices on either side of that bridge.
  [WFCtx (wf-more WWCtx FFCtx)])

(struct DecWork (focus context) #:transparent)
(struct DecFrontier (focus context) #:transparent)

;; The constructor determines the category of both replacement and context.
;; No separate result-sort field or compatibility condition is needed.
(struct ContractWork (name owner replacement context) #:transparent)
(struct ContractFrontier (name owner replacement context) #:transparent)

;; This stage deliberately owns its transition result instead of importing the
;; frozen source reducer's transition structure.
(struct derived-transition (name owner next) #:transparent)

(define (ww-context-in-language? term)
  (redex-match? pilot-decomposition-lang WWCtx term))

(define (wf-context-in-language? term)
  (redex-match? pilot-decomposition-lang WFCtx term))

(define (ff-context-in-language? term)
  (redex-match? pilot-decomposition-lang FFCtx term))

;; Contexts are stored nearest frame first.  Plugging applies that frame and
;; then continues toward the root.
(define (plug-ww work context)
  (match context
    ['ww-hole work]
    [`(ww-fresh ,intro ,tag ,outer)
     (plug-ww `(WorkFresh ,intro ,work ,tag) outer)]
    [`(ww-conj ,goal ,outer)
     (plug-ww `(Conj ,work ,goal) outer)]
    [`(ww-disj-left ,right ,outer)
     (plug-ww `(DisjL ,work ,right) outer)]
    [`(ww-disj-right ,left ,outer)
     (plug-ww `(DisjR ,left ,work) outer)]
    [_
     (raise-argument-error 'plug-ww
                           "ww-context-in-language?"
                           context)]))

(define (plug-ff frontier context)
  (match context
    ['ff-hole frontier]
    [`(ff-frontier-fresh ,intro ,tag ,outer)
     (plug-ff `(FrontierFresh ,intro ,frontier ,tag) outer)]
    [`(ff-emit ,answer ,outer)
     (plug-ff `(Emit ,answer ,frontier) outer)]
    [`(ff-forced ,outer)
     (plug-ff `(Forced ,frontier) outer)]
    [_
     (raise-argument-error 'plug-ff
                           "ff-context-in-language?"
                           context)]))

(define (plug-wf work context)
  (match context
    [`(wf-more ,work-context ,frontier-context)
     (plug-ff `(More ,(plug-ww work work-context))
              frontier-context)]
    [_
     (raise-argument-error 'plug-wf
                           "wf-context-in-language?"
                           context)]))

;; Public reconstruction accepts the indexed result as one value.  Callers do
;; not pass an unclassified focus/context pair to a generic compatibility test.
(define (plug decomposition-result)
  (match decomposition-result
    [(DecWork focus context)
     (plug-wf focus context)]
    [(DecFrontier focus context)
     (plug-ff focus context)]
    [_
     (raise-argument-error 'plug
                           "(or/c DecWork? DecFrontier?)"
                           decomposition-result)]))

(define (plug-contract contraction-result)
  (match contraction-result
    [(ContractWork _name _owner replacement context)
     (plug-wf replacement context)]
    [(ContractFrontier _name _owner replacement context)
     (plug-ff replacement context)]
    [_
     (raise-argument-error
      'plug-contract
      "(or/c ContractWork? ContractFrontier?)"
      contraction-result)]))

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
     `(suspend ,(substitute-goal body bindings) ,tag)]
    [_
     (error 'substitute-goal "unsupported goal form: ~e" goal)]))

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

(define (settled-success? work)
  (redex-match? pilot-source-lang S work))

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

;; These predicates encode source redex selection, not category compatibility.
;; They ensure that decomposition focuses the compound redex named by the frozen
;; source rule instead of descending to a smaller child that has no such step.
(define (work-fresh-redex? inner)
  (match inner
    ['Dead #t]
    [`(PendingDelay ,_work) #t]
    [`(DisjL ,active ,_alternate)
     (settled-success? active)]
    [`(DisjR ,_alternate ,active)
     (settled-success? active)]
    [_ #f]))

(define (conjunction-redex? left)
  (or (settled-success? left)
      (equal? left 'Dead)
      (match left
        [`(PendingDelay ,_work) #t]
        [_ #f])
      (and (settled-choice-view left) #t)))

(define (active-choice-redex? active)
  (or (equal? active 'Dead)
      (match active
        [`(PendingDelay ,_work) #t]
        [_ #f])
      (and (settled-choice-view active) #t)))

(define (work-redex? work)
  (match work
    [`(Work ,_goal ,_state) #t]
    [`(WorkFresh ,_intro ,inner ,_tag)
     (work-fresh-redex? inner)]
    [`(Conj ,left ,_goal)
     (conjunction-redex? left)]
    [`(DisjL ,left ,_right)
     (active-choice-redex? left)]
    [`(DisjR ,_left ,right)
     (active-choice-redex? right)]
    [_ #f]))

;; These rules have priority specifically at the More boundary.
(define (more-redex? work)
  (match work
    [`(WorkFresh ,_intro ,_inner ,_tag) #t]
    [`(Returned ,_state) #t]
    ['Dead #t]
    [`(PendingDelay ,_inner) #t]
    [`(DisjL ,active ,_alternate)
     (settled-success? active)]
    [`(DisjR ,_alternate ,active)
     (settled-success? active)]
    [_ #f]))

(define (decompose-work work work-context frontier-context)
  (cond
    [(work-redex? work)
     (DecWork work `(wf-more ,work-context ,frontier-context))]
    [else
     (match work
       [`(WorkFresh ,intro ,inner ,tag)
        (decompose-work inner
                        `(ww-fresh ,intro ,tag ,work-context)
                        frontier-context)]
       [`(Conj ,left ,goal)
        (decompose-work left
                        `(ww-conj ,goal ,work-context)
                        frontier-context)]
       [`(DisjL ,left ,right)
        (decompose-work left
                        `(ww-disj-left ,right ,work-context)
                        frontier-context)]
       [`(DisjR ,left ,right)
        (decompose-work right
                        `(ww-disj-right ,left ,work-context)
                        frontier-context)]
       [_
        ;; A terminal W below an unhandled W frame witnesses a stuck source
        ;; shape.  Retaining it as the focus makes contract return #f exactly as
        ;; the direct source traversal does.
        (DecWork work `(wf-more ,work-context ,frontier-context))])]))

(define (decompose-more work frontier-context)
  (if (more-redex? work)
      (DecWork work `(wf-more ww-hole ,frontier-context))
      (decompose-work work 'ww-hole frontier-context)))

(define (decompose-frontier frontier [frontier-context 'ff-hole])
  (match frontier
    [`(Emit ,answer ,rest)
     (decompose-frontier rest
                         `(ff-emit ,answer ,frontier-context))]
    [`(FrontierFresh ,intro ,rest ,tag)
     (decompose-frontier
      rest
      `(ff-frontier-fresh ,intro ,tag ,frontier-context))]
    [`(Forced ,rest)
     (decompose-frontier rest `(ff-forced ,frontier-context))]
    [`(More ,work)
     (decompose-more work frontier-context)]
    ['Done
     (DecFrontier 'Done frontier-context)]
    [`(Last ,answer)
     (DecFrontier `(Last ,answer) frontier-context)]
    [_
     (error 'decompose-frontier
            "unsupported frontier form: ~e"
            frontier)]))

(define (decompose frontier)
  (unless (well-formed-tree? frontier)
    (raise-arguments-error 'decompose
                           "term is not a well-formed pilot source tree"
                           "term" frontier))
  (decompose-frontier frontier))

(define (contract-more work frontier-context)
  (match work
    [`(WorkFresh ,intro ,inner ,tag)
     (ContractFrontier
      "expose-frontier-fresh"
      'core
      `(FrontierFresh ,intro (More ,inner) ,tag)
      frontier-context)]
    [`(Returned ,state)
     (ContractFrontier
      "finish-success"
      'core
      `(Last (Answer ,state))
      frontier-context)]
    ['Dead
     (ContractFrontier "finish-failure" 'core 'Done frontier-context)]
    [`(PendingDelay ,inner)
     (ContractFrontier
      "force-delay"
      'delay
      `(Forced (More ,inner))
      frontier-context)]
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (ContractFrontier
      "commit-choice-answer"
      'disj
      `(Emit ,(freeze-success active) (More ,alternate))
      frontier-context)]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (ContractFrontier
      "commit-right-choice-answer"
      'search-join
      `(Emit ,(freeze-success active) (More ,alternate))
      frontier-context)]
    [_ #f]))

(define (contract-atomic-work goal state used context)
  (match goal
    [`(succeed ,_tag)
     (ContractWork "work-succeed" 'core `(Returned ,state) context)]
    [`(fail ,_tag)
     (ContractWork "work-fail" 'core 'Dead context)]
    [`(put ,payload ,_tag)
     (ContractWork
      "work-put"
      'core
      `(Returned (state ,payload))
      context)]
    [`(fresh ,lexical ,body ,tag)
     (define intro
       (fresh-u-list used lexical))
     (define bindings
       (map list lexical intro))
     (ContractWork
      "allocate-fresh"
      'core
      `(WorkFresh ,intro
                  (Work ,(substitute-goal body bindings) ,state)
                  ,tag)
      context)]
    [`(conj ,left ,right ,_tag)
     (ContractWork
      "expand-conjunction"
      'core
      `(Conj (Work ,left ,state) ,right)
      context)]
    [`(disj ,left ,right ,_tag)
     (ContractWork
      "expand-disjunction"
      'disj
      `(DisjL (Work ,left ,state) (Work ,right ,state))
      context)]
    [`(suspend ,body ,_tag)
     (ContractWork
      "suspend-goal"
      'delay
      `(PendingDelay (Work ,body ,state))
      context)]
    [_ #f]))

(define (contract-work-fresh intro inner tag context)
  (match inner
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (ContractWork
      "expose-choice-through-work-fresh"
      'disj
      `(DisjL (WorkFresh ,intro ,active ,tag)
              (WorkFresh ,intro ,alternate ,tag))
      context)]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (ContractWork
      "expose-choice-through-work-fresh"
      'search-join
      `(DisjR (WorkFresh ,intro ,alternate ,tag)
              (WorkFresh ,intro ,active ,tag))
      context)]
    ['Dead
     (ContractWork "erase-dead-fresh" 'core 'Dead context)]
    [`(PendingDelay ,work)
     (ContractWork
      "bubble-delay-through-fresh"
      'delay
      `(PendingDelay (WorkFresh ,intro ,work ,tag))
      context)]
    [_ #f]))

(define (contract-conjunction left goal context)
  (match left
    [(? settled-success? success)
     (ContractWork
      "conj-return"
      'core
      (resume-success success goal)
      context)]
    ['Dead
     (ContractWork "conj-fail" 'core 'Dead context)]
    [`(PendingDelay ,work)
     (ContractWork
      "bubble-delay-through-conj"
      'delay
      `(PendingDelay (Conj ,work ,goal))
      context)]
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (ContractWork
      "late-distribute-settled"
      'disj
      `(DisjL ,(resume-success active goal)
              (Conj ,alternate ,goal))
      context)]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (ContractWork
      "late-distribute-right-settled"
      'search-join
      `(DisjR (Conj ,alternate ,goal)
              ,(resume-success active goal))
      context)]
    [_ #f]))

(define (contract-left-choice left right context)
  (match left
    ['Dead
     (ContractWork "skip-left-failure" 'disj right context)]
    [`(PendingDelay ,work)
     (ContractWork
      "rail-enter-right"
      'search-join
      `(PendingDelay (DisjR ,work ,right))
      context)]
    [_
     (match (settled-choice-view left)
       [(list _orientation success alternate)
        (ContractWork
         "reassociate-left-result"
         'disj
         `(DisjL ,success (DisjL ,alternate ,right))
         context)]
       [_ #f])]))

(define (contract-right-choice left right context)
  (match right
    ['Dead
     (ContractWork "skip-right-failure" 'search-join left context)]
    [`(PendingDelay ,work)
     (ContractWork
      "rail-return-left"
      'search-join
      `(PendingDelay (DisjL ,left ,work))
      context)]
    [_
     (match (settled-choice-view right)
       [(list _orientation success alternate)
        (ContractWork
         "reassociate-right-result"
         'search-join
         `(DisjR (DisjR ,left ,alternate) ,success)
         context)]
       [_ #f])]))

(define (contract-local focus context used)
  (match focus
    [`(Work ,goal ,state)
     (contract-atomic-work goal state used context)]
    [`(WorkFresh ,intro ,inner ,tag)
     (contract-work-fresh intro inner tag context)]
    [`(Conj ,left ,goal)
     (contract-conjunction left goal context)]
    [`(DisjL ,left ,right)
     (contract-left-choice left right context)]
    [`(DisjR ,left ,right)
     (contract-right-choice left right context)]
    [_ #f]))

(define (contract decomposition-result)
  (match decomposition-result
    [(DecFrontier _focus _context)
     #f]
    [(DecWork focus
              (and context
                   `(wf-more ,work-context ,frontier-context)))
     ;; More owns its boundary rules.  In particular, this case must precede
     ;; expose-choice-through-work-fresh for any WorkFresh at ww-hole.
     (or (and (equal? work-context 'ww-hole)
              (contract-more focus frontier-context))
         (contract-local focus
                         context
                         (logical-vars-in
                          (list focus context))))]
    [_
     (raise-argument-error 'contract
                           "(or/c DecWork? DecFrontier?)"
                           decomposition-result)]))

(define (derived-source-step frontier)
  (unless (well-formed-tree? frontier)
    (raise-arguments-error
     'derived-source-step
     "term is not a well-formed pilot source tree"
     "term" frontier))
  (match (contract (decompose frontier))
    [#f #f]
    [(and result
          (or (ContractWork name owner _replacement _context)
              (ContractFrontier name owner _replacement _context)))
     (define next
       (plug-contract result))
     (unless (well-formed-tree? next)
       (error 'derived-source-step
              "rule ~a produced a malformed source tree: ~e"
              name
              next))
     (derived-transition name owner next)]))
