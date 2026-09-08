#lang racket

(require racket/runtime-path
         (only-in "derive.rkt" control-definitions control-signatures)
         (only-in "../shared/control-transform.rkt" transform-tail))
(provide register-module-text generated-text generate! check-generated!)
(define-runtime-path directory ".")

;; This runtime only changes the representation of tail control transfers.
;; Its dispatch loop is a host trampoline; it constructs no object Delay.
(define register-runtime
  '((struct Registers (pc r0 r1 r2 r3 r4 steps) #:mutable #:transparent)
    ;; Racket evaluates all operands, left to right, before entering jump!.
    ;; Each dispatch arm also snapshots its input registers in local bindings.
    ;; Thus a transfer can use old r0 while replacing r0 and later registers.
    (define (jump! bank pc r0 [r1 #f] [r2 #f] [r3 #f] [r4 #f])
      (set-Registers-r0! bank r0)
      (set-Registers-r1! bank r1)
      (set-Registers-r2! bank r2)
      (set-Registers-r3! bank r3)
      (set-Registers-r4! bank r4)
      (set-Registers-pc! bank pc))
    (define (halt! bank value) (jump! bank 'halt value))
    (define (operand-count pc)
      (match pc
        ['halt 1]
        [_ (match (assq pc signatures)
             [(cons _ parameters) (length parameters)]
             [#f (raise-argument-error 'operand-count "known program counter" pc)])]))
    (define (register-values bank)
      (list (Registers-r0 bank) (Registers-r1 bank) (Registers-r2 bank)
            (Registers-r3 bank) (Registers-r4 bank)))
    ;; Arity comes from the program, and all inactive slots have one canonical
    ;; representation. The step counter is runner metadata, erased by decode.
    (define (validate-bank! bank)
      (unless (Registers? bank)
        (raise-argument-error 'decode "Registers?" bank))
      (define arity (operand-count (Registers-pc bank)))
      (unless (and (exact-nonnegative-integer? (Registers-steps bank))
                   (andmap not (drop (register-values bank) arity)))
        (raise-argument-error 'decode "canonical register configuration" bank))
      arity)
    (define (decode bank)
      (define arity (validate-bank! bank))
      (match (Registers-pc bank)
        ['halt (m:Halted (Registers-r0 bank))]
        [pc (m:Call pc (take (register-values bank) arity))]))
    (define (from-machine current)
      (match current
        [(m:Halted value) (Registers 'halt value #f #f #f #f 0)]
        [(m:Call pc operands)
         (unless (and (not (eq? pc 'halt))
                      (list? operands)
                      (= (length operands) (operand-count pc)))
           (raise-argument-error 'from-machine "Call with exact program arity" current))
         (define bank (Registers 'halt #f #f #f #f #f 0))
         (apply jump! bank pc operands)
         bank]
        [_ (raise-argument-error 'from-machine "Call or Halted" current)]))
    (define (initial goal #:owners [owners '(Owners)]
                     #:state [state '(state () () () (label "initial"))]
                     #:relations [relations #f])
      (Registers 'eval/d (retain-goal relations goal) state owners '()
                 (KCommit (if relations (KProgram relations (KDone)) (KDone))) 0))
    (define (step! bank)
      (validate-bank! bank)
      (match (Registers-pc bank)
        ['halt #f]
        [_ (dispatch! bank)
           (set-Registers-steps! bank (add1 (Registers-steps bank)))
           #t]))
    (define (drive/steps! bank fuel)
      (match (Registers-pc bank)
        ['halt (Registers-r0 bank)]
        [_ (when (zero? fuel) (exhausted 's-reference-registers (decode bank)))
           (step! bank)
           (drive/steps! bank (sub1 fuel))]))
    (define (drive! bank #:fuel [fuel 100000])
      (check-fuel fuel)
      (validate-bank! bank)
      (drive/steps! bank fuel))
    (define (run goal #:owners [owners '(Owners)]
                 #:state [state '(state () () () (label "initial"))]
                 #:relations [relations #f]
                 #:fuel [fuel 100000])
      (drive! (initial goal #:owners owners #:state state #:relations relations) #:fuel fuel))
    (define (resume-once frontier #:fuel [fuel 100000])
      (match frontier
        [`(program ,relations ,body)
         (drive! (Registers 'advance/d body '() (KProgram relations (KDone)) #f #f 0) #:fuel fuel)]
        [_ (drive! (Registers 'advance/d frontier '() (KDone) #f #f 0) #:fuel fuel)]))
    (define (collect-all frontier #:fuel [fuel 100000])
      (match frontier
        [`(program ,relations ,body)
         (drive! (Registers 'collect/d body '() (KProgram relations (KDone)) #f #f 0) #:fuel fuel)]
        [_ (drive! (Registers 'collect/d frontier '() (KDone) #f #f 0) #:fuel fuel)]))))

;; Compression reuses this compiler on an explicitly transformed list of
;; control definitions. The emitted instructions never execute machine:step.
(define (register-module-text definitions source-description
                              #:machine [machine-path "machine.rkt"])
  (define signatures (control-signatures definitions))
  (define names (map car signatures))
  (unless (and (pair? names)
               (= (length names) (length (remove-duplicates names)))
               (not (member 'halt names))
               (andmap (lambda (signature) (<= 1 (length (cdr signature)) 5)) signatures))
    (error 'register-module-text "expected unique controls with one to five operands"))
  (define clauses
    (for/list ([definition (in-list definitions)])
      (match-define `(define (,name ,arguments ...) ,body ...) definition)
      `[',name
        ,@(for/list ([argument (in-list arguments)] [slot (in-naturals)])
            `(define ,argument (,(string->symbol (format "Registers-r~a" slot)) bank)))
        ,(transform-tail `(begin ,@body) names
                         (lambda (pc args)
                           (unless (= (length args) (length (cdr (assq pc signatures))))
                             (error 'register-module-text "wrong operand count in ~e" `(,pc ,@args)))
                           `(jump! bank ',pc ,@args))
                         (lambda (value) `(halt! bank ,value)))]))
  (define forms
    (append
     (list '(require (only-in "../shared/kernel.rkt"
                             owners-support owners-append fresh-names substitute-goal)
                     "data.rkt" "relations.rkt" "../shared/runtime.rkt")
           `(require (prefix-in m: ,machine-path))
           '(provide (all-defined-out))
           `(define signatures ',signatures))
     register-runtime
     (list `(define (dispatch! bank)
              (match (Registers-pc bank)
                ,@clauses
                [other (raise-argument-error 'dispatch! "active program counter" other)])))))
  (with-output-to-string
    (lambda ()
      (displayln "#lang racket")
      (displayln (format ";; Generated from ~a. Regenerate; do not edit." source-description))
      (parameterize ([pretty-print-columns 96])
        (for ([form (in-list forms)] [index (in-naturals)])
          (unless (zero? index) (newline))
          (pretty-write form))))))

(define (generated-text)
  (register-module-text (control-definitions) "defunc.rkt by register-derive.rkt"))

(define (generate!)
  (call-with-output-file (build-path directory "registers.rkt")
    (lambda (output) (display (generated-text) output)) #:exists 'truncate/replace))

(define (check-generated!)
  (unless (equal? (generated-text) (file->string (build-path directory "registers.rkt")))
    (error 'check-generated! "registers.rkt is stale; regenerate with register-derive.rkt"))
  #t)

(module+ main
  (match (vector->list (current-command-line-arguments))
    ['() (generate!) (displayln "Generated registers.rkt from S reference defunc.rkt.")]
    ['("--check") (check-generated!) (displayln "Generated registers match defunc.rkt.")]
    [_ (error 'register-derive "usage: racket register-derive.rkt [--check]")]))
