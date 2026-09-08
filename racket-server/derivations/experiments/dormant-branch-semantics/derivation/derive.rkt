#lang racket

(require racket/runtime-path
         (only-in "../../../shared/control-transform.rkt" transform-tail))
(provide control-definitions control-signatures generated-text generate! check-generated!)
(define-runtime-path directory ".")

;; The shared restricted transformer rejects non-tail control calls. These
;; are the actual defunctionalized bodies, not independently written rules.
(define (control-definitions)
  (define module-datum
    (call-with-input-file (build-path directory "defunc.rkt")
      (lambda (input)
        (parameterize ([read-accept-reader #t])
          (syntax->datum (read-syntax "defunc.rkt" input))))))
  (match-define `(module ,_ ,_ (#%module-begin ,forms ...)) module-datum)
  (for/list ([form (in-list forms)]
             #:when (match form
                      [`(define (,(? symbol? name) ,_ ...) ,_ ...)
                       (regexp-match? #rx"/d$" (symbol->string name))]
                      [_ #f]))
    form))

(define (control-signatures [definitions (control-definitions)])
  (for/list ([definition (in-list definitions)])
    (match-define `(define (,name ,arguments ...) ,_ ...) definition)
    (cons name arguments)))

(define machine-runtime
  '((struct Call (pc operands) #:transparent)
    (struct Halted (value) #:transparent)
    (define (initial goal #:policy [policy 'flip] #:owners [owners '(Owners)]
                     #:state [state '(state () () () (label "initial"))]
                     #:relations [relations #f])
      (check-policy policy)
      (Call 'eval/d
            (list policy (retain-goal relations goal) state owners '()
                  (KCommit '() (if relations (KProgram relations (KDone)) (KDone))))))
    (define (initial-advance frontier)
      (match frontier
        [`(program ,relations ,body)
         (Call 'advance/d (list body '() (KProgram relations (KDone))))]
        [_ (Call 'advance/d (list frontier '() (KDone)))]))
    (define (initial-collect frontier)
      (match frontier
        [`(program ,relations ,body)
         (Call 'collect/d (list body (KProgram relations (KDone))))]
        [_ (Call 'collect/d (list frontier (KDone)))]))
    ;; This host loop only dispatches data configurations. It creates no
    ;; thunks, object-language Delay, scheduler switch, or public advance.
    (define (drive/steps current fuel)
      (match current
        [(Halted value) value]
        [_ (when (zero? fuel) (exhausted 'scheduler-family-machine current))
           (drive/steps (step current) (sub1 fuel))]))
    (define (drive current #:fuel [fuel 100000])
      (check-fuel fuel)
      (drive/steps current fuel))
    (define (run goal #:policy [policy 'flip] #:owners [owners '(Owners)]
                 #:state [state '(state () () () (label "initial"))]
                 #:relations [relations #f] #:fuel [fuel 100000])
      (drive (initial goal #:policy policy #:owners owners #:state state
                      #:relations relations) #:fuel fuel))
    (define (resume-once frontier #:fuel [fuel 100000])
      (drive (initial-advance frontier) #:fuel fuel))
    (define (collect-all frontier #:fuel [fuel 100000])
      (drive (initial-collect frontier) #:fuel fuel))))

(define (generated-text)
  (define definitions (control-definitions))
  (define signatures (control-signatures definitions))
  (define names (map car signatures))
  (unless (and (= (length names) 13)
               (= (length names) (length (remove-duplicates names)))
               (andmap (lambda (signature) (<= 1 (length (cdr signature)) 7)) signatures))
    (error 'derive "expected thirteen unique scheduler-family controls using at most seven operands"))
  (define clauses
    (for/list ([definition (in-list definitions)])
      (match-define `(define (,name ,arguments ...) ,body ...) definition)
      `[(Call ',name (list ,@arguments))
        ,(transform-tail `(begin ,@body) names
                         (lambda (pc args) `(Call ',pc (list ,@args)))
                         (lambda (value) `(Halted ,value)))]))
  (define forms
    (append
     (list '(require (only-in "../../../shared/kernel.rkt"
                             owners-support owners-append fresh-names substitute-goal)
                     "../../../s-reference/relations.rkt"
                     "../../../shared/runtime.rkt" "data.rkt")
           '(provide (all-defined-out))
           `(define signatures ',signatures))
     machine-runtime
     (list `(define (step current)
              (match current
                ,@clauses
                [(Halted _) #f]
                [_ (raise-argument-error 'step "derived scheduler-family configuration" current)])))))
  (with-output-to-string
    (lambda ()
      (displayln "#lang racket")
      (displayln ";; Generated from defunc.rkt by derive.rkt. Regenerate; do not edit.")
      (parameterize ([pretty-print-columns 96])
        (for ([form (in-list forms)] [index (in-naturals)])
          (unless (zero? index) (newline))
          (pretty-write form))))))

(define (generate!)
  (call-with-output-file (build-path directory "machine.rkt")
    (lambda (output) (display (generated-text) output)) #:exists 'truncate/replace))
(define (check-generated!)
  (unless (equal? (generated-text) (file->string (build-path directory "machine.rkt")))
    (error 'check-generated! "machine.rkt is stale; regenerate from defunc.rkt"))
  #t)

(module+ main
  (match (vector->list (current-command-line-arguments))
    ['() (generate!) (displayln "Generated machine.rkt from scheduler-family defunc.rkt.")]
    ['("--check") (check-generated!) (displayln "Generated machine matches defunc.rkt.")]
    [_ (error 'derive "usage: racket derive.rkt [--check]")]))
