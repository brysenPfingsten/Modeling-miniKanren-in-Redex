#lang racket

(require racket/pretty
         "source.rkt" "stages.rkt" "inspection.rkt"
         "../shared/stages/schema.rkt"
         (prefix-in checkpoint: "../matrix/source-s.rkt")
         (prefix-in direct: "interpreter.rkt"))

;; The outer disjunction requires internal force. Its suspended conjunction
;; gives the ordinary bind frame somewhere concrete to retain x's introduction.
(define goal
  '((∃ (x:x)
       (suspend
        ((succeed (label "head"))
         ∧ (∃ (x:y) (x:y =? (sym "new") (label "new")) (label "fresh-y"))
         (label "body-bind"))
        (label "pause"))
       (label "fresh-x"))
    ∨ (fail (label "right")) (label "choice")))

(define (show-owned-frame machine [fuel 10000])
  (when (zero? fuel) (error 'show "owned bind frame not reached"))
  (match machine
    [(M control (K (and frame (Frame 'bind _ _ owners)) _))
     #:when (not (equal? owners '(Owners)))
     (displayln "Refocusing retains the introduction in the ordinary bind frame:")
     (pretty-write `(control ,control))
     (pretty-write frame)]
    [_
     (match (m-step RetainedS machine)
       [(list "force-delay" next)
        (match-define (M control continuation) machine)
        (define inherited (continuation-support RetainedS continuation))
        (displayln "Checkpoint internal-force contraction:")
        (pretty-write (checkpoint:s-contract control inherited))
        (displayln "Retained-scope internal-force contraction:")
        (pretty-write (retained-contract control inherited))
        (show-owned-frame next (sub1 fuel))]
       [(list _ next) (show-owned-frame next (sub1 fuel))]
       [#f (error 'show "expected an internal force and owned bind frame")])]))

(module+ main
  (show-owned-frame (initial-M RetainedS `(collect ,(retained-query-initial goal))))
  (define descriptions (make-weak-hasheq))
  (define result
    (parameterize ([direct:current-closure-observer
                    (lambda (family procedure captures)
                      (record-closure! descriptions family procedure captures))])
      (direct:collect-all (direct:run goal))))
  (displayln "The reconstructed direct interpreter retains x and allocates y as u:1:")
  (pretty-write (reify-frontier descriptions result)))
