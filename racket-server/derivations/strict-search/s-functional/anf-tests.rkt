#lang racket
(require rackunit "../test-support/witnesses.rkt" "../shared/kernel-equations.rkt" "incremental-tests.rkt"
         (prefix-in d: "00-direct.rkt") (prefix-in a: "01-anf.rkt")
         (prefix-in c: "../test-support/corpus.rkt"))
(provide compare-runners)
(define (capture runner collect goal owners state)
  (define events '())
  (define result
    (parameterize ([current-atomic-observer
                    (lambda (g s) (set! events (cons (list g s) events)))])
      (collect (runner goal #:owners owners #:state state))))
  (list result (reverse events)))
(define (compare-runners predecessor predecessor-collect successor successor-collect)
  (for ([w (in-list validation-witnesses)])
    (check-equal? (capture successor successor-collect (witness-goal w) (witness-owners w) (witness-state w))
                  (capture predecessor predecessor-collect (witness-goal w) (witness-owners w) (witness-state w))
                  (symbol->string (witness-name w))))
  (for ([g (in-list c:search-corpus)])
    (check-equal? (capture successor successor-collect g '(Owners) '(state () () () (label "initial")))
                  (capture predecessor predecessor-collect g '(Owners) '(state () () () (label "initial"))))))
(module+ test
  (compare-runners d:run d:collect-all a:run a:collect-all)
  (check-incremental-runner 'anf a:run a:resume-once a:collect-all)
  (check-exn exn:fail?
             (lambda ()
               (a:bind/a '(Emit (Owners) (Answer (Owners) (state () () () (label "settled")))
                                (Done (Owners)))
                         (lambda (_state _owners _inherited) '(Empty (Owners)))
                         '(Owners) '()))))
