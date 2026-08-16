#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../kernel-interface.rkt"
         "../kernel-mk.rkt"
         (prefix-in production:
                    "../../../../src/search-lattice/reduction-relations/core-red.rkt"))

(provide kernel-parameter-tests)

(define empty-state
  '(state () () () (label "s")))

(define u0-cat-state
  '(state ((u:0 (sym "cat")))
          ()
          ((u:0 =? (sym "cat") (label "bind-cat")))
          (label "s")))

(define (kernel-results atomic state)
  (judgment-holds
   (kernel-step/mk ,atomic ,state kresult kell)
   (kresult kell)))

(define (restore-test-scope state ambient)
  (match state
    [`(state ,sub ,dis ,trail ,tag)
     `(state ,sub ,dis ,ambient ,trail ,tag)]))

(define (production-kernel-results atomic state ambient)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names
          production:local/base
          `(,atomic ,(restore-test-scope state ambient))))])
    (match-define (list name result) named)
    (list
     (match result
       [`(⊤ (state ,sub ,dis ,_cached-c ,trail ,tag))
        `(KernelSuccess (state ,sub ,dis ,trail ,tag))]
       ['(empty-tree) 'KernelFailure])
     `(kernel ,(string->symbol (~a name)) core))))

(define kernel-cases
  (list
   (list '(succeed (label "ok"))
         empty-state
         `(KernelSuccess ,empty-state)
         '(kernel succeed core))
   (list '(fail (label "no"))
         empty-state
         'KernelFailure
         '(kernel fail core))
   (list '(u:0 =? (sym "cat") (label "bind-cat"))
         empty-state
         `(KernelSuccess ,u0-cat-state)
         '(kernel unify-success core))
   (list '(u:0 =? (sym "dog") (label "conflict"))
         u0-cat-state
         'KernelFailure
         '(kernel unify-fail core))
   (list '(u:0 =? (sym "cat") (label "forbidden"))
         '(state ()
                 ((u:0 (sym "cat")))
                 ()
                 (label "s"))
         'KernelFailure
         '(kernel unify-violates-disequality core))
   (list '(u:0 != (sym "cat") (label "neq"))
         empty-state
         '(KernelSuccess
           (state ()
                  ((u:0 (sym "cat")))
                  ()
                  (label "s")))
         '(kernel disequality-success core))
   (list '((sym "cat") != (sym "cat") (label "neq"))
         empty-state
         'KernelFailure
         '(kernel disequality-fail core))))

(define kernel-parameter-tests
  (test-suite
   "whole-tree Redex column: kernel parameter boundary"

   (test-case
    "protocol results and labels expose only control-relevant shape"
    (check-true
     (redex-match? redex-column-kernel-interface-lang
                   kresult
                   '(KernelSuccess
                     (state private payload))))
    (check-equal?
     (term
      (kernel-success?
       (KernelSuccess (state private payload))))
     #t)
    (check-equal?
     (term (kernel-success? KernelFailure))
     #f)
    (check-equal?
     (term (kernel-label-name (kernel unify-success core)))
     'unify-success)
    (check-equal?
     (term (kernel-label-owner (kernel unify-success core)))
     'core))

   (test-case
    "Kmk state is c-free and its atomic label family is exact"
    (check-true
     (redex-match? redex-column-mk-kernel-lang kst empty-state))
    (check-false
     (redex-match?
      redex-column-mk-kernel-lang
      kst
      '(state () () () () (label "cached-c"))))
    (for ([case (in-list kernel-cases)])
      (match-define (list atomic state result label) case)
      (check-equal? (kernel-results atomic state)
                    (list (list result label))))
    (check-equal?
     (remove-duplicates
      (map (lambda (case) (fourth case)) kernel-cases))
     '((kernel succeed core)
       (kernel fail core)
       (kernel unify-success core)
       (kernel unify-fail core)
       (kernel unify-violates-disequality core)
       (kernel disequality-success core)
       (kernel disequality-fail core))))

   (test-case
    "fresh opening uses marker-owned support and avoids capture"
    (check-equal?
     (term (kernel-fresh/mk (x:a x:b) (u:0)))
     '(u:1 u:2))
    (check-equal?
     (term
      (kernel-open-fresh/mk
       (x:q)
       (conj
        (x:q =? (sym "cat") (label "outer-use"))
        (fresh
         (x:q)
         (x:q =? (sym "dog") (label "inner-use"))
         (label "inner-fresh"))
        (label "and"))
       ()))
     '(OpenedFresh
       (u:0)
       (conj
        (u:0 =? (sym "cat") (label "outer-use"))
        (fresh
         (x:q)
         (x:q =? (sym "dog") (label "inner-use"))
         (label "inner-fresh"))
        (label "and")))))

   (test-case
    "closed canonical query fresh translates to the shared control carrier"
    (define canonical-query
      '(∃ (x:q)
          (x:q =? (sym "cat") (label "eq"))
          (label "query-fresh")))
    (define column-query
      '(fresh
        (x:q)
        (x:q =? (sym "cat") (label "eq"))
        (label "query-fresh")))
    (check-equal?
     (term (canonical-goal->column/mk ,canonical-query))
     column-query)
    (check-true
     (judgment-holds (wf-goal/mk ,column-query () ())))
    (match-define
      '(OpenedFresh (u:0) (u:0 =? (sym "cat") (label "eq")))
      (term
       (kernel-open-fresh/mk
        (x:q)
        (x:q =? (sym "cat") (label "eq"))
        ())))
    (check-true
     (judgment-holds
      (wf-goal/mk
       (u:0 =? (sym "cat") (label "eq"))
       ()
       (u:0)))))

   (test-case
    "state and marked-answer well-formedness are indexed by marker scope"
    (check-true
     (judgment-holds (wf-state-at/mk ,empty-state ())))
    (check-true
     (judgment-holds (wf-state-at/mk ,u0-cat-state (u:0))))
    (check-false
     (judgment-holds (wf-state-at/mk ,u0-cat-state ())))
    (check-true
     (judgment-holds
      (wf-answer-at/mk
       (AnswerFresh
        (u:0)
        (Answer ,u0-cat-state)
        (label "query-fresh"))
       ())))
    (check-false
     (judgment-holds
      (wf-answer-at/mk
       (Answer ,u0-cat-state)
       ()))))

   (test-case
    "successful atomic steps preserve state well-formedness"
    (define preservation-cases
      (list
       (list '(succeed (label "ok")) empty-state '())
       (list '(u:0 =? (sym "cat") (label "eq"))
             empty-state
             '(u:0))
       (list '(u:0 != (sym "cat") (label "neq"))
             empty-state
             '(u:0))))
    (for ([case (in-list preservation-cases)])
      (match-define (list atomic state ambient) case)
      (check-true
       (judgment-holds (wf-state-at/mk ,state ,ambient)))
      (match (kernel-results atomic state)
        [(list (list `(KernelSuccess ,next-state) _label))
         (check-true
          (judgment-holds
           (wf-state-at/mk ,next-state ,ambient)))]
        [other
         (fail-check
          (format "expected one successful kernel result, got ~e"
                  other))])))

   (test-case
    "Kmk atomic judgment agrees with the production core kernel"
    (define case-ambient
      (list '()
            '()
            '(u:0)
            '(u:0)
            '(u:0)
            '(u:0)
            '()))
    (for ([case (in-list kernel-cases)]
          [ambient (in-list case-ambient)])
      (match-define (list atomic state _result _label) case)
      (check-equal?
       (kernel-results atomic state)
       (production-kernel-results atomic state ambient))))

   (test-case
    "observation reifies only the requested marker-owned variables"
    (check-equal?
     (term (kernel-observe/mk (u:0) ,u0-cat-state))
     '((sym "cat")))
    (check-equal?
     (term (kernel-observe/mk (u:1) ,u0-cat-state))
     '(u:1)))))

(module+ main
  (run-tests kernel-parameter-tests))
