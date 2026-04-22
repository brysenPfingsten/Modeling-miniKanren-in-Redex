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
         (all-from-out "program-runner.rkt"))

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
