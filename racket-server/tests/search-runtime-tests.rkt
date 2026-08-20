#lang racket

(require rackunit
         rackunit/text-ui
         "../src/search-runtime.rkt"
         "../src/search-strategy.rkt"
         "../src/sexpr-read.rkt"
         "../src/transpiler.rkt"
         "./example-compat-tests.rkt")

(provide SEARCH-RUNTIME)

(define (example-src label)
  (for/first ([pr (in-list (frontend-example-programs))]
              #:do [(match-define (cons example-label src) pr)]
              #:when (equal? example-label label))
    src))

(define (parse-src/canonical src)
  (parse-prog/canonical (read-all-sexprs (open-input-string src))))

(define factored-continuation-micro-program
  "(run 2 (q)
     (conj
       (disj
         (== q 'continuation)
         (== q 'witness))
       (== q q)))")

(define right-active-rail-cfg
  '(()
    (More
     (DisjR (Owners)
            (Dead (Owners))
            (Returned (Owners)
                      (state () () () (label "right")))))))

(define right-active-rail-next
  '(()
    (Emit (Owners)
          (Answer (Owners)
                  (state () () () (label "right")))
          (More (Dead (Owners))))))

(define (collect-step-names stepper cfg [remaining 8])
  (cond
    [(zero? remaining) '()]
    [else
     (match (stepper cfg)
       ['() '()]
       [(list (list name next))
        (cons name
              (collect-step-names stepper next (sub1 remaining)))])]))

(define/provide-test-suite SEARCH-RUNTIME
  (test-case "search strategy is scheduler-only and rejects retired hoist data"
    (check-equal? default-search-strategy (search-strategy "rail"))
    (check-equal? (search-strategy->jsexpr (search-strategy "flip"))
                  (hasheq 'scheduler "flip"))
    (check-equal? (normalize-search-strategy (hasheq 'scheduler "dfs"))
                  (search-strategy "dfs"))
    (check-exn exn:fail?
               (lambda ()
                 (normalize-search-strategy
                  (hasheq 'hoist "late" 'scheduler "rail"))))
    (check-exn exn:fail?
               (lambda ()
                 (normalize-search-strategy (search-strategy "zigzag")))))

  (test-case "strategy registry covers every surfaced structured strategy"
    (define-values (cfg0 _html) (parse-src/canonical (example-src "fives/fours")))
    (for ([strategy (in-list all-surfaced-search-strategies)])
      (match-define (strategy-spec spec-strategy _ in-domain? well-formed?)
        (lookup-strategy-spec strategy))
      (check-equal? spec-strategy
                    strategy)
      (check-equal? (in-domain? cfg0)
                    (search-config-in-domain? strategy cfg0))
      (check-equal? (well-formed? cfg0)
                    (search-config-well-formed? strategy cfg0))))

  (test-case "strategy lookup returns the same internal stepper as the registry"
    (define-values (cfg0 _html) (parse-src/canonical (example-src "fives/fours")))
    (for ([strategy (in-list all-surfaced-search-strategies)])
      (match-define (strategy-spec _ step-once _ _) (lookup-strategy-spec strategy))
      (check-equal? (step-once cfg0)
                    ((lookup-search-step-once strategy) cfg0))))

  (test-case "right-active search is rail-only in the runtime domain"
    (for ([strategy (in-list (list (search-strategy "dfs")
                                   (search-strategy "flip")))])
      (check-false (search-config-in-domain? strategy right-active-rail-cfg))
      (check-exn exn:fail?
                 (lambda ()
                   (check-search-config strategy right-active-rail-cfg)))
      (check-exn exn:fail?
                 (lambda ()
                   ((lookup-search-step-once strategy)
                    right-active-rail-cfg))))

    (define rail (search-strategy "rail"))
    (check-true (search-config-in-domain? rail right-active-rail-cfg))
    (check-true (search-config-well-formed? rail right-active-rail-cfg))
    (check-not-exn
     (lambda ()
       (check-search-config rail right-active-rail-cfg)))
    (check-equal?
     ((lookup-search-step-once rail) right-active-rail-cfg)
     (list (list "commit-right-choice-answer"
                 right-active-rail-next))))

  (test-case "factored flip witness continues past expand-disjunction"
    (define-values (cfg0 _html)
      (parse-prog/canonical
       (read-all-sexprs (open-input-string factored-continuation-micro-program))
       #:source-mode "micro"))
    (define names
      (collect-step-names
       (lookup-search-step-once (search-strategy "flip"))
       cfg0
       6))
    (check-equal? (take names 5)
                  '("allocate-fresh"
                    "expand-conjunction"
                    "expand-disjunction"
                    "unify-success"
                    "resume-left-choice-success"))))

(module+ test
  (run-tests SEARCH-RUNTIME))
