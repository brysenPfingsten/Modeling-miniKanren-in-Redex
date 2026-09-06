#lang racket

(require rackunit
         "data.rkt"
         (prefix-in m: "machine.rkt")
         (prefix-in r: "registers.rkt")
         "register-derive.rkt"
         (only-in "../shared/runtime.rkt" exn:fail:budget?))

(define yes '(succeed (label "yes")))
(define paused '(∃ (x:x)
                    (suspend (x:x =? (sym "answer") (label "bind-x")) (label "pause"))
                    (label "fresh-x")))

(module+ test
  (test-case "register dispatcher is generated from the retained control definitions"
    (check-true (check-generated!))
    (check-equal? r:signatures m:signatures)
    (check-exn exn:fail?
               (lambda () (register-module-text '((define (eval/d goal) (eval/d)))
                                                 "invalid zero-operand call")))
    (check-exn exn:fail?
               (lambda () (register-module-text '((define (same/d x) x)
                                                   (define (same/d y) y))
                                                 "invalid duplicate control"))))

  (test-case "structural encoding preserves active fields and clears inactive fields"
    ;; These fixtures exercise representation arities, independently of the
    ;; semantic reachability checks in register-compression-tests.rkt.
    (for ([signature (in-list m:signatures)])
      (match-define (cons pc parameters) signature)
      (define current (m:Call pc parameters))
      (define bank (r:from-machine current))
      (check-equal? (r:decode bank) current)
      (check-equal? (drop (r:register-values bank) (length parameters))
                    (make-list (- 5 (length parameters)) #f))
      (r:set-Registers-steps! bank 271)
      (check-equal? (r:decode bank) current "dispatch counter is erased"))
    (define final (m:Halted '(Done (Owners))))
    (check-equal? (r:decode (r:from-machine final)) final))

  (test-case "decoding rejects malformed register layouts and encoding rejects wrong arity"
    (for ([bank (in-list
                 (list 'not-registers
                       (r:Registers 'unknown 1 #f #f #f #f 0)
                       (r:Registers 'return/d 'value (KDone) 'stale #f #f 0)
                       (r:Registers 'halt '(Done (Owners)) #f #f #f 'stale 0)
                       (r:Registers 'halt '(Done (Owners)) #f #f #f #f -1)))])
      (check-exn exn:fail? (lambda () (r:decode bank))))
    (for ([current (in-list
                    (list (m:Call 'unknown '(x))
                          (m:Call 'return/d '(x))
                          (m:Call 'return/d '(x y z))
                          (m:Call 'return/d 'not-a-list)
                          (m:Call 'halt '(x))
                          'not-a-machine))])
      (check-exn exn:fail? (lambda () (r:from-machine current)))))

  (test-case "jump operands are evaluated before assignments, in their original order"
    (define bank (r:Registers 'return/d 'old-r0 'old-r1 #f #f #f 0))
    (define observations '())
    (r:jump! bank 'return/d
             (begin
               (set! observations (cons (r:Registers-r0 bank) observations))
               (r:Registers-r1 bank))
             (begin
               (set! observations (cons (r:Registers-r1 bank) observations))
               (r:Registers-r0 bank)))
    (check-equal? (reverse observations) '(old-r0 old-r1))
    (check-equal? (r:decode bank) (m:Call 'return/d '(old-r1 old-r0)))
    (r:halt! bank '(Done (Owners)))
    (check-equal? (r:register-values bank) '((Done (Owners)) #f #f #f #f)))

  (test-case "every instruction in a complete atomic run is one checkpoint transition"
    (define bank (r:initial yes))
    (check-equal? (r:decode bank) (m:initial yes))
    (define (check-trace current count)
      (check-equal? (r:decode bank) current)
      (check-equal? (r:Registers-steps bank) count)
      (match current
        [(m:Halted _)
         (check-false (r:step! bank))
         (check-equal? (r:decode bank) current)
         (check-equal? (r:Registers-steps bank) count)]
        [_ (define next (m:step current))
           (check-true (r:step! bank))
           (check-trace next (add1 count))]))
    (check-trace (m:initial yes) 0))

  (test-case "public initial, advancement, collection and halt boundaries agree"
    (define register-frontier (r:run paused))
    (define machine-frontier (m:run paused))
    (check-equal? register-frontier machine-frontier)
    (check-equal? (r:resume-once register-frontier) (m:resume-once machine-frontier))
    (check-equal? (r:collect-all register-frontier) (m:collect-all machine-frontier))
    (define complete (r:collect-all register-frontier))
    (check-equal? (r:resume-once complete) complete)
    (check-equal? (r:collect-all complete) complete))

  (test-case "transition budgets count dispatch instructions and permit zero-step halt"
    (check-exn exn:fail:budget? (lambda () (r:drive! (r:initial yes) #:fuel 0)))
    (check-exn exn:fail? (lambda () (r:drive! (r:initial yes) #:fuel -1)))
    (check-equal? (r:drive! (r:from-machine (m:Halted '(Done (Owners)))) #:fuel 0)
                  '(Done (Owners)))))
