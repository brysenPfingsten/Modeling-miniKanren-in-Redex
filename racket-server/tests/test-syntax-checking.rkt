#lang racket

(require rackunit
         rackunit/text-ui
         "../src/syntax-checking.rkt")

(define GOOD-SYNTAX-PROG
  "
(defrel (foo x) (== x 'bar))
(run* (q) (foo q))
")

(define BAD-SYNTAX-PROG
  "
(defrel (foo x) (== x 'foo))
(run* (foo q))
")

(define LOOP-PROG
  "
(defrel (loopo x) (loopo x))
(run* (q) (loopo q))
")

(define ARITY-MISMATCH
  "
(defrel (foo x y)
  (== x 'x))
(run* (q r s t) (foo q r s t))
")

(define-test-suite SYNTAX-CHECKING
  (test-not-exn "syntactically valid program is accepted"
                (lambda () (check-syntax-capture-error GOOD-SYNTAX-PROG)))

  (test-exn "syntactically invalid program is rejected"
            exn:fail?
            (lambda () (check-syntax-capture-error BAD-SYNTAX-PROG)))

  (test-not-exn "recursive program is checked without evaluation"
                (lambda () (check-syntax-capture-error LOOP-PROG)))

  (test-exn "relation-call arity mismatch is rejected"
            exn:fail?
            (lambda () (check-syntax-capture-error ARITY-MISMATCH))))

(define/provide-test-suite SYNTAX-CHECKER
  #:before (thunk (displayln "Running syntax-capture checks..."))
  #:after (thunk (displayln "Finished syntax-capture checks."))
  SYNTAX-CHECKING)

(module+ test
  (run-tests SYNTAX-CHECKER))
