#lang racket

(require "data.rkt" "source.rkt" "stages.rkt"
         "machine-correspondence.rkt"
         (only-in "readback.rkt" reify-frontier)
         (prefix-in f: "machine.rkt")
         (prefix-in a: "../shared/stages/schema.rkt"))

(define (normalize-administration current [fuel 10000])
  (cond
    [(a:m-admin? RetainedS current)
     (when (zero? fuel) (error 'show-machines "native administration exhausted fuel"))
     (match-define (list "admin" next) (a:m-step RetainedS current))
     (normalize-administration next (sub1 fuel))]
    [else current]))

;; Advance the two transition functions under the same prescribed-step
;; relation as the gate. There is no search through additional semantic work.
(define (walk functional native [fuel 10000])
  (define mapped (normalize-administration (functional->M functional)))
  (unless (equal? mapped native) (error 'show-machines "configuration images disagree"))
  (match functional
    [(f:Halted value)
     (unless (a:m-final? RetainedS native) (error 'show-machines "native side has not halted"))
     (displayln "Both machines halt at the same Frontier:")
     (pretty-write (reify-frontier value))
     value]
    [_
     (when (zero? fuel) (error 'show-machines "functional machine exhausted fuel"))
     (match functional
       [(f:Call 'force/d (list _ _ _))
        (displayln "Internal force, before its single source contraction:")
        (pretty-write functional)
        (pretty-write native)]
       [(f:Call 'eval/d (list _ _ _ _ (KConj _ owners _ _)))
        #:when (not (equal? owners '(Owners)))
        (displayln "An ordinary conjunction/bind frame retains the introductions:")
        (pretty-write functional)
        (pretty-write native)]
       [_ (void)])
     (define label (functional-step-label functional))
     (define next (f:step functional))
     (define native-next
       (match label
         [#f native]
         [_
          (match-define (list actual after) (a:m-step RetainedS native))
          (unless (equal? actual label) (error 'show-machines "operation labels disagree"))
          (normalize-administration after)]))
     (walk next native-next (sub1 fuel))]))

(module+ main
  (define goal
    '((∃ (x:x)
         (suspend
          ((succeed (label "head"))
           ∧ (∃ (x:y) (x:y =? x:x (label "alias")) (label "fresh-y"))
           (label "body-bind"))
          (label "pause"))
         (label "fresh-x"))
      ∨ (fail (label "right")) (label "choice")))
  (define initial (f:initial goal))
  (displayln "The functional initial continuation still contains KCommit:")
  (pretty-write (last (f:Call-operands initial)))
  (define frontier
    (walk initial
          (normalize-administration (a:initial-M RetainedS (retained-query-initial goal)))))
  (displayln "Advance the exposed Delay; its body requires internal force:")
  (define completed
    (walk (f:Call 'advance/d (list frontier '() (KDone)))
          (normalize-administration
           (a:initial-M RetainedS `(advance ,(reify-frontier frontier))))))
  (unless (retained-observation? (reify-frontier completed))
    (error 'show-machines "expected a completed example")))
