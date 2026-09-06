#lang racket

(require "03-data.rkt" "machine-correspondence.rkt"
         (prefix-in f: "04-machine.rkt")
         (prefix-in a: "../shared/stages/schema.rkt")
         (prefix-in rows: "../matrix/stages/instances.rkt")
         (prefix-in s: "../matrix/source-s.rkt"))

;; Small inspectable run using the two existing transition functions. Neither
;; driver recognizes a pending tip; only its machine's finality rule stops it.
(define (finish-functional current [fuel 1000])
  (match current
    [(f:Halted _) current]
    [_
     (when (zero? fuel) (error 'finish-functional "fuel exhausted"))
     (finish-functional (f:step current) (sub1 fuel))]))

(define (finish-refocused current [fuel 1000])
  (match (a:m-step rows:S current)
    [#f current]
    [(list _ next)
     (when (zero? fuel) (error 'finish-refocused "fuel exhausted"))
     (finish-refocused next (sub1 fuel))]))

(define (normalize-administration current)
  (if (a:m-admin? rows:S current)
      (match (a:m-step rows:S current)
        [(list "admin" next) (normalize-administration next)])
      current))

(define (show-operation label functional-start refocused-start)
  (define functional-end (finish-functional functional-start))
  (define refocused-end (finish-refocused refocused-start))
  (unless (equal? (functional->M functional-end) refocused-end)
    (error 'show-operation "different final configurations"))
  (unless (a:m-final? rows:S refocused-end)
    (error 'show-operation "refocused endpoint is not a native final state"))
  (displayln label)
  (pretty-write refocused-end)
  (displayln "Both machines halted by their own rules; direct images agree.")
  (values (f:Halted-value functional-end) (a:M-control refocused-end)))

(module+ main
  (define goal
    '((succeed (label "answer"))
      ∨ (suspend (fail (label "later failure")) (label "pause"))
      (label "choice")))
  (define functional-start (f:initial goal))
  (define refocused-start (a:initial-M rows:S (s:s-query-initial goal)))
  (displayln "Functional initial continuation:")
  (pretty-write (last (f:Call-operands functional-start)))
  (displayln "Independently decomposed source continuation:")
  (pretty-write (a:M-continuation refocused-start))
  (unless (equal? (functional->M functional-start) refocused-start)
    (error 'show-correspondence "initial direct configuration map differs"))
  (define-values (functional-frontier source-frontier)
    (show-operation "run = commit(eval): pending work is a terminal Frontier value"
                    functional-start refocused-start))
  (define-values (_functional-complete _source-complete)
    (show-operation "advance: preserve the answer, explicitly cross the pending Delay"
                    (f:Call 'advance/d (list functional-frontier (KDone)))
                    (a:initial-M rows:S `(advance ,source-frontier))))
  (define owners '(Owners (Owner (u:9) (label "saved-owner"))))
  (define state '(state () () () (label "initial")))
  (define body '(∃ (x:new) (x:new =? u:9 (label "alias")) (label "fresh")))
  (define functional-force
    (f:Call 'force/d (list `(Delay ,owners ,(REval body state '(u:9))) (KCommit (KDone)))))
  (define native-force
    (a:initial-M rows:S `(commit (force (Delay ,owners (eval (Owners) ,body ,state))))))
  (match-define (list "force-delay" after-force) (a:m-step rows:S native-force))
  (define pending-prefix (normalize-administration after-force))
  (unless (equal? (normalize-administration (functional->M (f:step functional-force)))
                  pending-prefix)
    (error 'show-correspondence "pending ownership phases differ"))
  (displayln "Internal force: independently derived pending prefix, before fresh allocation")
  (pretty-write pending-prefix)
  (define-values (_functional-forced _source-forced)
    (show-operation "Internal force: restore saved ownership only after Search matures"
                    functional-force native-force)))
