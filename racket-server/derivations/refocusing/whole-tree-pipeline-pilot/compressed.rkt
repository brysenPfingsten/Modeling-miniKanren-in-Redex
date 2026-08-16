#lang racket

(require racket/list
         "./language.rkt"
         (prefix-in exact: "./refocused.rkt"))

(provide (struct-out CRun)
         (struct-out CSettled)
         (struct-out CDead)
         (struct-out CDelay)
         (struct-out CFinal)
         (struct-out rule-mark)
         (struct-out transition-span)
         (struct-out compressed-transition)
         initial-compressed
         compressed->refocused
         compressed-readback
         compressed-step
         compressed-trace)

;; These are residual control modes obtained from the mutually recursive
;; refocusing dispatchers.  Their constructor shapes, rather than a stored
;; sort tag, determine the grammatical category of each payload.
(struct CRun (work context) #:transparent)
(struct CSettled (result context) #:transparent)
(struct CDead (context) #:transparent)
(struct CDelay (work context) #:transparent)
(struct CFinal (terminal context) #:transparent)

(struct rule-mark (name owner) #:transparent)

;; A macro transition always accounts for at least one frozen source rule.
;; This is a trace-data invariant, not a term-sort compatibility test.
(struct transition-span (marks)
  #:transparent
  #:guard
  (lambda (marks constructor-name)
    (unless (and (pair? marks)
                 (andmap rule-mark? marks))
      (raise-argument-error
       constructor-name
       "(and/c pair? (listof rule-mark?))"
       marks))
    marks))

(struct compressed-transition (span next) #:transparent)

;; Private symbolic-composition data.  Unlike the five C constructors, this
;; structure is not a machine state or a residual control mode.
(struct symbolic-path (marks next) #:transparent)

(define (mark name owner)
  (rule-mark name owner))

(define (prefix-path first path)
  (match path
    [(symbolic-path rest next)
     (symbolic-path (cons first rest) next)]
    [#f #f]))

(define (path->transition path)
  (match path
    [(symbolic-path marks next)
     (compressed-transition (transition-span marks) next)]
    [#f #f]))

;; The following helpers are the pure allocation kernel from the frozen source
;; calculus.  The compressed control relation below does not call source-step,
;; contract, refocus-contract, or machine-step.
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

;; The Redex grammar fixes the W/F categories, while these structural checks
;; enforce the frozen source's additional distinct-binder invariant.  Keeping
;; them here avoids a semantic dependency on source.rkt.
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

(define (frontier-terminal-count frontier)
  (match frontier
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

(define (well-formed-frontier? frontier)
  (and (frontier-in-language? frontier)
       (= 1 (frontier-terminal-count frontier))))

(define (settled-success? work)
  (match work
    [`(Returned ,_state) #t]
    [`(WorkFresh ,_intro ,inner ,_tag)
     (settled-success? inner)]
    [_ #f]))

(define (settled-choice? work)
  (match work
    [`(DisjL ,active ,_alternate)
     (settled-success? active)]
    [`(DisjR ,_alternate ,active)
     (settled-success? active)]
    [_ #f]))

(define (settled-result? work)
  (or (settled-success? work)
      (settled-choice? work)))

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

;; Turn a W datum into its residual dispatcher without performing a source
;; rule.  In particular, a WorkFresh at More remains pending in CRun or
;; CSettled so the boundary exposure stays visible in the next span.
(define (residual-work work context)
  (match work
    ['Dead
     (CDead context)]
    [`(PendingDelay ,inner)
     (CDelay inner context)]
    [(? settled-result? result)
     (CSettled result context)]
    [_
     (CRun work context)]))

;; A newly produced unfinished WorkFresh at More has a statically known next
;; boundary rule.  Symbolic composition includes that rule before stopping at
;; the next residual dispatcher.  All other W data stop without inspection by
;; a further source rule.
(define (after-unfinished work context)
  (match context
    [`(wf-more ww-hole ,frontier-context)
     (match work
       [`(WorkFresh ,intro ,inner ,tag)
        (symbolic-path
         (list (mark "expose-frontier-fresh" 'core))
         (residual-work
          inner
          `(wf-more
            ww-hole
            (ff-frontier-fresh ,intro ,tag ,frontier-context))))]
       [_
        (symbolic-path '() (residual-work work context))])]
    [_
     (symbolic-path '() (residual-work work context))]))

;; Success and settled-choice propagation is the upward SCC.  It crosses
;; context frames silently until the next source rule, then stops at the
;; resulting residual dispatcher.
(define (step-settled result context)
  (match context
    [`(wf-more ,work-context ,frontier-context)
     (define (outer-context outer)
       `(wf-more ,outer ,frontier-context))
     (match work-context
       ['ww-hole
        (match result
          [`(Returned ,state)
           (symbolic-path
            (list (mark "finish-success" 'core))
            (CFinal `(Last (Answer ,state)) frontier-context))]
          [`(WorkFresh ,intro ,inner ,tag)
           #:when (settled-success? inner)
           (symbolic-path
            (list (mark "expose-frontier-fresh" 'core))
            (residual-work
             inner
             `(wf-more
               ww-hole
               (ff-frontier-fresh ,intro ,tag ,frontier-context))))]
          [`(DisjL ,active ,alternate)
           #:when (settled-success? active)
           (define answer
             (freeze-success active))
           (symbolic-path
            (list (mark "commit-choice-answer" 'disj))
            (residual-work
             alternate
             `(wf-more
               ww-hole
               (ff-emit ,answer ,frontier-context))))]
          [`(DisjR ,alternate ,active)
           #:when (settled-success? active)
           (define answer
             (freeze-success active))
           (symbolic-path
            (list (mark "commit-right-choice-answer" 'search-join))
            (residual-work
             alternate
             `(wf-more
               ww-hole
               (ff-emit ,answer ,frontier-context))))]
          [_ #f])]
       [`(ww-fresh ,intro ,tag ,outer)
        (match result
          [(? settled-success? success)
           (step-settled
            `(WorkFresh ,intro ,success ,tag)
            (outer-context outer))]
          [`(DisjL ,active ,alternate)
           #:when (settled-success? active)
           (symbolic-path
            (list (mark "expose-choice-through-work-fresh" 'disj))
            (CSettled
             `(DisjL (WorkFresh ,intro ,active ,tag)
                     (WorkFresh ,intro ,alternate ,tag))
             (outer-context outer)))]
          [`(DisjR ,alternate ,active)
           #:when (settled-success? active)
           (symbolic-path
            (list
             (mark "expose-choice-through-work-fresh" 'search-join))
            (CSettled
             `(DisjR (WorkFresh ,intro ,alternate ,tag)
                     (WorkFresh ,intro ,active ,tag))
             (outer-context outer)))]
          [_ #f])]
       [`(ww-conj ,goal ,outer)
        (match result
          [(? settled-success? success)
           (prefix-path
            (mark "conj-return" 'core)
            (after-unfinished
             (resume-success success goal)
             (outer-context outer)))]
          [`(DisjL ,active ,alternate)
           #:when (settled-success? active)
           (prefix-path
            (mark "late-distribute-settled" 'disj)
            (after-unfinished
             `(DisjL ,(resume-success active goal)
                     (Conj ,alternate ,goal))
             (outer-context outer)))]
          [`(DisjR ,alternate ,active)
           #:when (settled-success? active)
           (prefix-path
            (mark "late-distribute-right-settled" 'search-join)
            (after-unfinished
             `(DisjR (Conj ,alternate ,goal)
                     ,(resume-success active goal))
             (outer-context outer)))]
          [_ #f])]
       [`(ww-disj-left ,right ,outer)
        (match result
          [(? settled-success? success)
           (step-settled `(DisjL ,success ,right)
                         (outer-context outer))]
          [`(DisjL ,active ,alternate)
           #:when (settled-success? active)
           (symbolic-path
            (list (mark "reassociate-left-result" 'disj))
            (CSettled
             `(DisjL ,active (DisjL ,alternate ,right))
             (outer-context outer)))]
          [`(DisjR ,alternate ,active)
           #:when (settled-success? active)
           (symbolic-path
            (list (mark "reassociate-left-result" 'disj))
            (CSettled
             `(DisjL ,active (DisjL ,alternate ,right))
             (outer-context outer)))]
          [_ #f])]
       [`(ww-disj-right ,left ,outer)
        (match result
          [(? settled-success? success)
           (step-settled `(DisjR ,left ,success)
                         (outer-context outer))]
          [`(DisjL ,active ,alternate)
           #:when (settled-success? active)
           (symbolic-path
            (list (mark "reassociate-right-result" 'search-join))
            (CSettled
             `(DisjR (DisjR ,left ,alternate) ,active)
             (outer-context outer)))]
          [`(DisjR ,alternate ,active)
           #:when (settled-success? active)
           (symbolic-path
            (list (mark "reassociate-right-result" 'search-join))
            (CSettled
             `(DisjR (DisjR ,left ,alternate) ,active)
             (outer-context outer)))]
          [_ #f])]
       [_ #f])]
    [_ #f]))

;; Failure propagation is its own recursive dispatcher.  Each source rule
;; either returns to CDead through an outer frame or exposes an alternate W to
;; CRun; no generic exact-machine fallback is involved.
(define (step-dead context)
  (match context
    [`(wf-more ,work-context ,frontier-context)
     (define (outer-context outer)
       `(wf-more ,outer ,frontier-context))
     (match work-context
       ['ww-hole
        (symbolic-path
         (list (mark "finish-failure" 'core))
         (CFinal 'Done frontier-context))]
       [`(ww-fresh ,_intro ,_tag ,outer)
        (symbolic-path
         (list (mark "erase-dead-fresh" 'core))
         (CDead (outer-context outer)))]
       [`(ww-conj ,_goal ,outer)
        (symbolic-path
         (list (mark "conj-fail" 'core))
         (CDead (outer-context outer)))]
       [`(ww-disj-left ,right ,outer)
        (symbolic-path
         (list (mark "skip-left-failure" 'disj))
         (residual-work right (outer-context outer)))]
       [`(ww-disj-right ,left ,outer)
        (symbolic-path
         (list (mark "skip-right-failure" 'search-join))
         (residual-work left (outer-context outer)))]
       [_ #f])]
    [_ #f]))

;; Delay propagation is the rail/flip-flop dispatcher.  Returning CDelay is a
;; recursive SCC boundary; forcing at More crosses to CRun under an F frame.
(define (step-delay work context)
  (match context
    [`(wf-more ,work-context ,frontier-context)
     (define (outer-context outer)
       `(wf-more ,outer ,frontier-context))
     (match work-context
       ['ww-hole
        (symbolic-path
         (list (mark "force-delay" 'delay))
         (residual-work
          work
          `(wf-more ww-hole (ff-forced ,frontier-context))))]
       [`(ww-fresh ,intro ,tag ,outer)
        (symbolic-path
         (list (mark "bubble-delay-through-fresh" 'delay))
         (CDelay `(WorkFresh ,intro ,work ,tag)
                 (outer-context outer)))]
       [`(ww-conj ,goal ,outer)
        (symbolic-path
         (list (mark "bubble-delay-through-conj" 'delay))
         (CDelay `(Conj ,work ,goal)
                 (outer-context outer)))]
       [`(ww-disj-left ,right ,outer)
        (symbolic-path
         (list (mark "rail-enter-right" 'search-join))
         (CDelay `(DisjR ,work ,right)
                 (outer-context outer)))]
       [`(ww-disj-right ,left ,outer)
        (symbolic-path
         (list (mark "rail-return-left" 'search-join))
         (CDelay `(DisjL ,left ,work)
                 (outer-context outer)))]
       [_ #f])]
    [_ #f]))

(define (step-atomic goal state context)
  (match goal
    [`(succeed ,_tag)
     (prefix-path
      (mark "work-succeed" 'core)
      (step-settled `(Returned ,state) context))]
    [`(fail ,_tag)
     (prefix-path
      (mark "work-fail" 'core)
      (step-dead context))]
    [`(put ,payload ,_tag)
     (prefix-path
      (mark "work-put" 'core)
      (step-settled `(Returned (state ,payload)) context))]
    [`(fresh ,lexical ,body ,tag)
     (define intro
       (fresh-u-list
        (logical-vars-in (list `(Work ,goal ,state) context))
        lexical))
     (define bindings
       (map list lexical intro))
     (prefix-path
      (mark "allocate-fresh" 'core)
      (after-unfinished
       `(WorkFresh ,intro
                   (Work ,(substitute-goal body bindings) ,state)
                   ,tag)
       context))]
    [`(conj ,left ,right ,_tag)
     (prefix-path
      (mark "expand-conjunction" 'core)
      (after-unfinished `(Conj (Work ,left ,state) ,right)
                        context))]
    [`(disj ,left ,right ,_tag)
     (prefix-path
      (mark "expand-disjunction" 'disj)
      (after-unfinished
       `(DisjL (Work ,left ,state) (Work ,right ,state))
       context))]
    [`(suspend ,body ,_tag)
     (prefix-path
      (mark "suspend-goal" 'delay)
      (step-delay `(Work ,body ,state) context))]
    [_ #f]))

(define (step-work-fresh intro inner tag context)
  (match inner
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (symbolic-path
      (list (mark "expose-choice-through-work-fresh" 'disj))
      (CSettled
       `(DisjL (WorkFresh ,intro ,active ,tag)
               (WorkFresh ,intro ,alternate ,tag))
       context))]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (symbolic-path
      (list (mark "expose-choice-through-work-fresh" 'search-join))
      (CSettled
       `(DisjR (WorkFresh ,intro ,alternate ,tag)
               (WorkFresh ,intro ,active ,tag))
       context))]
    ['Dead
     (symbolic-path
      (list (mark "erase-dead-fresh" 'core))
      (CDead context))]
    [`(PendingDelay ,work)
     (symbolic-path
      (list (mark "bubble-delay-through-fresh" 'delay))
      (CDelay `(WorkFresh ,intro ,work ,tag) context))]
    [_
     (step-run inner
               (match context
                 [`(wf-more ,work-context ,frontier-context)
                  `(wf-more
                    (ww-fresh ,intro ,tag ,work-context)
                    ,frontier-context)]))]))

(define (step-conjunction left goal context)
  (match left
    [(? settled-success? success)
     (prefix-path
      (mark "conj-return" 'core)
      (after-unfinished (resume-success success goal) context))]
    ['Dead
     (symbolic-path
      (list (mark "conj-fail" 'core))
      (CDead context))]
    [`(PendingDelay ,work)
     (symbolic-path
      (list (mark "bubble-delay-through-conj" 'delay))
      (CDelay `(Conj ,work ,goal) context))]
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (prefix-path
      (mark "late-distribute-settled" 'disj)
      (after-unfinished
       `(DisjL ,(resume-success active goal)
               (Conj ,alternate ,goal))
       context))]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (prefix-path
      (mark "late-distribute-right-settled" 'search-join)
      (after-unfinished
       `(DisjR (Conj ,alternate ,goal)
               ,(resume-success active goal))
       context))]
    [_
     (step-run left
               (match context
                 [`(wf-more ,work-context ,frontier-context)
                  `(wf-more
                    (ww-conj ,goal ,work-context)
                    ,frontier-context)]))]))

(define (step-left-choice left right context)
  (match left
    ['Dead
     (symbolic-path
      (list (mark "skip-left-failure" 'disj))
      (residual-work right context))]
    [`(PendingDelay ,work)
     (symbolic-path
      (list (mark "rail-enter-right" 'search-join))
      (CDelay `(DisjR ,work ,right) context))]
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (symbolic-path
      (list (mark "reassociate-left-result" 'disj))
      (CSettled `(DisjL ,active (DisjL ,alternate ,right)) context))]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (symbolic-path
      (list (mark "reassociate-left-result" 'disj))
      (CSettled `(DisjL ,active (DisjL ,alternate ,right)) context))]
    [_
     (step-run left
               (match context
                 [`(wf-more ,work-context ,frontier-context)
                  `(wf-more
                    (ww-disj-left ,right ,work-context)
                    ,frontier-context)]))]))

(define (step-right-choice left right context)
  (match right
    ['Dead
     (symbolic-path
      (list (mark "skip-right-failure" 'search-join))
      (residual-work left context))]
    [`(PendingDelay ,work)
     (symbolic-path
      (list (mark "rail-return-left" 'search-join))
      (CDelay `(DisjL ,left ,work) context))]
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (symbolic-path
      (list (mark "reassociate-right-result" 'search-join))
      (CSettled `(DisjR (DisjR ,left ,alternate) ,active) context))]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (symbolic-path
      (list (mark "reassociate-right-result" 'search-join))
      (CSettled `(DisjR (DisjR ,left ,alternate) ,active) context))]
    [_
     (step-run right
               (match context
                 [`(wf-more ,work-context ,frontier-context)
                  `(wf-more
                    (ww-disj-right ,left ,work-context)
                    ,frontier-context)]))]))

;; Downward execution first honors the More priority, then follows W structure
;; without a source mark until it reaches the next direct contraction.
(define (step-run work context)
  (match context
    [`(wf-more ww-hole ,frontier-context)
     (match work
       [`(WorkFresh ,intro ,inner ,tag)
        (symbolic-path
         (list (mark "expose-frontier-fresh" 'core))
         (residual-work
          inner
          `(wf-more
            ww-hole
            (ff-frontier-fresh ,intro ,tag ,frontier-context))))]
       [(? settled-result? result)
        (step-settled result context)]
       ['Dead
        (step-dead context)]
       [`(PendingDelay ,inner)
        (step-delay inner context)]
       [_
        (step-run/local work context)])]
    [_
     (step-run/local work context)]))

(define (step-run/local work context)
  (match work
    [`(Work ,goal ,state)
     (step-atomic goal state context)]
    [(? settled-result? result)
     (step-settled result context)]
    ['Dead
     (step-dead context)]
    [`(PendingDelay ,inner)
     (step-delay inner context)]
    [`(WorkFresh ,intro ,inner ,tag)
     (step-work-fresh intro inner tag context)]
    [`(Conj ,left ,goal)
     (step-conjunction left goal context)]
    [`(DisjL ,left ,right)
     (step-left-choice left right context)]
    [`(DisjR ,left ,right)
     (step-right-choice left right context)]
    [_ #f]))

(define (initial-frontier frontier context)
  (match frontier
    [`(Emit ,answer ,rest)
     (initial-frontier rest `(ff-emit ,answer ,context))]
    [`(FrontierFresh ,intro ,rest ,tag)
     (initial-frontier
      rest
      `(ff-frontier-fresh ,intro ,tag ,context))]
    [`(Forced ,rest)
     (initial-frontier rest `(ff-forced ,context))]
    [`(More ,work)
     (residual-work work `(wf-more ww-hole ,context))]
    ['Done
     (CFinal 'Done context)]
    [`(Last ,answer)
     (CFinal `(Last ,answer) context)]))

(define (initial-compressed frontier)
  (unless (well-formed-frontier? frontier)
    (raise-arguments-error
     'initial-compressed
     "term is not a well-formed pilot source tree"
     "term" frontier))
  (initial-frontier frontier 'ff-hole))

;; This is a decoding function only.  The direct compressed transition system
;; above never calls it or any exact refocused transition function.
(define (compressed->refocused state)
  (match state
    [(CRun work context)
     (exact:refocus-work work context)]
    [(CSettled result context)
     (exact:refocus-work result context)]
    [(CDead context)
     (exact:refocus-work 'Dead context)]
    [(CDelay work context)
     (exact:refocus-work `(PendingDelay ,work) context)]
    [(CFinal terminal context)
     (exact:refocus-frontier terminal context)]
    [_
     (raise-argument-error
      'compressed->refocused
      "(or/c CRun? CSettled? CDead? CDelay? CFinal?)"
      state)]))

(define (compressed-readback state)
  (exact:readback (compressed->refocused state)))

(define (compressed-step state)
  (path->transition
   (match state
     [(CRun work context)
      (step-run work context)]
     [(CSettled result context)
      (step-settled result context)]
     [(CDead context)
      (step-dead context)]
     [(CDelay work context)
      (step-delay work context)]
     [(CFinal _terminal _context)
      #f]
     [_
      (raise-argument-error
       'compressed-step
       "(or/c CRun? CSettled? CDead? CDelay? CFinal?)"
       state)])))

(define (compressed-trace state
                          [limit 256]
                          [spans '()]
                          [states (list state)])
  (match (compressed-step state)
    [#f
     (values (reverse spans)
             state
             (if (value-in-language? (compressed-readback state))
                 'value
                 'stuck)
             (reverse states))]
    [_ #:when (zero? limit)
     (values (reverse spans) state 'cap (reverse states))]
    [(compressed-transition span next)
     (compressed-trace next
                       (sub1 limit)
                       (cons span spans)
                       (cons next states))]))
