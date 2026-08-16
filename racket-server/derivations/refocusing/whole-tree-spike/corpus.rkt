#lang racket

(require "./main.rkt")

(provide (struct-out scenario)
         scenarios
         scenario-by-name
         scenario-semantics
         scenario-initial-tree)

(struct scenario (name index goal hoist scheduler expected-answers)
  #:transparent)

(define scenarios
  (list
   (scenario
    "simple success"
    'core
    '(succeed (label "ok"))
    'none
    'dfs
    '((state unit)))
   (scenario
    "simple failure"
    'core
    '(fail (label "no"))
    'none
    'dfs
    '())
   (scenario
    "conjunction handoff"
    'core
    '(conj (put (sym "first") (label "first"))
           (put (sym "second") (label "second"))
           (label "and"))
    'none
    'dfs
    '((state (sym "second"))))
   (scenario
    "two disjunction answers"
    'disj
    '(disj (put (sym "left") (label "left"))
           (put (sym "right") (label "right"))
           (label "split"))
    'late
    'dfs
   '((state (sym "left"))
      (state (sym "right"))))
   (scenario
    "successful left failed right"
    'disj
    '(disj (put (sym "left") (label "left"))
           (fail (label "right-fail"))
           (label "split"))
    'late
    'dfs
    '((state (sym "left"))))
   (scenario
    "failed left branch"
    'disj
    '(disj (fail (label "left-fail"))
           (put (sym "right") (label "right"))
           (label "split"))
    'late
    'dfs
    '((state (sym "right"))))
   (scenario
    "both disjunction branches fail"
    'disj
    '(disj (fail (label "left-fail"))
           (fail (label "right-fail"))
           (label "split"))
    'late
    'dfs
    '())
   (scenario
    "frontier fresh success"
    'core
    '(fresh (x:q)
            (put x:q (label "answer"))
            (label "fresh"))
    'none
    'dfs
    '((state u:0)))
   (scenario
    "frontier fresh answers"
    'search
    '(fresh (x:q)
            (disj (put x:q (label "left"))
                  (put x:q (label "right"))
                  (label "split"))
            (label "fresh"))
    'late
    'rail
    '((state u:0)
      (state u:0)))
   (scenario
    "frontier fresh answer then failure"
    'disj
    '(fresh (x:q)
            (disj (put x:q (label "answer"))
                  (fail (label "right-fail"))
                  (label "split"))
            (label "fresh"))
    'late
    'dfs
    '((state u:0)))
   (scenario
    "branch-local fresh answer"
    'search
    '(disj (fresh (x:branch)
                  (put x:branch (label "left"))
                  (label "branch-fresh"))
           (put (sym "right") (label "right"))
           (label "split"))
    'late
    'rail
    '((state u:0)
      (state (sym "right"))))
   (scenario
    "branch-local fresh subtree"
    'search
    '(disj (fresh (x:branch)
                  (disj (put x:branch (label "inner-left"))
                        (put x:branch (label "inner-right"))
                        (label "inner-split"))
                  (label "branch-fresh"))
           (put (sym "outer-right") (label "outer-right"))
           (label "outer-split"))
    'late
    'rail
    '((state u:0)
      (state u:0)
      (state (sym "outer-right"))))
   (scenario
    "nested lexical fresh allocation"
    'core
    '(fresh (x:outer x:shadow)
            (fresh (x:shadow)
                   (put (x:outer : x:shadow) (label "pair"))
                   (label "inner-fresh"))
            (label "outer-fresh"))
    'none
    'dfs
    '((state (u:0 : u:2))))
   (scenario
    "top delay"
    'delay
    '(suspend (put (sym "later") (label "later"))
              (label "delay"))
    'none
    'dfs
    '((state (sym "later"))))
   (scenario
    "answer then delayed answer"
    'search
    '(disj (put (sym "now") (label "now"))
           (suspend (put (sym "later") (label "later"))
                    (label "delay"))
           (label "split"))
    'late
    'rail
    '((state (sym "now"))
      (state (sym "later"))))
   (scenario
    "delayed left rail"
    'search
    '(disj (suspend (put (sym "later") (label "later"))
                    (label "delay"))
           (put (sym "now") (label "now"))
           (label "split"))
    'late
    'rail
    '((state (sym "now"))
      (state (sym "later"))))
   (scenario
    "two delayed rail turns"
    'search
    '(disj (suspend (put (sym "left") (label "left"))
                    (label "left-delay"))
           (suspend (put (sym "right") (label "right"))
                    (label "right-delay"))
           (label "split"))
    'late
    'rail
    '((state (sym "left"))
      (state (sym "right"))))
   (scenario
    "rail right failure"
    'search
    '(disj (suspend (put (sym "later") (label "later"))
                    (label "delay"))
           (fail (label "right-fail"))
           (label "split"))
    'late
    'rail
    '((state (sym "later"))))
   (scenario
    "early-late witness"
    'search
    '(conj (disj (put (sym "left") (label "left"))
                 (put (sym "right") (label "right"))
                 (label "split"))
           (succeed (label "continue"))
           (label "and"))
    'late
    'rail
    '((state (sym "left"))
      (state (sym "right"))))))

(define (scenario-by-name name)
  (for/first ([candidate (in-list scenarios)]
              #:when (equal? name (scenario-name candidate)))
    candidate))

(define (scenario-semantics selected)
  (make-semantics (scenario-index selected)
                  #:hoist (scenario-hoist selected)
                  #:scheduler (scenario-scheduler selected)))

(define (scenario-initial-tree selected)
  (initial-tree (scenario-goal selected)))
