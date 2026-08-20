#lang racket

(require rackunit
         rackunit/text-ui
         "../src/minikanren.rkt")

(module wrapper-usage racket
  (require "../src/minikanren.rkt")
  (provide wrapper-session
           wrapper-flip-session
           wrapper-bounded-results)

  (defrel (same x y)
    (== x y))

  (define wrapper-session
    (run* (q)
      (same q 'cat)))

  (define wrapper-flip-session
    (parameterize ([current-minikanren-search-strategy
                    (search-strategy "flip")])
      (run* (q)
        (same q 'dog))))

  (define wrapper-bounded-results
    (run 2 (q)
      (conde
        [(== q 'a)]
        [(== q 'b)]
        [(== q 'c)]))))

(require 'wrapper-usage)

(define/provide-test-suite MINIKANREN-LIBRARY
  (test-case "run* returns reified answers through the modeled semantics"
    (check-equal? wrapper-session
                  '(cat)))

  (test-case "wrapper respects the current search-strategy parameter"
    (check-equal? wrapper-flip-session
                  '(dog)))

  (test-case "run stops after the requested number of answers"
    (check-equal? wrapper-bounded-results
                  '(a b)))

  (test-case "evaluator accumulates defrel forms and returns reified answers on run"
    (define evaluator
      (make-minikanren-evaluator))
    (void
     (minikanren-eval! evaluator
                       '(defrel (same x y)
                          (== x y))))
    (check-equal? (minikanren-eval! evaluator
                                    '(run 1 (q)
                                       (same q 'otter)))
                  '(otter)))

  (test-case "evaluator processes multi-form source incrementally"
    (define evaluator
      (make-minikanren-evaluator))
    (check-equal? (minikanren-eval-source!
                   evaluator
                   "(defrel (same x y)
                      (== x y))
                    (run* (q)
                      (same q 'seal))")
                  '(seal))))

(module+ test
  (run-tests MINIKANREN-LIBRARY))
