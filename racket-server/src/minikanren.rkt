#lang racket

(require "program-runner.rkt"
         "sexpr-read.rkt"
         (for-syntax racket/base
                     syntax/parse))

(provide defrel
         run
         run*
         current-minikanren-search-strategy
         current-minikanren-compile-profile
         clear-module-definitions!
         module-definitions
         make-minikanren-evaluator
         minikanren-eval!
         minikanren-eval-source!
         clear-minikanren-evaluator!
         (struct-out minikanren-evaluator)
         run-source
         run-forms
         run-result-host-answers
         run-source->answers
         run-forms->answers
         run-source->host-answers
         run-forms->host-answers
         run-source->answer-nodes
         run-forms->answer-nodes
         run-source->picture
         run-forms->picture
         (struct-out run-result)
         (all-from-out "program-runner.rkt"))

(struct run-result (initial-config
                    final-config
                    step-count
                    answer-nodes
                    answers
                    picture)
  #:transparent)

(define default-step-cap 2048)

;; Automatic consumption belongs to this adapter. Session stepping remains
;; independent of answer limits and retains the actual matrix configuration.
(define (run-result-host-answers result)
  (for/list ([answer-node (in-list (run-result-answer-nodes result))])
    (answer-json->host-value (hash-ref answer-node 'reified '()))))

(define (normalize-answer-limit answer-limit)
  (cond
    [(false? answer-limit) #f]
    [(exact-nonnegative-integer? answer-limit) answer-limit]
    [else
     (error 'run-source
            "answer-limit must be #f or an exact nonnegative integer, got ~e"
            answer-limit)]))

(define (answer-limit-reached? session answer-limit)
  (match answer-limit
    [#f #f]
    [0 #t]
    [limit
     ;; Finish the eager round and its whole commitment before counting.
     ;; In particular Emit(A, commit(S)) is still running. Stop at More(Delay)
     ;; before another public advance; terminal Frontiers stop below as well.
     (and (eq? (model-session-status session) 'paused)
          (>= (length (model-session-current-answer-nodes session)) limit))]))

(define (run-until-limit session step-cap answer-limit [steps 0])
  (cond
    [(answer-limit-reached? session answer-limit)
     (values session steps)]
    [(model-session-done? session)
     (values session steps)]
    [(>= steps step-cap)
     (error 'run-source
            "step cap ~a reached before completion under search strategy ~e"
            step-cap
            (search-strategy->jsexpr
             (model-session-search-strategy session)))]
    [else
     (run-until-limit (model-session-step session)
                      step-cap
                      answer-limit
                      (add1 steps))]))

(define (run-session initial-session step-cap answer-limit)
  (unless (exact-positive-integer? step-cap)
    (error 'run-source
           "step-cap must be an exact positive integer, got ~e"
           step-cap))
  (define answer-limit* (normalize-answer-limit answer-limit))
  (define initial-config (model-session-current-config initial-session))
  (define-values (session step-count)
    (run-until-limit initial-session step-cap answer-limit*))
  (define available (model-session-current-answer-nodes session))
  (define answer-nodes
    (if answer-limit* (take available (min answer-limit* (length available))) available))
  ;; Return the requested prefix while retaining the whole completed Frontier
  ;; in the saved configuration and picture, including surplus answers.
  (run-result initial-config
              (model-session-current-config session)
              step-count
              answer-nodes
              (map (lambda (answer) (hash-ref answer 'reified '())) answer-nodes)
              (model-session-current-picture session)))

(define (run-source raw-prog
                    #:source-mode [source-mode default-source-mode]
                    #:compile-profile [compile-profile #f]
                    #:search-strategy [strategy default-search-strategy]
                    #:answer-limit [answer-limit #f]
                    #:step-cap [step-cap default-step-cap])
  (run-session (open-source raw-prog
                            #:source-mode source-mode
                            #:compile-profile compile-profile
                            #:search-strategy strategy)
               step-cap answer-limit))

(define (run-forms forms
                   #:source-mode [source-mode default-source-mode]
                   #:compile-profile [compile-profile #f]
                   #:search-strategy [strategy default-search-strategy]
                   #:answer-limit [answer-limit #f]
                   #:step-cap [step-cap default-step-cap])
  (run-session (open-forms forms
                           #:source-mode source-mode
                           #:compile-profile compile-profile
                           #:search-strategy strategy)
               step-cap answer-limit))

(define (run-source->answers raw-prog
                             #:source-mode [source-mode default-source-mode]
                             #:compile-profile [compile-profile #f]
                             #:search-strategy [strategy default-search-strategy]
                             #:answer-limit [answer-limit #f]
                             #:step-cap [step-cap default-step-cap])
  (run-result-answers
   (run-source raw-prog
               #:source-mode source-mode
               #:compile-profile compile-profile
               #:search-strategy strategy
               #:answer-limit answer-limit
               #:step-cap step-cap)))

(define (run-forms->answers forms
                            #:source-mode [source-mode default-source-mode]
                            #:compile-profile [compile-profile #f]
                            #:search-strategy [strategy default-search-strategy]
                            #:answer-limit [answer-limit #f]
                            #:step-cap [step-cap default-step-cap])
  (run-result-answers
   (run-forms forms
              #:source-mode source-mode
              #:compile-profile compile-profile
              #:search-strategy strategy
              #:answer-limit answer-limit
              #:step-cap step-cap)))

(define (run-source->host-answers raw-prog
                                  #:source-mode [source-mode default-source-mode]
                                  #:compile-profile [compile-profile #f]
                                  #:search-strategy [strategy default-search-strategy]
                                  #:answer-limit [answer-limit #f]
                                  #:step-cap [step-cap default-step-cap])
  (run-result-host-answers
   (run-source raw-prog
               #:source-mode source-mode
               #:compile-profile compile-profile
               #:search-strategy strategy
               #:answer-limit answer-limit
               #:step-cap step-cap)))

(define (run-forms->host-answers forms
                                 #:source-mode [source-mode default-source-mode]
                                 #:compile-profile [compile-profile #f]
                                 #:search-strategy [strategy default-search-strategy]
                                 #:answer-limit [answer-limit #f]
                                 #:step-cap [step-cap default-step-cap])
  (run-result-host-answers
   (run-forms forms
              #:source-mode source-mode
              #:compile-profile compile-profile
              #:search-strategy strategy
              #:answer-limit answer-limit
              #:step-cap step-cap)))

(define (run-source->answer-nodes raw-prog
                                  #:source-mode [source-mode default-source-mode]
                                  #:compile-profile [compile-profile #f]
                                  #:search-strategy [strategy default-search-strategy]
                                  #:answer-limit [answer-limit #f]
                                  #:step-cap [step-cap default-step-cap])
  (run-result-answer-nodes
   (run-source raw-prog
               #:source-mode source-mode
               #:compile-profile compile-profile
               #:search-strategy strategy
               #:answer-limit answer-limit
               #:step-cap step-cap)))

(define (run-forms->answer-nodes forms
                                 #:source-mode [source-mode default-source-mode]
                                 #:compile-profile [compile-profile #f]
                                 #:search-strategy [strategy default-search-strategy]
                                 #:answer-limit [answer-limit #f]
                                 #:step-cap [step-cap default-step-cap])
  (run-result-answer-nodes
   (run-forms forms
              #:source-mode source-mode
              #:compile-profile compile-profile
              #:search-strategy strategy
              #:answer-limit answer-limit
              #:step-cap step-cap)))

(define (run-source->picture raw-prog
                             #:source-mode [source-mode default-source-mode]
                             #:compile-profile [compile-profile #f]
                             #:search-strategy [strategy default-search-strategy]
                             #:answer-limit [answer-limit #f]
                             #:step-cap [step-cap default-step-cap])
  (run-result-picture
   (run-source raw-prog
               #:source-mode source-mode
               #:compile-profile compile-profile
               #:search-strategy strategy
               #:answer-limit answer-limit
               #:step-cap step-cap)))

(define (run-forms->picture forms
                            #:source-mode [source-mode default-source-mode]
                            #:compile-profile [compile-profile #f]
                            #:search-strategy [strategy default-search-strategy]
                            #:answer-limit [answer-limit #f]
                            #:step-cap [step-cap default-step-cap])
  (run-result-picture
   (run-forms forms
              #:source-mode source-mode
              #:compile-profile compile-profile
              #:search-strategy strategy
              #:answer-limit answer-limit
              #:step-cap step-cap)))

(struct minikanren-evaluator (definitions search-strategy compile-profile)
  #:mutable
  #:transparent)

(define current-minikanren-search-strategy
  (make-parameter default-search-strategy))

(define current-minikanren-compile-profile
  (make-parameter canonical-compile-profile))

(define module-definition-table
  (make-hash))

(define (module-definitions module-key)
  (hash-ref module-definition-table module-key '()))

(define (register-definition! module-key form-datum)
  (hash-set! module-definition-table
             module-key
             (append (module-definitions module-key)
                     (list form-datum))))

(define (clear-module-definitions! [module-key 'interactive])
  (hash-remove! module-definition-table module-key))

(define (make-minikanren-evaluator
         #:search-strategy [search-strategy (current-minikanren-search-strategy)]
         #:compile-profile [compile-profile (current-minikanren-compile-profile)])
  (minikanren-evaluator '()
                        (normalize-search-strategy search-strategy)
                        (normalize-compile-profile compile-profile "mini")))

(define (clear-minikanren-evaluator! evaluator)
  (set-minikanren-evaluator-definitions! evaluator '()))

(define (normalize-form-datum form)
  (cond
    [(syntax? form) (syntax->datum form)]
    [else form]))

(define (minikanren-eval! evaluator form)
  (define form-datum
    (normalize-form-datum form))
  (match form-datum
    [`(defrel . ,_)
     (set-minikanren-evaluator-definitions!
      evaluator
      (append (minikanren-evaluator-definitions evaluator)
              (list form-datum)))
     (void)]
    [`(run ,n ,_ . ,_)
     (run-forms->host-answers
      (append (minikanren-evaluator-definitions evaluator)
              (list form-datum))
      #:source-mode "mini"
      #:compile-profile
      (minikanren-evaluator-compile-profile evaluator)
      #:search-strategy
      (minikanren-evaluator-search-strategy evaluator)
      #:answer-limit n)]
    [`(run* ,_ . ,_)
     (run-forms->host-answers
      (append (minikanren-evaluator-definitions evaluator)
              (list form-datum))
      #:source-mode "mini"
      #:compile-profile
      (minikanren-evaluator-compile-profile evaluator)
      #:search-strategy
      (minikanren-evaluator-search-strategy evaluator))]
    [_ (error 'minikanren-eval!
              "expected a defrel, run, or run* form, got ~e"
              form-datum)]))

(define (minikanren-eval-source! evaluator source)
  (for/fold ([last-value (void)])
            ([form (in-list (read-all-sexprs (open-input-string source)))])
    (minikanren-eval! evaluator form)))

(begin-for-syntax
  (define (module-key-datum stx)
    (define src
      (syntax-source stx))
    (cond
      [(path? src) (path->string src)]
      [(string? src) src]
      [else 'interactive])))

(define-syntax (defrel stx)
  (syntax-parse stx
    [(_ . _)
     (define form-datum
       (syntax->datum stx))
     (define module-key
       (module-key-datum stx))
     #`(begin
         (register-definition! '#,module-key '#,form-datum)
         (void))]))

(define-syntax (run stx)
  (syntax-parse stx
    [(_ n:exact-nonnegative-integer . _)
     (define form-datum
       (syntax->datum stx))
     (define module-key
       (module-key-datum stx))
     #`(run-forms->host-answers
        (append (module-definitions '#,module-key)
                (list '#,form-datum))
        #:source-mode "mini"
        #:compile-profile (current-minikanren-compile-profile)
        #:search-strategy (current-minikanren-search-strategy)
        #:answer-limit n)]))

(define-syntax (run* stx)
  (syntax-parse stx
    [(_ . _)
     (define form-datum
       (syntax->datum stx))
     (define module-key
       (module-key-datum stx))
     #`(run-forms->host-answers
        (append (module-definitions '#,module-key)
                (list '#,form-datum))
        #:source-mode "mini"
        #:compile-profile (current-minikanren-compile-profile)
        #:search-strategy (current-minikanren-search-strategy))]))
