#lang racket

(provide empty-mk-state
         mk-kernel-cases)

;; Shared input data for the intrinsic Kmk checks and the temporary parity
;; check against the production kernel.  This module deliberately contains no
;; semantic imports: both presentations consume exactly the same seven cases.
(define empty-mk-state
  '(state () () () (label "s")))

(define u0-cat-state
  '(state ((u:0 (sym "cat")))
          ()
          ((u:0 =? (sym "cat") (label "bind-cat")))
          (label "s")))

(define mk-kernel-cases
  (list
   (list '(succeed (label "ok"))
         empty-mk-state
         '()
         '(kernel succeed core))
   (list '(fail (label "no"))
         empty-mk-state
         '()
         '(kernel fail core))
   (list '(u:0 =? (sym "cat") (label "bind-cat"))
         empty-mk-state
         '(u:0)
         '(kernel unify-success core))
   (list '(u:0 =? (sym "dog") (label "conflict"))
         u0-cat-state
         '(u:0)
         '(kernel unify-fail core))
   (list '(u:0 =? (sym "cat") (label "forbidden"))
         '(state ()
                 ((u:0 (sym "cat")))
                 ()
                 (label "s"))
         '(u:0)
         '(kernel unify-violates-disequality core))
   (list '(u:0 != (sym "cat") (label "neq"))
         empty-mk-state
         '(u:0)
         '(kernel disequality-success core))
   (list '((sym "cat") != (sym "cat") (label "neq"))
         empty-mk-state
         '()
         '(kernel disequality-fail core))))
