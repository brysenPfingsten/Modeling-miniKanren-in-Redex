#lang racket
(require rackunit "anf-tests.rkt" "incremental-tests.rkt" "03-data.rkt"
         (prefix-in c: "02-cps.rkt") (prefix-in d: "03-defunc.rkt"))
(module+ test
  (compare-runners c:run c:collect-all d:run d:collect-all)
  (check-incremental-runner 'defunctionalized d:run d:resume-once d:collect-all)
  (check-exn exn:fail?
             (lambda ()
               (d:bind/d '(Emit (Owners) (Answer (Owners) (state () () () (label "settled")))
                                (Done (Owners)))
                         (GRight '(succeed (label "should-not-run")))
                         '(Owners) '() (KDone))))
  (check-true (Failure? (atomic/data '(fail (label "fail"))
                                   '(state () () () (label "initial")))))
  (check-true (Success? (atomic/data '(succeed (label "ok"))
                                   '(state () () () (label "initial"))))))
