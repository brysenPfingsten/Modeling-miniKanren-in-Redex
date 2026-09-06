#lang racket

;; Shared closed first-order fixtures, independent of any semantic stage.
(provide core-corpus delay-corpus disjunction-corpus search-corpus
         nested-rail-goal)

(define success '(succeed (label "success")))
(define failure '(fail (label "failure")))
(define a '(∃ (x:q) (x:q =? (sym "A") (label "A")) (label "fresh-A")))
(define b '(∃ (x:q) (x:q =? (sym "B") (label "B")) (label "fresh-B")))
(define c '(∃ (x:q) (x:q =? (sym "C") (label "C")) (label "fresh-C")))

(define core-corpus
  (list
   success failure a
   '(∃ () (succeed (label "empty-body")) (label "empty-fresh"))
   '(∃ (x:unused x:q) (x:q =? (nat 7) (label "unused")) (label "multi"))
   '(∃ (x:q) (∃ (x:q) (x:q =? (sym "inner") (label "shadow"))
                 (label "inner-fresh")) (label "outer-fresh"))
   '(∃ (x:q) ((x:q != (sym "A") (label "neq")) ∧
              (x:q =? (sym "A") (label "bad")) (label "conj")) (label "fresh"))
   '(∃ (x:q) (x:q =? (x:q : empty) (label "occurs")) (label "fresh"))
   '(∃ (x:a x:b) ((x:a =? x:b (label "alias")) ∧
                   (x:b =? (sym "ok") (label "value")) (label "conj")) (label "fresh"))
   `(,a ∧ ,success (label "continue"))
   `(,a ∧ ,failure (label "fail-after-allocation"))))

(define delay-corpus
  (append core-corpus
          (for/list ([goal (in-list core-corpus)]) `(suspend ,goal (label "delay")))
          (list `((suspend ,a (label "left-delay")) ∧ ,b (label "bind-delay")))))

(define disjunction-corpus
  (append core-corpus
          (for*/list ([left (in-list (list success failure a))]
                      [right (in-list (list success failure b))])
            `(,left ∨ ,right (label "choice")))
          (list
           `((,a ∨ ,b (label "sibling-fresh")) ∧
             (∃ (x:later) (x:later =? (nat 9) (label "later")) (label "later-fresh"))
             (label "bind-eager-tail"))
           `(∃ (x:shared)
                (((x:shared =? (sym "A") (label "left")) ∨
                  (x:shared =? (sym "B") (label "right")) (label "shared-choice"))
                 ∧ (succeed (label "continue")) (label "conj")) (label "shared")))))

(define nested-rail-goal
  `((suspend (suspend ,a (label "A-inner")) (label "A-outer")) ∨
    ((suspend ,b (label "B-delay")) ∨ (suspend ,c (label "C-delay"))
     (label "inner-choice")) (label "outer-choice")))

(define search-corpus
  (remove-duplicates
   (append delay-corpus disjunction-corpus
           (for*/list ([left (in-list (list success failure a `(suspend ,a (label "delay-A"))))]
                       [right (in-list (list success failure b `(suspend ,b (label "delay-B"))))])
             `(,left ∨ ,right (label "mixed-choice")))
           (list nested-rail-goal
                 `((,a ∨ (suspend ,b (label "delay")) (label "choice")) ∧
                   (∃ (x:next) (succeed (label "bind-done")) (label "fresh-next"))
                   (label "bind-search"))))))
