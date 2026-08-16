#lang racket

(require racket/list
         "./language.rkt"
         (only-in "./decomposition.rkt"
                  ff-context-in-language?
                  plug-ff
                  plug-wf
                  wf-context-in-language?))

(provide (struct-out PromotedFinal)
         (struct-out PromotedStuck)
         fixed-point-evaluate
         fixed-point-readback
         fixed-run
         fixed-settled
         fixed-dead
         fixed-delay
         fixed-final)

;; Fixed-point promotion eliminates the compressed transport layer.  These are
;; evaluator outcomes, not control modes: their constructors encode the two
;; genuinely different result shapes without a reified W/F field.
(struct PromotedFinal (terminal context) #:transparent)
(struct PromotedStuck (work context) #:transparent)

;; This allocation kernel is copied from the frozen calculus.  The promoted
;; evaluator does not call a source, decomposition, refocused, or compressed
;; transition function.
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

;; The grammar fixes the W/F categories.  These structural checks additionally
;; preserve the frozen source's distinct-binder invariant at root entry.
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

;; These two dispatchers are the constructor-erased images of residual-work
;; and after-unfinished.  They tail-call the promoted control functions rather
;; than constructing an intermediate mode or transport value.
(define (continue-work work context)
  (match work
    ['Dead
     (dead context)]
    [`(PendingDelay ,inner)
     (delay inner context)]
    [(? settled-result? result)
     (settled result context)]
    [_
     (run work context)]))

(define (continue-unfinished work context)
  (match context
    [`(wf-more ww-hole ,frontier-context)
     (match work
       [`(WorkFresh ,intro ,inner ,tag)
        (continue-work
         inner
         `(wf-more
           ww-hole
           (ff-frontier-fresh ,intro ,tag ,frontier-context)))]
       [_
        (continue-work work context)])]
    [_
     (continue-work work context)]))

;; The five private functions are the fixed-point-promoted images of the five
;; checkpoint-4 constructors.  Every recursive edge is a direct tail call.
(define (settled result context)
  (match context
    [`(wf-more ,work-context ,frontier-context)
     (match work-context
       ['ww-hole
        (match result
          [`(Returned ,state)
           (final `(Last (Answer ,state)) frontier-context)]
          [`(WorkFresh ,intro ,inner ,tag)
           #:when (settled-success? inner)
           (continue-work
            inner
            `(wf-more
              ww-hole
              (ff-frontier-fresh ,intro ,tag ,frontier-context)))]
          [`(DisjL ,active ,alternate)
           #:when (settled-success? active)
           (continue-work
            alternate
            `(wf-more
              ww-hole
              (ff-emit ,(freeze-success active) ,frontier-context)))]
          [`(DisjR ,alternate ,active)
           #:when (settled-success? active)
           (continue-work
            alternate
            `(wf-more
              ww-hole
              (ff-emit ,(freeze-success active) ,frontier-context)))]
          [_
           (PromotedStuck result context)])]
       [`(ww-fresh ,intro ,tag ,outer)
        (match result
          [(? settled-success? success)
           (settled `(WorkFresh ,intro ,success ,tag)
                    `(wf-more ,outer ,frontier-context))]
          [`(DisjL ,active ,alternate)
           #:when (settled-success? active)
           (settled
            `(DisjL (WorkFresh ,intro ,active ,tag)
                    (WorkFresh ,intro ,alternate ,tag))
            `(wf-more ,outer ,frontier-context))]
          [`(DisjR ,alternate ,active)
           #:when (settled-success? active)
           (settled
            `(DisjR (WorkFresh ,intro ,alternate ,tag)
                    (WorkFresh ,intro ,active ,tag))
            `(wf-more ,outer ,frontier-context))]
          [_
           (PromotedStuck result context)])]
       [`(ww-conj ,goal ,outer)
        (match result
          [(? settled-success? success)
           (continue-unfinished
            (resume-success success goal)
            `(wf-more ,outer ,frontier-context))]
          [`(DisjL ,active ,alternate)
           #:when (settled-success? active)
           (continue-unfinished
            `(DisjL ,(resume-success active goal)
                    (Conj ,alternate ,goal))
            `(wf-more ,outer ,frontier-context))]
          [`(DisjR ,alternate ,active)
           #:when (settled-success? active)
           (continue-unfinished
            `(DisjR (Conj ,alternate ,goal)
                    ,(resume-success active goal))
            `(wf-more ,outer ,frontier-context))]
          [_
           (PromotedStuck result context)])]
       [`(ww-disj-left ,right ,outer)
        (match result
          [(? settled-success? success)
           (settled `(DisjL ,success ,right)
                    `(wf-more ,outer ,frontier-context))]
          [`(DisjL ,active ,alternate)
           #:when (settled-success? active)
           (settled `(DisjL ,active (DisjL ,alternate ,right))
                    `(wf-more ,outer ,frontier-context))]
          [`(DisjR ,alternate ,active)
           #:when (settled-success? active)
           (settled `(DisjL ,active (DisjL ,alternate ,right))
                    `(wf-more ,outer ,frontier-context))]
          [_
           (PromotedStuck result context)])]
       [`(ww-disj-right ,left ,outer)
        (match result
          [(? settled-success? success)
           (settled `(DisjR ,left ,success)
                    `(wf-more ,outer ,frontier-context))]
          [`(DisjL ,active ,alternate)
           #:when (settled-success? active)
           (settled `(DisjR (DisjR ,left ,alternate) ,active)
                    `(wf-more ,outer ,frontier-context))]
          [`(DisjR ,alternate ,active)
           #:when (settled-success? active)
           (settled `(DisjR (DisjR ,left ,alternate) ,active)
                    `(wf-more ,outer ,frontier-context))]
          [_
           (PromotedStuck result context)])]
       [_
        (PromotedStuck result context)])]
    [_
     (PromotedStuck result context)]))

(define (dead context)
  (match context
    [`(wf-more ,work-context ,frontier-context)
     (match work-context
       ['ww-hole
        (final 'Done frontier-context)]
       [`(ww-fresh ,_intro ,_tag ,outer)
        (dead `(wf-more ,outer ,frontier-context))]
       [`(ww-conj ,_goal ,outer)
        (dead `(wf-more ,outer ,frontier-context))]
       [`(ww-disj-left ,right ,outer)
        (continue-work right `(wf-more ,outer ,frontier-context))]
       [`(ww-disj-right ,left ,outer)
        (continue-work left `(wf-more ,outer ,frontier-context))]
       [_
        (PromotedStuck 'Dead context)])]
    [_
     (PromotedStuck 'Dead context)]))

(define (delay work context)
  (match context
    [`(wf-more ,work-context ,frontier-context)
     (match work-context
       ['ww-hole
        (continue-work
         work
         `(wf-more ww-hole (ff-forced ,frontier-context)))]
       [`(ww-fresh ,intro ,tag ,outer)
        (delay `(WorkFresh ,intro ,work ,tag)
               `(wf-more ,outer ,frontier-context))]
       [`(ww-conj ,goal ,outer)
        (delay `(Conj ,work ,goal)
               `(wf-more ,outer ,frontier-context))]
       [`(ww-disj-left ,right ,outer)
        (delay `(DisjR ,work ,right)
               `(wf-more ,outer ,frontier-context))]
       [`(ww-disj-right ,left ,outer)
        (delay `(DisjL ,left ,work)
               `(wf-more ,outer ,frontier-context))]
       [_
        (PromotedStuck `(PendingDelay ,work) context)])]
    [_
     (PromotedStuck `(PendingDelay ,work) context)]))

(define (run-atomic goal state context)
  (match goal
    [`(succeed ,_tag)
     (settled `(Returned ,state) context)]
    [`(fail ,_tag)
     (dead context)]
    [`(put ,payload ,_tag)
     (settled `(Returned (state ,payload)) context)]
    [`(fresh ,lexical ,body ,tag)
     (define intro
       (fresh-u-list
        (logical-vars-in (list `(Work ,goal ,state) context))
        lexical))
     (define bindings
       (map list lexical intro))
     (continue-unfinished
      `(WorkFresh ,intro
                  (Work ,(substitute-goal body bindings) ,state)
                  ,tag)
      context)]
    [`(conj ,left ,right ,_tag)
     (continue-unfinished `(Conj (Work ,left ,state) ,right)
                          context)]
    [`(disj ,left ,right ,_tag)
     (continue-unfinished
      `(DisjL (Work ,left ,state) (Work ,right ,state))
      context)]
    [`(suspend ,body ,_tag)
     (delay `(Work ,body ,state) context)]
    [_
     (PromotedStuck `(Work ,goal ,state) context)]))

(define (run-work-fresh intro inner tag context)
  (match inner
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (settled
      `(DisjL (WorkFresh ,intro ,active ,tag)
              (WorkFresh ,intro ,alternate ,tag))
      context)]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (settled
      `(DisjR (WorkFresh ,intro ,alternate ,tag)
              (WorkFresh ,intro ,active ,tag))
      context)]
    ['Dead
     (dead context)]
    [`(PendingDelay ,work)
     (delay `(WorkFresh ,intro ,work ,tag) context)]
    [_
     (match context
       [`(wf-more ,work-context ,frontier-context)
        (run inner
             `(wf-more
               (ww-fresh ,intro ,tag ,work-context)
               ,frontier-context))]
       [_
        (PromotedStuck `(WorkFresh ,intro ,inner ,tag) context)])]))

(define (run-conjunction left goal context)
  (match left
    [(? settled-success? success)
     (continue-unfinished (resume-success success goal) context)]
    ['Dead
     (dead context)]
    [`(PendingDelay ,work)
     (delay `(Conj ,work ,goal) context)]
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (continue-unfinished
      `(DisjL ,(resume-success active goal)
              (Conj ,alternate ,goal))
      context)]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (continue-unfinished
      `(DisjR (Conj ,alternate ,goal)
              ,(resume-success active goal))
      context)]
    [_
     (match context
       [`(wf-more ,work-context ,frontier-context)
        (run left
             `(wf-more
               (ww-conj ,goal ,work-context)
               ,frontier-context))]
       [_
        (PromotedStuck `(Conj ,left ,goal) context)])]))

(define (run-left-choice left right context)
  (match left
    ['Dead
     (continue-work right context)]
    [`(PendingDelay ,work)
     (delay `(DisjR ,work ,right) context)]
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (settled `(DisjL ,active (DisjL ,alternate ,right)) context)]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (settled `(DisjL ,active (DisjL ,alternate ,right)) context)]
    [_
     (match context
       [`(wf-more ,work-context ,frontier-context)
        (run left
             `(wf-more
               (ww-disj-left ,right ,work-context)
               ,frontier-context))]
       [_
        (PromotedStuck `(DisjL ,left ,right) context)])]))

(define (run-right-choice left right context)
  (match right
    ['Dead
     (continue-work left context)]
    [`(PendingDelay ,work)
     (delay `(DisjL ,left ,work) context)]
    [`(DisjL ,active ,alternate)
     #:when (settled-success? active)
     (settled `(DisjR (DisjR ,left ,alternate) ,active) context)]
    [`(DisjR ,alternate ,active)
     #:when (settled-success? active)
     (settled `(DisjR (DisjR ,left ,alternate) ,active) context)]
    [_
     (match context
       [`(wf-more ,work-context ,frontier-context)
        (run right
             `(wf-more
               (ww-disj-right ,left ,work-context)
               ,frontier-context))]
       [_
        (PromotedStuck `(DisjR ,left ,right) context)])]))

(define (run work context)
  (match context
    [`(wf-more ww-hole ,frontier-context)
     (match work
       [`(WorkFresh ,intro ,inner ,tag)
        (continue-work
         inner
         `(wf-more
           ww-hole
           (ff-frontier-fresh ,intro ,tag ,frontier-context)))]
       [(? settled-result? result)
        (settled result context)]
       ['Dead
        (dead context)]
       [`(PendingDelay ,inner)
        (delay inner context)]
       [_
        (run-local work context)])]
    [_
     (run-local work context)]))

(define (run-local work context)
  (match work
    [`(Work ,goal ,state)
     (run-atomic goal state context)]
    [(? settled-result? result)
     (settled result context)]
    ['Dead
     (dead context)]
    [`(PendingDelay ,inner)
     (delay inner context)]
    [`(WorkFresh ,intro ,inner ,tag)
     (run-work-fresh intro inner tag context)]
    [`(Conj ,left ,goal)
     (run-conjunction left goal context)]
    [`(DisjL ,left ,right)
     (run-left-choice left right context)]
    [`(DisjR ,left ,right)
     (run-right-choice left right context)]
    [_
     (PromotedStuck work context)]))

(define (final terminal context)
  (PromotedFinal terminal context))

(define (frontier-entry frontier context)
  (match frontier
    [`(Emit ,answer ,rest)
     (frontier-entry rest `(ff-emit ,answer ,context))]
    [`(FrontierFresh ,intro ,rest ,tag)
     (frontier-entry
      rest
      `(ff-frontier-fresh ,intro ,tag ,context))]
    [`(Forced ,rest)
     (frontier-entry rest `(ff-forced ,context))]
    [`(More ,work)
     (continue-work work `(wf-more ww-hole ,context))]
    ['Done
     (final 'Done context)]
    [`(Last ,answer)
     (final `(Last ,answer) context)]
    [_
     (raise-argument-error 'frontier-entry
                           "frontier-in-language?"
                           frontier)]))

;; The public mode entries validate their individual grammatical arguments.
;; No compatibility tag or recursive validation register is introduced.
(define (fixed-run work context)
  (unless (work-in-language? work)
    (raise-argument-error 'fixed-run "work-in-language?" work))
  (unless (wf-context-in-language? context)
    (raise-argument-error 'fixed-run
                          "wf-context-in-language?"
                          context))
  (run work context))

(define (fixed-settled result context)
  (unless (settled-result? result)
    (raise-argument-error 'fixed-settled "settled-result?" result))
  (unless (wf-context-in-language? context)
    (raise-argument-error 'fixed-settled
                          "wf-context-in-language?"
                          context))
  (settled result context))

(define (fixed-dead context)
  (unless (wf-context-in-language? context)
    (raise-argument-error 'fixed-dead
                          "wf-context-in-language?"
                          context))
  (dead context))

(define (fixed-delay work context)
  (unless (work-in-language? work)
    (raise-argument-error 'fixed-delay "work-in-language?" work))
  (unless (wf-context-in-language? context)
    (raise-argument-error 'fixed-delay
                          "wf-context-in-language?"
                          context))
  (delay work context))

(define (fixed-final terminal context)
  (unless (match terminal
            ['Done #t]
            [`(Last ,answer) (answer-in-language? answer)]
            [_ #f])
    (raise-argument-error 'fixed-final
                          "(or/c 'Done `(Last ,A))"
                          terminal))
  (unless (ff-context-in-language? context)
    (raise-argument-error 'fixed-final
                          "ff-context-in-language?"
                          context))
  (final terminal context))

(define (fixed-point-evaluate frontier)
  (unless (well-formed-frontier? frontier)
    (raise-arguments-error
     'fixed-point-evaluate
     "term is not a well-formed pilot source tree"
     "term" frontier))
  (frontier-entry frontier 'ff-hole))

(define (fixed-point-readback outcome)
  (match outcome
    [(PromotedFinal terminal context)
     (plug-ff terminal context)]
    [(PromotedStuck work context)
     (plug-wf work context)]
    [_
     (raise-argument-error
      'fixed-point-readback
      "(or/c PromotedFinal? PromotedStuck?)"
      outcome)]))
