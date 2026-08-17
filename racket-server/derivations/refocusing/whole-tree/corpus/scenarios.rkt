#lang racket

(provide nested-scope-witness-goal
         late-hoist-witness-goal
         rail-turn-witness-goal
         right-active-fresh-witness-goal)

;; The outer allocation becomes a FrontierFresh and owns the complete search.
;; The inner allocation is branch-local: it owns the two inner answers, but not
;; the outer-right answer.
(define nested-scope-witness-goal
  '(fresh (x:outer)
          (disj
           (fresh (x:inner)
                  (disj
                   (put (x:outer : x:inner) (label "inner-left"))
                   (put (x:outer : x:inner) (label "inner-right"))
                   (label "inner-split"))
                  (label "branch-fresh"))
           (put x:outer (label "outer-right"))
           (label "outer-split"))
          (label "outer-fresh")))

(define late-hoist-witness-goal
  '(conj
    (disj (put (sym "left") (label "left"))
          (put (sym "right") (label "right"))
          (label "split"))
    (succeed (label "continue"))
    (label "and")))

(define rail-turn-witness-goal
  '(disj
    (suspend (put (sym "left") (label "left"))
             (label "left-delay"))
    (suspend (put (sym "right") (label "right"))
             (label "right-delay"))
    (label "split")))

;; The inner delayed-left choice rotates to DisjR while its fresh scope remains
;; unfinished under an outer conjunction. Its right branch then settles and
;; exercises the right-active form of expose-choice-through-work-fresh.
(define right-active-fresh-witness-goal
  '(conj
    (conj
     (fresh (x:q)
            (put x:q (label "seed"))
            (label "fresh"))
     (disj
      (suspend (put (sym "later") (label "later"))
               (label "delay"))
      (put (sym "now") (label "now"))
      (label "split"))
     (label "seed-and-choice"))
    (succeed (label "continue"))
    (label "outer-and")))
