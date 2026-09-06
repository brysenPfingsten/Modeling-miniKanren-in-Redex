#lang racket

(require rackunit redex/reduction-semantics
         "source-s.rkt" "source-e.rkt" "source-n.rkt" "features.rkt"
         "../shared/maps.rkt" "../shared/wf.rkt" "../test-support/corpus.rkt")

;; Compare the literal source edges, including their allocation worlds, before
;; comparing the public endpoints. No functional-pipeline implementation is
;; used as an execution oracle here.
(define (check-source-square initial)
  (define s-steps (s-trace initial))
  (define e-initial (Q-SE initial))
  (define n-initial (Q-SN initial))
  (define e-steps (e-trace e-initial))
  (define n-steps (n-trace n-initial))
  (check-equal? (map first s-steps) (map first e-steps))
  (check-equal? (map first s-steps) (map first n-steps))
  (for ([s (in-list (cons initial (map second s-steps)))]
        [e (in-list (cons e-initial (map second e-steps)))]
        [n (in-list (cons n-initial (map second n-steps)))])
    (check-true (wf-s? s))
    (check-true (wf-e? e))
    (check-true (wf-n? n))
    (check-equal? (Q-SE s) e)
    (check-equal? (Q-EN e) n)
    (check-equal? (Q-SN s) n)
    (check-equal?
     (for/list ([step (in-list (apply-reduction-relation/tag-with-names strict-s-red s))])
       (list (first step) (Q-SE (second step))))
     (apply-reduction-relation/tag-with-names strict-e-red e)))
  (s-run initial))

(define (check-rounds frontier complete [fuel 100])
  (check-true (s-frontier? frontier))
  (check-equal? (check-source-square `(collect ,frontier)) complete)
  (cond
    [(s-observation? frontier)
     (check-equal? (check-source-square `(advance ,frontier)) frontier)]
    [else
     (when (zero? fuel) (error 'check-rounds "nonterminating finite corpus"))
     (define labels (map first (s-trace `(advance ,frontier))))
     (check-equal? (count (lambda (label) (equal? label "advance-delay")) labels) 1)
     (check-false (member "collect-delay" labels))
     (check-false (member "render-delay" labels))
     (check-rounds (check-source-square `(advance ,frontier)) complete (sub1 fuel))]))

(module+ test
  (define state '(state () () () (label "initial")))
  (define success '(succeed (label "success")))
  (define nested-delay `(suspend (suspend ,success (label "inner")) (label "outer")))

  (test-case "public resumption and delayed bind expose the stored computation directly"
    (define owners '(Owners (Owner (u:9) (label "saved"))))
    (define body `(eval (Owners) ,success ,state))
    (define delayed `(Delay ,owners ,body))
    (for ([before (in-list (list `(advance (More ,delayed))
                                 `(collect (More ,delayed))
                                 `(render ,delayed)
                                 `(bind (Owners) ,delayed ,success)))]
          [label (in-list '("advance-delay" "collect-delay" "render-delay" "bind-delay"))]
          [after (in-list (list `(Forced ,owners (commit ,body))
                                `(Forced ,owners (collect (commit ,body)))
                                `(Forced ,owners (render ,body))
                                `(Delay ,owners (bind (Owners) ,body ,success))))])
      (check-equal? (s-contract before) (list label after))
      (check-equal? (e-contract (Q-SE before)) (list label (Q-SE after)))
      (check-equal? (n-contract (Q-SN before)) (list label (Q-SN after)))
      (check-source-square before)
      (check-false (member "force-delay" (map first (s-trace before)))))
    (check-equal? (map first (s-trace `(advance (More ,delayed))))
                  '("advance-delay" "eval-atom" "commit-one")))

  (test-case "internal force waits for Search before attaching its pending owners"
    (define outer '(Owners (Owner (u:9) (label "outer"))))
    (define saved '(Owners (Owner (u:0) (label "saved"))))
    (define fresh '(∃ (x:new) (succeed (label "fresh-body")) (label "fresh")))
    (define body `(eval (Owners) ,fresh ,state))
    (define pending `(prefix ,outer (force (Delay ,saved ,body))))
    (define steps (s-trace pending))
    (check-equal? (first steps) `("force-delay" (prefix ,outer (prefix ,saved ,body))))
    (check-equal? (second steps)
                  `("allocate-fresh"
                    (prefix ,outer
                            (prefix ,saved
                                    (eval (Owners (Owner (u:1) (label "fresh")))
                                          (succeed (label "fresh-body")) ,state)))))
    (check-equal? (map first steps)
                  '("force-delay" "allocate-fresh" "eval-atom" "prefix-value" "prefix-value"))
    (check-equal? (check-source-square pending)
                  `(One (Owners (Owner (u:9) (label "outer"))
                                (Owner (u:0) (label "saved"))
                                (Owner (u:1) (label "fresh"))) ,state))
    (check-exn exn:fail:contract? (lambda () (prefix/s saved body)))
    (check-exn exn:fail:contract? (lambda () (prefix/s saved '(Done (Owners)))))
    (check-exn exn:fail:contract?
               (lambda () (prefix/s saved `(More (Delay (Owners) ,body))))))

  (test-case "pending prefix ancestry excludes sibling-private allocations"
    (define outer '(Owners (Owner (u:9) (label "outer"))))
    (define shared '(Owners (Owner (u:0) (label "shared"))))
    (define private '(Owners (Owner (u:1) (label "private"))))
    (define fresh '(∃ (x:new) (succeed (label "fresh-body")) (label "fresh")))
    (define initial
      `(prefix ,outer
               (mplus ,shared (One ,private ,state) (eval (Owners) ,fresh ,state))))
    (check-equal? (check-source-square initial)
                  `(Yield (Owners (Owner (u:9) (label "outer"))
                                 (Owner (u:0) (label "shared")))
                         (Answer ,private ,state)
                         (One (Owners (Owner (u:1) (label "fresh"))) ,state)))
    (check-false (wf-s? `(prefix ,outer (One ,outer ,state))))
    (check-false (wf-s? `(prefix (Owners) (eval (Owners) (u:1 =? (sym "x") (label "bad")) ,state)))))

  (test-case "commit is a native stopping boundary, including raw work beneath Delay"
    (define start (s-query-initial nested-delay))
    (define frontier (s-run start))
    (check-equal? (map first (s-trace start)) '("eval-suspend" "commit-delay"))
    (check-equal? frontier `(More (Delay (Owners) (eval (Owners) (suspend ,success (label "inner")) ,state))))
    (check-true (s-frontier? frontier))
    (check-false (s-observation? frontier))
    (check-false (s-value? frontier))
    (check-equal? (s-trace frontier) '())
    (check-equal? (s-run frontier 0) frontier)
    (check-equal? (Q-SE start) (e-query-initial nested-delay))
    (check-equal? (Q-SN start) (n-query-initial nested-delay)))

  (test-case "advance crosses one exposed delay and preserves existing history"
    (define first (s-run (s-query-initial nested-delay)))
    (define second (check-source-square `(advance ,first)))
    (check-equal? second
                  `(Forced (Owners) (More (Delay (Owners) (eval (Owners) ,success ,state)))))
    (define third (check-source-square `(advance ,second)))
    (check-equal? third `(Forced (Owners) (Forced (Owners) (Last (Owners) (Answer (Owners) ,state)))))
    (check-equal? (s-run `(advance ,third)) third)
    (check-equal? (check-source-square `(collect ,first)) third))

  (test-case "strict work precedes commitment and pending bind can discard candidates"
    (define choice `(,success ∨ ,success (label "choice")))
    (define labels (map first (s-trace (s-query-initial choice))))
    (check-equal? (take labels 4) '("eval-disj" "eval-atom" "eval-atom" "mplus-one"))
    (check-equal? (drop labels 4) '("commit-yield" "commit-one"))
    (define bound `(,choice ∧ (fail (label "continuation-fails")) (label "bind")))
    (define bound-labels (map first (s-trace (s-query-initial bound))))
    (check-false (member "commit-yield" bound-labels))
    (check-equal? (last bound-labels) "commit-empty")
    (check-equal? (s-run (s-query-initial bound)) '(Done (Owners))))

  (test-case "advance inherits shared and Delay Owners but excludes answer-private Owners"
    (define common '(Owners (Owner (u:9) (label "common"))))
    (define private '(Owners (Owner (u:0) (label "answer-private"))))
    (define history '(Owners (Owner () (label "history"))))
    (define local '(Owners (Owner (u:2) (label "delay-local"))))
    (define fresh '(∃ (x:new) (succeed (label "fresh-body")) (label "fresh")))
    (define initial
      `(Emit ,common (Answer ,private ,state)
             (Forced ,history (More (Delay ,local (eval (Owners) ,fresh ,state))))))
    (define final (check-source-square `(advance ,initial)))
    (check-equal? final
                  `(Emit ,common (Answer ,private ,state)
                         (Forced ,history
                                 (Forced ,local
                                         (Last (Owners)
                                               (Answer (Owners (Owner (u:0) (label "fresh"))) ,state))))))
    (check-true (s-observation? final))
    (check-equal? (s-run `(collect ,initial)) final))

  (test-case "feature frontiers admit exactly their Delay and Emit forms"
    (define pending `(More (Delay (Owners) (eval (Owners) ,success ,state))))
    (define emitting `(Emit (Owners) (Answer (Owners) ,state) (Done (Owners))))
    (for ([map-row (in-list (list values Q-SE Q-SN))]
          [core? (in-list (list s-core-frontier? e-core-frontier? n-core-frontier?))]
          [delay? (in-list (list s-delay-frontier? e-delay-frontier? n-delay-frontier?))]
          [disjunction? (in-list (list s-disjunction-frontier? e-disjunction-frontier? n-disjunction-frontier?))])
      (check-false (core? (map-row pending)))
      (check-false (core? (map-row emitting)))
      (check-true (delay? (map-row pending)))
      (check-false (delay? (map-row emitting)))
      (check-false (disjunction? (map-row pending)))
      (check-true (disjunction? (map-row emitting))))
    (check-equal? (s-core-query-initial success) (s-query-initial success))
    (check-equal? (e-core-query-initial success) (e-query-initial success))
    (check-equal? (n-core-query-initial success) (n-query-initial success)))

  (for ([goal (in-list search-corpus)] [index (in-naturals)])
    (test-case (format "incremental S/E/N source square and legacy completion ~a" index)
      (define complete (s-run `(render ,(s-initial goal))))
      (define frontier (check-source-square (s-query-initial goal)))
      (check-rounds frontier complete))))
