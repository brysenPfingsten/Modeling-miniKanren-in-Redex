#lang racket

(require rackunit "../shared/kernel.rkt")

;; Reject semantic callbacks throughout a result, not just at its outer tag.
(define (data-only? value)
  (match value
    [(? procedure?) #f]
    [(cons head tail) (and (data-only? head) (data-only? tail))]
    [(? vector?) (for/and ([field (in-vector value)]) (data-only? field))]
    [(? struct?) (data-only? (struct->vector value))]
    [_ #t]))

(module+ test
  (define fixtures
    (list
     (list 'S atomic/s 'u:0
           '(state () () () (label "incoming"))
           '(state ((u:0 (sym "A"))) ()
                   ((u:0 =? (sym "A") (label "bind"))) (label "incoming"))
           '(state ((u:0 (sym "A"))) ((u:0 (sym "B")))
                   ((u:0 =? (sym "A") (label "bind"))) (label "incoming")))
     (list 'E atomic/e 'u:0
           '(state (Support u:9 u:0 u:7) () () () (label "incoming"))
           '(state (Support u:9 u:0 u:7) ((u:0 (sym "A"))) ()
                   ((u:0 =? (sym "A") (label "bind"))) (label "incoming"))
           '(state (Support u:9 u:0 u:7) ((u:0 (sym "A"))) ((u:0 (sym "B")))
                   ((u:0 =? (sym "A") (label "bind"))) (label "incoming")))
     (list 'N atomic/n 1
           '(state 3 () () () (label "incoming"))
           '(state 3 ((1 (sym "A"))) ()
                   ((1 =? (sym "A") (label "bind"))) (label "incoming"))
           '(state 3 ((1 (sym "A"))) ((1 (sym "B")))
                   ((1 =? (sym "A") (label "bind"))) (label "incoming")))))

  (for ([fixture (in-list fixtures)])
    (match-define (list row atomic variable initial bound constrained) fixture)
    (test-case (format "~a atomic outcomes are eager native data" row)
      ;; These are inspectable completed results, not selectors needing a
      ;; subsequent callback application to finish primitive kernel work.
      (define success (atomic '(succeed (label "success")) initial))
      (define failure (atomic '(fail (label "failure")) initial))
      (define equality (atomic `(,variable =? (sym "A") (label "bind")) initial))
      (define disequality (atomic `(,variable != (sym "B") (label "keep")) bound))
      (check-equal? success (Success initial))
      (check-equal? failure (Failure))
      (check-equal? equality (Success bound))
      (check-equal? disequality (Success constrained))
      (for ([result (in-list (list success failure equality disequality))])
        (check-true (data-only? result)))
      (check-equal? (atomic `(,variable != (sym "A") (label "reject")) bound)
                    (Failure))
      (check-equal? (atomic `(,variable =? (,variable : empty) (label "occurs")) initial)
                    (Failure))
      (check-equal? (atomic '((sym "A") =? (sym "B") (label "conflict")) initial)
                    (Failure))
      (check-exn exn:fail:contract?
                 (lambda () (atomic '(not-an-atomic-goal) initial))))))
