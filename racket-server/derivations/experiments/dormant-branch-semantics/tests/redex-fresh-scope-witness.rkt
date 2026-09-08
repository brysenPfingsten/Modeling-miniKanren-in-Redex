#lang racket

(require racket/match
         redex/reduction-semantics
         "../../../../src/sexpr-read.rkt"
         "../../../../src/transpiler.rkt"
         (only-in "../source/reduction-relations/search-dfs-red.rkt"
                  search-dfs-red)
         (only-in "support.rkt" compiled-goal->online-fixture))

(provide branch-fresh-program
         shared-fresh-program
         parse-witness
         print-trace)

;; For this experiment's Redex stepper in DrRacket, evaluate one of:
;;   (require redex)
;;   (traces search-dfs-red (parse-witness branch-fresh-program))
;;   (traces search-dfs-red (parse-witness shared-fresh-program))
;;
;; The shell here is headless, so this file only compiles/prints terminal traces.

(define branch-fresh-program
  "(run* (q)
  (conde
    [(fresh (x)
       (== x 'left)
       (== q 'left))]
    [(fresh (x)
       (== x 'right)
       (== q 'right))]))")

(define shared-fresh-program
  "(run* (q)
  (fresh (x)
    (conde
      [(== x 'left)
       (== q 'left)]
      [(== x 'right)
       (== q 'right)])))")

;; The compiler produces strict `(program Γ (commit (eval ...)))` syntax.
;; Reuse the goal to initialize this earlier source, then project the empty
;; relation environment: these witnesses use its bare Frontier relation.
(define (parse-witness src)
  (define-values (config _html _query)
    (parse-prog/canonical (read-all-sexprs (open-input-string src))))
  (match (compiled-goal->online-fixture config)
    [`(() ,frontier) frontier]
    [config
     (error 'parse-witness
            "expected an empty relation environment, got ~e"
            config)]))

(module+ test
  (require rackunit)

  (struct witness-result (labels final) #:transparent)

  (define (run-witness/frontier frontier
                                [remaining 32]
                                [rev-labels '()])
    (when (negative? remaining)
      (error 'run-witness/frontier
             "trace exceeded its step bound at ~e"
             frontier))
    (match (apply-reduction-relation/tag-with-names
            search-dfs-red
            frontier)
      ['()
       (witness-result (reverse rev-labels) frontier)]
      [(list (list name frontier^))
       (run-witness/frontier frontier^
                             (sub1 remaining)
                             (cons name rev-labels))]
      [next*
       (error 'run-witness/frontier
              "expected one grammatical successor, got ~e"
              next*)]))

  (define (run-witness src)
    (run-witness/frontier (parse-witness src)))

  (test-case "branch-local fresh allocates once per branch and keeps distinct owners"
    (define result (run-witness branch-fresh-program))
    (check-equal?
     (witness-result-labels result)
     '("allocate-fresh"
       "expand-disjunction"
       "allocate-fresh"
       "expand-conjunction"
       "unify-success"
       "conj-return"
       "unify-success"
       "commit-choice-answer"
       "allocate-fresh"
       "expand-conjunction"
       "unify-success"
       "conj-return"
       "unify-success"
       "finish-success"))
    (check-match
     (witness-result-final result)
     `(Emit
       (Owners (Owner (u:0) (label "f0")))
       (Answer (Owners (Owner (u:1) (label "f2"))) ,_)
       (Last (Owners (Owner (u:2) (label "f6")))
             (Answer (Owners) ,_)))))

  (test-case "shared fresh crosses the boundary once and owns both answers"
    (define result (run-witness shared-fresh-program))
    (check-equal?
     (witness-result-labels result)
     '("allocate-fresh"
       "allocate-fresh"
       "expand-disjunction"
       "expand-conjunction"
       "unify-success"
       "conj-return"
       "unify-success"
       "commit-choice-answer"
       "expand-conjunction"
       "unify-success"
       "conj-return"
       "unify-success"
       "finish-success"))
    (check-match
     (witness-result-final result)
     `(Emit
       (Owners
        (Owner (u:0) (label "f0"))
        (Owner (u:1) (label "f1")))
       (Answer (Owners) ,_)
       (Last (Owners) (Answer (Owners) ,_))))))

(define (print-trace src [step-rel search-dfs-red] [limit 24])
  (define (loop cfg i)
    (printf "CFG ~a:\n~s\n" i cfg)
    (match (apply-reduction-relation/tag-with-names step-rel cfg)
      ['() (void)]
      [(list (list name cfg^))
       (printf "STEP ~a: ~a\n\n" i name)
       (when (< i limit)
         (loop cfg^ (add1 i)))]
      [next*
       (printf "NONDETERMINISTIC:\n~s\n" next*)]))
  (loop (parse-witness src) 0))

(module+ main
  (define choice
    (match (current-command-line-arguments)
      [(vector "shared") 'shared]
      [_ 'branch]))
  (match choice
    ['shared
     (displayln "Printing shared-fresh witness trace.")
     (displayln "In DrRacket, run `(traces search-dfs-red (parse-witness shared-fresh-program))`.")
     (print-trace shared-fresh-program)]
    ['branch
     (displayln "Printing branch-local fresh witness trace.")
     (displayln "In DrRacket, run `(traces search-dfs-red (parse-witness branch-fresh-program))`.")
     (print-trace branch-fresh-program)]))
