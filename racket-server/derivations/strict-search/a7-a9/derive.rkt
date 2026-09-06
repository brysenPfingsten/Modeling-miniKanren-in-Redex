#lang racket

(require racket/runtime-path)
(provide control-definitions control-signatures generated-texts generate! check-generated!
         transform-tail)
(define-runtime-path directory ".")

;; A small, deliberately restricted tail-call reifier, not a Racket compiler.
;; It accepts the match/if/begin tail fragment used by 03-defunc. It rejects
;; calls/references to control functions in primitive (non-tail) positions.
;; Both generated artifacts come from these function bodies, not copies of
;; the previously implemented strict machine or register dispatcher.
(define (control-definitions)
  (define module-datum
    (call-with-input-file (build-path directory "03-defunc.rkt")
      (lambda (input)
        (parameterize ([read-accept-reader #t])
          (syntax->datum (read-syntax "03-defunc.rkt" input))))))
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

(define (primitive! expression names)
  (match expression
    [`(quote ,_) (void)]
    [(? symbol? name)
     (when (member name names)
       (error 'derive "control procedure in a non-tail position: ~e" expression))]
    [(cons head tail) (primitive! head names) (primitive! tail names)]
    [_ (void)]))

(define (transform-body body names jump halt)
  (when (null? body) (error 'derive "empty control body"))
  (define preceding (drop-right body 1))
  (for-each (lambda (expression) (primitive! expression names)) preceding)
  (append preceding (list (transform-tail (last body) names jump halt))))

(define (transform-tail expression names jump halt)
  (match expression
    [`(match ,subject ,clauses ...)
     (primitive! subject names)
     `(match ,subject
        ,@(for/list ([clause (in-list clauses)])
            (match-define (cons pattern body) clause)
            `(,pattern ,@(transform-body body names jump halt))))]
    [`(if ,test ,yes ,no)
     (primitive! test names)
     `(if ,test ,(transform-tail yes names jump halt)
                ,(transform-tail no names jump halt))]
    [`(begin ,body ...) `(begin ,@(transform-body body names jump halt))]
    [(list (? (lambda (name) (member name names)) name) arguments ...)
     (for-each (lambda (argument) (primitive! argument names)) arguments)
     (jump name arguments)]
    [_ (primitive! expression names) (halt expression)]))

(define machine-runtime
  '((struct Call (pc operands) #:transparent)
    (struct Halted (value) #:transparent)
    (define (initial goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)]
                     #:observe? [observe? #t])
      (Call 'eval/d (list goal state K (if observe? (KRun (KDone)) (KDone)))))
    (define (drive/steps current fuel)
      (match current
        [(Halted value) value]
        [_ (when (zero? fuel) (exhausted 'machine current))
           (drive/steps (step current) (sub1 fuel))]))
    (define (drive current #:fuel [fuel 100000])
      (check-fuel fuel)
      (drive/steps current fuel))
    (define (run-search goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)]
                        #:fuel [fuel 100000])
      (drive (initial goal #:kernel K #:state state #:observe? #f) #:fuel fuel))
    (define (run goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)]
                 #:fuel [fuel 100000])
      (drive (initial goal #:kernel K #:state state) #:fuel fuel))))

(define register-runtime
  '((struct Registers (pc r0 r1 r2 r3 steps) #:mutable #:transparent)
    ;; Every argument is evaluated before any assignment by jump!.
    (define (jump! bank pc r0 [r1 #f] [r2 #f] [r3 #f])
      (set-Registers-r0! bank r0)
      (set-Registers-r1! bank r1)
      (set-Registers-r2! bank r2)
      (set-Registers-r3! bank r3)
      (set-Registers-pc! bank pc))
    (define (halt! bank value) (jump! bank 'halt value))
    (define (initial goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)]
                     #:observe? [observe? #t])
      (Registers 'eval/d goal state K (if observe? (KRun (KDone)) (KDone)) 0))
    (define (decode bank)
      (match (Registers-pc bank)
        ['halt (m:Halted (Registers-r0 bank))]
        [pc
         (match (assq pc signatures)
           [(cons _ parameters)
            (m:Call pc (take (list (Registers-r0 bank) (Registers-r1 bank)
                                  (Registers-r2 bank) (Registers-r3 bank))
                            (length parameters)))]
           [#f (error 'decode "unknown PC: ~e" pc)])]))
    (define (from-machine current)
      (match current
        [(m:Halted value) (Registers 'halt value #f #f #f 0)]
        [(m:Call pc operands)
         (define bank (Registers 'halt #f #f #f #f 0))
         (apply jump! bank pc operands)
         bank]))
    (define (step! bank)
      (match (Registers-pc bank)
        ['halt #f]
        [_ (dispatch! bank)
           (set-Registers-steps! bank (add1 (Registers-steps bank)))
           #t]))
    (define (drive/steps! bank fuel)
      (match (Registers-pc bank)
        ['halt (Registers-r0 bank)]
        [_ (when (zero? fuel) (exhausted 'registers (decode bank)))
           (step! bank)
           (drive/steps! bank (sub1 fuel))]))
    (define (drive! bank #:fuel [fuel 100000])
      (check-fuel fuel)
      (drive/steps! bank fuel))
    (define (run-search goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)]
                        #:fuel [fuel 100000])
      (drive! (initial goal #:kernel K #:state state #:observe? #f) #:fuel fuel))
    (define (run goal #:kernel [K d:basic-kernel] #:state [state (d:empty-state)]
                 #:fuel [fuel 100000])
      (drive! (initial goal #:kernel K #:state state) #:fuel fuel))))

(define (module-text forms)
  (with-output-to-string
    (lambda ()
      (displayln "#lang racket")
      (displayln ";; Generated from 03-defunc.rkt by derive.rkt. Regenerate; do not edit.")
      (parameterize ([pretty-print-columns 96])
        (for ([form (in-list forms)]) (pretty-write form) (newline))))))

(define (generated-texts)
  (define definitions (control-definitions))
  (define signatures (control-signatures definitions))
  (define names (map car signatures))
  (unless (and (pair? names) (= (length names) (length (remove-duplicates names)))
               (andmap (lambda (signature) (<= 1 (length (cdr signature)) 4)) signatures))
    (error 'derive "expected unique control points using at most four operands"))
  (define imports
    '(require (prefix-in d: "../../functional-search/direct-interpreter.rkt")
              "03-data.rkt" "runtime.rkt"))
  (define machine-clauses
    (for/list ([definition (in-list definitions)])
      (match-define `(define (,name ,arguments ...) ,body ...) definition)
      `[(Call ',name (list ,@arguments))
        ,@(transform-body body names
                          (lambda (pc args) `(Call ',pc (list ,@args)))
                          (lambda (value) `(Halted ,value)))]))
  (define register-clauses
    (for/list ([definition (in-list definitions)])
      (match-define `(define (,name ,arguments ...) ,body ...) definition)
      `[',name
        ,@(for/list ([argument (in-list arguments)] [slot (in-naturals)])
            `(define ,argument (,(string->symbol (format "Registers-r~a" slot)) bank)))
        ,@(transform-body body names
                          (lambda (pc args) `(jump! bank ',pc ,@args))
                          (lambda (value) `(halt! bank ,value)))]))
  (list
   (cons "04-machine.rkt"
         (module-text
          (append
           (list imports '(provide (all-defined-out)) `(define signatures ',signatures))
           machine-runtime
           (list `(define (step current)
                    (match current
                      ,@machine-clauses
                      [(Halted _) #f]
                      [_ (raise-argument-error 'step "derived machine configuration" current)]))))))
   (cons "05-registers.rkt"
         (module-text
          (append
           (list imports '(require (prefix-in m: "04-machine.rkt"))
                 '(provide (all-defined-out)) `(define signatures ',signatures))
           register-runtime
           (list `(define (dispatch! bank)
                    (match (Registers-pc bank)
                      ,@register-clauses
                      [other (error 'dispatch! "unknown PC: ~e" other)]))))))))

(define (generate!)
  (for ([artifact (in-list (generated-texts))])
    (match-define (cons name content) artifact)
    (call-with-output-file (build-path directory name)
      (lambda (output) (display content output)) #:exists 'truncate/replace)))

(define (check-generated!)
  (for ([artifact (in-list (generated-texts))])
    (match-define (cons name content) artifact)
    (unless (equal? content (file->string (build-path directory name)))
      (error 'check-generated! "generated file is stale: ~a" name)))
  #t)

(module+ main
  (match (vector->list (current-command-line-arguments))
    ['() (generate!) (displayln "Generated 04-machine.rkt and 05-registers.rkt.")]
    ['("--check") (check-generated!) (displayln "Generated artifacts match 03-defunc.rkt.")]
    [_ (error 'derive "usage: racket derive.rkt [--check]")]))
