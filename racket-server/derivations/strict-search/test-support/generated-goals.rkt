#lang racket

(provide generated-goals)

;; Independent deterministic generation over closed first-order goals. The
;; generator tracks lexical scope and deliberately includes nested shadowing,
;; empty binders, pair terms, disjunction, conjunction, and actual suspension.
;; It does not derive cases from a source relation or its rule table.
(define generated-goals
  (parameterize ([current-pseudo-random-generator (make-pseudo-random-generator)])
    (random-seed 905417)
    (local [(define serial 0)
            (define (fresh-name)
              (set! serial (add1 serial))
              (string->symbol (format "x:generated-~a" serial)))
            (define (term* variables depth)
              (match (random (if (null? variables) 4 5))
                [0 `(nat ,(random 3))]
                [1 `(sym ,(if (zero? (random 2)) "A" "B"))]
                [2 'empty]
                [3 (if (zero? depth)
                       (zero? (random 2))
                       `(,(term* variables (sub1 depth)) :
                         ,(term* variables (sub1 depth))))]
                [4 (list-ref variables (random (length variables)))]))
            (define (atomic variables)
              (match (random 6)
                [0 '(succeed (label "success"))]
                [1 '(fail (label "failure"))]
                [2
                 (define t (term* variables 1))
                 `(,t =? ,t (label "reflexive"))]
                [3 `(,(term* variables 1) != ,(term* variables 1) (label "neq"))]
                [_ `(,(term* variables 1) =? ,(term* variables 1) (label "unify"))]))
            (define (goal depth [variables '()])
              (if (zero? depth)
                  (atomic variables)
                  (match (random 6)
                    [(or 0 1) (atomic variables)]
                    [2
                     (define names
                       (match (random 3)
                         [0 '()]
                         [1 '(x:q)]
                         [2 (list 'x:q (fresh-name))]))
                     `(∃ ,names ,(goal (sub1 depth)
                                       (append names (remove* names variables)))
                         (label "generated-fresh"))]
                    [3 `(suspend ,(goal (sub1 depth) variables) (label "delay"))]
                    [4 `(,(goal (sub1 depth) variables) ∧
                          ,(goal (sub1 depth) variables) (label "conj"))]
                    [5 `(,(goal (sub1 depth) variables) ∨
                          ,(goal (sub1 depth) variables) (label "disj"))])))]
      (for/list ([i (in-range 120)]) (goal (if (< i 80) 4 5))))))

