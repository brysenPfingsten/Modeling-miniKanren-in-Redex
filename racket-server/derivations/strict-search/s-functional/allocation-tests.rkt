#lang racket
(require rackunit "../test-support/witnesses.rkt"
         (prefix-in d: "00-direct.rkt")
         (prefix-in q: "../shared/maps.rkt")
         (prefix-in bridge: "../matrix/interpreter-oracle.rkt")
         (prefix-in rhs: "../a7-a9/05-registers.rkt"))

(module+ test
  ;; These unequal S observations have equal E (and therefore N) images.
  ;; They are concrete losses of provenance, not claims of answer differences.
  (define no-binder '(succeed (label "ok")))
  (define empty-binder `(∃ () ,no-binder (label "empty")))
  (define grouped '(∃ (x:a x:b) (succeed (label "ok")) (label "pair")))
  (define nested
    '(∃ (x:a) (∃ (x:b) (succeed (label "ok")) (label "second")) (label "first")))
  (for ([pair (in-list (list (list no-binder empty-binder) (list grouped nested)))])
    (match-define (list left right) pair)
    (define l (d:collect-all (d:run left)))
    (define r (d:collect-all (d:run right)))
    (check-not-equal? l r)
    (check-equal? (q:Q-SE l) (q:Q-SE r))
    (check-equal? (q:Q-SN l) (q:Q-SN r)))
  ;; The established N RHS uses host Fresh/Atom callbacks. The existing test
  ;; bridge changes that interface explicitly, independently of allocation Q.
  (for ([w (in-list validation-witnesses)])
    (match-define `(eval ,goal-n ,state-n) (q:Q-SN (witness-initial w)))
    (define result-s
      (d:collect-all
       (d:run (witness-goal w) #:owners (witness-owners w) #:state (witness-state w))))
    (check-equal? (bridge:observation->direct (q:Q-SN result-s))
                  (rhs:run (bridge:goal->direct goal-n)
                           #:state (bridge:state->direct state-n)))
    (check-equal? (q:Q-SN result-s) (q:Q-EN (q:Q-SE result-s)))))
