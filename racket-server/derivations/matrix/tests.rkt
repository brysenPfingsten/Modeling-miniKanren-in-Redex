#lang racket

(require rackunit redex/reduction-semantics
         "source-s.rkt" "source-e.rkt" "source-n.rkt"
         "../shared/maps.rkt" "../test-support/corpus.rkt" "../shared/wf.rkt")

(module+ test
  (require (submod "kernel-tests.rkt" test))
  (for ([goal (in-list search-corpus)] [index (in-naturals)])
    (test-case (format "strict representation source ~a" index)
      (define s0 `(render ,(s-initial goal)))
      (define e0 `(render ,(e-initial goal)))
      (define n0 `(render ,(n-initial goal)))
      (check-true (redex-match? StrictS q s0))
      (check-true (redex-match? StrictE q e0))
      (check-true (redex-match? StrictN q n0))
      (check-equal? (Q-SE s0) e0)
      (check-equal? (Q-SN s0) n0)
      (define s-steps (s-trace s0))
      (define e-steps (e-trace e0))
      (define n-steps (n-trace n0))
      (check-equal? (map first s-steps) (map first e-steps))
      (check-equal? (map first s-steps) (map first n-steps))
      ;; Exact every-step vertical squares, including raw named proof counts.
      (for ([s (in-list (cons s0 (map second s-steps)))]
            [e (in-list (cons e0 (map second e-steps)))]
            [n (in-list (cons n0 (map second n-steps)))])
        (check-true (wf-s? s))
        (check-true (wf-e? e))
        (check-true (wf-n? n))
        (check-equal? (Q-SE s) e)
        (check-equal? (Q-EN e) n)
        (check-equal? (Q-SN s) n)
        (check-equal? (Q-SN s) (Q-EN (Q-SE s)))
        (check-equal?
         (for/list ([step (in-list (apply-reduction-relation/tag-with-names strict-s-red s))])
           (list (first step) (Q-SE (second step))))
         (apply-reduction-relation/tag-with-names strict-e-red e)))
      (define s-final (s-run s0))
      (define e-final (e-run e0))
      (define n-final (n-run n0))
      (check-equal? (Q-SE s-final) e-final)
      (check-equal? (Q-SN s-final) n-final)))

  (test-case "sparse support addresses order and unused allocations"
    (define e
      '(eval (∃ (x:new) ((u:9 =? (sym "outer") (label "outer")) ∧
                         (x:new =? u:2 (label "new")) (label "conj")) (label "fresh"))
             (state (Support u:9 u:2 u:7) () () () (label "sparse"))))
    (check-equal? (second (third (Q-EN e))) 3)
    (check-equal? (map first (e-trace e)) (map first (n-trace (Q-EN e)))))

  (test-case "invalid addressing domain is rejected"
    (check-exn exn:fail?
               (lambda () (Q-EN '(One (state (Support u:0 u:0) () () () (label "bad"))))))
    (check-exn exn:fail?
               (lambda () (Q-EN '(eval (u:7 =? (sym "bad") (label "bad"))
                                      (state (Support) () () () (label "bad")))))))

  (test-case "WF rejects invalid world support and shared future goals"
    (check-false (wf-s? '(One (Owners (Owner (u:0 u:0) (label "duplicate")))
                            (state () () () (label "state")))))
    (check-false (wf-s? '(One (Owners) (state ((u:0 (sym "missing"))) () () (label "state")))))
    (check-false (wf-n? '(One (state 1 ((1 (sym "out-of-bounds"))) () () (label "state")))))
    (check-false
     (wf-e? '(bind (Yield (state (Support u:0) () () () (label "left"))
                         (One (state (Support u:1) () () () (label "right"))))
                   (u:0 =? (sym "not-shared") (label "future")))))
    (check-false
     (wf-s? '(bind (Owners)
                   (One (Owners (Owner (u:0) (label "local")))
                        (state () () () (label "state")))
                   (u:0 =? (sym "not-in-prefix") (label "future"))))))

  (test-case "public source budgets reject negative values"
    (for ([run (in-list (list s-run e-run n-run))]
          [initial (in-list (list s-initial e-initial n-initial))]
          [trace (in-list (list s-trace e-trace n-trace))])
      (define start (initial '(succeed (label "budget"))))
      (check-exn exn:fail:contract? (lambda () (run start -1)))
      (check-exn exn:fail:contract? (lambda () (trace start -1))))))

(module+ test
  (define replay-owners '(Owners (Owner (u:9 u:2) (label "sparse"))))
  (define replay-sub '((u:2 (sym "A")) (u:9 u:2)))
  (define replay-trail
    '((u:9 =? u:2 (label "alias")) (u:2 =? (sym "A") (label "value"))))
  (define (replay-witness substitution trail)
    `(One ,replay-owners
          (state ,substitution ((u:9 (sym "avoid"))) ,trail (label "replay"))))
  (define (check-replay-domain witness expected)
    (check-equal? (wf-s? witness) expected)
    (check-equal? (wf-e? (Q-SE witness)) expected)
    (check-equal? (wf-n? (Q-SN witness)) expected))

  (test-case "full row kernels replay sparse alias trails exactly"
    (check-replay-domain (replay-witness replay-sub replay-trail) #t)
    (check-replay-domain (replay-witness '() '()) #t))
  (test-case "stored substitutions require their complete trail"
    (check-replay-domain (replay-witness replay-sub '()) #f)
    (check-replay-domain (replay-witness replay-sub (list (first replay-trail))) #f))
  (test-case "scoped but contradictory trails are rejected"
    (check-replay-domain
     (replay-witness replay-sub
                     '((u:9 =? u:2 (label "alias"))
                       (u:2 =? (sym "B") (label "wrong-value")))) #f)
    (check-replay-domain
     (replay-witness replay-sub
                     (append replay-trail '((u:2 =? (sym "B") (label "failed-unification"))))) #f))
  (test-case "replay preserves exact alias structure and order"
    (check-replay-domain (replay-witness replay-sub (reverse replay-trail)) #f)
    (check-replay-domain
     (replay-witness '((u:2 (sym "A")) (u:9 (sym "A"))) replay-trail) #f)))
