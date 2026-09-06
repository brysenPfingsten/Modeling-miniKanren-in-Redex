#lang racket

(require rackunit racket/runtime-path
         "../test-support/witnesses.rkt" "../shared/kernel-equations.rkt"
         "partial-oracle.rkt" "../test-support/frontiers.rkt"
         (prefix-in s: "../matrix/source-s.rkt"))

(provide check-incremental-runner)

(define examples validation-witnesses)

;; Only the path before More is settled. Include exact Answers and Owner
;; positions; answer equality after projecting names would be too weak.
(define (settled-prefix frontier)
  (match frontier
    [`(More (Delay ,_ ,_)) '()]
    [`(Emit ,owners ,answer ,rest)
     (cons `(Emit ,owners ,answer) (settled-prefix rest))]
    [`(Forced ,owners ,rest) (cons `(Forced ,owners) (settled-prefix rest))]
    [terminal (list terminal)]))

(define (observe thunk)
  (define reversed '())
  (define result
    (parameterize ([current-atomic-observer
                    (lambda (goal state)
                      (set! reversed (cons (list goal state) reversed)))])
      (thunk)))
  (values result (reverse reversed)))

(define (check-boundaries actual expected resume-once
                          [fuel 1000] [reversed-work '()])
  ;; This inspection does not invoke or traverse a functional Delay body.
  (check-equal? (partial-shape actual) (partial-shape expected)
                "exact completed prefix and suspended boundary")
  (if (pending? expected)
      (let ([before-shape (partial-shape actual)]
            [before-prefix (settled-prefix actual)])
        (when (zero? fuel) (error 'check-boundaries "too many exposed boundaries"))
        (let-values ([(expected* work) (oracle-resume-once expected)]
                     [(actual* actual-work) (observe (lambda () (resume-once actual)))])
          (check-equal? (partial-shape actual) before-shape
                        "resumption does not mutate its input frontier")
          (check-equal? (take (settled-prefix actual*) (length before-prefix)) before-prefix
                        "every previously settled Answer and Owner stays in the same prefix")
          (check-equal? actual-work work
                        "exact atomic goal and incoming State work in this one exposed resumption")
          (check-boundaries actual* expected* resume-once (sub1 fuel)
                            (append (reverse work) reversed-work))))
      (values actual (reverse reversed-work))))

(define (check-example w run resume-once collect-all)
  (define goal (witness-goal w))
  (define owners (witness-owners w))
  (define state (witness-state w))
  (define-values (expected first-work)
    (oracle-initial goal #:owners owners #:state state))
  (define-values (actual actual-first-work)
    (observe (lambda () (run goal #:owners owners #:state state))))
  (check-equal? actual-first-work first-work
                "strict eager work required before the first partial result")
  (define-values (completed rest-work) (check-boundaries actual expected resume-once))
  ;; Check the oracle's structural readback against the unchanged completed
  ;; source semantics too. This does not substitute for per-boundary checks.
  (check-equal? completed (s:s-run `(render ,(witness-initial w))))
  (define-values (collected collector-work)
    (observe (lambda () (collect-all actual))))
  (check-equal? collected completed)
  (check-equal? collector-work rest-work
                "collect-all crosses exactly the remaining exposed resumptions")
  (define-values (no-more no-work)
    (observe (lambda () (resume-once completed))))
  (check-equal? no-more completed)
  (check-equal? no-work '()
                "a completed frontier contains no suspension to cross"))

(define (named name)
  (or (findf (lambda (w) (eq? (witness-name w) name)) examples)
      (error 'named "missing incremental witness ~a" name)))

(define (run-named run name)
  (define w (named name))
  (run (witness-goal w) #:owners (witness-owners w) #:state (witness-state w)))

(define (check-literal-boundaries run resume-once)
  ;; A suspended value is not itself evidence of a forcing event. In the
  ;; nested rail each call adds one visible Forced, even though executing a
  ;; raw resumption can force internally while restoring nested orientation.
  (define rail (run-named run 'nested-rail))
  (check-equal? (partial-shape rail) '(More (Delay (Owners) pending)))
  (define rail1 (resume-once rail))
  (check-equal? (partial-shape rail1) '(Forced (Owners) (More (Delay (Owners) pending))))
  (define rail2 (resume-once rail1))
  (check-equal? (partial-shape rail2)
                '(Forced (Owners) (Forced (Owners) (More (Delay (Owners) pending)))))
  (define rail3 (resume-once rail2))
  (check-equal? (partial-shape rail3)
                '(Forced (Owners) (Forced (Owners) (Forced (Owners) (More (Delay (Owners) pending))))))
  (define rail4 (resume-once rail3))
  (check-match rail4
               `(Forced (Owners) (Forced (Owners) (Forced (Owners) (Forced (Owners)
                 (Emit (Owners)
                       (Answer (Owners (Owner (u:0) (label "fresh-A")))
                               (state ((u:0 (sym "A"))) ()
                                      ((u:0 =? (sym "A") (label "A"))) (label "initial")))
                       (Emit (Owners)
                             (Answer (Owners (Owner (u:0) (label "fresh-B")))
                                     (state ((u:0 (sym "B"))) ()
                                            ((u:0 =? (sym "B") (label "B"))) (label "initial")))
                             (Last (Owners)
                                   (Answer (Owners (Owner (u:0) (label "fresh-C")))
                                           (state ((u:0 (sym "C"))) ()
                                                  ((u:0 =? (sym "C") (label "C")))
                                                  (label "initial")))))))))))
  (check-equal?
   (partial-shape (run-named run 'allocation-across-delay))
   '(More (Delay (Owners (Owner (u:0) (label "outer-owner"))) pending)))
  (check-equal?
   (resume-once (run-named run 'allocation-across-delay))
   '(Forced
     (Owners (Owner (u:0) (label "outer-owner")))
     (Last (Owners)
           (Answer (Owners (Owner (u:1) (label "inner-owner")))
                   (state ((u:1 (sym "A")) (u:0 (sym "A"))) ()
                          ((u:0 =? (sym "A") (label "outer-value"))
                           (u:1 =? u:0 (label "inner-alias")))
                          (label "initial"))))))
  (check-equal?
   (partial-shape (run-named run 'delayed-sibling-capture))
   '(More (Delay (Owners (Owner (u:0) (label "shared-owner"))) pending)))
  (check-equal?
   (run-named run 'empty-binder)
   '(Last (Owners) (Answer (Owners (Owner () (label "empty-fresh")))
                          (state () () () (label "initial")))))
  (check-equal?
   (run-named run 'allocated-failure)
   '(Done (Owners (Owner (u:0) (label "failed-owner")))))
  (check-false (pending? (run-named run 'answer-local-continuation)))
  (check-false (pending? (run-named run 'eager-bind-residual)))
  (check-equal? (run-named run 'intermediate-success-then-failure)
                '(Done (Owners (Owner (u:0) (label "temporary-owner")))))
  (check-equal? (partial-shape (run-named run 'delayed-continuation-schedule))
                '(More (Delay (Owners (Owner (u:0) (label "shared-input-owner"))) pending)))
  (define-values (_ready sibling-work)
    (observe (lambda () (run-named run 'strict-sibling-maturation))))
  (check-equal? (map (lambda (event) (last (first event))) sibling-work)
                '((label "left-ready") (label "right-start") (label "right-finished")))
  (define-values (_pending continuation-work)
    (observe (lambda () (run-named run 'delayed-continuation-schedule))))
  (check-equal? (map (lambda (event) (last (first event))) continuation-work)
                '((label "input-A") (label "input-B"))))

(define (check-incremental-runner label run resume-once collect-all)
  (test-case (format "~a: literal incremental boundaries" label)
    (check-literal-boundaries run resume-once))
  (for ([w (in-list examples)])
    (test-case (format "~a: boundary work and exact S allocation ~a" label (witness-name w))
      (check-example w run resume-once collect-all))))

(define-runtime-path direct-module "00-direct.rkt")
(module+ test
  (check-incremental-runner 'direct
                            (dynamic-require direct-module 'run)
                            (dynamic-require direct-module 'resume-once)
                            (dynamic-require direct-module 'collect-all)))
