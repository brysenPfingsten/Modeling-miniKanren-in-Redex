#lang racket
(require "../shared/kernel-equations.rkt"
         (only-in "partial-oracle.rkt" [partial-shape frontier-shape])
         (prefix-in d: "00-direct.rkt")
         (prefix-in r: "05-registers.rkt")
         (prefix-in q: "../shared/maps.rkt"))

;; The first run returns settled Emit with unfinished Search inside More.
;; Its More(Delay(...)) tip remains unforced. Both subsequent
;; observations preserve that answer while crossing just one exposed Delay.
;; The sibling worlds independently allocate u:0 on opposite sides of Delay.
(define demo-goal
  '((∃ (x:a) (x:a =? (sym "A") (label "A")) (label "left-owner"))
    ∨ (suspend
       (suspend
        (∃ (x:b) (x:b =? (sym "B") (label "B")) (label "right-owner"))
        (label "inner-delay"))
       (label "outer-delay"))
    (label "eager-prefix")))

(define (show-step label compute)
  (define reversed-work '())
  (define result
    (parameterize ([current-atomic-observer
                    (lambda (goal _state)
                      (set! reversed-work (cons (last goal) reversed-work)))])
      (compute)))
  (printf "~a\npartial frontier: ~s\natomic work: ~s\n\n"
          label (frontier-shape result) (reverse reversed-work))
  result)

(define (check-registers direct registers)
  (unless (equal? (frontier-shape direct) (frontier-shape registers))
    (error 'show "partial register frontier differs from direct result")))

(module+ main
  (define initial (show-step "run: settled Emit followed by unfinished More(Delay(...))"
                             (lambda () (d:run demo-goal))))
  (define initial/r (r:run demo-goal))
  (check-registers initial initial/r)
  (define once (show-step "resume-once: first exposed boundary crossed"
                          (lambda () (d:resume-once initial))))
  (define once/r (r:resume-once initial/r))
  (check-registers once once/r)
  (define twice (show-step "resume-once: second exposed boundary crossed"
                           (lambda () (d:resume-once once))))
  (check-registers twice (r:resume-once once/r))
  (define collected
    (show-step "collect-all: explicitly cross every remaining boundary from the initial result"
               (lambda () (d:collect-all initial))))
  (unless (equal? collected (r:collect-all initial/r))
    (error 'show "completed register observation differs from direct result"))
  (printf "N projection of the completed S observation: ~s\n" (q:Q-SN collected)))
