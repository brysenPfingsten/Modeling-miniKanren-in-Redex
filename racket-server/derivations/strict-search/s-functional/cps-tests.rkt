#lang racket
(require rackunit "anf-tests.rkt" "incremental-tests.rkt"
         (prefix-in a: "01-anf.rkt") (prefix-in c: "02-cps.rkt"))
(module+ test
  (compare-runners a:run a:collect-all c:run c:collect-all)
  (check-incremental-runner 'cps c:run c:resume-once c:collect-all)
  (check-exn exn:fail?
             (lambda ()
               (c:bind/k '(Emit (Owners) (Answer (Owners) (state () () () (label "settled")))
                                (Done (Owners)))
                         (lambda (_state _owners _inherited k) (k '(Empty (Owners))))
                         '(Owners) '() values))))
