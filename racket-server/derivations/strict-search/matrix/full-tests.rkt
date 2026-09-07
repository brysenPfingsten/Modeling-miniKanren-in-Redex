#lang racket

(require rackunit redex/reduction-semantics
         "full-source.rkt" "stages/full.rkt" "stages/instances.rkt"
         "../shared/maps.rkt" "../shared/wf.rkt" "../shared/kernel.rkt"
         "../shared/stages/schema.rkt" "../shared/stages/maps.rkt"
         "../test-support/stage-checks.rkt"
         (only-in "stages/tests.rkt" check-all-vertical)
         (only-in "../retained-scope/source.rkt" retained-rel-red)
         (only-in "../retained-scope/stages.rkt" RetainedSRel))

(define definitions
  '((r:eq (x:a x:b) (x:a =? x:b (label "eq-body")))
    (r:two (x:q)
           ((r:eq x:q (sym "A") (label "left-call")) ∨
            (∃ (x:unused) (r:eq x:q (sym "B") (label "right-call")) (label "right-fresh"))
            (label "choice")))
    (r:append (x:a x:b x:out)
              (((x:a =? empty (label "empty")) ∧
                (r:eq x:b x:out (label "base-result")) (label "base")) ∨
               (∃ (x:head x:tail x:rest)
                  (((x:a =? (x:head : x:tail) (label "split")) ∧
                    (x:out =? (x:head : x:rest) (label "result")) (label "cons")) ∧
                   (r:append x:tail x:b x:rest (label "recursive-call")) (label "recur"))
                  (label "cons-fresh")) (label "append-choice")))
    (r:even (x:xs)
            ((x:xs =? empty (label "even-empty")) ∨
             (∃ (x:a x:rest)
                ((x:xs =? (x:a : x:rest) (label "even-split")) ∧
                 (r:odd x:rest (label "odd-call")) (label "even-step")) (label "even-fresh"))
             (label "even-choice")))
    (r:odd (x:xs)
           (∃ (x:a x:rest)
              ((x:xs =? (x:a : x:rest) (label "odd-split")) ∧
               (r:even x:rest (label "even-call")) (label "odd-step")) (label "odd-fresh")))
    (r:repeat (x:q)
              ((r:eq x:q (sym "A") (label "repeat-answer")) ∨
               (suspend (r:repeat x:q (label "repeat-call")) (label "explicit-pause"))
               (label "repeat-choice")))
    (r:fresh (x:old)
              (∃ (x:unused x:new) (r:eq x:new x:old (label "fresh-alias")) (label "relation-fresh")))
    (r:loop () (r:loop (label "loop")))))

(define finite-goals
  (list
   '(∃ (x:q) (r:two x:q (label "query")) (label "query-fresh"))
   '(∃ (x:q)
       ((r:two x:q (label "query")) ∧
        (suspend (r:eq x:q (sym "B") (label "pending-filter")) (label "filter-delay"))
        (label "pending-bind")) (label "query-fresh"))
   '(∃ (x:q)
       (r:append ((sym "a") : ((sym "b") : empty)) ((sym "c") : empty) x:q (label "append-query"))
       (label "query-fresh"))
   '(r:even ((sym "a") : ((sym "b") : empty)) (label "mutual-query"))
   '(∃ (x:outer)
       ((r:eq x:outer (sym "old") (label "before-delay")) ∧
        (suspend (r:fresh x:outer (label "after-delay")) (label "allocation-delay"))
        (label "retain-old")) (label "outer-fresh"))
   '(∃ (x:q)
       ((suspend (suspend (r:eq x:q (sym "A") (label "A")) (label "A-inner")) (label "A-outer")) ∨
        ((suspend (r:eq x:q (sym "B") (label "B")) (label "B-delay")) ∨
         (suspend (r:eq x:q (sym "C") (label "C")) (label "C-delay")) (label "inner-rail"))
        (label "outer-rail")) (label "query-fresh"))))

(define (check-edge source)
  (define e (Q-SE source))
  (define n (Q-SN source))
  (check-equal? (Q-EN e) n)
  (check-true (wf-s-rel? source))
  (check-true (wf-e-rel? e))
  (check-true (wf-n-rel? n))
  (define edges (apply-reduction-relation/tag-with-names strict-s-rel-red source))
  (check-equal? edges (apply-reduction-relation/tag-with-names retained-rel-red source))
  (check-equal? (map (lambda (edge) (list (first edge) (Q-SE (second edge)))) edges)
                (apply-reduction-relation/tag-with-names strict-e-rel-red e))
  (check-equal? (map (lambda (edge) (list (first edge) (Q-SN (second edge)))) edges)
                (apply-reduction-relation/tag-with-names strict-n-rel-red n))
  edges)

(define (check-path current [fuel 3000])
  (match (check-edge current)
    ['() (check-true (s-rel-frontier? current)) current]
    [(list (list _ next))
     (when (zero? fuel) (error 'check-path "finite fixture exhausted"))
     (check-path next (sub1 fuel))]))

(define (check-stages source)
  (check-row SRel strict-s-rel-red source)
  (check-row ERel strict-e-rel-red (Q-SE source))
  (check-row NRel strict-n-rel-red (Q-SN source))
  (check-all-vertical source SRel ERel NRel)
  (for ([operations (in-list
                     (list (list decompose d-step d-trace)
                           (list initial-Z z-step z-trace)
                           (list initial-M m-step m-trace)
                           (list initial-B b-step b-trace)))])
    (match-define (list initial step trace) operations)
    (define start (initial RetainedSRel source))
    (check-equal? start (initial SRel source))
    (for ([current (in-list (cons start (map second (trace RetainedSRel start))))])
      (check-equal? (step RetainedSRel current) (step SRel current)))))

(define (advance-program program)
  (match-define `(program ,environment ,frontier) program)
  `(program ,environment (advance ,frontier)))

(module+ test
  (for* ([goal (in-list finite-goals)] [sparse? (in-list '(#f #t))])
    (test-case (format "full native relation scope and all stage squares sparse=~a: ~s" sparse? goal)
      (define source
        (s-rel-query-initial goal #:relations definitions
                             #:owners (if sparse?
                                          '(Owners (Owner (u:9 u:2) (label "sparse"))
                                                   (Owner () (label "unused"))) '(Owners))))
      (define frontier (check-path source))
      (check-stages source)
      (match-define `(program ,environment ,body) frontier)
      (define collection `(program ,environment (collect ,body)))
      (define complete (check-path collection))
      (check-stages collection)
      (check-true (s-rel-observation? complete))
      (define advanced (check-path (advance-program frontier)))
      (check-stages (advance-program frontier))
      (match-define `(program ,_ ,advanced-body) advanced)
      (check-equal? (check-path `(program ,environment (collect ,advanced-body))) complete)))

  (test-case "program frame retains environment and call substitution is one eager step"
    (define source (s-rel-query-initial '(r:eq (sym "A") (sym "A") (label "call"))
                                        #:relations definitions))
    (match-define (M control continuation) (initial-M SRel source))
    (check-equal? (frame-environment (Z-frames (decode-MZ (M control continuation)))) definitions)
    (match-define (list "eval-call" (M next kept)) (m-step SRel (initial-M SRel source)))
    (check-equal? continuation kept)
    (check-equal? next '(eval (Owners) ((sym "A") =? (sym "A") (label "eq-body"))
                              (state () () () (label "initial"))))
    (check-equal? (map first (d-trace SRel (decompose SRel source)))
                  '("eval-call" "eval-atom" "commit-one")))

  (test-case "explicit suspension makes recursive boundaries productive"
    (define initial (s-rel-query-initial
                     '(∃ (x:q) (r:repeat x:q (label "query")) (label "fresh"))
                     #:relations definitions))
    (define (rounds frontier remaining)
      (check-true (s-rel-frontier? frontier))
      (check-false (s-rel-observation? frontier))
      (unless (zero? remaining)
        (define computation (advance-program frontier))
        (check-stages computation)
        (rounds (check-path computation) (sub1 remaining))))
    (rounds (check-path initial) 4))

  (test-case "unguarded recursion remains running without hidden Delay or early commitment"
    (define initial
      (s-rel-query-initial '((succeed (label "candidate")) ∨
                            (r:loop (label "recursive-right")) (label "strict-choice"))
                           #:relations definitions))
    (define (bounded current remaining labels)
      (check-false (s-rel-frontier? current))
      (cond
        [(zero? remaining) (reverse labels)]
        [else
         (match-define (list (list label next)) (check-edge current))
         (bounded next (sub1 remaining) (cons label labels))]))
    (check-equal? (bounded initial 24 '())
                  (append '("eval-disj" "eval-atom") (make-list 22 "eval-call"))))

  (test-case "full WF rejects undefined/arity/capture/duplicate definitions and lexical actuals"
    (define good (s-rel-query-initial '(r:eq (sym "A") (sym "A") (label "ok"))
                                     #:relations definitions))
    (check-true (wf-s-rel? good))
    (for ([bad (in-list
                (list (s-rel-query-initial '(r:missing (label "bad")) #:relations definitions)
                      (s-rel-query-initial '(r:eq (sym "A") (label "bad")) #:relations definitions)
                      (s-rel-query-initial '(r:eq x:free (sym "A") (label "bad")) #:relations definitions)
                      (s-rel-query-initial '(r:x (label "bad"))
                                           #:relations '((r:x () (u:9 =? (sym "A") (label "capture")))))
                      (s-rel-query-initial '(r:x (label "bad"))
                                           #:relations '((r:x () (succeed (label "a")))
                                                         (r:x () (succeed (label "b")))))))])
      (check-false (wf-s-rel? bad)))
    (check-false (wf-s? good))
    (check-exn exn:fail:contract? (lambda () (initial-M S good))))

  (test-case "status inspects pending syntax without evaluating the selected operation"
    (define state '(state () () () (label "initial")))
    (define sources
      (list
       (s-rel-query-initial '(r:loop (label "unproductive")) #:relations definitions)
       (s-rel-query-initial '(r:missing (label "undefined")) #:relations definitions)
       `(program ,definitions (commit (force (One (Owners) ,state))))
       `(program ,definitions (More (Delay (Owners) (eval (Owners) (r:loop (label "later")) ,state))))
       `(program ,definitions (Emit (Owners) (Answer (Owners) ,state) (Done (Owners))))
       `(program ,definitions (commit (eval (Owners) (fail (label "work")) ,state)))))
    (for ([source (in-list sources)]
          [expected (in-list '(running stuck stuck paused complete running))])
      (check-equal? (s-rel-status source) expected)
      (check-equal? (e-rel-status (Q-SE source)) expected)
      (check-equal? (n-rel-status (Q-SN source)) expected))
    ;; The pending failure remains eval; status has not contracted it into
    ;; Empty or committed Done, and an unproductive call is never entered.
    (check-equal? (last sources)
                  `(program ,definitions (commit (eval (Owners) (fail (label "work")) ,state)))))

  (test-case "call substitution preserves fresh shadowing and parameter positions"
    (define environment
      '((r:shadow (x:q x:other)
                  (∃ (x:q) ((x:q =? x:other (label "local")) ∧
                             (r:eq x:other x:q (label "call")) (label "both")) (label "fresh")))))
    (check-equal?
     (instantiate-relation environment '(r:shadow u:9 u:2 (label "entry")))
     '(∃ (x:q) ((x:q =? u:2 (label "local")) ∧
                  (r:eq u:2 x:q (label "call")) (label "both")) (label "fresh")))))
