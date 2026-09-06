#lang racket

(require rackunit redex/reduction-semantics racket/runtime-path
         "shared/grammar-s.rkt" "shared/grammar-e.rkt" "shared/grammar-n.rkt"
         (prefix-in q: "shared/maps.rkt")
         (only-in "retained-scope/source.rkt" ScopeS)
         (prefix-in i: "retained-scope/interpreter.rkt")
         (prefix-in numeric: "source.rkt"))

(define-runtime-path numeric-interpreter "../functional-search/direct-interpreter.rkt")

(define state '(state () () () (label "initial")))
(define goal '(succeed (label "next")))
(define active `(Yield (Owners) (Answer (Owners) ,state) (Empty (Owners))))
(define pending `(More (Delay (Owners) (eval (Owners) ,goal ,state))))

(module+ test
  (test-case "retained and shared S grammars separate Yield Search from More Frontier"
    (for ([predicates
           (in-list
            (list (list (lambda (x) (redex-match? ScopeS SV x))
                        (lambda (x) (redex-match? ScopeS F x))
                        (lambda (x) (redex-match? ScopeS c x)))
                  (list (lambda (x) (redex-match? StrictS SV x))
                        (lambda (x) (redex-match? StrictS F x))
                        (lambda (x) (redex-match? StrictS c x)))))])
      (match-define (list search? frontier? computation?) predicates)
      (check-true (search? active))
      (check-false (frontier? active))
      (check-true (frontier? pending))
      (check-false (computation? pending))
      ;; Deliberately construct the obsolete active spelling as a negative
      ;; grammar witness. It is not an accepted alias or a runtime adapter.
      (check-false (computation? (cons 'More (cdr active))))))

  (test-case "ownerless E and N maps retain the same constructor distinction"
    (for ([row
           (in-list
            (list (list q:Q-SE
                        (lambda (x) (redex-match? StrictE SV x))
                        (lambda (x) (redex-match? StrictE F x))
                        (lambda (x) (redex-match? StrictE c x)))
                  (list q:Q-SN
                        (lambda (x) (redex-match? StrictN SV x))
                        (lambda (x) (redex-match? StrictN F x))
                        (lambda (x) (redex-match? StrictN c x)))))])
      (match-define (list project search? frontier? computation?) row)
      (define search (project active))
      (define frontier (project pending))
      (check-equal? (car search) 'Yield)
      (check-equal? (car frontier) 'More)
      (check-equal? (length frontier) 2)
      (check-true (search? search))
      (check-false (frontier? search))
      (check-true (frontier? frontier))
      (check-false (computation? frontier))
      (check-false (computation? (cons 'More (cdr search))))))

  (test-case "Yield contexts keep eager work and cannot descend beneath Frontier More"
    (define work `(eval (Owners) ,goal ,state))
    (define eager `(Yield (Owners) (Answer (Owners) ,state) ,work))
    (check-true (redex-match? ScopeS c eager))
    (check-false (redex-match? ScopeS SV eager))
    (check-true (redex-match? ScopeS E `(Yield (Owners) (Answer (Owners) ,state) ,(term hole))))
    (check-false (redex-match? ScopeS C `(More (Delay (Owners) ,(term hole))))))

  (test-case "the direct interpreter builds Yield before commitment"
    (define search (i:eval/s `(,goal ∨ ,goal (label "choice")) state '(Owners) '()))
    (check-match search `(Yield (Owners) (Answer (Owners) ,_) (One (Owners) ,_)))
    (check-true (redex-match? ScopeS SV search))
    (check-match (i:commit/s search) `(Emit (Owners) ,_ (Last (Owners) ,_))))

  (test-case "commit retains unary More and public advance crosses its Delay"
    (define search (i:eval/s `(suspend ,goal (label "delay")) state '(Owners) '()))
    (define frontier (i:commit/s search))
    (check-equal? frontier `(More ,search))
    (check-match (i:resume-once frontier) `(Forced (Owners) (Last (Owners) ,_))))

  (test-case "the numeric comparison source uses Yield without a More alias"
    (check-true (numeric:search-value? '(Yield state (Empty 0))))
    (check-false (numeric:search-value? '(More state (Empty 0))))
    (check-true (procedure? (dynamic-require numeric-interpreter 'Yield)))
    (for ([name (in-list '(More More? More-state More-rest))])
      (check-equal? (dynamic-require numeric-interpreter name (lambda () 'absent)) 'absent))))
