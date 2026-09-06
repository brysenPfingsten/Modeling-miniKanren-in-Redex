#lang racket
(require rackunit "../test-support/witnesses.rkt" "../shared/kernel-equations.rkt"
         (prefix-in d: "00-direct.rkt")
         (prefix-in s: "../matrix/source-s.rkt")
         (prefix-in c: "../test-support/corpus.rkt"))

(module+ test
  ;; Compare all provenance before applying any representation projection.
  (for ([w (in-list validation-witnesses)])
    (check-equal? (d:collect-all (d:run (witness-goal w) #:owners (witness-owners w)
                                     #:state (witness-state w)))
                  (s:s-run `(render ,(witness-initial w)))
                  (symbol->string (witness-name w))))
  (for ([g (in-list c:search-corpus)])
    (check-equal? (d:collect-all (d:run g)) (s:s-run `(render ,(s:s-initial g)))))
  (define events '())
  (define strict-goal
    '(((succeed (label "a")) ∨ (succeed (label "b")) (label "left")) ∧
      (succeed (label "continue")) (label "bind")))
  (parameterize ([current-atomic-observer
                  (lambda (g _s) (set! events (append events (list g))))])
    (void (d:run strict-goal)))
  (check-equal? (map last events)
                '((label "a") (label "b") (label "continue") (label "continue")))
  (set! events '())
  (define delayed
    (parameterize ([current-atomic-observer
                    (lambda (g _s) (set! events (append events (list g))))])
      (d:run '(suspend (succeed (label "later")) (label "delay")))))
  (check-equal? events '())
  (parameterize ([current-atomic-observer
                  (lambda (g _s) (set! events (append events (list g))))])
    (void (d:resume-once delayed)))
  (check-equal? (map last events) '((label "later")))
  ;; Normal run commits a completed answer to Emit before resume/collect.
  ;; Inspect the actual source-level procedure and invoke its raw body: it
  ;; returns active Search without fabricating settled output or Forced.
  (define prefixed
    (d:run '((succeed (label "A")) ∨
             (suspend (suspend (succeed (label "B")) (label "inner")) (label "outer"))
             (label "choice"))))
  (match-define `(Emit (Owners) (Answer (Owners) ,_)
                      (More (Delay (Owners) ,tip))) prefixed)
  (check-true (procedure? tip))
  (define next (tip))
  (check-match next `(Delay (Owners) ,(? procedure?)))
  (check-match (d:resume-once prefixed)
               `(Emit (Owners) (Answer (Owners) ,_)
                      (Forced (Owners) (More (Delay (Owners) ,(? procedure?))))))
  ;; An eager intermediate answer can still fail its pending conjunction.
  ;; Direct evaluation therefore yields active Search, and only commit turns
  ;; the completed current chunk into settled frontier constructors.
  (define active
    (d:eval/s '((succeed (label "raw-A")) ∨
                (suspend (succeed (label "raw-B")) (label "raw-delay"))
                (label "raw-choice"))
              '(state () () () (label "initial")) '(Owners) '()))
  (check-match active `(Yield (Owners) (Answer (Owners) ,_) (Delay (Owners) ,(? procedure?))))
  (set! events '())
  (define committed
    (parameterize ([current-atomic-observer
                    (lambda (g _s) (set! events (cons g events)))])
      (d:commit/s active)))
  (check-match committed
               `(Emit (Owners) (Answer (Owners) ,_) (More (Delay (Owners) ,(? procedure?)))))
  (check-equal? events '() "commit constructs the eager frontier without forcing or kernel work")
  (define continued? #f)
  (check-exn exn:fail?
             (lambda ()
               (d:bind/s committed (lambda (_state _owners _inherited)
                                      (set! continued? #t)
                                      '(Empty (Owners)))
                         '(Owners) '())))
  (check-false continued? "settled frontier must never reach a core bind continuation"))
