#lang racket
(require rackunit "../test-support/witnesses.rkt" "strictness-tests.rkt"
         (only-in "partial-oracle.rkt" search->partial)
         (prefix-in d: "00-direct.rkt") (prefix-in a: "01-anf.rkt")
         (prefix-in c: "02-cps.rkt") (prefix-in f: "03-defunc.rkt")
         (prefix-in m: "04-machine.rkt") (prefix-in r: "05-registers.rkt")
         (prefix-in ref: "../shared/stages/schema.rkt")
         (prefix-in rows: "../matrix/stages/instances.rkt"))

(module+ test
  ;; Each explicit program is checked against the independent S machine as
  ;; well as against its predecessor. Evaluate the reference once per case.
  ;; A functional Delay body is opaque before defunctionalization; compare its
  ;; exact eager chunk and full forced observation. transition-tests checks
  ;; suspended bodies and administrative machine spans structurally later.
  (for ([w (in-list validation-witnesses)])
    (define initial (witness-initial w))
    (define expected-frontier
      (frontier-shape (search->partial (ref:run-M rows:S initial))))
    (define expected-observation (ref:run-M rows:S `(render ,initial)))
    (for ([runners (in-list (list (list d:run d:collect-all)
                                 (list a:run a:collect-all)
                                 (list c:run c:collect-all)
                                 (list f:run f:collect-all)
                                 (list m:run m:collect-all)
                                 (list r:run r:collect-all)))])
      (match-define (list run collect-all) runners)
      (define frontier
        (run (witness-goal w) #:owners (witness-owners w) #:state (witness-state w)))
      (check-equal?
       (frontier-shape frontier)
       expected-frontier)
      (check-equal?
       (collect-all frontier)
       expected-observation))))
