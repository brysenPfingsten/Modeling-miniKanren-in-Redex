#lang racket

(require racket/string
         "search-lattice/picture.rkt"
         "search-runtime.rkt"
         "search-strategy.rkt"
         "sexpr-read.rkt"
         "syntax-checking.rkt"
         "transpiler.rkt"
         "zipper.rkt")

(provide open-source
         open-forms
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
         answer-json->host-value
         picture->answer-nodes
         (struct-out model-step)
         (struct-out model-session)
         model-session-current-step
         model-session-current-step-name
         model-session-current-config
         model-session-current-picture
         model-session-current-answer-nodes
         model-session-current-answers
         model-session-current-host-answers
         model-session-step-index
         model-session-done?
         model-session-step
         model-session-back
         model-session-reset
         (struct-out run-result)
         (struct-out search-strategy)
         default-search-strategy
         all-surfaced-search-strategies
         search-strategy->jsexpr
         normalize-search-strategy
         default-source-mode
         normalize-source-mode
         (struct-out compile-profile)
         canonical-compile-profile
         canonical-compile-profile-jsexpr
         normalize-compile-profile
         compile-profile->jsexpr
         canonical-parser-profile
         canonical-parser-target-id)

(struct model-step (name config) #:transparent)

(struct model-session (zipper step-once nqv search-strategy) #:transparent)

(struct run-result (initial-config
                    final-config
                    step-count
                    answer-nodes
                    answers
                    picture)
  #:transparent)

(define default-step-cap 2048)
(define reified-var-rx #px"^_\\.[0-9]+$")

(define (normalize-form-datum form)
  (cond
    [(syntax? form) (syntax->datum form)]
    [else form]))

(define (forms->source-string forms)
  (string-join (map (lambda (form)
                      (format "~s" (normalize-form-datum form)))
                    forms)
               "\n"))

(define (prepare-source raw-prog source-mode compile-profile strategy)
  (define source-mode*
    (normalize-source-mode source-mode))
  (define compile-profile*
    (normalize-compile-profile compile-profile source-mode*))
  (define strategy*
    (normalize-search-strategy strategy))
  (when (equal? source-mode* "mini")
    (void (check-syntax-capture-error raw-prog)))
  (define sexpr-prog
    (read-all-sexprs (open-input-string raw-prog)))
  (define-values (initial-config _html)
    (parse-prog/canonical sexpr-prog
                          #:source-mode source-mode*
                          #:compile-profile compile-profile*))
  (unless (canonical-target-in-domain? initial-config canonical-parser-target-id)
    (error 'prepare-source
           "transpiler produced a program outside canonical target ~a"
           canonical-parser-target-id))
  (check-canonical-well-formed initial-config canonical-parser-target-id)
  (check-search-config strategy* initial-config)
  (values initial-config
          (program-query-var-count initial-config)
          strategy*))

(define (final-frontier? frontier)
  (match frontier
    ['(empty-tree) #t]
    [`(⊤ ,_) #t]
    [(or `(ScopedTree ,_ ,inner ,_)
         `(ScopedShell ,_ ,inner ,_))
     (final-frontier? inner)]
    [`(Deferred ,inner)
     (final-frontier? inner)]
    [`(,_ + ,rest)
     (final-frontier? rest)]
    [_ #f]))

(define (final-config? cfg)
  (match cfg
    [`(,_ ,frontier)
     (final-frontier? frontier)]
    [_ #f]))

(define (picture->answer-nodes node [acc '()])
  (match node
    [(? hash? h)
     (define acc^
       (if (equal? (hash-ref h 'renderRole #f) "answer-node")
           (cons h acc)
           acc))
     (for/fold ([acc acc^])
               ([child (in-list (hash-ref h 'children '()))])
       (picture->answer-nodes child acc))]
    [_ acc]))

(define (answer-json->host-value datum)
  (match datum
    [(? hash? h)
     (cond
       [(hash-has-key? h 'sym)
        (string->symbol (hash-ref h 'sym))]
       [(hash-has-key? h 'num)
        (hash-ref h 'num)]
       [(hash-has-key? h 'var)
        (string->symbol (hash-ref h 'var))]
       [(hash-has-key? h 'pair)
        (match (hash-ref h 'pair)
          [(list left right)
           (cons (answer-json->host-value left)
                 (answer-json->host-value right))]
          [_ h])]
       [else h])]
    [(? string? s)
     (if (regexp-match? reified-var-rx s)
         (string->symbol s)
         s)]
    [(? list? elems)
     (map answer-json->host-value elems)]
    [_ datum]))

(define (answer-nodes->reified answer-nodes)
  (for/list ([answer-node (in-list answer-nodes)])
    (hash-ref answer-node 'reified '())))

(define (answer-nodes->host-values answer-nodes)
  (for/list ([answer-node (in-list answer-nodes)])
    (answer-json->host-value (hash-ref answer-node 'reified '()))))

(define (run-result-host-answers result)
  (answer-nodes->host-values (run-result-answer-nodes result)))

(define (make-initial-session initial-config nqv strategy)
  (model-session
   (zipper-add (make-empty-zipper)
               (model-step "Initialize Program" initial-config))
   (lookup-search-step-once strategy)
   nqv
   strategy))

(define (open-source raw-prog
                     #:source-mode [source-mode default-source-mode]
                     #:compile-profile [compile-profile #f]
                     #:search-strategy [strategy default-search-strategy])
  (define-values (initial-config nqv strategy*)
    (prepare-source raw-prog source-mode compile-profile strategy))
  (make-initial-session initial-config nqv strategy*))

(define (open-forms forms
                    #:source-mode [source-mode default-source-mode]
                    #:compile-profile [compile-profile #f]
                    #:search-strategy [strategy default-search-strategy])
  (open-source (forms->source-string forms)
               #:source-mode source-mode
               #:compile-profile compile-profile
               #:search-strategy strategy))

(define (model-session-current-step session)
  (match-define (model-session (zipper _ curr _ _) _ _ _) session)
  curr)

(define (model-session-current-step-name session)
  (model-step-name (model-session-current-step session)))

(define (model-session-current-config session)
  (model-step-config (model-session-current-step session)))

(define (model-session-current-picture session)
  (cfg->operational-picture (model-session-current-config session)
                            (model-session-nqv session)))

(define (model-session-current-answer-nodes session)
  (reverse (picture->answer-nodes (model-session-current-picture session))))

(define (model-session-current-answers session)
  (answer-nodes->reified (model-session-current-answer-nodes session)))

(define (model-session-current-host-answers session)
  (answer-nodes->host-values (model-session-current-answer-nodes session)))

(define (model-session-step-index session)
  (zipper-idx (model-session-zipper session)))

(define (model-session-done? session)
  (match-define (model-session (zipper _ _ next _) step-once _ _) session)
  (and (null? next)
       (null? (step-once (model-session-current-config session)))))

(define (model-session-step session)
  (match-define (model-session zipper step-once nqv _) session)
  (define-values (maybe-next zipper^)
    (zipper-forward zipper))
  (cond
    [(model-step? maybe-next)
     (struct-copy model-session session [zipper zipper^])]
    [else
     (match (step-once (model-step-config (zipper-curr zipper)))
       ['()
        session]
       [(list (list name new-config))
        (struct-copy model-session session
                     [zipper (zipper-add zipper
                                         (model-step name new-config))])]
       [_ (error 'model-session-step
                 "expected a deterministic successor under search strategy ~e"
                 (search-strategy->jsexpr
                  (model-session-search-strategy session)))])]))

(define (model-session-back session)
  (define-values (_maybe-back zipper^)
    (zipper-back (model-session-zipper session)))
  (struct-copy model-session session [zipper zipper^]))

(define (model-session-reset session)
  (match-define (model-session (zipper prev curr _ _) _ _ _) session)
  (define init-step
    (cond
      [(pair? prev)
       (for/first ([entry (in-list (reverse prev))]
                   #:when (model-step? entry))
         entry)]
      [(model-step? curr) curr]
      [else #f]))
  (unless (model-step? init-step)
    (error 'model-session-reset
           "session has no initial program to reset to"))
  (struct-copy model-session session
               [zipper (zipper-add (make-empty-zipper) init-step)]))

(define (normalize-answer-limit answer-limit)
  (cond
    [(false? answer-limit) #f]
    [(exact-nonnegative-integer? answer-limit) answer-limit]
    [else
     (error 'run-source
            "answer-limit must be #f or an exact nonnegative integer, got ~e"
            answer-limit)]))

(define (answer-limit-reached? session answer-limit)
  (and answer-limit
       (>= (length (model-session-current-answer-nodes session))
           answer-limit)))

(define (run-until-limit session step-cap answer-limit [steps 0])
  (cond
    [(answer-limit-reached? session answer-limit)
     (values session steps)]
    [(model-session-done? session)
     (if (final-config? (model-session-current-config session))
         (values session steps)
         (error 'run-source
                "execution got stuck after ~a steps under search strategy ~e"
                steps
                (search-strategy->jsexpr
                 (model-session-search-strategy session))))]
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

(define (session->run-result session step-count)
  (define answer-nodes
    (model-session-current-answer-nodes session))
  (run-result (model-step-config
               (let ([zip (model-session-zipper session)])
                 (cond
                   [(pair? (zipper-prev zip))
                    (car (reverse (zipper-prev zip)))]
                   [else (zipper-curr zip)])))
              (model-session-current-config session)
              step-count
              answer-nodes
              (answer-nodes->reified answer-nodes)
              (model-session-current-picture session)))

(define (run-source raw-prog
                    #:source-mode [source-mode default-source-mode]
                    #:compile-profile [compile-profile #f]
                    #:search-strategy [strategy default-search-strategy]
                    #:answer-limit [answer-limit #f]
                    #:step-cap [step-cap default-step-cap])
  (unless (exact-positive-integer? step-cap)
    (error 'run-source
           "step-cap must be an exact positive integer, got ~e"
           step-cap))
  (define session
    (open-source raw-prog
                 #:source-mode source-mode
                 #:compile-profile compile-profile
                 #:search-strategy strategy))
  (define answer-limit*
    (normalize-answer-limit answer-limit))
  (define-values (final-session step-count)
    (run-until-limit session step-cap answer-limit*))
  (session->run-result final-session step-count))

(define (run-forms forms
                   #:source-mode [source-mode default-source-mode]
                   #:compile-profile [compile-profile #f]
                   #:search-strategy [strategy default-search-strategy]
                   #:answer-limit [answer-limit #f]
                   #:step-cap [step-cap default-step-cap])
  (run-source (forms->source-string forms)
              #:source-mode source-mode
              #:compile-profile compile-profile
              #:search-strategy strategy
              #:answer-limit answer-limit
              #:step-cap step-cap))

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
