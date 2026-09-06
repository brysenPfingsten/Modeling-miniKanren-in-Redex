#lang racket

(require racket/runtime-path
         (only-in "../shared/control-transform.rkt" transform-body))
(provide control-definitions control-signatures generated-texts generate! check-generated!)
(define-runtime-path directory ".")

;; A small, deliberately restricted tail-call reifier, not a Racket compiler.
;; It accepts the match/if/begin tail fragment used by 03-defunc. It rejects
;; calls/references to control functions in primitive (non-tail) positions.
;; Both generated artifacts come from the local S function bodies. The N
;; reifier supplies this transformation design, not its machine transitions.
;; Native outcome dispatch and resumption application are reified alongside
;; the remaining controls; no kernel callback appears in a configuration.
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

(define machine-runtime
  '((struct Call (pc operands) #:transparent)
    (struct Halted (value) #:transparent)
    (define (initial goal #:owners [owners '(Owners)]
                     #:state [state '(state () () () (label "initial"))])
      (Call 'eval/d (list goal state owners '() (KCommit (KDone)))))
    (define (drive/steps current fuel)
      (match current
        [(Halted value) value]
        [_ (when (zero? fuel) (exhausted 'machine current))
           (drive/steps (step current) (sub1 fuel))]))
    (define (drive current #:fuel [fuel 100000])
      (check-fuel fuel)
      (drive/steps current fuel))
    (define (run goal #:owners [owners '(Owners)]
                 #:state [state '(state () () () (label "initial"))]
                 #:fuel [fuel 100000])
      (drive (initial goal #:owners owners #:state state) #:fuel fuel))
    (define (resume-once frontier #:fuel [fuel 100000])
      (drive (Call 'advance/d (list frontier (KDone))) #:fuel fuel))
    (define (collect-all frontier #:fuel [fuel 100000])
      (drive (Call 'collect/d (list frontier (KDone))) #:fuel fuel))))

(define register-runtime
  '((struct Registers (pc r0 r1 r2 r3 r4 steps) #:mutable #:transparent)
    ;; Every argument is evaluated before any assignment by jump!.
    (define (jump! bank pc r0 [r1 #f] [r2 #f] [r3 #f] [r4 #f])
      (set-Registers-r0! bank r0)
      (set-Registers-r1! bank r1)
      (set-Registers-r2! bank r2)
      (set-Registers-r3! bank r3)
      (set-Registers-r4! bank r4)
      (set-Registers-pc! bank pc))
    (define (halt! bank value) (jump! bank 'halt value))
    (define (initial goal #:owners [owners '(Owners)]
                     #:state [state '(state () () () (label "initial"))])
      (Registers 'eval/d goal state owners '() (KCommit (KDone)) 0))
    (define (decode bank)
      (match (Registers-pc bank)
        ['halt (m:Halted (Registers-r0 bank))]
        [pc
         (match (assq pc signatures)
           [(cons _ parameters)
            (m:Call pc (take (list (Registers-r0 bank) (Registers-r1 bank)
                                  (Registers-r2 bank) (Registers-r3 bank)
                                  (Registers-r4 bank))
                            (length parameters)))]
           [#f (error 'decode "unknown PC: ~e" pc)])]))
    (define (from-machine current)
      (match current
        [(m:Halted value) (Registers 'halt value #f #f #f #f 0)]
        [(m:Call pc operands)
         (define bank (Registers 'halt #f #f #f #f #f 0))
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
    (define (run goal #:owners [owners '(Owners)]
                 #:state [state '(state () () () (label "initial"))]
                 #:fuel [fuel 100000])
      (drive! (initial goal #:owners owners #:state state) #:fuel fuel))
    (define (resume-once frontier #:fuel [fuel 100000])
      (drive! (Registers 'advance/d frontier (KDone) #f #f #f 0) #:fuel fuel))
    (define (collect-all frontier #:fuel [fuel 100000])
      (drive! (Registers 'collect/d frontier (KDone) #f #f #f 0) #:fuel fuel))))

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
  (unless (and (= (length names) 13) (= (length names) (length (remove-duplicates names)))
               (andmap (lambda (signature) (<= 1 (length (cdr signature)) 5)) signatures))
    (error 'derive "expected thirteen unique S control points using at most five operands"))
  (define imports
    '(require (only-in "../shared/kernel.rkt"
                      owners-support owners-append fresh-names substitute-goal)
              "03-data.rkt" "../shared/runtime.rkt"))
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
