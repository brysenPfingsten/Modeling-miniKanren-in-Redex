#lang racket

(require "data.rkt" "machine-correspondence.rkt"
         "compression-correspondence.rkt"
         (only-in "readback.rkt" reify-frontier)
         (only-in "../shared/kernel-equations.rkt" current-atomic-observer)
         (prefix-in f: "machine.rkt")
         (prefix-in r: "registers.rkt")
         (prefix-in c: "compressed.rkt"))

;; The observer measures the demonstration's actual primitive work. Neither
;; bank nor decoder uses it to execute a resumption or represent a closure.
(define (observe-work compute)
  (define reversed '())
  (define value
    (parameterize ([current-atomic-observer
                    (lambda (goal state)
                      (set! reversed (cons (list goal state) reversed)))])
      (compute)))
  (values value (reverse reversed)))

(define (follow-span! bank span)
  (match span
    ['() (void)]
    [(cons (OriginalStep pcs label) rest)
     (define decoded (r:decode bank))
     (match-define (f:Call pc _) decoded)
     (unless (and (member pc pcs) (equal? (functional-step-label decoded) label))
       (error 'show-register-compression "original transition differs from its prescribed span"))
     (pretty-write decoded)
     (printf "  -- ~a -->\n" (or label 'admin))
     (r:step! bank)
     (follow-span! bank rest)]))

(define (show-case goal)
  (define owners '(Owners (Owner (u:9 u:2) (label "existing"))
                         (Owner () (label "empty-introduction"))))
  (define compressed (c:initial goal #:owners owners))
  (define original (compressed->registers compressed))
  (printf "\nAtomic example: ~s\n" goal)
  (displayln "The original register machine takes these three transitions:")
  (define-values (_ original-work)
    (observe-work
     (lambda () (follow-span! original (compressed-step-span compressed)))))
  (pretty-write (r:decode original))
  (displayln "The compressed register machine reaches that configuration in one transition:")
  (pretty-write (compressed->functional compressed))
  (define-values (stepped? compressed-work)
    (observe-work (lambda () (c:step! compressed))))
  (unless (and stepped?
               (equal? (r:decode original) (compressed->functional compressed))
               (equal? original-work compressed-work)
               (= (length original-work) 1))
    (error 'show-register-compression "compressed span or actual kernel work differs"))
  (pretty-write (compressed->functional compressed))
  (match (compressed->functional compressed)
    [(f:Call 'return/d (list _ (KCommit (KDone))))
     (displayln "KCommit is still pending. No answer was committed by this compression.")]
    [_ (error 'show-register-compression "expected the unchanged commitment continuation")])
  (define original-frontier (r:drive! original))
  (define compressed-frontier (c:drive! compressed))
  (unless (equal? original-frontier compressed-frontier)
    (error 'show-register-compression "final Frontiers differ"))
  (printf "Complete run: ~a original transitions, ~a compressed transitions.\n"
          (r:Registers-steps original) (c:Registers-steps compressed))
  (displayln "The same Frontier retains both introduction groups:")
  (pretty-write (reify-frontier compressed-frontier)))

(module+ main
  (show-case '(succeed (label "answer")))
  (show-case '(fail (label "failure"))))
